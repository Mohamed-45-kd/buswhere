import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/core.dart';
import '../widgets/entrance.dart';
import '../widgets/transit.dart';

/// How BusWhere works, in three cards, shown once before the rider's first trip.
/// Each card shows a small piece of the real UI instead of an illustration.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _finish() {
    final app = AppScope.read(context);
    app.setIntroSeen();
    context.go(app.tripReady ? '/rider' : '/rider/locate');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final cards = [
      (
        step: app.t('1 · Dooro', '1 · Choose'),
        title: app.t('Xagee joogtaa, xagee u socotaa?', 'Where are you, where are you going?'),
        body: app.t('Dooro tuuladaada iyo meesha aad u socoto. App-ku wuu xasuustaa safarkaaga.', 'Pick your village and where you are going. The app remembers your trip.'),
        scene: const _ChooseScene(),
      ),
      (
        step: app.t('2 · Arag', '2 · See'),
        title: app.t('Arag basaska tooska ah', 'See the buses live'),
        body: app.t('Basaska u socda meeshaada iyo inta daqiiqo ay kaa xigaan. Hadda = basku waa yimid.', 'Buses heading your way and how many minutes away. Hadda = the bus is here.'),
        scene: const _SeeScene(),
      ),
      (
        step: app.t('3 · Sug', '3 · Wait'),
        title: app.t('Taabo "Waan sugayaa"', 'Tap "Waan sugayaa"'),
        body: app.t('Darawalku wuu arkaa inta qof ee sugaya joogsi kasta, si uu kuugu yimaado.', 'Drivers see how many people wait at each stop, so they come to you.'),
        scene: const _WaitScene(),
      ),
    ];
    final last = _page == cards.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(children: [
              Text(app.t('Sida ay u shaqeyso', 'How it works'), style: BWText.label.copyWith(color: BW.textSecondary)),
              const Spacer(),
              BWButton(app.t('Ka bood', 'Skip'), variant: BtnVariant.ghost, small: true, fullWidth: false, onTap: _finish),
            ]),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: cards.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final c = cards[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: BW.night, borderRadius: BorderRadius.circular(BW.rXl)),
                        child: Center(child: Entrance(key: ValueKey(i), child: c.scene)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    BWBadge(c.step, tone: BadgeTone.info, small: true),
                    const SizedBox(height: 10),
                    Text(c.title, style: BWText.h1),
                    const SizedBox(height: 8),
                    Text(c.body, style: BWText.body.copyWith(color: BW.textSecondary)),
                  ]),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          // The logo's three dots, as the page indicator.
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < cards.length; i++)
              AnimatedContainer(
                duration: BW.base,
                curve: BW.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _page ? 24 : 10,
                height: 10,
                decoration: BoxDecoration(color: i <= _page ? BW.teal : BW.night300, borderRadius: BorderRadius.circular(5)),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(16),
            child: BWButton(
              last ? app.t('Bilow', 'Start') : app.t('Sii wad', 'Next'),
              subLabel: last ? app.t('Dooro tuuladaada · Choose your village', 'Choose your village · Dooro tuuladaada') : app.sub('Sii wad', 'Next'),
              iconRight: 'arrow-right',
              onTap: last ? _finish : () => _pages.nextPage(duration: BW.base, curve: BW.easeOut),
            ),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── scenes (pieces of the real UI, not interactive)

class _ChooseScene extends StatelessWidget {
  const _ChooseScene();
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _Pill(dot: BW.teal, text: 'Jigjiga Yar → Masalaha'),
          const SizedBox(height: 14),
          BWCard(
            padding: EdgeInsets.zero,
            child: Column(children: const [
              BWListItem(icon: 'map-pin', tone: Tone.teal, title: 'Jigjiga Yar', subtitle: '26 Juun · 3 bas', divider: true, trailing: BWIcon('circle-check', color: BW.teal)),
              BWListItem(icon: 'map-pin', tone: Tone.teal, title: 'Masalaha', subtitle: '26 Juun · 2 bas', divider: true),
              BWListItem(icon: 'map-pin', tone: Tone.neutral, title: 'Calaamadaha', subtitle: '26 Juun · 1 bas', dim: true),
            ]),
          ),
        ]),
      );
}

class _SeeScene extends StatelessWidget {
  const _SeeScene();
  @override
  Widget build(BuildContext context) => const IgnorePointer(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BusCard(route: 'Bas 12 · Cali', detail: 'Wuxuu ag joogaa Dugsiga', status: 'Wuu socdaa', statusTone: StatusTone.teal, waiting: 4, minutes: 0, selected: true),
          SizedBox(height: 10),
          BusCard(route: 'Bas 4 · Maxamed', detail: '1.8 km u jira Isgoyska weyn', status: 'Wuu socdaa', statusTone: StatusTone.teal, waiting: 4, minutes: 7),
        ]),
      );
}

class _WaitScene extends StatelessWidget {
  const _WaitScene();
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: BW.night700, borderRadius: BorderRadius.circular(BW.rLg)),
            child: const Row(children: [
              Expanded(child: Text('Isgoyska weyn\nDarawalka ayaa arka', style: TextStyle(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w600, color: BW.onDarkMuted))),
              WaitingCount(count: 5, large: true, dark: true, label: 'qof sugaya'),
            ]),
          ),
          const SizedBox(height: 14),
          BWButton('Waan sugayaa', subLabel: "I'm waiting", icon: 'hand', onTap: () {}),
        ]),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.dot, required this.text});
  final Color dot;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: BW.white, borderRadius: BorderRadius.circular(BW.rMd)),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: BW.night))),
          const Text('Beddel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BW.teal)),
        ]),
      );
}
