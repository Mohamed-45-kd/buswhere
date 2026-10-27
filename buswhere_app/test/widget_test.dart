import 'package:buswhere/data/live_service.dart';
import 'package:buswhere/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase/supabase.dart';

void main() {
  const stop = LatLng(9.5572, 44.0890);

  test('bus at the stop reads "Hadda" (0 minutes)', () {
    expect(LiveService.etaMinutes(const LatLng(9.5573, 44.0891), stop, null), 0);
  });

  test('ETA grows with distance and falls with speed', () {
    const far = LatLng(9.5480, 44.0700); // about 2.3 km away
    final slow = LiveService.etaMinutes(far, stop, null);
    final fast = LiveService.etaMinutes(far, stop, 10);
    expect(slow, greaterThan(fast));
    expect(slow, inInclusiveRange(8, 12));
  });

  test('a bus not heard from for 5 minutes is hidden; after 1 minute it is stale', () {
    LiveBus at(Duration ago) => LiveBus.fromRow({
          'bus_id': 'b',
          'driver_id': 'd',
          'driver_name': 'Cali',
          'bus_number': 12,
          'village_id': 'v',
          'destination_village_id': 'w',
          'lat': 9.55,
          'lng': 44.08,
          'speed': null,
          'online': true,
          'is_full': false,
          'updated_at': DateTime.now().subtract(ago).toUtc().toIso8601String(),
        });
    expect(at(const Duration(seconds: 10)).visible, isTrue);
    expect(at(const Duration(seconds: 10)).stale, isFalse);
    expect(at(const Duration(minutes: 2)).stale, isTrue);
    expect(at(const Duration(minutes: 6)).visible, isFalse);
  });

  group('availability', () {
    LiveService store() {
      final live = LiveService(SupabaseClient('http://localhost', 'test-key'));
      live.villages = [Village.fromRow({'id': 'v', 'district_id': 'd', 'name_so': 'V', 'name_en': 'V', 'lat': 9.5572, 'lng': 44.0890, 'is_active': true})];
      live.stops = [Stop.fromRow({'id': 's', 'village_id': 'v', 'name': 'Isgoyska weyn', 'sub': null, 'lat': 9.5572, 'lng': 44.0890, 'sort': 0})];
      return live;
    }

    LiveBus busAt(String id, double lat, double lng) => LiveBus.fromRow({
          'bus_id': id, 'driver_id': 'd$id', 'driver_name': 'X', 'bus_number': 1, 'village_id': 'v', 'destination_village_id': 'w',
          'lat': lat, 'lng': lng, 'speed': null, 'online': true, 'is_full': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });

    test('a bus 2 km away is available; one 40 km away is not', () {
      final live = store();
      live.busLive['near'] = busAt('near', 9.5480, 44.0700);
      live.busLive['far'] = busAt('far', 9.9000, 44.0700);
      expect(live.busesFor('v', 'w', 's').map((b) => b.live.busId), ['near']);
      expect(live.farBusesFor('v', 'w', 's').map((b) => b.live.busId), ['far']);
    });

    test('nearest stop and village from a GPS point', () {
      final live = store();
      final n = live.nearestStopTo(const LatLng(9.5575, 44.0893), 'v');
      expect(n!.stop.id, 's');
      expect(n.m, lessThan(60));
      expect(live.nearestVillage(const LatLng(9.5575, 44.0893))!.village.id, 'v');
    });
  });
}
