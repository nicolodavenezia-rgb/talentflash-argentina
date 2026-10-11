import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env_config.dart';
import 'core/routing/app_entry_point.dart';
import 'features/authentication/data/second_factor_attempt_recorder.dart';
import 'features/authentication/data/second_factor_cleanup_policy.dart';
import 'features/authentication/data/session_scoped_http_client.dart';
import 'features/authentication/providers/auth_providers.dart';

/// Inicialización compartida por los binarios general, candidato y empresa.
Future<void> bootstrap(AppEntryPoint entryPoint) async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = EnvConfig.fromEnvironment();
  config.validateForStartup();

  // Todo el tráfico de Supabase pasa por este cliente. Solo interviene en
  // las rutas de segundo factor: una respuesta que llega cuando la sesión que
  // la pidió ya no es la vigente se descarta antes de que el SDK pueda
  // guardarla como sesión (ver `SessionScopedHttpClient`).
  // Composición del transporte, de afuera hacia adentro:
  //
  //   GoTrueClient
  //     └─ SessionScopedHttpClient          descarta respuestas de otra sesión
  //          └─ SecondFactorAttemptRecorder anota cada verify que sale
  //               └─ cliente terminal (lo crea el recorder, no se inyecta)
  //
  // El recorder es el punto MÁS INTERNO a propósito: cualquier cosa que se
  // agregue por encima —incluido un cliente que reintente— pasa igual por él,
  // pedido por pedido. Y como crea su propio cliente terminal, no se puede
  // meter nada por debajo, que es la única posición desde la que un reintento
  // quedaría sin anotar.
  final cleanupPolicy = SecondFactorCleanupPolicy();
  final httpClient = SessionScopedHttpClient(
    SecondFactorAttemptRecorder(cleanupPolicy),
    currentAccessToken: () =>
        Supabase.instance.client.auth.currentSession?.accessToken,
  );

  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabaseAnonKey,
    httpClient: httpClient,
  );

  // Cerrar sesión o cambiar de cuenta descarta lo aprendido: los factores de
  // otra cuenta nunca son candidatos. Olvidar solo hace que la app se
  // abstenga más.
  //
  // El `onError` vacío es deliberado y por eso lleva este comentario: un
  // error del stream no puede tumbar el arranque de la app, y perderse un
  // evento acá **no relaja ninguna garantía** —lo único que se pierde es un
  // olvido, y no olvidar deja a la política con datos de más, que hoy no
  // habilitan nada porque no hay bajas automáticas—. No se reporta a Sentry
  // a propósito: agregar ese camino es un cambio aparte, no de este.
  Supabase.instance.client.auth.onAuthStateChange.listen(
    (state) => cleanupPolicy.onSessionUser(state.session?.user.id),
    onError: (Object _) {},
  );

  void runTalentFlash() {
    runApp(
      ProviderScope(
        overrides: [
          envConfigProvider.overrideWithValue(config),
          appEntryPointProvider.overrideWithValue(entryPoint),
          secondFactorCleanupPolicyProvider.overrideWithValue(cleanupPolicy),
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
