import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/bus_map.dart';
import '../../widgets/core.dart';
import '../../widgets/errors.dart';
import '../../widgets/toast_host.dart';
import '../../widgets/transit.dart';
import 'village_editor.dart';

void _done(AppState app, String? err, {String? okSo, String? okEn}) {
  if (err != null) {
    showToast(ToastData(errorText(app, err), icon: 'circle-alert', tone: ToastTone.danger));
  } else if (okSo != null) {
    showToast(ToastData(app.t(okSo, okEn ?? okSo), icon: 'circle-check', tone: ToastTone.success));
  }
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  String _tab = 'places';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final live = app.live;
    final (title, sub) = switch (_tab) {
      'places' => (app.t('Magaalooyin iyo tuulooyin', 'Cities & villages'), app.sub('Magaalooyin iyo tuulooyin', 'Cities & villages')),
      'drivers' => (app.t('Darawallada iyo basaska', 'Drivers & buses'), app.sub('Darawallada iyo basaska', 'Drivers & buses')),
      'map' => (app.t('Khariidadda tooska ah', 'Live map'), app.sub('Khariidadda tooska ah', 'Live map')),
      _ => (app.t('Warbixinno', 'Reports'), app.sub('Warbixinno', 'Reports')),
    };
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          BWTopBar(
            title: title,
            subtitle: '${live.adminEmail ?? app.t('Maamul', 'Admin')} · $sub',
            onBack: () => context.go('/'),
            actions: [
              BWIconButton('log-out', label: app.t('Ka bax', 'Sign out'), onTap: () async {
                await live.adminSignOut();
                if (context.mounted) context.go('/');
              }),
            ],
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: live,
              builder: (context, _) => switch (_tab) {
                'places' => _Places(app),
                'drivers' => _Drivers(app),
                'map' => _LiveMap(app),
                _ => _Reports(app),
              },
            ),
          ),
        ]),
      ),
      bottomNavigationBar: BWBottomNav(
        value: _tab,
        onChange: (t) {
          setState(() => _tab = t);
          if (t == 'drivers' || t == 'reports') live.loadAdmin();
        },
        items: [
          NavItem('places', 'map-pin', app.t('Meelaha', 'Places')),
          NavItem('drivers', 'users', app.t('Darawal', 'Drivers')),
          NavItem('map', 'map', app.t('Toos', 'Live')),
          NavItem('reports', 'flag', app.t('Warbixin', 'Reports')),
        ],
      ),
    );
  }
}

// ───────────────────────── places
class _Places extends StatelessWidget {
  const _Places(this.app);
  final AppState app;
  @override
  Widget build(BuildContext context) {
    final live = app.live;
    void openEditor(District d, Village? v) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VillageEditor(district: d, village: v)));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
      SectionLabel(app.t('Magaalooyin', 'Cities'), app.sub('Magaalooyin', 'Cities')),
      const SizedBox(height: 8),
      BWCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(children: [
          for (final c in live.cities)
            BWSwitchRow(
              label: app.en ? c.nameEn : c.nameSo,
              subLabel: '${live.districtsOf(c.id).length} ${app.t('degmo', 'districts')}',
              value: c.isActive,
              onChanged: (on) async => _done(app, await live.setActive('cities', c.id, on)),
            ),
        ]),
      ),
      for (final c in live.cities.where((c) => c.isActive))
        for (final d in live.districtsOf(c.id)) ...[
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: SectionLabel(d.name, app.en ? c.nameEn : c.nameSo)),
            Pressable(
              onTap: () async => _done(app, await live.setActive('districts', d.id, !d.isActive)),
              builder: (_) => BWBadge(d.isActive ? app.t('Shidan', 'On') : app.t('Dansan', 'Off'), tone: d.isActive ? BadgeTone.live : BadgeTone.neutral, dot: true, small: true),
            ),
          ]),
          const SizedBox(height: 8),
          if (d.isActive)
            BWCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (final v in live.villagesOf(d.id, activeOnly: false))
                  BWListItem(
                    icon: 'map-pin',
                    tone: v.isActive ? Tone.teal : Tone.neutral,
                    title: v.nameSo,
                    subtitle: app.t(
                      '${live.stopsOf(v.id).length} joogsi · ${live.activeBusCount(v.id)} bas · ${live.waitingCount(villageId: v.id)} sugaya',
                      '${live.stopsOf(v.id).length} stops · ${live.activeBusCount(v.id)} buses · ${live.waitingCount(villageId: v.id)} waiting',
                    ),
                    dim: !v.isActive,
                    divider: true,
                    chevron: true,
                    onTap: () => openEditor(d, v),
                  ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: BWButton(app.t('Ku dar tuulo', 'Add village'), icon: 'plus', variant: BtnVariant.ghost, small: true, onTap: () => openEditor(d, null)),
                ),
              ]),
            ),
        ],
    ]);
  }
}

