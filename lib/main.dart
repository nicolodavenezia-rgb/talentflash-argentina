import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/config/env_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = EnvConfig.fromEnvironment();

  if (config.sentryEnabled) {
    // T-010: Sentry por flavor. Sin DSN (dev) la app corre sin Sentry y sin
    // cuenta. El DSN llega por dart-define; jamás hardcodeado.
    await SentryFlutter.init((options) {
      options
        ..dsn = config.sentryDsn
        ..environment = config.environment.name
        ..tracesSampleRate = 0.2
        ..sendDefaultPii = false; // PRIVACY.md: minimización de datos
    }, appRunner: () => _run(config));
  } else {
    _run(config);
  }
}

void _run(EnvConfig config) {
  runApp(
    ProviderScope(
      overrides: [envConfigProvider.overrideWithValue(config)],
      child: const TalentFlashApp(),
    ),
  );
}
