import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'core.dart';

enum LogoVariant { lockup, mark, wordmark }

class BWLogo extends StatelessWidget {
  const BWLogo({super.key, this.variant = LogoVariant.lockup, this.reverse = false, required this.height});
  final LogoVariant variant;
  final bool reverse;
  final double height;
  @override
  Widget build(BuildContext context) {
    final name = switch (variant) { LogoVariant.lockup => 'lockup', LogoVariant.mark => 'mark', LogoVariant.wordmark => 'wordmark' };
    return Image.asset('assets/logo/logo-$name${reverse ? '-reverse' : ''}.png', height: height, semanticLabel: 'BusWhere', filterQuality: FilterQuality.medium);
  }
}

/// Big minutes number + "daqiiqo". 0 minutes reads "Hadda" on yellow.
class EtaPill extends StatelessWidget {
  const EtaPill({super.key, required this.minutes, this.large = false, this.dark = false, this.unit = 'daqiiqo', this.nowLabel = 'Hadda', this.muted = false});
  final int minutes;
  final bool large, dark, muted;
  final String unit, nowLabel;
  @override
  Widget build(BuildContext context) {
    final now = minutes == 0 && !muted;
    final bg = now ? BW.busYellow : dark ? BW.night700 : BW.sand200;
    final fg = now ? BW.night : dark ? BW.white : (muted ? BW.night500 : BW.night);
    final uc = dark ? BW.onDarkMuted : BW.textSecondary;
    final content = now
        ? Text(nowLabel, style: TextStyle(fontSize: large ? 28 : 18, height: large ? 36 / 28 : 28 / 18, fontWeight: FontWeight.w700, color: fg))
        : large
            ? Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('$minutes', style: BWText.eta.copyWith(color: fg)),
                const SizedBox(width: 4),
                Text(unit, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: uc)),
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Text('$minutes', style: TextStyle(fontSize: 24, height: 28 / 24, fontWeight: FontWeight.w700, letterSpacing: -0.48, color: fg)),
                Text(unit, style: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600, color: uc)),
              ]);
    return AnimatedContainer(
      duration: BW.base,
      constraints: BoxConstraints(minWidth: large ? 96 : 64, minHeight: large ? 0 : 52),
      padding: large ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10) : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(large ? BW.rLg : BW.rSm)),
      alignment: Alignment.center,
      child: content,
    );
  }
}

/// The logo's three dots, reused as a riders-waiting meter.
class WaitingCount extends StatelessWidget {
  const WaitingCount({super.key, required this.count, this.label = 'sugaya', this.subLabel, this.large = false, this.dark = false});
  final int count;
  final String label;
  final String? subLabel;
  final bool large, dark;
  @override
  Widget build(BuildContext context) {
    final dot = dark ? BW.teal300 : BW.teal;
    final off = dark ? BW.night600 : BW.night300;
    final d = large ? 12.0 : 8.0;
    final dots = Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 3; i++) ...[
        if (i > 0) SizedBox(width: large ? 5 : 3),
        AnimatedContainer(duration: BW.base, width: d, height: d, decoration: BoxDecoration(color: count > i ? dot : off, shape: BoxShape.circle)),
      ],
    ]);
    final num = Text('$count', style: TextStyle(fontSize: large ? 40 : 18, height: large ? 44 / 40 : 24 / 18, fontWeight: FontWeight.w700, letterSpacing: large ? -0.8 : -0.36, color: dark ? BW.white : BW.night));
    final lab = label.isEmpty && subLabel == null
        ? null
        : Text.rich(
            TextSpan(children: [
              TextSpan(text: label),
              if (subLabel != null) TextSpan(text: ' · $subLabel', style: const TextStyle(fontWeight: FontWeight.w400)),
            ]),
            style: TextStyle(fontSize: large ? 16 : 14, height: 20 / 14, fontWeight: FontWeight.w600, color: dark ? BW.onDarkMuted : BW.textSecondary),
          );
    final head = Row(mainAxisSize: MainAxisSize.min, children: [dots, SizedBox(width: large ? 10 : 6), num]);
    if (large) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [head, if (lab != null) ...[const SizedBox(height: 6), lab]]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [head, if (lab != null) ...[const SizedBox(width: 8), lab]]);
  }
}

enum StatusTone { neutral, teal, danger }