// ───────────────────────── drivers & buses
class _Drivers extends StatelessWidget {
  const _Drivers(this.app);
  final AppState app;
  @override
  Widget build(BuildContext context) {
    final live = app.live;
    final buses = live.buses.values.toList()..sort((a, b) => a.number.compareTo(b.number));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
      Row(children: [
        Expanded(child: SectionLabel(app.t('Darawallada', 'Drivers'), '${live.drivers.length}')),
        BWButton(app.t('Ku dar', 'Add'), icon: 'plus', variant: BtnVariant.ghost, small: true, fullWidth: false, onTap: () => _editDriver(context, app, null)),
      ]),
      const SizedBox(height: 8),
      BWCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (final (i, d) in live.drivers.indexed)
            () {
              final lb = live.busLive.values.where((b) => b.driverId == d.id).firstOrNull;
              final bus = live.busById(d.busId);
              final where = lb == null ? null : '${live.villageOrNull(lb.villageId)?.nameSo} → ${live.villageOrNull(lb.destinationId)?.nameSo}';
              return BWListItem(
                icon: 'user-round',
                tone: lb != null ? Tone.yellow : Tone.neutral,
                title: '${d.name} · ${bus == null ? app.t('bas la\'aan', 'no bus') : 'Bas ${bus.number}'}',
                subtitle: [
                  '+252 ${d.phone}',
                  if (!d.approved) app.t('la joojiyay', 'suspended'),
                  if (d.locked) app.t('PIN waa la xiray', 'PIN locked'),
                  where ?? app.t('Lama xirin tuulo', 'Not in a village'),
                ].join(' · '),
                divider: i < live.drivers.length - 1,
                dim: !d.approved,
                trailing: lb != null
                    ? BWBadge(lb.online && !lb.stale ? app.t('Toos', 'Live') : 'Offline', tone: lb.online && !lb.stale ? BadgeTone.live : BadgeTone.neutral, dot: true, small: true)
                    : null,
                chevron: true,
                onTap: () => _editDriver(context, app, d),
              );
            }(),
          if (live.drivers.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(app.t('Darawal weli lama gelin.', 'No drivers yet.'), style: BWText.small)),
        ]),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: SectionLabel(app.t('Basaska', 'Buses'), '${buses.length}')),
        BWButton(app.t('Diiwaan geli', 'Register'), icon: 'plus', variant: BtnVariant.ghost, small: true, fullWidth: false, onTap: () => _editBus(context, app, null)),
      ]),
      const SizedBox(height: 8),
      BWCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (final (i, b) in buses.indexed)
            () {
              final drv = live.drivers.where((d) => d.busId == b.id).firstOrNull;
              return BWListItem(
                icon: 'bus-front',
                tone: live.busLive.containsKey(b.id) ? Tone.yellow : Tone.neutral,
                title: 'Bas ${b.number} · ${b.plate}',
                subtitle: '${b.capacity} ${app.t('kursi', 'seats')} · ${b.owner.isEmpty ? '—' : b.owner} · ${drv?.name ?? app.t('darawal la\'aan', 'no driver')}',
                divider: i < buses.length - 1,
                chevron: true,
                onTap: () => _editBus(context, app, b),
              );
            }(),
          if (buses.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(app.t('Bas weli lama diiwaan gelin.', 'No buses yet.'), style: BWText.small)),
        ]),
      ),
    ]);
  }

  void _editDriver(BuildContext context, AppState app, DriverRow? d) {
    final live = app.live;
    final name = TextEditingController(text: d?.name), phone = TextEditingController(text: d?.phone), pin = TextEditingController();
    var busId = d?.busId;
    var approved = d?.approved ?? true;
    final active = d != null && live.busLive.values.any((b) => b.driverId == d.id);
    showBWSheet(
      context,
      icon: 'user',
      title: d == null ? app.t('Darawal cusub', 'New driver') : d.name,
      subtitle: d == null ? app.t('Sii PIN 4 lambar ah. Darawalku wuxuu ku galaa lambarkiisa iyo PIN-ka.', 'Give a 4-digit PIN. The driver signs in with phone + PIN.') : null,
      body: StatefulBuilder(
        builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BWInput(controller: name, icon: 'user', label: app.t('Magaca hore', 'First name')),
          const SizedBox(height: 10),
          BWInput(controller: phone, icon: 'phone', prefixText: '+252 ', label: app.t('Telefoon', 'Phone'), keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))]),
          const SizedBox(height: 10),
          BWInput(
            controller: pin,
            icon: 'square',
            label: d == null ? 'PIN' : app.t('PIN cusub (ikhtiyaari)', 'New PIN (optional)'),
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 12),
          Text(app.t('Baska', 'Bus'), style: BWText.label.copyWith(color: BW.textSecondary)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final b in live.buses.values.toList()..sort((a, b) => a.number.compareTo(b.number)))
              BWTag('Bas ${b.number}', selected: busId == b.id, onTap: () => set(() => busId = busId == b.id ? null : b.id)),
          ]),
          const SizedBox(height: 8),
          BWSwitchRow(label: app.t('La oggol yahay', 'Allowed to drive'), subLabel: app.t('Dami si aad u joojiso darawalka', 'Turn off to suspend this driver'), value: approved, onChanged: (x) => set(() => approved = x)),
        ]),
      ),
      actions: (ctx) => [
        BWButton(app.t('Kaydi', 'Save'), icon: 'check', onTap: () async {
          final p = pin.text.trim();
          final err = await live.saveDriver(id: d?.id, name: name.text, phone: phone.text, pin: p.isEmpty ? null : p, busId: busId, approved: approved);
          if (err == null && ctx.mounted) Navigator.pop(ctx);
          _done(app, err, okSo: 'Waa la kaydiyay', okEn: 'Saved');
        }),
        if (active)
          BWButton(app.t('Ka saar tuulada', 'Withdraw from village'), icon: 'log-out', variant: BtnVariant.outline, onTap: () async {
            Navigator.pop(ctx);
            _done(app, await live.adminWithdraw(d.id), okSo: 'Waa laga saaray', okEn: 'Withdrawn');
          }),
        BWButton(app.t('Maya', 'Cancel'), variant: BtnVariant.ghost, onTap: () => Navigator.pop(ctx)),
      ],
    );
  }

  void _editBus(BuildContext context, AppState app, Bus? b) {
    final live = app.live;
    final nextNumber = live.buses.values.fold(0, (m, x) => x.number > m ? x.number : m) + 1;
    final number = TextEditingController(text: '${b?.number ?? nextNumber}'), plate = TextEditingController(text: b?.plate);
    final cap = TextEditingController(text: '${b?.capacity ?? 14}'), owner = TextEditingController(text: b?.owner);
    showBWSheet(
      context,
      icon: 'bus-front',
      title: b == null ? app.t('Bas cusub', 'New bus') : 'Bas ${b.number}',
      body: Column(children: [
        BWInput(controller: number, label: app.t('Lambarka baska', 'Bus number'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
        const SizedBox(height: 10),
        BWInput(controller: plate, label: app.t('Taarikada', 'Plate')),
        const SizedBox(height: 10),
        BWInput(controller: cap, label: app.t('Kuraasta', 'Seats'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
        const SizedBox(height: 10),
        BWInput(controller: owner, label: app.t('Mulkiilaha', 'Owner')),
      ]),
      actions: (ctx) => [
        BWButton(app.t('Kaydi', 'Save'), icon: 'check', onTap: () async {
          if (plate.text.trim().isEmpty || int.tryParse(number.text) == null) return;
          final err = await live.saveBus(id: b?.id, number: int.parse(number.text), plate: plate.text.trim(), capacity: int.tryParse(cap.text) ?? 14, owner: owner.text.trim());
          if (err == null && ctx.mounted) Navigator.pop(ctx);
          _done(app, err, okSo: 'Waa la kaydiyay', okEn: 'Saved');
        }),
        BWButton(app.t('Maya', 'Cancel'), variant: BtnVariant.ghost, onTap: () => Navigator.pop(ctx)),
      ],
    );
  }
}

// ───────────────────────── live map
class _LiveMap extends StatelessWidget {
  const _LiveMap(this.app);
  final AppState app;
  @override
  Widget build(BuildContext context) {
    final live = app.live;
    final buses = live.busLive.values.where((b) => b.position != null).toList();
    final online = buses.where((b) => b.visible).length;
    final waiting = live.waitingCount();
    final center = live.villages.isEmpty ? const LatLng(9.5560, 44.0880) : live.villages.first.center;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(children: [
          Expanded(child: _Stat(value: '$online', label: app.t('bas toos ah', 'buses live'), icon: 'bus-front', tone: Tone.yellow)),
          const SizedBox(width: 10),
          Expanded(child: _Stat(value: '$waiting', label: app.t('qof sugaya', 'people waiting'), icon: 'users', tone: Tone.teal)),
        ]),
      ),
      Expanded(
        child: app.online
            ? BusMap(
                center: center,
                zoom: 14,
                buses: [for (final b in buses) MapBus(id: b.busId, pos: b.position!, label: 'Bas ${b.busNumber}', muted: !b.visible || b.stale)],
                places: [
                  for (final s in live.stops)
                    if (live.waitingCount(stopId: s.id) > 0) MapPlace(s.pos, s.name, kind: PlaceKind.waiting, count: live.waitingCount(stopId: s.id)),
                ],
              )
            : Padding(padding: const EdgeInsets.all(16), child: BWBanner(tone: BannerTone.offline, title: app.t('Internet ma jiro', 'No internet'))),
      ),
      Container(
        width: double.infinity,
        color: BW.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          live.connected ? '${app.t('Toos', 'Live')} · ${freshness(live.lastUpdate, app.en)}' : app.t('Xiriirka ayaa dib loo samaynayaa…', 'Reconnecting…'),
          style: BWText.small.copyWith(color: BW.textSecondary),
        ),
      ),
    ]);
  }
}

