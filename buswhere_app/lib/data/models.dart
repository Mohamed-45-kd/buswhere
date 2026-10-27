import 'package:latlong2/latlong.dart';

// Rows from the Supabase tables (see supabase/migrations).

double _d(Object? v) => (v as num).toDouble();
double? _dn(Object? v) => (v as num?)?.toDouble();
DateTime _t(Object? v) => DateTime.parse(v as String).toLocal();

class City {
  City.fromRow(Map<String, dynamic> r)
      : id = r['id'],
        nameSo = r['name_so'],
        nameEn = r['name_en'],
        isActive = r['is_active'],
        sort = r['sort'] ?? 0;
  final String id;
  final String nameSo, nameEn;
  final bool isActive;
  final int sort;
}

class District {
  District.fromRow(Map<String, dynamic> r)
      : id = r['id'],
        cityId = r['city_id'],
        name = r['name'],
        isActive = r['is_active'],
        sort = r['sort'] ?? 0;
  final String id, cityId, name;
  final bool isActive;
  final int sort;
}

class Village {
  Village.fromRow(Map<String, dynamic> r)
      : id = r['id'],
        districtId = r['district_id'],
        nameSo = r['name_so'],
        nameEn = r['name_en'],
        center = LatLng(_d(r['lat']), _d(r['lng'])),
        isActive = r['is_active'];
  final String id, districtId, nameSo, nameEn;
  final LatLng center;
  final bool isActive;
}

class Stop {
  Stop.fromRow(Map<String, dynamic> r)
      : id = r['id'],
        villageId = r['village_id'],
        name = r['name'],
        sub = r['sub'],
        pos = LatLng(_d(r['lat']), _d(r['lng'])),
        sort = r['sort'] ?? 0;
  final String id, villageId, name;
  final String? sub; // landmark hint
  final LatLng pos;
  final int sort;
}

class Bus {
  Bus.fromRow(Map<String, dynamic> r)
      : id = r['id'],
        number = r['number'],
        plate = r['plate'],
        capacity = r['capacity'],
        owner = r['owner'] ?? '';
  final String id;
  final int number;
  final String plate;
  final int capacity;
  final String owner;
}

/// A bus on the road (table bus_live). Position is null until the first GPS fix.
class LiveBus {
  LiveBus.fromRow(Map<String, dynamic> r)
      : busId = r['bus_id'],
        driverId = r['driver_id'],
        driverName = r['driver_name'],
        busNumber = r['bus_number'],
        villageId = r['village_id'],
        destinationId = r['destination_village_id'],
        position = r['lat'] == null ? null : LatLng(_d(r['lat']), _d(r['lng'])),
        speed = _dn(r['speed']),
        online = r['online'],
        full = r['is_full'],
        updatedAt = _t(r['updated_at']);
  final String busId, driverId, driverName, villageId, destinationId;
  final int busNumber;
  final LatLng? position;
  final double? speed; // m/s from the phone, when it knows
  final bool online, full;
  final DateTime updatedAt;

  Duration get age => DateTime.now().difference(updatedAt);

  /// Seen on the map: online, has a fix, and heard from in the last 5 minutes.
  bool get visible => online && position != null && age < const Duration(minutes: 5);

  /// Older than a minute: show "last seen" instead of pretending it's live.
  bool get stale => age > const Duration(minutes: 1);
}

enum WaitStatus { waiting, boarded, picked, expired, cancelled }

class WaitingRequest {
  WaitingRequest.fromRow(Map<String, dynamic> r)
      : id = r['id'],
        villageId = r['village_id'],
        destinationVillageId = r['destination_village_id'],
        stopId = r['stop_id'],
        expiresAt = _t(r['expires_at']),
        status = WaitStatus.values.byName(r['status']);
  final String id, villageId, destinationVillageId, stopId;
  final DateTime expiresAt;
  final WaitStatus status;
}

/// The signed-in driver (rpc driver_me).
class DriverMe {
  DriverMe.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'],
        busNumber = j['bus']?['number'],
        busPlate = j['bus']?['plate'],
        villageId = j['assignment']?['village_id'],
        destinationId = j['assignment']?['destination_village_id'],
        online = j['live']?['online'] ?? true,
        full = j['live']?['full'] ?? false;
  final String id, name;
  final int? busNumber;
  final String? busPlate, villageId, destinationId;
  final bool online, full;
  bool get active => villageId != null;
}

/// A driver row as admins see it.
class DriverRow {
  DriverRow.fromRow(Map<String, dynamic> r)
      : id = r['id'],
        name = r['name'],
        phone = r['phone'],
        busId = r['bus_id'],
        approved = r['approved'],
        signedIn = r['auth_uid'] != null,
        locked = r['locked_until'] != null && _t(r['locked_until']).isAfter(DateTime.now());
  final String id, name, phone;
  final String? busId;
  final bool approved, signedIn, locked;
}
