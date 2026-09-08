import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env_config.dart';
import 'core/routing/app_entry_point.dart';
import 'features/authentication/data/session_scoped_http_client.dart';

/// Inicialización compartida por los binarios general, candidato y empresa.
Future<void> bootstrap(AppEntryPoint entryPoint) async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = EnvConfig.fromEnvironment();
  config.validateForStartup();

  // Todo el tráfico de Supabase pasa por este cliente. Solo interviene en
  // las rutas de segundo factor: una respuesta que llega cuando la sesión que
  // la pidió ya no es la vigente se descarta antes de que el SDK pueda
  // guardarla como sesión (ver `SessionScopedHttpClient`).
  final httpClient = SessionScopedHttpClient(
    http.Client(),
    currentAccessToken: () =>
        Supabase.instance.client.auth.currentSession?.accessToken,
  );

  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabaseAnonKey,
    httpClient: httpClient,
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
