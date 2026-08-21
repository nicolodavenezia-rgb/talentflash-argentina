import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Entornos soportados (ARCHITECTURE.md §9): dev / staging / prod.
enum AppEnvironment {
  dev,
  staging,
  prod;

  /// Parsea el valor de `APP_ENV`. Estricto a propósito: un flavor mal escrito
  /// debe fallar al arrancar, no degradar silenciosamente a dev.
  static AppEnvironment parse(String raw) {
    return AppEnvironment.values.asNameMap()[raw] ??
        (throw ArgumentError.value(
          raw,
          'APP_ENV',
          'Valores válidos: dev, staging, prod',
        ));
  }
}

/// Configuración inyectada en build con `--dart-define-from-file=env/<flavor>.json`.
///
/// Regla de seguridad (SECURITY.md §4): acá solo viven valores PÚBLICOS
/// (URL del proyecto, anon key, DSN de Sentry). Ningún secreto real entra
/// al binario ni al repositorio.
class EnvConfig {
  const EnvConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.sentryDsn,
  });

  factory EnvConfig.fromEnvironment() {
    return EnvConfig(
      environment: AppEnvironment.parse(
        const String.fromEnvironment('APP_ENV', defaultValue: 'dev'),
      ),
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      sentryDsn: const String.fromEnvironment('SENTRY_DSN'),
    );
  }

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String sentryDsn;

  bool get isProd => environment == AppEnvironment.prod;

  bool get supabaseConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      supabaseUrl != 'POR_CONFIGURAR' &&
      supabaseAnonKey != 'POR_CONFIGURAR';

  /// Falla temprano si se inició un binario sin su archivo de flavor. Las
  /// credenciales aceptadas acá son públicas; service_role nunca entra al app.
  void validateForStartup() {
    if (!supabaseConfigured) {
      throw StateError(
        'Supabase no está configurado. Ejecutá Flutter con '
        '--dart-define-from-file=env/${environment.name}.json',
      );
    }
  }

  /// Sentry se habilita solo si el flavor trae un DSN (T-010): en dev queda
  /// apagado y no se necesita cuenta para desarrollar.
  bool get sentryEnabled => sentryDsn.isNotEmpty;
}

/// Se sobreescribe en `main()` con la configuración real del flavor.
final envConfigProvider = Provider<EnvConfig>(
  (ref) => throw UnimplementedError(
    'envConfigProvider debe sobreescribirse en ProviderScope (main.dart)',
  ),
);
