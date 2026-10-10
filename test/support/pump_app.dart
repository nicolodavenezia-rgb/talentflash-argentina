import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:talentflash_argentina/app.dart';
import 'package:talentflash_argentina/core/config/env_config.dart';
import 'package:talentflash_argentina/core/routing/app_entry_point.dart';
import 'package:talentflash_argentina/core/routing/app_router.dart';
import 'package:talentflash_argentina/features/authentication/providers/auth_providers.dart';
import 'package:talentflash_argentina/features/companies/providers/company_verification_providers.dart';
import 'package:talentflash_argentina/features/consents/providers/consents_providers.dart';
import 'package:talentflash_argentina/features/jobs/providers/job_offers_providers.dart';
import 'package:talentflash_argentina/features/legal/providers/legal_providers.dart';
import 'package:talentflash_argentina/features/notifications/providers/notification_prefs_providers.dart';
import 'package:talentflash_argentina/features/onboarding/providers/onboarding_providers.dart';
import 'package:talentflash_argentina/features/profiles/providers/profile_providers.dart';

import 'fake_auth_repository.dart';
import 'fake_company_verification_repository.dart';
import 'fake_job_offers_repository.dart';
import 'fake_onboarding_repositories.dart';
import 'fake_profile_repositories.dart';

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
  TalentFlashHarness(
    this.container,
    this.authRepository,
    this.onboardingRepository,
    this.consentsRepository,
    this.catalogRepository,
    this.notificationPrefsRepository,
    this.legalRepository,
    this.profileRepository,
    this.companyAccessRepository,
    this.avatarPicker,
    this.companyVerificationRepository,
    this.constanciaPicker,
    this.jobOffersRepository,
  );

  final ProviderContainer container;
  final FakeAuthRepository authRepository;
  final FakeOnboardingRepository onboardingRepository;
  final FakeConsentsRepository consentsRepository;
  final FakeCatalogRepository catalogRepository;
  final FakeNotificationPrefsRepository notificationPrefsRepository;
  final FakeLegalRepository legalRepository;
  final FakeProfileRepository profileRepository;
  final FakeCompanyAccessRepository companyAccessRepository;
  final FakeAvatarImagePicker avatarPicker;
  final FakeCompanyVerificationRepository companyVerificationRepository;
  final FakeConstanciaPicker constanciaPicker;
  final FakeJobOffersRepository jobOffersRepository;

  GoRouter get router => container.read(appRouterProvider);

  /// Ruta que el router está mostrando ahora mismo.
  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
}

/// Monta la app real (router, tema y localización incluidos) con repositorios
/// falsos: ningún test toca `Supabase.instance`.
///
/// Por defecto la cuenta simulada ya completó el onboarding y tiene los
/// consentimientos obligatorios vigentes, así los tests de auth del Bloque B
/// conservan su semántica ("una cuenta lista entra directo a su shell").
///
/// [riverpodRetry] en true deja el reintento por defecto de Riverpod, como
/// en producción (`bootstrap.dart` usa un `ProviderScope` sin `retry`): un
/// provider que falla con una `Exception` queda cargando mientras se
/// reintenta, unos 38 segundos en total. Sirve para probar lo que la
/// pantalla muestra en esa ventana, que con el reintento apagado no existe.
Future<TalentFlashHarness> pumpTalentFlashApp(
  WidgetTester tester, {
  required FakeAuthRepository authRepository,
  AppEntryPoint entryPoint = AppEntryPoint.chooser,
  bool riverpodRetry = false,
  FakeOnboardingRepository? onboardingRepository,
  FakeConsentsRepository? consentsRepository,
  FakeCatalogRepository? catalogRepository,
  FakeNotificationPrefsRepository? notificationPrefsRepository,
  FakeLegalRepository? legalRepository,
  FakeProfileRepository? profileRepository,
  FakeCompanyAccessRepository? companyAccessRepository,
  FakeAvatarImagePicker? avatarPicker,
  FakeCompanyVerificationRepository? companyVerificationRepository,
  FakeConstanciaPicker? constanciaPicker,
  FakeJobOffersRepository? jobOffersRepository,
}) async {
  addTearDown(authRepository.dispose);
  final onboarding = onboardingRepository ?? FakeOnboardingRepository();
  final consents = consentsRepository ?? FakeConsentsRepository();
  final catalog = catalogRepository ?? FakeCatalogRepository();
  final prefs =
      notificationPrefsRepository ?? FakeNotificationPrefsRepository();
  final legal = legalRepository ?? FakeLegalRepository();
  final profiles = profileRepository ?? FakeProfileRepository();
  final companyAccess =
      companyAccessRepository ?? FakeCompanyAccessRepository();
  final picker = avatarPicker ?? FakeAvatarImagePicker();
  final verification =
      companyVerificationRepository ?? FakeCompanyVerificationRepository();
  final constancia = constanciaPicker ?? FakeConstanciaPicker();
  final jobOffers = jobOffersRepository ?? FakeJobOffersRepository();
  final container = ProviderContainer.test(
    // Riverpod 3 reintenta con backoff los providers que fallan; en tests eso
    // vuelve no determinista cualquier escenario de error (el fake consume el
    // fallo y el reintento "se cura" solo). Acá los errores son finales,
    // salvo que el test pida el reintento de producción ([riverpodRetry]).
    retry: riverpodRetry ? null : (retryCount, error) => null,
    overrides: [
      envConfigProvider.overrideWithValue(testEnvConfig),
      appEntryPointProvider.overrideWithValue(entryPoint),
      authRepositoryProvider.overrideWithValue(authRepository),
      onboardingRepositoryProvider.overrideWithValue(onboarding),
      consentsRepositoryProvider.overrideWithValue(consents),
      catalogRepositoryProvider.overrideWithValue(catalog),
      notificationPrefsRepositoryProvider.overrideWithValue(prefs),
      legalRepositoryProvider.overrideWithValue(legal),
      profileRepositoryProvider.overrideWithValue(profiles),
      companyAccessRepositoryProvider.overrideWithValue(companyAccess),
      avatarImagePickerProvider.overrideWithValue(picker),
      companyVerificationRepositoryProvider.overrideWithValue(verification),
      constanciaPickerProvider.overrideWithValue(constancia),
      // Sin este override, cualquier pantalla de ofertas caería en el
      // repositorio real y en `Supabase.instance`.
      jobOffersRepositoryProvider.overrideWithValue(jobOffers),
      // "Ahora" fijo: la ventana de publicación (D1) no depende de la fecha
      // en que corre la suite.
      jobClockProvider.overrideWithValue(() => testJobNow),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const TalentFlashApp(),
    ),
  );
  return TalentFlashHarness(
    container,
    authRepository,
    onboarding,
    consents,
    catalog,
    prefs,
    legal,
    profiles,
    companyAccess,
    picker,
    verification,
    constancia,
    jobOffers,
  );
}
