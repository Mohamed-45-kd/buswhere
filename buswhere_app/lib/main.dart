import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/live_service.dart';
import 'screens/admin/admin_home.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/driver/drive_screen.dart';
import 'screens/driver/login_screen.dart';
import 'screens/driver/village_pick_screen.dart';
import 'screens/intro_screen.dart';
import 'screens/rider/bus_detail_screen.dart';
import 'screens/rider/city_screen.dart';
import 'screens/rider/rider_home.dart';
import 'screens/rider/village_screen.dart';
import 'screens/welcome_screen.dart';
import 'state/app_state.dart';
import 'theme/tokens.dart';
import 'widgets/core.dart';
import 'widgets/toast_host.dart';
import 'widgets/transit.dart';

// Set at build time: flutter build web --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'http://127.0.0.1:54321');
const _supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseKey);
  final live = LiveService(Supabase.instance.client);
  final state = await AppState.load(live);
  runApp(BusWhereApp(state: state));
  live.start();
}

class BusWhereApp extends StatefulWidget {
  const BusWhereApp({super.key, required this.state});
  final AppState state;
  @override
  State<BusWhereApp> createState() => _BusWhereAppState();
}

class _BusWhereAppState extends State<BusWhereApp> {
  bool _firstRoute = true;
  late final GoRouter _router = GoRouter(
    initialLocation: '/',
    refreshListenable: widget.state.live,
    redirect: (context, s) {
      final app = widget.state;
      final live = app.live;
      if (!live.ready) return null; // the loading gate covers everything
      final loc = s.matchedLocation;
      final first = _firstRoute;
      _firstRoute = false;
      // Reopen where the person left off — only on launch, so "Start page" still works.
      if (loc == '/' && app.onboarded && first) {
        if (app.role == 'driver') return '/driver';
        if (app.role == 'admin') return '/admin';
        return app.tripReady ? '/rider' : '/rider/city';
      }
      if (loc.startsWith('/driver') && loc != '/driver/login' && live.me == null) return '/driver/login';
      if (loc == '/driver/login' && live.me != null) return '/driver';
      if (loc == '/admin' && !live.isAdmin) return '/admin/login';
      if (loc == '/admin/login' && live.isAdmin) return '/admin';
      if ((loc == '/rider' || loc.startsWith('/rider/bus')) && !app.tripReady) return '/rider/city';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/intro', builder: (_, _) => const IntroScreen()),
      GoRoute(path: '/rider/city', builder: (_, _) => const CityScreen()),
      GoRoute(path: '/rider/from', builder: (_, _) => const VillageScreen(step: 2)),
      GoRoute(path: '/rider/to', builder: (_, _) => const VillageScreen(step: 3)),
      GoRoute(path: '/rider', builder: (_, _) => const RiderHome()),
      GoRoute(path: '/rider/bus/:id', builder: (_, s) => BusDetailScreen(busId: s.pathParameters['id']!)),
      GoRoute(path: '/driver/login', builder: (_, _) => const DriverLoginScreen()),
      GoRoute(path: '/driver', builder: (_, _) => const DriveScreen()),
      GoRoute(path: '/driver/village', builder: (_, _) => const VillagePickScreen()),
      GoRoute(path: '/admin/login', builder: (_, _) => const AdminLoginScreen()),
      GoRoute(path: '/admin', builder: (_, _) => const AdminHome()),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      child: MaterialApp.router(
        title: 'BusWhere',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        routerConfig: _router,
        builder: (context, child) => MobileFrame(
          child: ListenableBuilder(
            listenable: widget.state.live,
            builder: (context, _) => widget.state.live.ready ? ToastHost(child: child ?? const SizedBox()) : const _LoadingGate(),
          ),
        ),
      ),
    );
  }
}

/// First load: logo while data arrives; a plain retry if there is no connection.
class _LoadingGate extends StatelessWidget {
  const _LoadingGate();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final failed = app.live.loadError != null;
    return ColoredBox(
      color: BW.night,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const Spacer(),
            const BWLogo(variant: LogoVariant.mark, reverse: true, height: 96),
            const SizedBox(height: 24),
            if (!failed) const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: BW.teal300)),
            if (failed) ...[
              // Tell "no internet" apart from "our server said no", so riders don't blame their data.
              Text(app.online ? app.t('Adeegga lama gaari karo', "Can't reach BusWhere") : app.t('Internet ma jiro', 'No internet'), style: BWText.h2.copyWith(color: BW.white)),
              const SizedBox(height: 6),
              Text(
                app.online ? app.t('Waxaan ku jirnaa hagaajin. Isku day mar kale dhowr daqiiqo kadib.', 'We are fixing it. Try again in a few minutes.') : app.t('Hubi xogtaada oo isku day mar kale.', 'Check your data and try again.'),
                textAlign: TextAlign.center,
                style: BWText.body.copyWith(color: BW.onDarkMuted),
              ),
            ],
            const Spacer(),
            if (failed) BWButton(app.t('Isku day', 'Try again'), subLabel: app.sub('Isku day', 'Try again'), icon: 'refresh-cw', onTap: app.live.retry),
          ]),
        ),
      ),
    );
  }
}
