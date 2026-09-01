import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/providers/auth_providers.dart';
import 'package:talentflash_argentina/features/consents/domain/consent_type.dart';
import 'package:talentflash_argentina/features/consents/providers/consents_providers.dart';
import 'package:talentflash_argentina/features/notifications/domain/notification_prefs.dart';
import 'package:talentflash_argentina/features/notifications/providers/notification_prefs_providers.dart';
import 'package:talentflash_argentina/features/onboarding/domain/candidate_onboarding_data.dart';
import 'package:talentflash_argentina/features/onboarding/domain/onboarding_progress.dart';
import 'package:talentflash_argentina/features/onboarding/providers/candidate_onboarding_controller.dart';
import 'package:talentflash_argentina/features/onboarding/providers/onboarding_providers.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_onboarding_repositories.dart';

void main() {
  ({
    ProviderContainer container,
    FakeOnboardingRepository onboarding,
    FakeConsentsRepository consents,
    FakeNotificationPrefsRepository prefs,
  })
  makeContainer({
    CandidateOnboardingData draft = const CandidateOnboardingData(),
    bool mandatoryGranted = true,
  }) {
    final auth = FakeAuthRepository();
    addTearDown(auth.dispose);
    final onboarding = FakeOnboardingRepository(onboardingCompleted: false)
      ..draft = draft;
    final consents = FakeConsentsRepository(mandatoryGranted: mandatoryGranted);
    final prefs = FakeNotificationPrefsRepository();
    final container = ProviderContainer.test(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        onboardingRepositoryProvider.overrideWithValue(onboarding),
        consentsRepositoryProvider.overrideWithValue(consents),
        notificationPrefsRepositoryProvider.overrideWithValue(prefs),
      ],
    );
    return (
      container: container,
      onboarding: onboarding,
      consents: consents,
      prefs: prefs,
    );
  }

  const completeDraft = CandidateOnboardingData(
    fullName: 'Ana Pérez',
    birthDate: null,
    provinceId: FakeCatalogRepository.cabaProvinceId,
    localityId: FakeCatalogRepository.cabaLocalityId,
    neighborhoodId: FakeCatalogRepository.palermoId,
    sectorId: FakeCatalogRepository.gastronomiaSectorId,
    availability: CandidateAvailability.inmediata,
    workModes: {CandidateWorkMode.presencial},
  );

  test(
    'sin consentimientos vigentes arranca en el paso de consentimientos',
    () async {
      final setup = makeContainer(mandatoryGranted: false);
      final state = await setup.container.read(
        candidateOnboardingControllerProvider.future,
      );
      expect(state.step, CandidateStep.consents);
    },
  );

  test('retoma donde quedó: identidad guardada → paso de ubicación', () async {
    final setup = makeContainer(
      draft: CandidateOnboardingData(
        fullName: 'Ana Pérez',
        birthDate: DateTime(1995, 4, 10),
      ),
    );
    final state = await setup.container.read(
      candidateOnboardingControllerProvider.future,
    );
    expect(state.step, CandidateStep.place);
  });

  test('una persona menor queda bloqueada SIN persistir nada', () async {
    final setup = makeContainer();
    await setup.container.read(candidateOnboardingControllerProvider.future);
    final controller = setup.container.read(
      candidateOnboardingControllerProvider.notifier,
    );

    await controller.submitIdentity(
      fullName: 'Persona Menor',
      birthDate: DateTime.now().subtract(const Duration(days: 365 * 15)),
    );

    final state = setup.container
        .read(candidateOnboardingControllerProvider)
        .value!;
    expect(state.underage, isTrue);
    expect(setup.onboarding.calls, isNot(contains('saveCandidateData')));
  });

  test('guardar identidad persiste la instantánea y avanza', () async {
    final setup = makeContainer();
    await setup.container.read(candidateOnboardingControllerProvider.future);
    final controller = setup.container.read(
      candidateOnboardingControllerProvider.notifier,
    );

    await controller.submitIdentity(
      fullName: '  Ana Pérez ',
      birthDate: DateTime(1995, 4, 10),
    );

    final state = setup.container
        .read(candidateOnboardingControllerProvider)
        .value!;
    expect(state.step, CandidateStep.place);
    expect(setup.onboarding.lastSavedData?.fullName, 'Ana Pérez');
    expect(setup.onboarding.lastSavedData?.birthDate, DateTime(1995, 4, 10));
  });

  test('el doble submit no duplica llamadas', () async {
    final setup = makeContainer();
    await setup.container.read(candidateOnboardingControllerProvider.future);
    final controller = setup.container.read(
      candidateOnboardingControllerProvider.notifier,
    );

    setup.onboarding.pendingAction = Completer<void>();
    final first = controller.submitIdentity(
      fullName: 'Ana Pérez',
      birthDate: DateTime(1995, 4, 10),
    );
    final second = controller.submitIdentity(
      fullName: 'Ana Pérez',
      birthDate: DateTime(1995, 4, 10),
    );
    setup.onboarding.pendingAction!.complete();
    await Future.wait([first, second]);

    expect(
      setup.onboarding.calls.where((c) => c == 'saveCandidateData').length,
      1,
    );
  });

  test('el paso de privacidad otorga y revoca según los toggles', () async {
    final setup = makeContainer();
    // Estado previo: publicación ya otorgada, IA no.
    setup.consents.grantLocally(ConsentType.videoProfilePublication);
    final initial = await setup.container.read(
      candidateOnboardingControllerProvider.future,
    );
    expect(
      initial.consents.isCurrentlyGranted(ConsentType.videoProfilePublication),
      isTrue,
    );
    final controller = setup.container.read(
      candidateOnboardingControllerProvider.notifier,
    );

    await controller.submitPrivacy(publishProfile: false, aiFeatures: true);

    expect(
      setup.consents.calls,
      containsAll(<String>[
        'revoke:video_profile_publication@$testConsentVersion',
        'grant:ai_features@$testConsentVersion',
      ]),
    );
    final state = setup.container
        .read(candidateOnboardingControllerProvider)
        .value!;
    expect(
      state.consents.isCurrentlyGranted(ConsentType.videoProfilePublication),
      isFalse,
    );
    expect(state.consents.isCurrentlyGranted(ConsentType.aiFeatures), isTrue);
  });

  test('guardar preferencias de notificaciones hace upsert y avanza', () async {
    final setup = makeContainer();
    await setup.container.read(candidateOnboardingControllerProvider.future);
    final controller = setup.container.read(
      candidateOnboardingControllerProvider.notifier,
    );

    final chosen = [
      const NotificationChannelPrefs(
        category: NotificationCategory.message,
        pushEnabled: true,
      ),
    ];
    await controller.submitNotificationPrefs(chosen);

    expect(setup.prefs.stored, chosen);
    expect(
      setup.container.read(candidateOnboardingControllerProvider).value!.step,
      CandidateStep.summary,
    );
  });

  test('terminar llama a la RPC y refresca el estado global', () async {
    final setup = makeContainer(draft: completeDraft);
    await setup.container.read(candidateOnboardingControllerProvider.future);
    // El router necesita el estado global: se materializa el provider.
    setup.container.listen(onboardingResolutionProvider, (_, _) {});
    await pumpEventQueue();

    await setup.container
        .read(candidateOnboardingControllerProvider.notifier)
        .finish();

    expect(setup.onboarding.calls, contains('completeCandidateOnboarding'));
    final resolution =
        setup.container.read(onboardingResolutionProvider) as OnboardingReady;
    expect(resolution.progress.completed, isTrue);
  });

  test('un fallo tipado queda en el estado y no rompe el paso', () async {
    final setup = makeContainer();
    await setup.container.read(candidateOnboardingControllerProvider.future);
    final controller = setup.container.read(
      candidateOnboardingControllerProvider.notifier,
    );

    setup.onboarding.nextFailure = const DataFailure(DataFailureCode.network);
    await controller.submitIdentity(
      fullName: 'Ana Pérez',
      birthDate: DateTime(1995, 4, 10),
    );

    final state = setup.container
        .read(candidateOnboardingControllerProvider)
        .value!;
    expect(state.failure?.code, DataFailureCode.network);
    expect(state.submitting, isFalse);
    expect(state.underage, isFalse);
  });
}
