import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool isOnline() => web.window.navigator.onLine;

void onConnectivityChange(void Function(bool online) cb) {
  web.window.addEventListener('online', ((web.Event _) => cb(true)).toJS);
  web.window.addEventListener('offline', ((web.Event _) => cb(false)).toJS);
}

void vibrate() {
  try {
    web.window.navigator.vibrate(<JSNumber>[200.toJS, 100.toJS, 200.toJS].toJS);
  } catch (_) {}
}

Future<bool> requestNotifications() async {
  try {
    if (web.Notification.permission == 'granted') return true;
    final p = await web.Notification.requestPermission().toDart;
    return p.toDart == 'granted';
  } catch (_) {
    return false;
  }
}

void showNotification(String title, String body) {
  try {
    if (web.Notification.permission != 'granted') return;
    web.Notification(title, web.NotificationOptions(body: body, icon: 'icons/Icon-192.png'));
  } catch (_) {}
}

/// Calls [onPos] with each GPS fix; returns a function that stops watching.
void Function() watchPosition(void Function(double lat, double lng, double? speed, double? heading) onPos, void Function(String error) onError) {
  final geo = web.window.navigator.geolocation;
  final id = geo.watchPosition(
    ((web.GeolocationPosition p) {
      final c = p.coords;
      onPos(c.latitude, c.longitude, c.speed, c.heading);
    }).toJS,
    ((web.GeolocationPositionError e) => onError(e.code == 1 ? 'denied' : 'unavailable')).toJS,
    web.PositionOptions(enableHighAccuracy: true, maximumAge: 5000, timeout: 20000),
  );
  return () => geo.clearWatch(id);
}

web.WakeLockSentinel? _wake;
bool _wakeWanted = false, _wakeListening = false;

/// Drivers keep the app open while driving: stop the screen from sleeping.
void keepScreenOn(bool on) {
  _wakeWanted = on;
  if (on) {
    web.window.navigator.wakeLock.request('screen').toDart.then((s) => _wake = s, onError: (_) {});
    if (!_wakeListening) {
      _wakeListening = true;
      // The lock drops when the app is hidden; take it again when it comes back.
      web.document.addEventListener('visibilitychange', ((web.Event _) {
        if (_wakeWanted && web.document.visibilityState == 'visible') {
          web.window.navigator.wakeLock.request('screen').toDart.then((s) => _wake = s, onError: (_) {});
        }
      }).toJS);
    }
  } else {
    _wake?.release();
    _wake = null;
  }
}

/// One GPS fix for a rider: (lat, lng, accuracy in metres). Throws 'denied', 'unavailable' or 'timeout'.
Future<({double lat, double lng, double accuracy})> currentPosition() {
  final done = Completer<({double lat, double lng, double accuracy})>();
  web.window.navigator.geolocation.getCurrentPosition(
    ((web.GeolocationPosition p) => done.complete((lat: p.coords.latitude, lng: p.coords.longitude, accuracy: p.coords.accuracy))).toJS,
    ((web.GeolocationPositionError e) => done.completeError(switch (e.code) { 1 => 'denied', 3 => 'timeout', _ => 'unavailable' })).toJS,
    web.PositionOptions(enableHighAccuracy: true, maximumAge: 30000, timeout: 15000),
  );
  return done.future;
}
