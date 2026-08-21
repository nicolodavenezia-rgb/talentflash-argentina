import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env_config.dart';
import 'core/routing/app_entry_point.dart';

/// Inicialización compartida por los binarios general, candidato y empresa.
Future<void> bootstrap(AppEntryPoint entryPoint) async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = EnvConfig.fromEnvironment();
  config.validateForStartup();

  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabaseAnonKey,
  );

  void runTalentFlash() {
    runApp(
      ProviderScope(
        overrides: [
          envConfigProvider.overrideWithValue(config),
          appEntryPointProvider.overrideWithValue(entryPoint),
        ],
        child: const TalentFlashApp(),
      ),
    );
  }

  if (config.sentryEnabled) {
    // El DSN llega por dart-define; jamás se hardcodea un secreto de runtime.
    await SentryFlutter.init((options) {
      options
        ..dsn = config.sentryDsn
        ..environment = config.environment.name
        ..tracesSampleRate = 0.2
        ..sendDefaultPii = false;
    }, appRunner: runTalentFlash);
  } else {
    runTalentFlash();
  }
}
