import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/live_service.dart';
import '../platform/platform.dart' as platform;

/// App-wide state: language and the rider's remembered choices.
/// Driver and admin sessions live in Supabase auth (see LiveService).
class AppState extends ChangeNotifier {
  AppState(this.live, this._prefs) {
    lang = _prefs.getString('lang') ?? 'so';
    cityId = _prefs.getString('city');
    districtId = _prefs.getString('district');
    fromId = _prefs.getString('from');
    toId = _prefs.getString('to');
    stopId = _prefs.getString('stop');
    saveData = _prefs.getBool('saveData') ?? false;
    notify = _prefs.getBool('notify') ?? true;
    favourites = (_prefs.getStringList('favs') ?? []).toSet();
    recent = _prefs.getStringList('recent') ?? [];
    onboarded = _prefs.getBool('onboarded') ?? false;
    role = _prefs.getString('role') ?? 'rider';
    introSeen = _prefs.getBool('introSeen') ?? false;
    online = platform.isOnline();
    platform.onConnectivityChange((o) {
      online = o;
      notifyListeners();
    });
  }

  static Future<AppState> load(LiveService live) async => AppState(live, await SharedPreferences.getInstance());

  final LiveService live;
  final SharedPreferences _prefs;

  late String lang;
  bool get en => lang == 'en';
  String? cityId, districtId, fromId, toId, stopId;
  late bool saveData, notify, onboarded, introSeen;
  late String role; // rider | driver | admin — where the app opens next time
  late Set<String> favourites;
  late List<String> recent;
  bool online = true;

  /// Somali first, English second — swaps when the person picks English.
  String t(String so, String enText) => en ? enText : so;
  String sub(String so, String enText) => en ? so : enText;

  void setLang(String l) {
    lang = l;
    _prefs.setString('lang', l);
    notifyListeners();
  }

  void setIntroSeen() {
    introSeen = true;
    _prefs.setBool('introSeen', true);
  }

  void setRole(String r) {
    role = r;
    onboarded = true;
    _prefs
      ..setString('role', r)
      ..setBool('onboarded', true);
  }

  void setDistrict(String city, String district) {
    cityId = city;
    districtId = district;
    _prefs
      ..setString('city', city)
      ..setString('district', district);
    notifyListeners();
  }

  void setFrom(String v) {
    fromId = v;
    if (toId == v) toId = null;
    stopId = live.stopsOf(v).firstOrNull?.id;
    _prefs.setString('from', v);
    if (stopId != null) _prefs.setString('stop', stopId!);
    _remember(v);
    notifyListeners();
  }

  void setTo(String v) {
    toId = v;
    _prefs.setString('to', v);
    _remember(v);
    notifyListeners();
  }

  void setStop(String s) {
    stopId = s;
    _prefs.setString('stop', s);
    notifyListeners();
  }

  void _remember(String v) {
    recent = [v, ...recent.where((x) => x != v)].take(3).toList();
    _prefs.setStringList('recent', recent);
  }

  void toggleFavourite(String v) {
    favourites.contains(v) ? favourites.remove(v) : favourites.add(v);
    _prefs.setStringList('favs', favourites.toList());
    notifyListeners();
  }

  void setSaveData(bool v) {
    saveData = v;
    _prefs.setBool('saveData', v);
    notifyListeners();
  }

  Future<void> setNotify(bool v) async {
    notify = v;
    _prefs.setBool('notify', v);
    if (v) await platform.requestNotifications();
    notifyListeners();
  }

  /// The saved trip still exists (an admin may have removed a village).
  bool get tripReady => live.villageOrNull(fromId)?.isActive == true && live.villageOrNull(toId)?.isActive == true;
}

/// Gives every widget access to [AppState] and rebuilds on its changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
