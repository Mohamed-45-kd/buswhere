import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/core.dart';
import '../widgets/entrance.dart';
import '../widgets/transit.dart';

/// First thing a person sees: the brand, proof the buses are live, and one way in.
/// Drivers and admins have quieter doors at the bottom.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final live = app.live;
    void start() {
      app.setRole('rider');
      context.go(!app.introSeen ? '/intro' : (app.tripReady ? '/rider' : '/rider/city'));
    }

    return Scaffold(
      backgroundColor: BW.night,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const BWLogo(variant: LogoVariant.wordmark, reverse: true, height: 22),
              const Spacer(),
              BWSegmented(onDark: true, value: app.lang, onChange: app.setLang, options: const [SegOption('so', 'Soomaali'), SegOption('en', 'English')]),
            ]),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Entrance(child: BWLogo(variant: LogoVariant.mark, reverse: true, height: 132)),
                const SizedBox(height: 28),
                Entrance(
                  delay: const Duration(milliseconds: 80),
                  child: Text(app.t('Ogow halka uu basku joogo', 'Know where the bus is'), style: BWText.display.copyWith(color: BW.white)),
                ),
                const SizedBox(height: 8),
                Entrance(
                  delay: const Duration(milliseconds: 140),
                  child: Text(
                    app.t('Arag basaska tooska ah, ogow inta ay kaa xigaan, oo u sheeg darawalka inaad sugayso.', 'See buses live, know how far away they are, and tell the driver you are waiting.'),
                    style: BWText.bodyLg.copyWith(color: BW.onDarkMuted),
                  ),
                ),
                const SizedBox(height: 24),
                Entrance(
                  delay: const Duration(milliseconds: 200),
                  child: ListenableBuilder(listenable: live, builder: (context, _) => _LiveStrip(app)),
                ),
              ]),
            ),
            Entrance(
              delay: const Duration(milliseconds: 260),
              child: BWButton(app.t('Bilow', 'Start'), subLabel: app.t('Raadi baskaaga · Find your bus', 'Find your bus · Raadi baskaaga'), iconRight: 'arrow-right', onTap: start),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _QuietLink(icon: 'bus', label: app.t('Darawal ma tahay? Gal', 'Driver? Sign in'), onTap: () {
                app.setRole('driver');
                context.go('/driver');
              }),
              Container(width: 1, height: 18, color: BW.night600, margin: const EdgeInsets.symmetric(horizontal: 4)),
              _QuietLink(icon: 'settings', label: app.t('Maamulka', 'Admin'), onTap: () {
                app.setRole('admin');
                context.go('/admin');
              }),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// "Live now": how many buses are out and how many people are waiting.
class _LiveStrip extends StatelessWidget {
  const _LiveStrip(this.app);
  final AppState app;
  @override
  Widget build(BuildContext context) {
    final live = app.live;
    final buses = live.busLive.values.where((b) => b.visible).length;
    final waiting = live.waitingCount();
    final district = live.districts.where((d) => d.isActive).firstOrNull?.name ?? '26 Juun';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(color: BW.night700, borderRadius: BorderRadius.circular(BW.rLg)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          BWBadge(live.connected ? app.t('Toos hadda', 'Live now') : app.t('Xiriirinaya…', 'Connecting…'), tone: live.connected ? BadgeTone.live : BadgeTone.dark, dot: true, small: true),
          const Spacer(),
          Text('Hargeysa · $district', style: const TextStyle(fontSize: 13, color: BW.onDarkMuted)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _Stat(icon: 'bus-front', value: '$buses', label: app.t('bas toos ah', 'buses live'), tone: Tone.yellow),
          Container(width: 1, height: 36, color: BW.night600, margin: const EdgeInsets.symmetric(horizontal: 16)),
          Expanded(child: WaitingCount(count: waiting, dark: true, label: app.t('qof sugaya', 'people waiting'))),
        ]),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label, required this.tone});
  final String icon, value, label;
  final Tone tone;
  @override
  Widget build(BuildContext context) => Row(children: [
        IconTile(icon, tone: tone, size: 36, iconSize: 20, radius: 10),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 18, height: 22 / 18, fontWeight: FontWeight.w700, color: BW.white)),
          Text(label, style: const TextStyle(fontSize: 12, height: 16 / 12, color: BW.onDarkMuted)),
        ]),
      ]);
}

class _QuietLink extends StatelessWidget {
  const _QuietLink({required this.icon, required this.label, required this.onTap});
  final String icon, label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        semanticLabel: label,
        builder: (p) => Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: p ? BW.night700 : Colors.transparent, borderRadius: BorderRadius.circular(BW.rSm)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            BWIcon(icon, size: 18, color: BW.teal300),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: BW.white)),
          ]),
        ),
      );
}
