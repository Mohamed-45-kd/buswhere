import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/core.dart';
import '../../widgets/transit.dart';
import 'wait_sheet.dart';

/// Plate, driver first name, ETA, seats (later) and the stop-by-stop line.
class BusDetailScreen extends StatelessWidget {
  const BusDetailScreen({super.key, required this.busId});
  final String busId;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final live = app.live;
    void back() => context.canPop() ? context.pop() : context.go('/rider');
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: live,
          builder: (context, _) {
            final from = live.villageById(app.fromId!), to = live.villageById(app.toId!);
            final stops = live.stopsOf(from.id);
            final myStop = live.stopOrNull(app.stopId) ?? stops.firstOrNull;
            final v = live.busesFor(from.id, to.id, myStop?.id).where((b) => b.live.busId == busId).firstOrNull;
            final bus = live.busById(busId);
            final title = 'Bas ${v?.live.busNumber ?? bus?.number ?? ''}';
            if (v == null) {
              return Column(children: [
                BWTopBar(title: title, subtitle: '${from.nameSo} → ${to.nameSo}', onBack: back),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: BWBanner(
                    tone: BannerTone.info,
                    title: app.t('Basku hadda ma muuqdo', 'This bus is not showing now'),
                    message: app.t('Darawalku wuu ka baxay tuulada ama xiriirka ayaa go\'ay.', 'The driver left the village or lost connection.'),
                    actionLabel: app.t('Ku noqo', 'Back'),
                    onAction: back,
                  ),
                ),
              ]);
            }
            final waiting = live.myRequest != null && live.myRequest!.villageId == from.id && live.myRequest!.destinationVillageId == to.id;
            final lb = v.live;

            // Where the bus is along the village's stops: at a stop when within 120 m,
            // otherwise a separate "on the way" point before the stop it is heading for.
            final near = live.nearestStop(lb);
            final atStop = near != null && live.distance(near.pos, lb.position!) < 120;
            final nearIdx = near == null ? 0 : stops.indexWhere((s) => s.id == near.id);
            final lead = atStop ? 0 : 1; // extra node for the bus on the road
            final km = near == null ? '' : (live.distance(near.pos, lb.position!) / 1000).toStringAsFixed(1);
            final routeStops = [
              for (final (i, s) in stops.indexed) ...[
                if (!atStop && i == nearIdx) RouteStop(app.t('Basku hadda', 'The bus now'), sub: app.t('$km km ka hor ${s.name}', '$km km before ${s.name}')),
                RouteStop(
                  s.name,
                  sub: s.id == myStop?.id ? app.t('Halkaad joogto · You are here', 'You are here · Halkaad joogto') : s.sub,
                  waiting: live.waitingCount(stopId: s.id, destId: lb.destinationId),
                ),
              ],
              RouteStop(live.villageOrNull(lb.destinationId)?.nameSo ?? '', sub: v.matching ? app.t('Meesha aad u socoto · Destination', 'Destination · Meesha aad u socoto') : app.t('Halka uu basku u socdo', 'Where this bus is going')),
            ];
            final busAt = nearIdx.toDouble();
            final myIdx = stops.indexWhere((s) => s.id == myStop?.id);
            final myNode = myIdx < 0 ? null : myIdx + (!atStop && myIdx >= nearIdx ? lead : 0);

            return Column(children: [
              BWTopBar(title: title, subtitle: '${from.nameSo} → ${to.nameSo}', onBack: back),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
                  BWCard(
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(app.t('Wuxuu imanayaa · Arrives in', 'Arrives in · Wuxuu imanayaa'), style: BWText.label.copyWith(color: BW.textSecondary)),
                          const SizedBox(height: 8),
                          BWBadge(
                            lb.full ? app.t('Buuxa · Full', 'Full · Buuxa') : (lb.stale ? app.t('Xogtii hore', 'Last seen') : app.t('Wuu socdaa', 'On the way')),
                            tone: lb.full ? BadgeTone.danger : (lb.stale ? BadgeTone.neutral : BadgeTone.live),
                            dot: true,
                          ),
                        ]),
                      ),
                      EtaPill(minutes: v.eta, large: true, unit: app.t('daqiiqo', 'min'), nowLabel: app.t('Hadda', 'Now')),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  BWCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      BWListItem(icon: 'bus-front', tone: Tone.yellow, title: bus?.plate ?? '—', subtitle: app.t('Taarikada · Plate', 'Plate · Taarikada'), divider: true),
                      BWListItem(icon: 'user-round', tone: Tone.neutral, title: lb.driverName, subtitle: app.t('Darawalka · Driver', 'Driver · Darawalka'), divider: true),
                      BWListItem(icon: 'users', tone: Tone.teal, title: app.t('Kuraasta · dhowaan', 'Seats · coming soon'), subtitle: bus == null ? null : app.t('${bus.capacity} kursi', '${bus.capacity} seats')),
                    ]),
                  ),
                  if (stops.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    BWCard(child: RouteLine(stops: routeStops, busAt: busAt, myStop: myNode, myLabel: app.t('Tuuladaada', 'Your stop'))),
                  ],
                  const SizedBox(height: 12),
                  BWCard(
                    variant: CardVariant.sunken,
                    child: Row(children: [
                      Expanded(child: Text(app.t('${from.nameSo} · dadka sugaya', '${from.nameEn} · people waiting'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                      WaitingCount(count: live.waitingCount(villageId: from.id, destId: to.id), label: app.t('qof', 'people')),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Text('${app.t('Xogtii', 'Updated')} ${freshness(lb.updatedAt, app.en)}', textAlign: TextAlign.center, style: BWText.small.copyWith(color: BW.night500)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: BWButton(
                  waiting ? app.t('Jooji sugitaanka', 'Stop waiting') : app.t('Waan sugayaa', "I'm waiting"),
                  subLabel: waiting ? app.sub('Jooji sugitaanka', 'Stop waiting') : app.sub('Waan sugayaa', "I'm waiting"),
                  icon: waiting ? 'x' : 'hand',
                  variant: waiting ? BtnVariant.outline : BtnVariant.primary,
                  onTap: myStop == null ? null : () => waiting ? showStopWaitSheet(context) : showWaitSheet(context),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
