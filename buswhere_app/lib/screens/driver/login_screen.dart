import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/core.dart';
import '../../widgets/errors.dart';
import '../../widgets/transit.dart';

/// Phone + PIN. The admin adds each driver and gives them their PIN.
class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});
  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final app = AppScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await app.live.driverSignIn(_phone.text, _pin.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err == null ? null : errorText(app, err);
    });
    if (err == null) {
      app.setRole('driver');
      context.go('/driver');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
            decoration: const BoxDecoration(color: BW.night, borderRadius: BorderRadius.vertical(bottom: Radius.circular(BW.rXl))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                BWIconButton('arrow-left', label: app.t('Ku noqo', 'Back'), variant: IconBtnVariant.dark, onTap: () => context.go('/')),
                const Spacer(),
                const BWLogo(variant: LogoVariant.wordmark, reverse: true, height: 22),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 18, 0, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(app.t('Gal sida darawal', 'Driver sign in'), style: BWText.h1.copyWith(color: BW.white)),
                  const SizedBox(height: 2),
                  Text(app.sub('Gal sida darawal', 'Driver sign in'), style: const TextStyle(fontSize: 15, color: BW.onDarkMuted)),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              BWInput(
                controller: _phone,
                icon: 'phone',
                prefixText: '+252 ',
                hint: '63 410 0012',
                label: app.t('Lambarka telefoonka', 'Phone number'),
                keyboardType: TextInputType.phone,
                maxLength: 13,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))],
              ),
              const SizedBox(height: 12),
              BWInput(
                controller: _pin,
                icon: 'square',
                hint: '••••',
                label: 'PIN',
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscure: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: (_) => _signIn(),
              ),
              const SizedBox(height: 12),
              BWCard(
                variant: CardVariant.sunken,
                padding: const EdgeInsets.all(12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const BWIcon('info', size: 18, color: BW.night600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      app.t('PIN-ka waxaa ku siinaya maamulka BusWhere. Ha la wadaagin qof kale.', 'Your PIN comes from the BusWhere admin. Do not share it.'),
                      style: BWText.small.copyWith(color: BW.textSecondary),
                    ),
                  ),
                ]),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                BWBanner(tone: BannerTone.danger, title: _error!),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: BWButton(app.t('Gal', 'Sign in'), subLabel: app.sub('Gal', 'Sign in'), iconRight: 'arrow-right', busy: _busy, onTap: _signIn),
          ),
        ]),
      ),
    );
  }
}