// ───────────────────────── reports
class _Reports extends StatelessWidget {
  const _Reports(this.app);
  final AppState app;
  @override
  Widget build(BuildContext context) {
    final live = app.live;
    final r = live.report;
    if (r == null) return const Center(child: CircularProgressIndicator(color: BW.teal));
    final hours = [for (final h in (r['waits_by_hour'] as List? ?? List.filled(24, 0))) (h as num).toInt()];
    final peak = hours.fold(0, (a, b) => a > b ? a : b);
    final peakHour = peak == 0 ? null : hours.indexOf(peak);
    final busiest = [for (final b in (r['busiest_villages'] as List)) (b['village_id'] as String, (b['n'] as num).toInt())];
    final maxV = busiest.isEmpty ? 1 : busiest.first.$2;
    return RefreshIndicator(
      color: BW.teal,
      onRefresh: live.loadAdmin,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
        Row(children: [
          Expanded(child: _Stat(value: '${r['trips_today']}', label: app.t('safar maanta', 'trips today'), icon: 'route', tone: Tone.yellow)),
          const SizedBox(width: 10),
          Expanded(child: _Stat(value: '${r['waits_today']}', label: app.t('sugitaan maanta', 'waits today'), icon: 'hand', tone: Tone.teal)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Stat(value: '${r['picked_up_today']}', label: app.t('la qaaday maanta', 'picked up today'), icon: 'circle-check', tone: Tone.teal)),
          const SizedBox(width: 10),
          Expanded(child: _Stat(value: peakHour == null ? '—' : '${peakHour.toString().padLeft(2, '0')}:00', label: app.t('saacadda ugu mashquulsan', 'peak hour'), icon: 'clock', tone: Tone.yellow)),
        ]),
        const SizedBox(height: 12),
        BWCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionLabel(app.t('Sugitaanka saacad kasta', 'Waiting by hour'), app.sub('Sugitaanka saacad kasta', 'Waiting by hour')),
            const SizedBox(height: 4),
            Text(app.t('Maanta, waqtiga Hargeysa', 'Today, Hargeisa time'), style: BWText.small.copyWith(color: BW.textSecondary)),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (var h = 5; h < 23; h++)
                  Expanded(
                    child: Tooltip(
                      message: '${h.toString().padLeft(2, '0')}:00 · ${hours[h]}',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Container(
                          height: peak == 0 ? 2 : 2 + 118 * hours[h] / peak,
                          decoration: BoxDecoration(color: h == peakHour ? BW.busYellow : BW.teal, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              for (final h in ['05', '09', '13', '17', '22']) Text(h, style: BWText.small.copyWith(color: BW.night500, fontSize: 12)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        BWCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionLabel(app.t('Tuulooyinka ugu mashquulsan', 'Busiest villages'), app.t('7 maalmood', '7 days')),
            const SizedBox(height: 12),
            if (busiest.isEmpty) Text(app.t('Xog weli ma jirto.', 'No data yet.'), style: BWText.small),
            for (final (id, n) in busiest) ...[
              Row(children: [
                SizedBox(width: 110, child: Text(live.villageOrNull(id)?.nameSo ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: n / maxV, minHeight: 10, backgroundColor: BW.sand200, color: BW.teal))),
                SizedBox(width: 44, child: Text('$n', textAlign: TextAlign.right, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 10),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.icon, required this.tone});
  final String value, label, icon;
  final Tone tone;
  @override
  Widget build(BuildContext context) => BWCard(
        child: Row(children: [
          IconTile(icon, tone: tone),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: const TextStyle(fontSize: 24, height: 28 / 24, fontWeight: FontWeight.w700, letterSpacing: -0.48)),
              Text(label, maxLines: 2, style: BWText.small.copyWith(color: BW.textSecondary)),
            ]),
          ),
        ]),
      );
}
