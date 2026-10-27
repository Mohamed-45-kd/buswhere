import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/core.dart';
import '../../widgets/errors.dart';
import '../../widgets/toast_host.dart';
import '../../widgets/transit.dart';

/// Cities → villages, one tap to pick; then where the bus is going.
class VillagePickScreen extends StatefulWidget {
  const VillagePickScreen({super.key});
  @override
  State<VillagePickScreen> createState() => _VillagePickScreenState();
}

class _VillagePickScreenState extends State<VillagePickScreen> {
  String _city = 'hargeysa';
  Village? _village;
  String? _dest;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(body: SafeArea(child: ListenableBuilder(listenable: app.live, builder: (context, _) => _village == null ? _list(app) : _destination(app, _village!))));
  }

  Widget _list(AppState app) {
    final live = app.live;
    final d = live.me;
    if (d == null) return const SizedBox.shrink();
    final districts = live.districtsOf(_city).where((x) => x.isActive).toList();
    final villages = [for (final dd in districts) ...live.villagesOf(dd.id)];
    final total = villages.fold(0, (s, v) => s + live.waitingCount(villageId: v.id));
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 22),
        decoration: const BoxDecoration(color: BW.night, borderRadius: BorderRadius.vertical(bottom: Radius.circular(BW.rXl))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const BWLogo(variant: LogoVariant.wordmark, reverse: true, height: 22),
            const Spacer(),
            BWBadge('Bas ${d.busNumber ?? '—'}', tone: BadgeTone.dark, dot: true),
            BWIconButton('log-out', label: app.t('Ka bax akoonka', 'Sign out'), variant: IconBtnVariant.dark, onTap: () async {
              await live.driverSignOut();
              if (mounted) context.go('/');
            }),
          ]),
          const SizedBox(height: 14),
          Text(app.t('Salaan, ${d.name}', 'Hello, ${d.name}'), style: BWText.h1.copyWith(color: BW.white)),
          Text('${live.cityById(_city).nameSo} · ${districts.map((x) => x.name).join(', ')}', style: const TextStyle(fontSize: 15, color: BW.onDarkMuted)),
          const SizedBox(height: 16),
          WaitingCount(count: total, large: true, dark: true, label: app.t('qof ayaa sugaya degmada', 'people waiting in the district'), subLabel: app.sub('sugaya', 'waiting')),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(app.t('Ku biir tuulo', 'Join a village'), style: BWText.h3),
          Text(app.t('Join one village at a time', 'Hal tuulo markiiba'), style: BWText.small.copyWith(color: BW.textSecondary)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            for (final c in live.cities) BWTag(app.en ? c.nameEn : c.nameSo, selected: c.id == _city, disabled: !c.isActive, onTap: () => setState(() => _city = c.id)),
          ]),
        ]),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
          BWCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final (i, v) in villages.indexed)
                () {
                  final n = live.waitingCount(villageId: v.id);
                  final b = live.activeBusCount(v.id);
                  return BWListItem(
                    icon: 'map-pin',
                    tone: n > 0 ? Tone.teal : Tone.neutral,
                    title: v.nameSo,
                    subtitle: app.t('$b bas ayaa ka shaqeeya', '$b buses working here'),
                    divider: i < villages.length - 1,
                    chevron: true,
                    trailing: WaitingCount(count: n, label: ''),
                    onTap: () => setState(() {
                      _village = v;
                      _dest = null;
                    }),
                  );
                }(),
            ]),
          ),
        ]),
      ),
    ]);
  }

  Widget _destination(AppState app, Village v) {
    final live = app.live;
    final others = live.villagesOf(v.districtId).where((x) => x.id != v.id).toList()
      ..sort((a, b) => live.waitingCount(villageId: v.id, destId: b.id).compareTo(live.waitingCount(villageId: v.id, destId: a.id)));
    if (others.isEmpty) return const SizedBox.shrink();
    final dest = _dest ?? others.first.id;
    return Column(children: [
      BWTopBar(title: v.nameSo, subtitle: app.t('Ku biir tuuladan · Join this village', 'Join this village · Ku biir tuuladan'), onBack: () => setState(() => _village = null)),
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
          BWCard(
            variant: CardVariant.dark,
            child: Row(children: [
              Expanded(child: Text(app.t('Hadda sugaya\nWaiting now', 'Waiting now\nHadda sugaya'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: BW.onDarkMuted))),
              WaitingCount(count: live.waitingCount(villageId: v.id), large: true, dark: true, label: app.t('qof', 'people')),
            ]),
          ),
          const SizedBox(height: 12),
          BWCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.t('Xagee u socotaa?', 'Where is the bus going?'), style: BWText.h3),
              Text(app.sub('Xagee u socotaa?', 'Where is the bus going?'), style: BWText.small.copyWith(color: BW.textSecondary)),
              const SizedBox(height: 6),
              BWRadioGroup(
                value: dest,
                onChange: (x) => setState(() => _dest = x),
                options: [
                  for (final o in others)
                    RadioOption(o.id, o.nameSo, app.t('${live.waitingCount(villageId: v.id, destId: o.id)} qof ayaa halkaas u socda', '${live.waitingCount(villageId: v.id, destId: o.id)} people going there')),
                ],
              ),
            ]),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: BWButton(app.t('Ku biir oo bilow', 'Join and start'), subLabel: app.sub('Ku biir oo bilow', 'Join and start'), icon: 'play', busy: _busy, onTap: () async {
          setState(() => _busy = true);
          final err = await live.assign(v.id, dest);
          if (!mounted) return;
          setState(() => _busy = false);
          if (err == null || err == 'already-active') {
            showToast(err == null
                ? ToastData(app.t('Waxaad ku biirtay ${v.nameSo}', 'You joined ${v.nameEn}'), icon: 'circle-check', tone: ToastTone.success)
                : ToastData(errorText(app, err), icon: 'circle-alert', tone: ToastTone.danger));
            context.go('/driver');
          } else {
            showToast(ToastData(errorText(app, err), icon: 'circle-alert', tone: ToastTone.danger));
          }
        }),
      ),
    ]);
  }
}
