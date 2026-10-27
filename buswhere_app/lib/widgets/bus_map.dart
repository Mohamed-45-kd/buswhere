import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/tokens.dart';
import 'core.dart';

class MapBus {
  const MapBus({required this.id, required this.pos, required this.label, this.selected = false, this.muted = false});
  final String id;
  final LatLng pos;
  final String label; // e.g. "5 daq" or "Hadda"
  final bool selected, muted;
}

class MapPlace {
  const MapPlace(this.pos, this.label, {this.kind = PlaceKind.destination, this.count, this.id, this.accuracyM});
  final LatLng pos;
  final String label;
  final PlaceKind kind;
  final int? count;
  final String? id; // for tappable stops
  final double? accuracyM; // for the GPS dot
}

/// me = the rider's chosen stop · stop = another stop they can pick · gps = where the phone says they are.
enum PlaceKind { me, destination, waiting, stop, gps }

/// Light, low-detail CARTO/OSM map with BusWhere markers on top.
class BusMap extends StatefulWidget {
  const BusMap({super.key, required this.center, this.zoom = 15, this.buses = const [], this.places = const [], this.route = const [], this.onBusTap, this.onTilesFailed, this.focus, this.onMapTap, this.onPlaceTap});
  final LatLng center;
  final double zoom;
  final List<MapBus> buses;
  final List<MapPlace> places;
  final List<LatLng> route;
  final ValueChanged<String>? onBusTap;
  final VoidCallback? onTilesFailed;
  final LatLng? focus; // pan here when it changes
  final ValueChanged<LatLng>? onMapTap;
  final ValueChanged<String>? onPlaceTap; // a stop's id

  @override
  State<BusMap> createState() => _BusMapState();
}

class _BusMapState extends State<BusMap> {
  final _ctl = MapController();
  bool _ready = false;
  int _errors = 0;

  @override
  void didUpdateWidget(BusMap old) {
    super.didUpdateWidget(old);
    final f = widget.focus;
    if (_ready && f != null && f != old.focus) {
      _ctl.move(f, _ctl.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _ctl,
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: widget.zoom,
        minZoom: 12,
        maxZoom: 18,
        backgroundColor: BW.sand200,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        onMapReady: () => _ready = true,
        onTap: widget.onMapTap == null ? null : (_, p) => widget.onMapTap!(p),
      ),
      children: [
        TileLayer(
          // OpenStreetMap's own tiles: free with attribution, fine for a pilot.
          // For launch, move to a keyed provider (CARTO, MapTiler, Stadia) — CARTO's free basemaps now need a key.
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          maxNativeZoom: 19,
          userAgentPackageName: 'so.buswhere.app',
          errorTileCallback: (tile, error, stack) {
            if (++_errors == 6) widget.onTilesFailed?.call();
          },
        ),
        // GPS accuracy circle under everything else.
        CircleLayer(circles: [
          for (final p in widget.places.where((p) => p.kind == PlaceKind.gps && (p.accuracyM ?? 0) > 15))
            CircleMarker(point: p.pos, radius: p.accuracyM!.clamp(15, 400), useRadiusInMeter: true, color: BW.teal.withValues(alpha: 0.12), borderColor: BW.teal.withValues(alpha: 0.5), borderStrokeWidth: 1),
        ]),
        if (widget.route.length > 1)
          PolylineLayer(polylines: [Polyline(points: widget.route, color: BW.teal.withValues(alpha: 0.9), strokeWidth: 6, strokeCap: StrokeCap.round, strokeJoin: StrokeJoin.round)]),
        MarkerLayer(markers: [
          for (final p in widget.places) _place(p),
          for (final b in widget.buses.where((b) => !b.selected)) _bus(b),
          for (final b in widget.buses.where((b) => b.selected)) _bus(b),
        ]),
        const SimpleAttributionWidget(source: Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 9)), backgroundColor: Color(0xB3FFFFFF)),
      ],
    );
  }

  Marker _bus(MapBus b) => Marker(
        point: b.pos,
        width: 130,
        height: 44,
        alignment: const Alignment(0.71, 0), // puts the bus tile's centre on the point
        child: Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: widget.onBusTap == null ? null : () => widget.onBusTap!(b.id),
            child: AnimatedContainer(
              duration: BW.base,
              padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
              decoration: BoxDecoration(
                color: b.muted ? BW.night500 : BW.night,
                borderRadius: BorderRadius.circular(12),
                boxShadow: b.selected ? const [BoxShadow(color: BW.busYellow, spreadRadius: 3)] : BW.shadowFloat,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: b.muted ? BW.night300 : BW.busYellow, borderRadius: BorderRadius.circular(9)),
                  alignment: Alignment.center,
                  child: const BWIcon('bus-front', size: 20, color: BW.night),
                ),
                const SizedBox(width: 6),
                Text(b.label, style: const TextStyle(fontSize: 14, height: 1, fontWeight: FontWeight.w700, color: BW.white)),
              ]),
            ),
          ),
        ),
      );

  Marker _place(MapPlace p) {
    switch (p.kind) {
      case PlaceKind.me:
        return Marker(
          point: p.pos,
          width: 160,
          height: 30,
          alignment: const Alignment(0.86, 0),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: BW.teal, shape: BoxShape.circle, border: Border.all(color: BW.white, width: 4), boxShadow: const [BoxShadow(color: BW.teal, spreadRadius: 2)]),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: BW.white, borderRadius: BorderRadius.circular(8)),
                child: Text(p.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1, fontWeight: FontWeight.w700, color: BW.night)),
              ),
            ),
          ]),
        );
      case PlaceKind.destination:
        return Marker(
          point: p.pos,
          width: 140,
          height: 30,
          alignment: const Alignment(1, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(color: BW.night, borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const BWIcon('flag', size: 14, color: BW.busYellow),
                const SizedBox(width: 6),
                Text(p.label, style: const TextStyle(fontSize: 13, height: 1, fontWeight: FontWeight.w700, color: BW.white)),
              ]),
            ),
          ),
        );
      case PlaceKind.stop:
        return Marker(
          point: p.pos,
          width: 150,
          height: 34,
          alignment: const Alignment(0.88, 0),
          child: GestureDetector(
            onTap: widget.onPlaceTap == null || p.id == null ? null : () => widget.onPlaceTap!(p.id!),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 16, height: 16, decoration: BoxDecoration(color: BW.white, shape: BoxShape.circle, border: Border.all(color: BW.teal, width: 4))),
              const SizedBox(width: 5),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xE6FFFFFF), borderRadius: BorderRadius.circular(8)),
                  child: Text(p.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 1, fontWeight: FontWeight.w600, color: BW.night)),
                ),
              ),
            ]),
          ),
        );
      case PlaceKind.gps:
        return Marker(
          point: p.pos,
          width: 24,
          height: 24,
          child: Semantics(
            label: p.label,
            child: Container(
              decoration: BoxDecoration(color: BW.night, shape: BoxShape.circle, border: Border.all(color: BW.white, width: 4), boxShadow: BW.shadowFloat),
            ),
          ),
        );
      case PlaceKind.waiting:
        return Marker(
          point: p.pos,
          width: 64,
          height: 32,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: (p.count ?? 0) > 0 ? BW.teal : BW.night300, borderRadius: BorderRadius.circular(999), border: Border.all(color: BW.white, width: 2)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const BWIcon('users', size: 14, color: BW.white),
                const SizedBox(width: 4),
                Text('${p.count ?? 0}', style: const TextStyle(fontSize: 13, height: 1, fontWeight: FontWeight.w700, color: BW.white)),
              ]),
            ),
          ),
        );
    }
  }
}
