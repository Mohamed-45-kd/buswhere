import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/live_service.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/bus_map.dart';
import '../../widgets/core.dart';
import '../../widgets/errors.dart';
import '../../widgets/toast_host.dart';
import '../../widgets/transit.dart';

/// Driving: online toggle, GPS status, waiting count per stop, map of riders waiting, withdraw.
class DriveScreen extends StatelessWidget {
  const DriveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final live = app.live;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: live,
          builder: (context, _) {
            final me = live.me;
            if (me == null || !me.active) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.go(me == null ? '/driver/login' : '/driver/village');
              });
              return const SizedBox.shrink();
            }
            final v = live.villageOrNull(me.villageId), dest = live.villageOrNull(me.destinationId);
            if (v == null || dest == null) return const SizedBox.shrink();
            final stops = live.stopsOf(v.id);
            final total = live.waitingCount(villageId: v.id, destId: dest.id);
            final elsewhere = live.waitingCount(villageId: v.id) - total;
            final pos = live.myBus?.position ?? live.lastFix;

            Future<void> act(Future<String?> f) async {
              final err = await f;
              if (err != null) showToast(ToastData(errorText(app, err), icon: 'circle-alert', tone: ToastTone.danger));
            }

            return Column(children: [
              BWTopBar(
                dark: true,
                title: '${v.nameSo} → ${dest.nameSo}',
                subtitle: 'Bas ${me.busNumber ?? ''} · ${app.t('Tuulada aad ku jirto', 'Your village')}',
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: BWBadge(me.online ? app.t('Toos', 'Live') : 'Offline', tone: me.online ? BadgeTone.live : BadgeTone.dark, dot: true),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                decoration: const BoxDecoration(color: BW.night, borderRadius: BorderRadius.vertical(bottom: Radius.circular(BW.rXl))),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: BW.night700, borderRadius: BorderRadius.circular(BW.rLg)),
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(app.t('Wadarta sugaya', 'Total waiting'), style: BWText.label.copyWith(color: BW.onDarkMuted)),
                          Text('${app.t('U socda', 'Going to')} ${dest.nameSo}', style: BWText.small.copyWith(color: BW.onDarkMuted)),
                          if (elsewhere > 0) Text(app.t('+$elsewhere meelo kale', '+$elsewhere other places'), style: BWText.small.copyWith(color: BW.teal300)),
                        ]),
                      ),
                      WaitingCount(count: total, large: true, dark: true, label: app.t('qof', 'people')),
                    ]),
                    const SizedBox(height: 12),
                    _DarkToggle(
                      icon: me.online ? 'wifi' : 'wifi-off',
                      on: me.online,
                      label: me.online ? app.t('Waad shaqeynaysaa · Online', 'Online · Waad shaqeynaysaa') : app.t('Offline · rakaabku kuma arkaan', "Offline · riders can't see you"),
                      onTap: () => act(live.setDriverStatus(online: !me.online)),
                    ),
                    const SizedBox(height: 8),
                    _DarkToggle(
                      icon: 'users',
                      on: me.full,
                      onColor: BW.red600,
                      label: me.full ? app.t('Basku waa buuxaa · Full', 'Bus is full · Buuxa') : app.t('Kuraas ayaa bannaan', 'Seats free'),
                      onTap: () => act(live.setDriverStatus(full: !me.full)),
                    ),
                  ]),
                ),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  if (!me.online) ...[
                    BWBanner(
                      tone: BannerTone.warning,
                      title: app.t('Rakaabku ma arkaan baskaaga', "Riders can't see your bus"),
                      message: app.t('30 daqiiqo offline kadib waxaa lagaa saarayaa tuulada.', 'After 30 minutes offline you are withdrawn from the village.'),
                    ),
                    const SizedBox(height: 12),
                  ] else if (live.gps != GpsState.ok) ...[
                    BWBanner(
                      tone: live.gps == GpsState.waiting ? BannerTone.info : BannerTone.danger,
                      title: switch (live.gps) {
                        GpsState.denied => app.t('Goobta waa la diiday', 'Location is blocked'),
                        GpsState.unsupported => app.t('Taleefanku GPS ma bixiyo', 'This phone has no GPS'),
                        _ => app.t('GPS-ka ayaa la raadinayaa…', 'Finding your GPS…'),
                      },
                      message: live.gps == GpsState.denied
                          ? app.t('Fur dejinta browser-ka oo u oggolow BusWhere goobta, kadibna dib u fur.', 'Allow location for BusWhere in browser settings, then reopen.')
                          : app.t('Rakaabku waxay arkaan baskaaga marka GPS la helo.', 'Riders see your bus once GPS is found.'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (total == 0) ...[
                    BWBanner(tone: BannerTone.info, title: app.t('Cidna ma sugayso', 'No one is waiting'), message: app.t('Cidna halkan kuma sugayso. Waxaad u guuri kartaa tuulo kale.', 'No one is waiting here. You can move to another village.')),
                    const SizedBox(height: 12),
                  ],
                  if (!app.saveData && app.online) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(BW.rLg),
                      child: SizedBox(
                        height: 190,
                        child: BusMap(
                          center: pos ?? v.center,
                          zoom: 15,
                          buses: [if (pos != null) MapBus(id: 'me', pos: pos, label: 'Bas ${me.busNumber ?? ''}', selected: true, muted: !me.online)],
                          places: [
                            for (final s in stops) MapPlace(s.pos, s.name, kind: PlaceKind.waiting, count: live.waitingCount(stopId: s.id, destId: dest.id)),
                            MapPlace(dest.center, dest.nameSo),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SectionLabel(app.t('Joogsiyada', 'Stops'), app.sub('Joogsiyada', 'Stops')),
                  const SizedBox(height: 8),
                  BWCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (final (i, s) in stops.indexed)
                        () {
                          final n = live.waitingCount(stopId: s.id, destId: dest.id);
                          return BWListItem(
                            icon: n > 0 ? 'map-pin' : 'check',
                            tone: n > 0 ? Tone.teal : Tone.neutral,
                            title: s.name,
                            subtitle: n > 0 ? s.sub : app.t('Cidna ma sugayso · No one waiting', 'No one waiting · Cidna ma sugayso'),
                            divider: i < stops.length - 1,
                            dim: n == 0,
                            trailing: WaitingCount(count: n, label: ''),
                            onTap: n == 0
                                ? null
                                : () async {
                                    final got = await live.pickUp(s.id);
                                    showToast(ToastData(app.t('$got qof ayaa la qaaday · ${s.name}', 'Picked up $got · ${s.name}'), icon: 'check', tone: ToastTone.success));
                                  },
                          );
                        }(),
                      if (stops.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(app.t('Tuuladan joogsi lama gelin weli.', 'No stops added for this village yet.'), style: BWText.small)),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const BWIcon('info', size: 16, color: BW.night600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        app.t('Taabo joogsi marka aad qaaddo rakaabka. App-ka fur inta aad wado.', 'Tap a stop after picking up. Keep the app open while driving.'),
                        style: const TextStyle(fontSize: 13, height: 18 / 13, color: BW.textSecondary),
                      ),
                    ),
                  ]),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(children: [
                  Expanded(child: BWButton(app.t('Beddel', 'Change'), subLabel: app.t('Meesha · Destination', 'Destination'), icon: 'route', variant: BtnVariant.outline, small: true, onTap: () => _changeDest(context, app))),
                  const SizedBox(width: 10),
                  Expanded(child: BWButton(app.t('Ka bax', 'Withdraw'), subLabel: app.t('Tuulada · Village', 'Village'), icon: 'log-out', variant: BtnVariant.outline, small: true, onTap: () => _withdraw(context, app, v.nameSo))),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }

  void _changeDest(BuildContext context, AppState app) {
    final live = app.live;
    final me = live.me!;
    final v = live.villageById(me.villageId!);
    final others = live.villagesOf(v.districtId).where((x) => x.id != v.id).toList();
    var to = me.destinationId!;
    showBWSheet(
      context,
      icon: 'route',
      title: app.t('Xagee u socotaa hadda?', 'Where to now?'),
      subtitle: app.t('Safar cusub. Waxaad ku sii jiraysaa ${v.nameSo}.', 'A new trip. You stay in ${v.nameEn}.'),
      body: StatefulBuilder(
        builder: (ctx, set) => BWRadioGroup(
          value: to,
          onChange: (x) => set(() => to = x),
          options: [for (final o in others) RadioOption(o.id, o.nameSo, app.t('${live.waitingCount(villageId: v.id, destId: o.id)} qof ayaa u socda', '${live.waitingCount(villageId: v.id, destId: o.id)} people going'))],
        ),
      ),
      actions: (ctx) => [
        BWButton(app.t('Kaydi', 'Save'), subLabel: app.sub('Kaydi', 'Save'), icon: 'check', onTap: () async {
          Navigator.pop(ctx);
          final err = await live.changeDestination(to);
          if (err != null) showToast(ToastData(errorText(app, err), icon: 'circle-alert', tone: ToastTone.danger));
        }),
        BWButton(app.t('Maya', 'Cancel'), variant: BtnVariant.ghost, onTap: () => Navigator.pop(ctx)),
      ],
    );
  }

  void _withdraw(BuildContext context, AppState app, String village) {
    showBWSheet(
      context,
      icon: 'log-out',
      title: app.t('Ka bax $village?', 'Leave $village?'),
      subtitle: app.t("Rakaabka ma arki doonaan baskaaga. Riders won't see your bus here.", "Riders won't see your bus here. Rakaabka ma arki doonaan baskaaga."),
      actions: (ctx) => [
        BWButton(app.t('Haa, ka bax', 'Yes, withdraw'), subLabel: app.t('Withdraw, choose another village', 'Ka bax, dooro tuulo kale'), variant: BtnVariant.dark, onTap: () async {
          Navigator.pop(ctx);
          final err = await app.live.withdraw();
          if (err != null) {
            showToast(ToastData(errorText(app, err), icon: 'circle-alert', tone: ToastTone.danger));
            return;
          }
          showToast(ToastData(app.t('Waad ka baxday $village', 'You left $village'), icon: 'log-out'));
          if (context.mounted) context.go('/driver/village');
        }),
        BWButton(app.t('Maya, sii joog', 'No, stay'), variant: BtnVariant.ghost, onTap: () => Navigator.pop(ctx)),
      ],
    );
  }
}

class _DarkToggle extends StatelessWidget {
  const _DarkToggle({required this.on, required this.label, required this.onTap, required this.icon, this.onColor = BW.teal});
  final bool on;
  final String label, icon;
  final VoidCallback onTap;
  final Color onColor;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: false,
        semanticLabel: label,
        builder: (_) => Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: BW.night, borderRadius: BorderRadius.circular(BW.rSm)),
          child: Row(children: [
            BWIcon(icon, size: 20, color: on ? BW.teal300 : BW.onDarkMuted),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: BW.white))),
            AnimatedContainer(
              duration: BW.base,
              width: 52,
              height: 32,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: on ? onColor : BW.night600, borderRadius: BorderRadius.circular(16)),
              alignment: on ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: BW.white, shape: BoxShape.circle)),
            ),
          ]),
        ),
      );
}
