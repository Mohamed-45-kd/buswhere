import '../state/app_state.dart';

/// Plain words for the error codes the database functions raise.
String errorText(AppState app, String code) => switch (code) {
      'offline' => app.t('Internet ma jiro. Isku day mar kale.', 'No internet. Try again.'),
      'rate-limit' => app.t('Isku day mar dambe.', 'Too many tries. Try again later.'),
      'bad-login' => app.t('Lambarka ama PIN-ka waa khalad', 'Wrong phone number or PIN'),
      'locked' => app.t('Akoonka waa la xiray 15 daqiiqo', 'Locked for 15 minutes'),
      'not-approved' => app.t('Weli lama ansixin. La xiriir maamulka.', 'Not approved yet. Contact the admin.'),
      'no-bus' => app.t('Bas laguuma xirin. La xiriir maamulka.', 'No bus linked to you. Contact the admin.'),
      'already-active' => app.t('Horey ayaad tuulo ugu jirtaa', 'You are already in a village'),
      'not-admin' => app.t('Akoonkan maamul ma aha', 'This account is not an admin'),
      'bad-pin' => app.t('PIN-ku waa 4–6 lambar', 'PIN must be 4–6 digits'),
      'bad-phone' => app.t('Lambar sax ah geli', 'Enter a valid phone number'),
      'same-village' => app.t('Dooro tuulo kale', 'Pick a different village'),
      _ when code.contains('duplicate key') => app.t('Horey ayuu u jiray', 'That already exists'),
      _ => app.t('Wax baa khaldamay. Isku day mar kale.', 'Something went wrong. Try again.'),
    };
