import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../platform/platform.dart' as platform;
import 'models.dart';

/// A bus as one rider sees it from their stop.
class BusView {
  BusView({required this.live, required this.bus, required this.eta, required this.matching, required this.distanceM});
  final LiveBus live;
  final Bus? bus;
  final int eta; // minutes to the rider's stop
  final bool matching; // heading to the rider's destination
  final double distanceM;
}

enum LiveEventKind { busNear, busArrived, waitExpired, pickedUp, withdrawnByServer }

class LiveEvent {
  const LiveEvent(this.kind, {this.busNumber, this.minutes, this.reason});
  final LiveEventKind kind;
  final int? busNumber, minutes;
  final String? reason;
}

enum GpsState { off, waiting, ok, denied, unsupported }

/// Client-side store for the Supabase backend: keeps the small public tables
/// in memory, follows them over Realtime (with a polling fallback for weak
/// data), and wraps the RPCs from supabase/migrations.
class LiveService extends ChangeNotifier {
  LiveService(this._db);

  final SupabaseClient _db;
  static const pingEvery = Duration(seconds: 10);
  static const _dist = Distance();

  // Public data
  List<City> cities = [];
  List<District> districts = [];
  List<Village> villages = [];
  List<Stop> stops = [];
  final buses = <String, Bus>{};
  final busLive = <String, LiveBus>{}; // busId → live row
  final _counts = <String, int>{}; // "village|destination|stop" → n
  DateTime lastUpdate = DateTime.now();
  bool ready = false, connected = false;
  String? loadError;

  // Rider
  WaitingRequest? myRequest;
  final _notified = <String>{};

  // Driver
  DriverMe? me;
  GpsState gps = GpsState.off;
  LatLng? lastFix;
  void Function()? _stopGeo;
  Timer? _pingTimer;
  ({double lat, double lng, double? speed, double? heading})? _fix;

  // Admin
  bool isAdmin = false;
  String? adminEmail;
  List<DriverRow> drivers = [];
  Map<String, dynamic>? report;

  RealtimeChannel? _channel;
  Timer? _tick, _poll;
  final _events = StreamController<LiveEvent>.broadcast();
  Stream<LiveEvent> get events => _events.stream;

  String? get _uid => _db.auth.currentUser?.id;

  // ───────────────────────── start-up
  Future<void> start() async {
    try {
      if (_db.auth.currentSession == null) await _db.auth.signInAnonymously();
      await _loadAll();
      await _loadMine();
      ready = true;
      loadError = null;
    } catch (e) {
      loadError = '$e';
      debugPrint('BusWhere load failed: $e');
    }
    _subscribe();
    _tick ??= Timer.periodic(const Duration(seconds: 5), (_) => _onTick());
    _poll ??= Timer.periodic(const Duration(seconds: 20), (_) => _refreshLive());
    notifyListeners();
  }

  Future<void> retry() => start();

  Future<void> _loadAll() async {
    final r = await Future.wait([
      _db.from('cities').select().order('sort'),
      _db.from('districts').select().order('sort'),
      _db.from('villages').select().order('name_so'),
      _db.from('stops').select().order('sort'),
      _db.from('buses').select().order('number'),
    ]);
    cities = r[0].map(City.fromRow).toList();
    districts = r[1].map(District.fromRow).toList();
    villages = r[2].map(Village.fromRow).toList();
    stops = r[3].map(Stop.fromRow).toList();
    buses
      ..clear()
      ..addEntries(r[4].map((x) => MapEntry(x['id'] as String, Bus.fromRow(x))));
    await _refreshLive(notify: false);
  }

  Future<void> _refreshLive({bool notify = true}) async {
    try {
      final r = await Future.wait([_db.from('bus_live').select(), _db.from('waiting_counts').select().gt('n', 0)]);
      busLive
        ..clear()
        ..addEntries(r[0].map((x) => MapEntry(x['bus_id'] as String, LiveBus.fromRow(x))));
      _counts
        ..clear()
        ..addEntries(r[1].map((x) => MapEntry(_key(x), x['n'] as int)));
      lastUpdate = DateTime.now();
      if (notify) notifyListeners();
    } catch (_) {
      // Weak data: keep showing what we have; freshness labels tell the truth.
    }
  }

