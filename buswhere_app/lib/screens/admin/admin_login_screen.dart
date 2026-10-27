import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/core.dart';
import '../../widgets/errors.dart';

/// Email + password, for accounts listed in the admins table.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final app = AppScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await app.live.adminSignIn(_email.text, _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err == null ? null : errorText(app, err);
    });
    if (err == null) {
      app.setRole('admin');
      context.go('/admin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          BWTopBar(title: app.t('Maamulka', 'Admin'), subtitle: app.t('Gal · Sign in', 'Sign in · Gal'), onBack: () => context.go('/')),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              BWInput(controller: _email, icon: 'user', label: 'Email', keyboardType: TextInputType.emailAddress, autofocus: true),
              const SizedBox(height: 12),
              BWInput(controller: _password, icon: 'square', label: app.t('Furaha sirta', 'Password'), obscure: true, onSubmitted: (_) => _go()),
              const SizedBox(height: 12),
              Text(
                app.t('Riders-ka iyo darawallada uma baahna akoon maamul. Akoonka maamulka waxaa lagu sameeyaa Supabase.', 'Riders and drivers do not need this. Admin accounts are created in Supabase.'),
                style: BWText.small.copyWith(color: BW.textSecondary),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                BWBanner(tone: BannerTone.danger, title: _error == errorText(app, 'bad-login') ? app.t('Email-ka ama furaha waa khalad', 'Wrong email or password') : _error!),
              ],
            ]),
          ),
          Padding(padding: const EdgeInsets.all(16), child: BWButton(app.t('Gal', 'Sign in'), subLabel: app.sub('Gal', 'Sign in'), iconRight: 'arrow-right', busy: _busy, onTap: _go)),
        ]),
      ),
    );
  }
}
