import 'dart:async';

import 'package:flutter/material.dart';

import '../data/live_service.dart';
import '../platform/platform.dart' as platform;
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'core.dart';

class ToastData {
  const ToastData(this.message, {this.icon, this.tone = ToastTone.neutral, this.actionLabel, this.onAction, this.seconds = 4});
  final String message;
  final String? icon, actionLabel;
  final ToastTone tone;
  final VoidCallback? onAction;
  final int seconds;
}

final toastBus = ValueNotifier<ToastData?>(null);
Timer? _toastTimer;

void showToast(ToastData t) {
  _toastTimer?.cancel();
  toastBus.value = t;
  _toastTimer = Timer(Duration(seconds: t.seconds), () => toastBus.value = null);
}

/// Shows toasts above the bottom actions and turns live events into toasts / notifications.
class ToastHost extends StatefulWidget {
  const ToastHost({super.key, required this.child});
  final Widget child;
  @override
  State<ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<ToastHost> {
  StreamSubscription<LiveEvent>? _sub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= AppScope.read(context).live.events.listen(_onEvent);
  }

  void _onEvent(LiveEvent e) {
    final app = AppScope.read(context);
    switch (e.kind) {
      case LiveEventKind.busNear:
        if (!app.notify) return;
        final msg = app.t('Bas ${e.busNumber} wuxuu kaa xigaa ${e.minutes} daqiiqo', 'Bus ${e.busNumber} is ${e.minutes} min away');
        platform.vibrate();
        platform.showNotification('BusWhere', msg);
        showToast(ToastData(msg, icon: 'bell', seconds: 6));
      case LiveEventKind.busArrived:
        platform.vibrate();
        showToast(ToastData(
          app.t('Bas ${e.busNumber} wuu yimid', 'Bus ${e.busNumber} is here'),
          icon: 'bus-front',
          tone: ToastTone.success,
          actionLabel: app.t('Waan fuulay', "I'm on"),
          onAction: () {
            app.live.stopWaiting(boarded: true);
            toastBus.value = null;
          },
          seconds: 10,
        ));
      case LiveEventKind.waitExpired:
        showToast(ToastData(app.t('Sugitaankaagu wuu dhacay (15 daqiiqo)', 'Your wait expired (15 min)'), icon: 'clock'));
      case LiveEventKind.pickedUp:
        showToast(ToastData(app.t('Darawalku wuxuu sheegay inuu ku qaaday', 'The driver marked you as picked up'), icon: 'circle-check', tone: ToastTone.success));
      case LiveEventKind.withdrawnByServer:
        platform.vibrate();
        showToast(ToastData(
          e.reason == 'auto-offline'
              ? app.t('Waxaa lagaa saaray tuulada (30 daqiiqo offline)', 'Withdrawn after 30 min offline')
              : app.t('Maamulka ayaa kaa saaray tuulada', 'An admin withdrew you from the village'),
          icon: 'log-out',
          seconds: 8,
        ));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      Positioned(
        left: BW.gutter,
        right: BW.gutter,
        bottom: 160 + MediaQuery.paddingOf(context).bottom,
        child: ValueListenableBuilder<ToastData?>(
          valueListenable: toastBus,
          builder: (_, t, _) => AnimatedSwitcher(
            duration: BW.base,
            switchInCurve: BW.easeOut,
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .2), end: Offset.zero).animate(a), child: c)),
            // Toasts sit above the Navigator, outside any Material: give them one so text is styled.
            child: t == null ? const SizedBox.shrink() : Material(key: ValueKey(t), type: MaterialType.transparency, child: BWToast(t.message, icon: t.icon, tone: t.tone, actionLabel: t.actionLabel, onAction: t.onAction)),
          ),
        ),
      ),
    ]);
  }
}