  Future<void> _loadMine() async {
    final uid = _uid;
    if (uid == null) return;
    final w = await _db.from('waiting_requests').select().eq('rider_uid', uid).eq('status', 'waiting').maybeSingle();
    myRequest = w == null ? null : WaitingRequest.fromRow(w);
    await refreshMe(notify: false);
    final a = await _db.from('admins').select('uid').eq('uid', uid).maybeSingle();
    isAdmin = a != null;
    adminEmail = isAdmin ? _db.auth.currentUser?.email : null;
    if (isAdmin) await loadAdmin(notify: false);
  }

  static String _key(Map<String, dynamic> r) => '${r['village_id']}|${r['destination_village_id']}|${r['stop_id']}';

  void _subscribe() {
    if (_channel != null) return;
    void onRow(String table, PostgresChangePayload p) {
      final row = p.eventType == PostgresChangeEvent.delete ? p.oldRecord : p.newRecord;
      switch (table) {
        case 'bus_live':
          final id = row['bus_id'] as String?;
          if (id == null) return;
          if (p.eventType == PostgresChangeEvent.delete) {
            busLive.remove(id);
          } else {
            busLive[id] = LiveBus.fromRow(p.newRecord);
          }
          if (me != null && row['driver_id'] == me!.id) refreshMe();
        case 'waiting_counts':
          final n = (p.newRecord['n'] as int?) ?? 0;
          if (p.eventType == PostgresChangeEvent.delete || n == 0) {
            _counts.remove(_key(row));
          } else {
            _counts[_key(row)] = n;
          }
        case 'waiting_requests':
          if (p.newRecord['rider_uid'] != _uid) return;
          final w = WaitingRequest.fromRow(p.newRecord);
          if (w.status == WaitStatus.waiting) {
            myRequest = w;
          } else if (myRequest?.id == w.id) {
            myRequest = null;
            if (w.status == WaitStatus.expired) _events.add(const LiveEvent(LiveEventKind.waitExpired));
            if (w.status == WaitStatus.picked) _events.add(const LiveEvent(LiveEventKind.pickedUp));
          }
        case 'village_assignments':
          if (me != null && p.newRecord['driver_id'] == me!.id && p.newRecord['ended_at'] != null) {
            final reason = p.newRecord['end_reason'] as String?;
            if (reason != 'driver') _events.add(LiveEvent(LiveEventKind.withdrawnByServer, reason: reason));
            refreshMe();
          }
        default:
          _loadAll().then((_) => notifyListeners());
          return;
      }
      lastUpdate = DateTime.now();
      notifyListeners();
    }

    var ch = _db.channel('buswhere-live');
    for (final t in ['bus_live', 'waiting_counts', 'waiting_requests', 'village_assignments', 'cities', 'districts', 'villages', 'stops', 'buses']) {
      ch = ch.onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: t, callback: (p) => onRow(t, p));
    }
    _channel = ch.subscribe((status, err) {
      final was = connected;
      connected = status == RealtimeSubscribeStatus.subscribed;
      if (connected && !was) _refreshLive();
      if (was != connected) notifyListeners();
    });
  }

  void _onTick() {
    final mine = myRequest;
    if (mine != null) {
      for (final b in busesFor(mine.villageId, mine.destinationVillageId, mine.stopId)) {
        if (!b.matching || b.live.full || b.live.stale) continue;
        if (b.eta == 0 && _notified.add('${b.live.busId}:here')) {
          _events.add(LiveEvent(LiveEventKind.busArrived, busNumber: b.live.busNumber));
        } else if (b.eta <= 2 && _notified.add('${b.live.busId}:near')) {
          _events.add(LiveEvent(LiveEventKind.busNear, busNumber: b.live.busNumber, minutes: b.eta));
        }
      }
    }
    notifyListeners(); // ages and ETAs move on
  }

  // ───────────────────────── lookups
  City cityById(String id) => cities.firstWhere((c) => c.id == id);
  District districtById(String id) => districts.firstWhere((d) => d.id == id);
  Village villageById(String id) => villages.firstWhere((v) => v.id == id);
  Village? villageOrNull(String? id) => villages.where((v) => v.id == id).firstOrNull;
  Stop stopById(String id) => stops.firstWhere((s) => s.id == id);
  Stop? stopOrNull(String? id) => stops.where((s) => s.id == id).firstOrNull;
  Bus? busById(String? id) => buses[id];
  List<District> districtsOf(String cityId) => districts.where((d) => d.cityId == cityId).toList();
  List<Village> villagesOf(String districtId, {bool activeOnly = true}) =>
      villages.where((v) => v.districtId == districtId && (!activeOnly || v.isActive)).toList();
  List<Stop> stopsOf(String villageId) => stops.where((s) => s.villageId == villageId).toList()..sort((a, b) => a.sort.compareTo(b.sort));

  /// Buses working [villageId] that are near enough to be offered to its riders.
  int activeBusCount(String villageId) {
    final v = villageOrNull(villageId);
    if (v == null) return 0;
    return busLive.values.where((b) => b.villageId == villageId && b.visible && _dist(b.position!, v.center) <= maxRiderDistanceM).length;
  }

  int waitingCount({String? villageId, String? destId, String? stopId}) {
    var n = 0;
    _counts.forEach((k, v) {
      final p = k.split('|');
      if ((villageId == null || p[0] == villageId) && (destId == null || p[1] == destId) && (stopId == null || p[2] == stopId)) n += v;
    });
    return n;
  }

  /// City buses average ~18 km/h; roads are ~1.3× the straight line.
  static int etaMinutes(LatLng from, LatLng to, double? speed) {
    final d = _dist(from, to);
    if (d < 80) return 0;
    final v = (speed != null && speed > 2) ? math.min(speed, 12.0) : 5.0;
    return (d * 1.3 / v / 60).ceil().clamp(1, 99);
  }

  /// A bus further than this from the rider's stop, or later than [maxEtaMin],
  /// is not "available": riders see "No bus available" instead of a 70-minute wait.
  static const maxRiderDistanceM = 6000.0;
  static const maxEtaMin = 30;

  /// Buses working [villageId] that are near enough to be useful: those heading
  /// to [destId] first by ETA, others after.
  List<BusView> busesFor(String villageId, String destId, String? stopId) =>
      _busesFor(villageId, destId, stopId).where((v) => v.distanceM <= maxRiderDistanceM && v.eta <= maxEtaMin).toList();

  /// Buses in the village that are on the road but too far away to offer (for an honest note).
  List<BusView> farBusesFor(String villageId, String destId, String? stopId) =>
      _busesFor(villageId, destId, stopId).where((v) => v.matching && (v.distanceM > maxRiderDistanceM || v.eta > maxEtaMin)).toList();

  List<BusView> _busesFor(String villageId, String destId, String? stopId) {
    final target = stopOrNull(stopId)?.pos ?? villageOrNull(villageId)?.center;
    if (target == null) return [];
    final out = <BusView>[];
    for (final b in busLive.values) {
      if (b.villageId != villageId || !b.visible) continue;
      out.add(BusView(live: b, bus: buses[b.busId], eta: etaMinutes(b.position!, target, b.speed), matching: b.destinationId == destId, distanceM: _dist(b.position!, target)));
    }
    out.sort((x, y) => x.matching != y.matching ? (x.matching ? -1 : 1) : x.eta.compareTo(y.eta));
    return out;
  }

  // ───────────────────────── rider's own position
  LatLng? riderPos;
  double? riderAccuracyM;
  DateTime? riderPosAt;
  bool locating = false;

  /// Asks the phone where the rider is. Returns null, or 'denied' / 'unavailable' / 'timeout' / 'unsupported'.
  Future<String?> locateRider() async {
    locating = true;
    notifyListeners();
    try {
      final p = await platform.currentPosition();
      riderPos = LatLng(p.lat, p.lng);
      riderAccuracyM = p.accuracy;
      riderPosAt = DateTime.now();
      return null;
    } catch (e) {
      return e is String ? e : 'unavailable';
    } finally {
      locating = false;
      notifyListeners();
    }
  }

  /// Closest active village to [p] (by its nearest stop or centre), with the distance.
  ({Village village, double m})? nearestVillage(LatLng p, {String? districtId}) {
    ({Village village, double m})? best;
    for (final v in villages.where((v) => v.isActive && (districtId == null || v.districtId == districtId))) {
      final pts = [v.center, ...stopsOf(v.id).map((s) => s.pos)];
      final m = pts.map((x) => _dist(x, p)).reduce(math.min);
      if (best == null || m < best.m) best = (village: v, m: m);
    }
    return best;
  }

  /// Closest stop of [villageId] to [p], with the distance.
  ({Stop stop, double m})? nearestStopTo(LatLng p, String villageId) {
    ({Stop stop, double m})? best;
    for (final s in stopsOf(villageId)) {
      final m = _dist(s.pos, p);
      if (best == null || m < best.m) best = (stop: s, m: m);
    }
    return best;
  }

  /// Nearest stop of the bus's village, for "Wuxuu joogaa …".
  Stop? nearestStop(LiveBus b) {
    final p = b.position;
    if (p == null) return null;
    final ss = stopsOf(b.villageId);
    if (ss.isEmpty) return null;
    ss.sort((x, y) => _dist(x.pos, p).compareTo(_dist(y.pos, p)));
    return ss.first;
  }

  double distance(LatLng a, LatLng b) => _dist(a, b);

  // ───────────────────────── rider
  /// Returns an error code, or null on success.
  Future<String?> startWaiting(String villageId, String destId, String stopId) => _run(() async {
        final r = await _db.rpc('start_waiting', params: {'p_village': villageId, 'p_destination': destId, 'p_stop': stopId});
        myRequest = WaitingRequest.fromRow(r);
        _notified.clear();
      });

  Future<String?> stopWaiting({bool boarded = false}) => _run(() async {
        await _db.rpc('stop_waiting', params: {'p_boarded': boarded});
        myRequest = null;
      });

  // ───────────────────────── driver
  Future<void> refreshMe({bool notify = true}) async {
    try {
      final j = await _db.rpc('driver_me');
      me = j == null ? null : DriverMe.fromJson(Map<String, dynamic>.from(j));
    } catch (_) {}
    _syncGps();
    if (notify) notifyListeners();
  }

  Future<String?> driverSignIn(String phone, String pin) async {
    try {
      final j = Map<String, dynamic>.from(await _db.rpc('driver_sign_in', params: {'p_phone': phone, 'p_pin': pin}));
      if (j['error'] != null) return j['error'] as String;
      await refreshMe();
      return null;
    } catch (e) {
      return _code(e);
    }
  }

  Future<void> driverSignOut() async {
    await _run(() async {
      if (me?.active == true) await _db.rpc('driver_withdraw');
      await _db.rpc('driver_sign_out');
    });
    me = null;
    _syncGps();
    notifyListeners();
  }

  Future<String?> assign(String villageId, String destId) => _run(() async {
        await _db.rpc('driver_assign', params: {'p_village': villageId, 'p_destination': destId});
        await refreshMe(notify: false);
        _sendPing(force: true);
      });

  Future<String?> changeDestination(String destId) => _run(() async {
        await _db.rpc('driver_change_destination', params: {'p_destination': destId});
        await refreshMe(notify: false);
      });

  Future<String?> withdraw() => _run(() async {
        await _db.rpc('driver_withdraw');
        await refreshMe(notify: false);
      });

  Future<String?> setDriverStatus({bool? online, bool? full}) => _run(() async {
        await _db.rpc('driver_set_status', params: {'p_online': online, 'p_full': full});
        await refreshMe(notify: false);
        if (online == true) _sendPing(force: true);
      });

  Future<int> pickUp(String stopId) async {
    try {
      return (await _db.rpc('driver_pick_up', params: {'p_stop': stopId})) as int;
    } catch (_) {
      return 0;
    }
  }

  LiveBus? get myBus => me == null ? null : busLive.values.where((b) => b.driverId == me!.id).firstOrNull;

  /// GPS runs only while the driver is in a village and online.
  void _syncGps() {
    final want = me?.active == true && me!.online;
    if (want && _stopGeo == null) {
      gps = GpsState.waiting;
      _stopGeo = platform.watchPosition((lat, lng, speed, heading) {
        _fix = (lat: lat, lng: lng, speed: speed, heading: heading);
        lastFix = LatLng(lat, lng);
        final first = gps != GpsState.ok;
        gps = GpsState.ok;
        if (first) {
          _sendPing(force: true);
          notifyListeners();
        }
      }, (err) {
        gps = err == 'denied' ? GpsState.denied : (err == 'unsupported' ? GpsState.unsupported : gps);
        notifyListeners();
      });
      platform.keepScreenOn(true);
      _pingTimer = Timer.periodic(pingEvery, (_) => _sendPing());
    } else if (!want && _stopGeo != null) {
      _stopGeo!();
      _stopGeo = null;
      _pingTimer?.cancel();
      _pingTimer = null;
      platform.keepScreenOn(false);
      gps = GpsState.off;
    }
  }

  DateTime? _lastPing;
  Future<void> _sendPing({bool force = false}) async {
    final f = _fix;
    if (f == null || me?.active != true || me?.online != true) return;
    if (!force && _lastPing != null && DateTime.now().difference(_lastPing!) < const Duration(seconds: 8)) return;
    _lastPing = DateTime.now();
    try {
      await _db.rpc('driver_ping', params: {'p_lat': f.lat, 'p_lng': f.lng, 'p_speed': f.speed, 'p_heading': f.heading});
    } catch (_) {}
  }

  // ───────────────────────── admin
  Future<String?> adminSignIn(String email, String password) async {
    try {
      await _db.auth.signInWithPassword(email: email.trim(), password: password);
      me = null;
      myRequest = null;
      await _loadMine();
      if (!isAdmin) {
        await adminSignOut();
        return 'not-admin';
      }
      notifyListeners();
      return null;
    } on AuthException {
      return 'bad-login';
    } catch (e) {
      return _code(e);
    }
  }

  Future<void> adminSignOut() async {
    await _db.auth.signOut();
    isAdmin = false;
    adminEmail = null;
    drivers = [];
    report = null;
    await _db.auth.signInAnonymously();
    await _loadMine();
    notifyListeners();
  }

  Future<void> loadAdmin({bool notify = true}) async {
    if (!isAdmin) return;
    try {
      final r = await _db.from('drivers').select('id, name, phone, bus_id, approved, auth_uid, locked_until').order('name');
      drivers = r.map(DriverRow.fromRow).toList();
      report = Map<String, dynamic>.from(await _db.rpc('admin_report'));
    } catch (e) {
      debugPrint('admin load failed: $e');
    }
    if (notify) notifyListeners();
  }

  Future<String?> saveDriver({String? id, required String name, required String phone, String? pin, String? busId, bool approved = true}) => _run(() async {
        await _db.rpc('admin_save_driver', params: {'p_id': id, 'p_name': name, 'p_phone': phone, 'p_pin': pin, 'p_bus': busId, 'p_approved': approved});
        await loadAdmin(notify: false);
      });

  Future<String?> adminWithdraw(String driverId) => _run(() => _db.rpc('admin_withdraw_driver', params: {'p_driver': driverId}));

  Future<String?> saveBus({String? id, required int number, required String plate, required int capacity, required String owner}) =>
      _run(() => _db.from('buses').upsert({if (id != null) 'id': id, 'number': number, 'plate': plate, 'capacity': capacity, 'owner': owner}));

  Future<String?> setActive(String table, String id, bool active) => _run(() => _db.from(table).update({'is_active': active}).eq('id', id));

  Future<String?> saveVillage({String? id, required String districtId, required String nameSo, required String nameEn, required LatLng center}) => _run(() async {
        await _db.from('villages').upsert({
          if (id != null) 'id': id,
          'district_id': districtId,
          'name_so': nameSo,
          'name_en': nameEn.isEmpty ? nameSo : nameEn,
          'lat': center.latitude,
          'lng': center.longitude,
        });
        await _loadAll();
      });

  Future<String?> saveStop({String? id, required String villageId, required String name, String? sub, required LatLng pos, int sort = 0}) => _run(() async {
        await _db.from('stops').upsert({
          if (id != null) 'id': id,
          'village_id': villageId,
          'name': name,
          'sub': (sub ?? '').isEmpty ? null : sub,
          'lat': pos.latitude,
          'lng': pos.longitude,
          'sort': sort,
        });
        await _loadAll();
      });

  Future<String?> deleteStop(String id) => _run(() async {
        await _db.from('stops').delete().eq('id', id);
        await _loadAll();
      });

  // ───────────────────────── plumbing
  Future<String?> _run(Future<void> Function() f) async {
    try {
      await f();
      notifyListeners();
      return null;
    } catch (e) {
      notifyListeners();
      return _code(e);
    }
  }

  static String _code(Object e) {
    if (e is PostgrestException) return e.message;
    final s = '$e';
    if (s.contains('SocketException') || s.contains('Failed to fetch') || s.contains('ClientException')) return 'offline';
    return s;
  }

  @override
  void dispose() {
    _tick?.cancel();
    _poll?.cancel();
    _pingTimer?.cancel();
    _stopGeo?.call();
    _channel?.unsubscribe();
    _events.close();
    super.dispose();
  }
}
