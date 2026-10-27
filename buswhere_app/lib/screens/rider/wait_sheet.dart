import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../widgets/core.dart';
import '../../widgets/errors.dart';
import '../../widgets/toast_host.dart';

/// "Ma sugaysaa?" — confirm waiting and pick the stop.
Future<void> showWaitSheet(BuildContext context) {
  final app = AppScope.read(context);
  final live = app.live;
  final from = live.villageById(app.fromId!), to = live.villageById(app.toId!);
  final stops = live.stopsOf(from.id);
  var stopId = stops.any((s) => s.id == app.stopId) ? app.stopId! : stops.first.id;
  return showBWSheet(
    context,
    icon: 'hand',
    title: app.t('Ma sugaysaa?', 'Are you waiting?'),
    subtitle: app.t('Darawallada u socda ${to.nameSo} ayaa arki doona inaad ${from.nameSo} joogto.', 'Drivers heading to ${to.nameEn} will see you are in ${from.nameEn}.'),
    body: StatefulBuilder(
      builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionLabel(app.t('Joogsigaaga', 'Your stop'), app.sub('Joogsigaaga', 'Your stop')),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in stops)
            BWTag(s.name, selected: s.id == stopId, icon: 'map-pin', onTap: () => set(() => stopId = s.id)),
        ]),
      ]),
    ),
    actions: (ctx) => [
      BWButton(app.t('Haa, waan sugayaa', "Yes, I'm waiting"), subLabel: app.sub('Haa, waan sugayaa', "Yes, I'm waiting"), onTap: () async {
        app.setStop(stopId);
        Navigator.pop(ctx);
        final err = await live.startWaiting(from.id, to.id, stopId);
        showToast(err == null
            ? ToastData(app.t('Darawalku wuu ku arkaa', 'The driver can see you'), icon: 'circle-check', tone: ToastTone.success)
            : ToastData(errorText(app, err), icon: 'circle-alert', tone: ToastTone.danger));
      }),
      BWButton(app.t('Maya', 'No'), variant: BtnVariant.ghost, onTap: () => Navigator.pop(ctx)),
    ],
  );
}

/// While waiting: "I'm on the bus" or stop waiting.
Future<void> showStopWaitSheet(BuildContext context) {
  final app = AppScope.read(context);
  return showBWSheet(
    context,
    icon: 'bus-front',
    title: app.t('Ma fuushay basku?', 'Are you on the bus?'),
    subtitle: app.t('Sugitaankaagu wuxuu dhacayaa 15 daqiiqo kadib.', 'Your wait ends by itself after 15 minutes.'),
    actions: (ctx) => [
      BWButton(app.t('Waan fuulay', "I'm on the bus"), subLabel: app.sub('Waan fuulay', "I'm on the bus"), icon: 'circle-check', onTap: () {
        app.live.stopWaiting(boarded: true);
        Navigator.pop(ctx);
        showToast(ToastData(app.t('Safar wanaagsan!', 'Have a good trip!'), icon: 'bus-front', tone: ToastTone.success));
      }),
      BWButton(app.t('Jooji sugitaanka', 'Stop waiting'), variant: BtnVariant.outline, icon: 'x', onTap: () {
        app.live.stopWaiting();
        Navigator.pop(ctx);
        showToast(ToastData(app.t('Sugitaanka waa la joojiyay', 'Waiting stopped'), icon: 'x'));
      }),
      BWButton(app.t('Ku noqo', 'Back'), variant: BtnVariant.ghost, onTap: () => Navigator.pop(ctx)),
    ],
  );
}
