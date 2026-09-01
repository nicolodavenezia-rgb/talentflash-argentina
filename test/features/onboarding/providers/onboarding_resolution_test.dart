import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/authentication/providers/auth_providers.dart';
import 'package:talentflash_argentina/features/consents/providers/consents_providers.dart';
import 'package:talentflash_argentina/features/onboarding/domain/onboarding_progress.dart';
import 'package:talentflash_argentina/features/onboarding/providers/onboarding_providers.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_onboarding_repositories.dart';

void main() {
  ({
    ProviderContainer container,
    FakeAuthRepository auth,
    FakeOnboardingRepository onboarding,
    FakeConsentsRepository consents,
  })
  makeContainer({
    AuthStatus initialStatus = const AuthStatusSignedOut(),
    bool onboardingCompleted = true,
    bool mandatoryGranted = true,
  }) {
    final auth = FakeAuthRepository(initialStatus: initialStatus);
    addTearDown(auth.dispose);
    final onboarding = FakeOnboardingRepository(
      onboardingCompleted: onboardingCompleted,
    );
    final consents = FakeConsentsRepository(mandatoryGranted: mandatoryGranted);
    final container = ProviderContainer.test(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        onboardingRepositoryProvider.overrideWithValue(onboarding),
        consentsRepositoryProvider.overrideWithValue(consents),
      ],
    );
    return (
      container: container,
      auth: auth,
      onboarding: onboarding,
      consents: consents,
    );
  }

  test('sin sesión no aplica onboarding', () async {
    final setup = makeContainer();
    expect(
      setup.container.read(onboardingResolutionProvider),
      const OnboardingNotRequired(),
    );
  });

  test('con sesión de candidato resuelve desde la base', () async {
    final setup = makeContainer();
    setup.container.listen(onboardingResolutionProvider, (_, _) {});
    setup.auth.emitSignedIn(BusinessRole.candidate);
    await pumpEventQueue();

    final resolution = setup.container.read(onboardingResolutionProvider);
    expect(resolution, isA<OnboardingReady>());
    final progress = (resolution as OnboardingReady).progress;
    expect(progress.completed, isTrue);
    expect(progress.pendingMandatoryConsents, isEmpty);
  });

  test('onboarding incompleto se refleja como needsWizard', () async {
    final setup = makeContainer(onboardingCompleted: false);
    setup.container.listen(onboardingResolutionProvider, (_, _) {});
    setup.auth.emitSignedIn(BusinessRole.company);
    await pumpEventQueue();

    final resolution =
        setup.container.read(onboardingResolutionProvider) as OnboardingReady;
    expect(resolution.progress.needsWizard, isTrue);
  });

  test(
    'versión obligatoria vieja exige reconsentimiento aunque esté completo',
    () async {
      final setup = makeContainer(mandatoryGranted: false);
      setup.container.listen(onboardingResolutionProvider, (_, _) {});
      setup.auth.emitSignedIn(BusinessRole.candidate);
      await pumpEventQueue();

      final resolution =
          setup.container.read(onboardingResolutionProvider) as OnboardingReady;
      expect(resolution.progress.completed, isTrue);
      expect(resolution.progress.needsReconsent, isTrue);
    },
  );

  test('admin jamás pasa por onboarding', () async {
    final setup = makeContainer();
    setup.container.listen(onboardingResolutionProvider, (_, _) {});
    setup.auth.emitSignedIn(BusinessRole.admin);
    await pumpEventQueue();

    expect(
      setup.container.read(onboardingResolutionProvider),
      const OnboardingNotRequired(),
    );
    expect(setup.onboarding.calls, isEmpty);
  });

  test(
    'un fallo de carga deja el estado en Resolviendo con reintento',
    () async {
      final setup = makeContainer();
      setup.onboarding.nextFailure = const DataFailure(DataFailureCode.network);
      setup.container.listen(onboardingResolutionProvider, (_, _) {});
      setup.auth.emitSignedIn(BusinessRole.candidate);
      await pumpEventQueue();

      expect(
        setup.container.read(onboardingResolutionProvider),
        const OnboardingResolving(failed: true),
      );

      // El reintento con la red de vuelta resuelve normalmente.
      setup.container.read(onboardingResolutionProvider.notifier).retry();
      await pumpEventQueue();
      expect(
        setup.container.read(onboardingResolutionProvider),
        isA<OnboardingReady>(),
      );
    },
  );

  test(
    'reload conserva el estado hasta tener el nuevo (sin parpadeo)',
    () async {
      final setup = makeContainer(onboardingCompleted: false);
      setup.container.listen(onboardingResolutionProvider, (_, _) {});
      setup.auth.emitSignedIn(BusinessRole.candidate);
      await pumpEventQueue();
      expect(
        (setup.container.read(
          onboardingResolutionProvider,
        ) as OnboardingReady).progress.needsWizard,
        isTrue,
      );

      // El wizard terminó server-side; el reload trae el estado nuevo.
      setup.onboarding.onboardingCompleted = true;
      await setup.container
          .read(onboardingResolutionProvider.notifier)
          .reload();
      final resolution =
          setup.container.read(onboardingResolutionProvider) as OnboardingReady;
      expect(resolution.progress.completed, isTrue);
    },
  );

  test('cerrar sesión vuelve a NoRequerido', () async {
    final setup = makeContainer();
    setup.container.listen(onboardingResolutionProvider, (_, _) {});
    setup.auth.emitSignedIn(BusinessRole.candidate);
    await pumpEventQueue();
    setup.auth.emit(const AuthStatusSignedOut());
    await pumpEventQueue();

    expect(
      setup.container.read(onboardingResolutionProvider),
      const OnboardingNotRequired(),
    );
  });
}
