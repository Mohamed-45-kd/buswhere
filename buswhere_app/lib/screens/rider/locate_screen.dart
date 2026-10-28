import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/bus_map.dart';
import '../../widgets/core.dart';
import '../../widgets/entrance.dart';

enum _State { asking, locating, found, far, denied, failed }

/// Step 1 of a trip: "Where are you?" answered by the phone. A pop-up asks the
/// rider to turn on location, the map shows them, and we pick their village and
/// nearest stop. Riders can tap another stop, or choose their village by hand.
class LocateScreen extends StatefulWidget {
  const LocateScreen({super.key});
  @override
  State<LocateScreen> createState() => _LocateScreenState();
}

class _LocateScreenState extends State<LocateScreen> {
  _State _state = _State.asking;
  Village? _village;
  Stop? _stop;
  double? _stopM, _villageM;

  static const _hargeisa = LatLng(9.5560, 44.0880);
  static const _farM = 3000.0; // further than this from every pilot village = "not near"

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askPopup());
  }

  /// The pop-up: explain why, then let the browser ask for permission.
  Future<void> _askPopup() async {
    if (!mounted) return;
    final app = AppScope.read(context);
    final go = await showBWSheet<bool>(
      context,
      icon: 'locate-fixed',
      title: app.t('Shid goobtaada', 'Turn on your location'),
      subtitle: app.t(
        'Si aan u ogaano halka aad joogto oo aan kuu tusno basaska kuu dhow. Goobtaada lama kaydiyo, cidna lama tuso.',
        "So we know where you are and can show the buses near you. Your location isn't saved or shown to anyone.",
      ),
      actions: (ctx) => [
        BWButton(app.t('Shid goobta', 'Turn on location'), subLabel: app.sub('Shid goobta', 'Turn on location'), icon: 'locate-fixed', onTap: () => Navigator.pop(ctx, true)),
        BWButton(app.t('Gacanta ku dooro tuuladaada', "I'll choose my village"), variant: BtnVariant.ghost, onTap: () => Navigator.pop(ctx, false)),
      ],
    );
    if (!mounted) return;
    if (go == true) {
      _locate();
    } else if (go == false) {
      context.go('/rider/city');
    }
    // Dismissed by tapping outside: stay here; the button below asks again.
  }

  Future<void> _locate() async {
    final app = AppScope.read(context);
    final live = app.live;
    setState(() => _state = _State.locating);
    final err = await live.locateRider();
    if (!mounted) return;
    if (err != null) {
      setState(() => _state = err == 'denied' ? _State.denied : _State.failed);
      return;
    }
    final n = live.nearestVillage(live.riderPos!);
    if (n == null || n.m > _farM) {
      setState(() {
        _state = _State.far;
        _villageM = n?.m;
        _village = n?.village;
      });
      return;
    }
    final s = live.nearestStopTo(live.riderPos!, n.village.id);
    setState(() {
      _state = _State.found;
      _village = n.village;
      _villageM = n.m;
      _stop = s?.stop;
      _stopM = s?.m;
    });
  }

  void _pickStop(String id) {
    final live = AppScope.read(context).live;
    final s = live.stopById(id);
    setState(() {
      _stop = s;
      _stopM = live.riderPos == null ? null : live.distance(s.pos, live.riderPos!);
    });
  }

  void _continue() {
    final app = AppScope.read(context);
    final v = _village!;
    app.setDistrict(app.live.districtById(v.districtId).cityId, v.districtId);
    app.setFrom(v.id);
    if (_stop != null) app.setStop(_stop!.id);
    app.tripStart = '/rider/locate';
    context.go('/rider/to');
  }

  String _km(double m) => m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final live = app.live;
    final gps = live.riderPos;
    final stops = _state == _State.found && _village != null ? live.stopsOf(_village!.id) : const <Stop>[];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          BWTopBar(
            title: app.t('Xagee joogtaa?', 'Where are you?'),
            subtitle: app.sub('Xagee joogtaa?', 'Where are you?'),
            onBack: () => context.go('/'),
          ),
          const StepBar(1, total: 2),
          Expanded(
            child: Stack(children: [
              Positioned.fill(
                child: app.online
                    ? BusMap(
                        center: gps ?? _hargeisa,
                        zoom: gps == null ? 13 : 16,
                        focus: gps,
                        focusZoom: 16.5,
                        focusLift: 150, // the rider's dot sits above the bottom card
                        onPlaceTap: _state == _State.found ? _pickStop : null,
                        onMapTap: _state == _State.found && _village != null
                            ? (p) {
                                final n = live.nearestStopTo(p, _village!.id);
                                if (n != null && n.m < 800) _pickStop(n.stop.id);
                              }
                            : null,
                        places: [
                          for (final s in stops)
                            MapPlace(s.pos, s.name, kind: s.id == _stop?.id ? PlaceKind.me : PlaceKind.stop, id: s.id),
                          if (gps != null) MapPlace(gps, app.t('Adiga', 'You'), kind: PlaceKind.gps, accuracyM: live.riderAccuracyM),
                        ],
                      )
                    : const ColoredBox(color: BW.sand200),
              ),
              Positioned(left: 12, right: 12, bottom: 12, child: Entrance(key: ValueKey(_state), child: _panel(app))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _panel(AppState app) {
    Widget card(List<Widget> children) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: BW.white, borderRadius: BorderRadius.circular(BW.rXl), boxShadow: BW.shadowFloat),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        );
    final manual = BWButton(app.t('Gacanta ku dooro tuuladaada', "I'll choose my village"), variant: BtnVariant.ghost, small: true, onTap: () => context.go('/rider/city'));

    switch (_state) {
      case _State.asking:
        return card([
          Text(app.t('Goobtaada ayaan u baahannahay', 'We need your location'), style: BWText.h3),
          const SizedBox(height: 4),
          Text(app.t('Si aan u helno tuuladaada iyo basaska kuu dhow.', 'To find your village and the buses near you.'), style: BWText.small.copyWith(color: BW.textSecondary)),
          const SizedBox(height: 14),
          BWButton(app.t('Shid goobta', 'Turn on location'), subLabel: app.sub('Shid goobta', 'Turn on location'), icon: 'locate-fixed', onTap: _locate),
          const SizedBox(height: 4),
          manual,
        ]);
      case _State.locating:
        return card([
          Row(children: [
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: BW.teal)),
            const SizedBox(width: 14),
            Expanded(child: Text(app.t('Waan ku raadinaynaa…', 'Finding you…'), style: BWText.h3)),
          ]),
          const SizedBox(height: 6),
          Text(app.t('Haddii la weydiiyo, taabo "Allow / Oggolow".', 'If your phone asks, tap "Allow".'), style: BWText.small.copyWith(color: BW.textSecondary)),
        ]);
      case _State.found:
        final v = _village!;
        return card([
          Row(children: [
            const IconTile('map-pin', tone: Tone.teal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(app.t('Halkan ayaad joogtaa', 'You are here'), style: BWText.label.copyWith(color: BW.textSecondary)),
                Text(app.en ? v.nameEn : v.nameSo, style: BWText.h2),
              ]),
            ),
            BWBadge(app.live.districtById(v.districtId).name, tone: BadgeTone.info, small: true),
          ]),
          if (_stop != null) ...[
            const SizedBox(height: 12),
            BWCard(
              variant: CardVariant.sunken,
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const BWIcon('flag', size: 20, color: BW.teal),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: app.t('Joogsigaaga: ', 'Your stop: ')),
                    TextSpan(text: _stop!.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (_stopM != null) TextSpan(text: ' · ${_km(_stopM!)}'),
                  ]), style: const TextStyle(fontSize: 15)),
                ),
              ]),
            ),
            const SizedBox(height: 6),
            Text(app.t('Taabo joogsi kale khariidadda haddii aad rabto.', 'Tap another stop on the map to change it.'), style: BWText.small.copyWith(color: BW.textSecondary)),
          ],
          const SizedBox(height: 14),
          BWButton(app.t('Xagee u socotaa?', 'Where are you going?'), subLabel: app.t('Sii wad · Continue', 'Continue · Sii wad'), iconRight: 'arrow-right', onTap: _continue),
        ]);
      case _State.far:
        return card([
          Text(app.t('Kama dhowid tuulooyinka BusWhere', "You're not near a BusWhere village"), style: BWText.h3),
          const SizedBox(height: 4),
          Text(
            _village == null
                ? app.t('Hadda BusWhere wuxuu ka shaqeeyaa 26 Juun, Hargeysa.', 'BusWhere runs in 26 Juun, Hargeisa for now.')
                : app.t('Tuulada ugu dhow, ${_village!.nameSo}, waa ${_km(_villageM!)}. Hadda BusWhere wuxuu ka shaqeeyaa 26 Juun, Hargeysa.',
                    'The nearest, ${_village!.nameEn}, is ${_km(_villageM!)} away. BusWhere runs in 26 Juun, Hargeisa for now.'),
            style: BWText.small.copyWith(color: BW.textSecondary),
          ),
          const SizedBox(height: 14),
          BWButton(app.t('Dooro tuuladaada', 'Choose your village'), icon: 'map-pin', onTap: () => context.go('/rider/city')),
          const SizedBox(height: 4),
          BWButton(app.t('Isku day mar kale', 'Try again'), variant: BtnVariant.ghost, small: true, onTap: _locate),
        ]);
      case _State.denied:
      case _State.failed:
        final denied = _state == _State.denied;
        return card([
          Text(denied ? app.t('Goobta waa xiran tahay', 'Location is off') : app.t('Goobtaada lama helin', "We couldn't find you"), style: BWText.h3),
          const SizedBox(height: 4),
          Text(
            denied
                ? app.t('Fur dejinta browser-ka (quful-ka ku xiga cinwaanka) → Goobta → Oggolow, kadibna isku day.', 'Open your browser settings (the lock next to the address) → Location → Allow, then try again.')
                : app.t('Isku day meel bannaan, ama dooro tuuladaada.', 'Try again in the open, or choose your village.'),
            style: BWText.small.copyWith(color: BW.textSecondary),
          ),
          const SizedBox(height: 14),
          BWButton(app.t('Isku day mar kale', 'Try again'), icon: 'refresh-cw', onTap: _locate),
          const SizedBox(height: 4),
          manual,
        ]);
    }
  }

}
