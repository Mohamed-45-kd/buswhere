import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/bus_map.dart';
import '../../widgets/core.dart';
import '../../widgets/errors.dart';
import '../../widgets/toast_host.dart';

enum _Mode { center, stop }

/// Names, on/off, the village's place on the map, and its stops.
class VillageEditor extends StatefulWidget {
  const VillageEditor({super.key, required this.district, this.village});
  final District district;
  final Village? village;
  @override
  State<VillageEditor> createState() => _VillageEditorState();
}

class _VillageEditorState extends State<VillageEditor> {
  late final _so = TextEditingController(text: widget.village?.nameSo);
  late final _en = TextEditingController(text: widget.village?.nameEn);
  late String? _id = widget.village?.id;
  late LatLng _center;
  _Mode _mode = _Mode.stop;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final live = AppScope.read(context).live;
    final others = live.villagesOf(widget.district.id, activeOnly: false);
    _center = widget.village?.center ?? (others.isNotEmpty ? others.first.center : const LatLng(9.5560, 44.0880));
    if (widget.village == null) _mode = _Mode.center;
  }

  @override
  void dispose() {
    _so.dispose();
    _en.dispose();
    super.dispose();
  }

  static String _slug(String s) {
    final base = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return '${base.isEmpty ? 'tuulo' : base}-${Random().nextInt(0xffff).toRadixString(16)}';
  }

  Future<void> _save() async {
    final app = AppScope.read(context);
    if (_so.text.trim().isEmpty) {
      showToast(ToastData(app.t('Geli magaca tuulada', 'Enter the village name'), icon: 'circle-alert', tone: ToastTone.danger));
      return;
    }
    setState(() => _busy = true);
    final id = _id ?? _slug(_so.text);
    final err = await app.live.saveVillage(id: id, districtId: widget.district.id, nameSo: _so.text.trim(), nameEn: _en.text.trim(), center: _center);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (err == null) {
        _id = id;
        _mode = _Mode.stop;
      }
    });
    showToast(err == null
        ? ToastData(app.t('Waa la kaydiyay. Hadda ku dar joogsiyada.', 'Saved. Now add the stops.'), icon: 'circle-check', tone: ToastTone.success)
        : ToastData(errorText(app, err), icon: 'circle-alert', tone: ToastTone.danger));
  }

  void _stopSheet({Stop? stop, LatLng? at}) {
    final app = AppScope.read(context);
    final live = app.live;
    final name = TextEditingController(text: stop?.name), sub = TextEditingController(text: stop?.sub);
    showBWSheet(
      context,
      icon: 'map-pin',
      title: stop == null ? app.t('Joogsi cusub', 'New stop') : stop.name,
      subtitle: app.t('Isticmaal magac maxalli ah: suuq, masjid, dugsi…', 'Use a local landmark: market, mosque, school…'),
      body: Column(children: [
        BWInput(controller: name, label: app.t('Magaca joogsiga', 'Stop name'), autofocus: true),
        const SizedBox(height: 10),
        BWInput(controller: sub, label: app.t('Calaamad (English, ikhtiyaari)', 'Landmark in English (optional)')),
      ]),
      actions: (ctx) => [
        BWButton(app.t('Kaydi', 'Save'), icon: 'check', onTap: () async {
          if (name.text.trim().isEmpty) return;
          final err = await live.saveStop(id: stop?.id, villageId: _id!, name: name.text.trim(), sub: sub.text.trim(), pos: stop?.pos ?? at!, sort: stop?.sort ?? live.stopsOf(_id!).length);
          if (err == null && ctx.mounted) Navigator.pop(ctx);
          if (err != null) showToast(ToastData(errorText(app, err), icon: 'circle-alert', tone: ToastTone.danger));
        }),
        if (stop != null)
          BWButton(app.t('Tirtir joogsiga', 'Delete stop'), icon: 'x', variant: BtnVariant.outline, onTap: () async {
            Navigator.pop(ctx);
            final err = await live.deleteStop(stop.id);
            if (err != null) showToast(ToastData(errorText(app, err), icon: 'circle-alert', tone: ToastTone.danger));
          }),
        BWButton(app.t('Maya', 'Cancel'), variant: BtnVariant.ghost, onTap: () => Navigator.pop(ctx)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final live = app.live;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: live,
          builder: (context, _) {
            final v = live.villageOrNull(_id);
            final stops = _id == null ? <Stop>[] : live.stopsOf(_id!);
            return Column(children: [
              BWTopBar(
                title: v?.nameSo ?? app.t('Tuulo cusub', 'New village'),
                subtitle: widget.district.name,
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
                  BWCard(
                    child: Column(children: [
                      BWInput(controller: _so, label: app.t('Magaca (Soomaali)', 'Name (Somali)')),
                      const SizedBox(height: 10),
                      BWInput(controller: _en, label: app.t('Magaca (English)', 'Name (English)')),
                      if (v != null) ...[
                        const SizedBox(height: 4),
                        BWSwitchRow(
                          label: app.t('Rakaabku way arkaan', 'Shown to riders'),
                          subLabel: app.t('Dami si aad u qariso tuuladan', 'Turn off to hide this village'),
                          value: v.isActive,
                          onChanged: (on) async {
                            final err = await live.setActive('villages', v.id, on);
                            if (err != null) showToast(ToastData(errorText(app, err), icon: 'circle-alert', tone: ToastTone.danger));
                          },
                        ),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 12),
                  if (_id != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: BWSegmented(
                        value: _mode.name,
                        onChange: (m) => setState(() => _mode = _Mode.values.byName(m)),
                        options: [SegOption('stop', app.t('Ku dar joogsi', 'Add stops')), SegOption('center', app.t('Dhig tuulada', 'Place village'))],
                      ),
                    ),
                  Text(
                    _mode == _Mode.center
                        ? app.t('Taabo khariidadda meesha tuuladu ku taal.', 'Tap the map where the village is.')
                        : app.t('Taabo khariidadda meel joogsi ah si aad ugu darto.', 'Tap the map at a stop to add it.'),
                    style: BWText.small.copyWith(color: BW.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(BW.rLg),
                    child: SizedBox(
                      height: 300,
                      child: BusMap(
                        center: _center,
                        zoom: 16,
                        places: [
                          MapPlace(_center, _so.text.isEmpty ? app.t('Tuulada', 'Village') : _so.text),
                          for (final s in stops) MapPlace(s.pos, s.name, kind: PlaceKind.me),
                        ],
                        onMapTap: (p) {
                          if (_mode == _Mode.center) {
                            setState(() => _center = p);
                          } else if (_id != null) {
                            _stopSheet(at: p);
                          }
                        },
                      ),
                    ),
                  ),
                  if (_id != null) ...[
                    const SizedBox(height: 16),
                    SectionLabel(app.t('Joogsiyada', 'Stops'), '${stops.length}'),
                    const SizedBox(height: 8),
                    BWCard(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        for (final (i, s) in stops.indexed)
                          BWListItem(icon: 'map-pin', tone: Tone.teal, title: s.name, subtitle: s.sub, divider: i < stops.length - 1, chevron: true, onTap: () => _stopSheet(stop: s)),
                        if (stops.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(app.t('Weli joogsi ma jiro. Rakaabku uma sugi karaan tuulo aan joogsi lahayn.', "No stops yet. Riders can't wait in a village without stops."), style: BWText.small),
                          ),
                      ]),
                    ),
                  ],
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: BWButton(
                  _id == null ? app.t('Samee tuulada', 'Create village') : app.t('Kaydi magaca iyo goobta', 'Save name and place'),
                  icon: 'check',
                  busy: _busy,
                  onTap: _save,
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
