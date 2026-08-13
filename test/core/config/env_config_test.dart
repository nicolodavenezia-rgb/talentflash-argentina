import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/core/config/env_config.dart';

void main() {
  group('AppEnvironment.parse', () {
    test('acepta los tres flavors válidos', () {
      expect(AppEnvironment.parse('dev'), AppEnvironment.dev);
      expect(AppEnvironment.parse('staging'), AppEnvironment.staging);
      expect(AppEnvironment.parse('prod'), AppEnvironment.prod);
    });

    test('rechaza flavors desconocidos en vez de degradar en silencio', () {
      expect(() => AppEnvironment.parse('produccion'), throwsArgumentError);
      expect(() => AppEnvironment.parse(''), throwsArgumentError);
    });
  });

  group('EnvConfig', () {
    test('fromEnvironment sin dart-define cae en dev sin Sentry', () {
      final config = EnvConfig.fromEnvironment();
      expect(config.environment, AppEnvironment.dev);
      expect(config.isProd, isFalse);
      expect(config.sentryEnabled, isFalse);
    });

    test('sentryEnabled se activa solo con DSN presente', () {
      const withDsn = EnvConfig(
        environment: AppEnvironment.staging,
        supabaseUrl: 'https://stg.example.supabase.co',
        supabaseAnonKey: 'anon',
        sentryDsn: 'https://x@o0.ingest.sentry.io/0',
      );
      expect(withDsn.sentryEnabled, isTrue);
    });
  });
}