class BusCard extends StatelessWidget {
  const BusCard({super.key, required this.route, this.detail, this.minutes, this.status, this.statusTone = StatusTone.neutral, this.waiting, this.onTap, this.selected = false, this.muted = false, this.unit = 'daqiiqo', this.nowLabel = 'Hadda'});
  final String route;
  final String? detail, status;
  final int? minutes, waiting;
  final StatusTone statusTone;
  final VoidCallback? onTap;
  final bool selected, muted;
  final String unit, nowLabel;
  @override
  Widget build(BuildContext context) {
    final st = switch (statusTone) { StatusTone.neutral => BW.textSecondary, StatusTone.teal => BW.teal, StatusTone.danger => BW.red600 };
    return Pressable(
      onTap: onTap,
      scale: false,
      semanticLabel: [route, ?detail, ?status, if (minutes != null) (minutes == 0 ? nowLabel : '$minutes $unit')].join(', '),
      builder: (p) => AnimatedContainer(
        duration: BW.fast,
        constraints: const BoxConstraints(minHeight: 80),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p ? BW.sand200 : BW.white,
          borderRadius: BorderRadius.circular(BW.rLg),
          border: Border.all(color: selected ? BW.busYellow : Colors.transparent, width: 2),
        ),
        child: Opacity(
          opacity: muted ? 0.6 : 1,
          child: Row(children: [
            IconTile('bus-front', tone: muted ? Tone.neutral : Tone.yellow, size: 52, iconSize: 28, radius: 14),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(route, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w700)),
                if (detail != null) Text(detail!, maxLines: 2, overflow: TextOverflow.ellipsis, style: BWText.small.copyWith(color: BW.textSecondary)),
                if (status != null || waiting != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      if (status != null) Text(status!, style: BWText.label.copyWith(color: st)),
                      if (waiting != null)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const BWIcon('users', size: 16, color: BW.teal),
                          const SizedBox(width: 5),
                          Text('$waiting', style: BWText.label.copyWith(color: BW.teal)),
                        ]),
                    ]),
                  ),
              ]),
            ),
            if (minutes != null) ...[const SizedBox(width: 8), EtaPill(minutes: minutes!, muted: muted, unit: unit, nowLabel: nowLabel)],
          ]),
        ),
      ),
    );
  }
}

class RouteStop {
  const RouteStop(this.name, {this.sub, this.waiting});
  final String name;
  final String? sub;
  final int? waiting;
}

/// Stop-by-stop line. [busAt] is the bus's fractional stop index (1.5 = between stop 1 and 2).
class RouteLine extends StatelessWidget {
  const RouteLine({super.key, required this.stops, required this.busAt, this.myStop, this.myLabel = 'Tuuladaada'});
  final List<RouteStop> stops;
  final double busAt;
  final int? myStop;
  final String myLabel;
  @override
  Widget build(BuildContext context) {
    final between = busAt % 1 > 0.05 && busAt % 1 < 0.95;
    final at = between ? -1 : busAt.round();
    Color seg(bool done) => done ? BW.night300 : BW.teal;
    return Column(children: [
      for (var i = 0; i < stops.length; i++)
        Builder(builder: (_) {
          final s = stops[i];
          final passed = i < busAt && i != at;
          final busHere = i == at;
          final busAfter = between && i == busAt.floor();
          final mine = i == myStop;
          final last = i == stops.length - 1;
          return IntrinsicHeight(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 68),
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  width: 40,
                  child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
                    if (i > 0) Positioned(top: 0, height: 20, child: Container(width: 4, color: seg(busAt >= i))),
                    if (!last) Positioned(top: 20, bottom: 0, child: Container(width: 4, color: seg(busAt >= i + 1))),
                    if (busHere)
                      const IconTile('bus-front', tone: Tone.yellow, size: 40, radius: 12)
                    else
                      Padding(
                        padding: EdgeInsets.only(top: mine ? 9 : 11),
                        child: Container(
                          width: mine ? 22 : 18,
                          height: mine ? 22 : 18,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: mine ? BW.teal : BW.white, border: Border.all(color: passed ? BW.night300 : BW.teal, width: 4)),
                        ),
                      ),
                    if (busAfter) const Positioned(top: 38, child: IconTile('bus-front', tone: Tone.yellow, size: 36, iconSize: 22, radius: 10)),
                  ]),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: busHere ? 8 : 6, bottom: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text(s.name, style: TextStyle(fontSize: 17, height: 24 / 17, fontWeight: mine || busHere ? FontWeight.w700 : FontWeight.w600, color: passed ? BW.night500 : BW.night)),
                        if (mine) Text(myLabel, style: const TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w700, color: BW.teal)),
                      ]),
                      if (s.sub != null) Text(s.sub!, style: BWText.small.copyWith(color: BW.textSecondary)),
                    ]),
                  ),
                ),
                if (s.waiting != null && !passed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const BWIcon('users', size: 18, color: BW.teal),
                      const SizedBox(width: 5),
                      Text('${s.waiting}', style: const TextStyle(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w700, color: BW.teal)),
                    ]),
                  ),
              ]),
            ),
          );
        }),
    ]);
  }
}

/// "Toos · 4 il. kahor" — always say how fresh data is.
String freshness(DateTime t, bool en) {
  final s = DateTime.now().difference(t).inSeconds;
  if (s < 60) return en ? '${s}s ago' : '$s il. kahor';
  final m = s ~/ 60;
  return en ? '$m min ago' : '$m daqiiqo kahor';
}
