// Web capabilities (online status, vibration, notifications) with a no-op
// fallback for the Android build.
export 'platform_stub.dart' if (dart.library.js_interop) 'platform_web.dart';
