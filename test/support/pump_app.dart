import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:talentflash_argentina/app.dart';
import 'package:talentflash_argentina/core/config/env_config.dart';
import 'package:talentflash_argentina/core/routing/app_entry_point.dart';
import 'package:talentflash_argentina/core/routing/app_router.dart';
import 'package:talentflash_argentina/features/authentication/providers/auth_providers.dart';

import 'fake_auth_repository.dart';

/// Configuración pública equivalente a `env/dev.json`. Nunca hay secretos en
/// los tests, igual que en el repositorio.
const testEnvConfig = EnvConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: 'http://127.0.0.1:54321',
  supabaseAnonKey: 'sb_publishable_de_prueba',
  sentryDsn: '',
);

/// App montada para un test, con acceso al contenedor de providers.
class TalentFlashHarness {
  TalentFlashHarness(this.container, this.authRepository);

  final ProviderContainer container;
  final FakeAuthRepository authRepository;

  GoRouter get router => container.read(appRouterProvider);

  /// Ruta que el router está mostrando ahora mismo.
  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
}

/// Monta la app real (router, tema y localización incluidos) con el
/// repositorio de auth falso: ningún test toca `Supabase.instance`.
Future<TalentFlashHarness> pumpTalentFlashApp(
  WidgetTester tester, {
  required FakeAuthRepository authRepository,
  AppEntryPoint entryPoint = AppEntryPoint.chooser,
}) async {
  addTearDown(authRepository.dispose);
  final container = ProviderContainer.test(
    overrides: [
      envConfigProvider.overrideWithValue(testEnvConfig),
      appEntryPointProvider.overrideWithValue(entryPoint),
      authRepositoryProvider.overrideWithValue(authRepository),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const TalentFlashApp(),
    ),
  );
  return TalentFlashHarness(container, authRepository);
}
