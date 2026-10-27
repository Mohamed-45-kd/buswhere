import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/core.dart';
import '../../widgets/toast_host.dart';

/// Step 2 (where you are) and step 3 (where you're going).
class VillageScreen extends StatefulWidget {
  const VillageScreen({super.key, required this.step});
  final int step;
  @override
  State<VillageScreen> createState() => _VillageScreenState();
}

class _VillageScreenState extends State<VillageScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final live = app.live;
    final isFrom = widget.step == 2;
    final districtId = app.districtId ?? '26juun';
    final from = app.fromId == null ? null : live.villageById(app.fromId!);
    final all = live.villagesOf(districtId).where((v) => isFrom || v.id != app.fromId).toList()
      ..sort((a, b) => (app.favourites.contains(b.id) ? 1 : 0) - (app.favourites.contains(a.id) ? 1 : 0));
    final shown = all.where((v) => v.nameSo.toLowerCase().contains(_q.toLowerCase()) || v.nameEn.toLowerCase().contains(_q.toLowerCase())).toList();
    final recent = app.recent.where((id) => all.any((v) => v.id == id)).map(live.villageById).toList();
    final district = live.districtById(districtId);
    final title = isFrom ? app.t('Xagee joogtaa?', 'Where are you?') : app.t('Xagee u socotaa?', 'Where are you going?');
    final sub = isFrom ? app.sub('Xagee joogtaa?', 'Which village are you in?') : app.sub('Xagee u socotaa?', 'Where are you going?');

    Future<void> useMyLocation() async {
      final err = await live.locateRider();
      if (!context.mounted) return;
      if (err != null) {
        showToast(ToastData(
          err == 'denied'
              ? app.t('Goobta waa la diiday. U oggolow BusWhere goobta, ama dooro tuuladaada hoos.', 'Location is blocked. Allow it for BusWhere, or pick your village below.')
              : app.t('Goobtaada lama helin. Dooro tuuladaada hoos.', "Couldn't find you. Pick your village below."),
          icon: 'circle-alert',
          tone: ToastTone.danger,
          seconds: 6,
        ));
        return;
      }
      final n = live.nearestVillage(live.riderPos!, districtId: districtId);
      if (n == null || n.m > 3000) {
        final d = n == null ? '' : ' (${(n.m / 1000).toStringAsFixed(1)} km)';
        showToast(ToastData(
          app.t('Kama dhowid tuulooyinka ${live.districtById(districtId).name}$d. Dooro hoos.', "You're not near a ${live.districtById(districtId).name} village$d. Pick one below."),
          icon: 'map-pin',
          seconds: 6,
        ));
        return;
      }
      app.setFrom(n.village.id);
      final stop = live.nearestStopTo(live.riderPos!, n.village.id);
      if (stop != null) app.setStop(stop.stop.id);
      showToast(ToastData(
        app.t('Waxaad joogtaa ${n.village.nameSo}${stop == null ? '' : ' · ${stop.stop.name}'}', 'You are in ${n.village.nameEn}${stop == null ? '' : ' · ${stop.stop.name}'}'),
        icon: 'circle-check',
        tone: ToastTone.success,
      ));
      context.go('/rider/to');
    }

    void pick(String id) {
      if (isFrom) {
        app.setFrom(id);
        context.go('/rider/to');
      } else {
        app.setTo(id);
        live.stopWaiting();
        context.go('/rider');
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          BWTopBar(title: title, subtitle: sub, onBack: () => context.go(isFrom ? '/rider/city' : '/rider/from')),
          StepBar(widget.step),
          Expanded(
            child: ListenableBuilder(
              listenable: live,
              builder: (context, _) => ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
                if (!isFrom && from != null) ...[
                  BWCard(
                    variant: CardVariant.sunken,
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Container(width: 14, height: 14, decoration: const BoxDecoration(color: BW.teal, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(TextSpan(children: [
                          TextSpan(text: app.t('Waxaad joogtaa ', 'You are in ')),
                          TextSpan(text: from.nameSo, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ]), style: const TextStyle(fontSize: 15)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                ],
                if (isFrom) ...[
                  BWCard(
                    variant: CardVariant.info,
                    padding: EdgeInsets.zero,
                    onTap: live.locating ? null : useMyLocation,
                    child: BWListItem(
                      icon: live.locating ? 'refresh-cw' : 'locate-fixed',
                      tone: Tone.teal,
                      title: live.locating ? app.t('Waa la raadinayaa…', 'Finding you…') : app.t('Isticmaal goobtayda', 'Use my location'),
                      subtitle: app.t('Waxaan helaynaa tuulada iyo joogsiga kuugu dhow', 'We find your nearest village and stop'),
                      chevron: !live.locating,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                BWInput(icon: 'search', hint: app.t('Raadi tuulo · Search village', 'Search village · Raadi tuulo'), onChanged: (v) => setState(() => _q = v)),
                if (recent.isNotEmpty && _q.isEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: [for (final r in recent) BWTag(r.nameSo, icon: 'clock', onTap: () => pick(r.id))]),
                ],
                const SizedBox(height: 14),
                BWCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (final (i, v) in shown.indexed)
                      BWListItem(
                        icon: 'map-pin',
                        tone: Tone.teal,
                        title: v.nameSo,
                        subtitle: () {
                          final n = live.activeBusCount(v.id);
                          return '${district.name} · ${app.t('$n bas hadda', '$n buses now')}';
                        }(),
                        divider: i < shown.length - 1,
                        chevron: true,
                        trailing: _FavButton(on: app.favourites.contains(v.id), onTap: () => app.toggleFavourite(v.id), label: app.t('Jeclaysi', 'Favourite')),
                        onTap: () => pick(v.id),
                      ),
                    if (shown.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text(app.t('Lama helin · Not found', 'Not found · Lama helin'), style: const TextStyle(color: BW.textSecondary))),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _FavButton extends StatelessWidget {
  const _FavButton({required this.on, required this.onTap, required this.label});
  final bool on;
  final VoidCallback onTap;
  final String label;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        semanticLabel: label,
        builder: (_) => SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Stack(alignment: Alignment.center, children: [
              BWIcon('heart', size: 22, color: on ? BW.teal : BW.night300),
              if (on) Container(width: 8, height: 8, decoration: const BoxDecoration(color: BW.teal, shape: BoxShape.circle)),
            ]),
          ),
        ),
      );
}
