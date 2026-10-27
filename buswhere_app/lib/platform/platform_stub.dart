bool isOnline() => true;

void onConnectivityChange(void Function(bool online) cb) {}

void vibrate() {}

Future<bool> requestNotifications() async => false;

void showNotification(String title, String body) {}

/// Calls [onPos] with each GPS fix; returns a function that stops watching.
void Function() watchPosition(void Function(double lat, double lng, double? speed, double? heading) onPos, void Function(String error) onError) {
  onError('unsupported');
  return () {};
}

void keepScreenOn(bool on) {}

/// One GPS fix for a rider: (lat, lng, accuracy in metres) or an error code.
Future<({double lat, double lng, double accuracy})> currentPosition() async => throw 'unsupported';
