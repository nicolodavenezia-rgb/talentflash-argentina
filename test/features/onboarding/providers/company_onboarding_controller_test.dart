import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/providers/auth_providers.dart';
import 'package:talentflash_argentina/features/consents/providers/consents_providers.dart';
import 'package:talentflash_argentina/features/notifications/providers/notification_prefs_providers.dart';
import 'package:talentflash_argentina/features/onboarding/domain/company_onboarding_data.dart';
import 'package:talentflash_argentina/features/onboarding/providers/company_onboarding_controller.dart';
import 'package:talentflash_argentina/features/onboarding/providers/onboarding_providers.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_onboarding_repositories.dart';

void main() {
  ({
    ProviderContainer container,
    FakeOnboardingRepository onboarding,
    FakeConsentsRepository consents,
  })
  makeContainer({bool mandatoryGranted = true}) {
    final auth = FakeAuthRepository();
    addTearDown(auth.dispose);
    final onboarding = FakeOnboardingRepository(onboardingCompleted: false);
    final consents = FakeConsentsRepository(mandatoryGranted: mandatoryGranted);
    final container = ProviderContainer.test(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        onboardingRepositoryProvider.overrideWithValue(onboarding),
        consentsRepositoryProvider.overrideWithValue(consents),
        notificationPrefsRepositoryProvider.overrideWithValue(
          FakeNotificationPrefsRepository(),
        ),
      ],
    );
    return (container: container, onboarding: onboarding, consents: consents);
  }

  void fillWizard(CompanyOnboardingController controller) {
    controller.submitCompanyData(
      legalName: 'Gastro SA',
      tradeName: 'La Fantasía',
      cuit: '30-71234567-8',
      sectorId: FakeCatalogRepository.gastronomiaSectorId,
      sizeRange: CompanySizeRange.from11To50,
    );
    controller.submitPlace(
      provinceId: FakeCatalogRepository.cabaProvinceId,
      localityId: FakeCatalogRepository.cabaLocalityId,
      website: 'https://lafantasia.test',
    );
    controller.submitApplicant(
      fullName: 'Dueña Prueba',
      position: 'Dueña',
      relationship: CompanyRelationship.owner,
    );
  }

  test(
    'con consentimientos vigentes arranca en los datos de la empresa',
    () async {
      final setup = makeContainer();
      final state = await setup.container.read(
        companyOnboardingControllerProvider.future,
      );
      expect(state.step, CompanyStep.company);
    },
  );

  test(
    'los pasos de datos avanzan en memoria (nada se persiste hasta el final)',
    () async {
      final setup = makeContainer();
      await setup.container.read(companyOnboardingControllerProvider.future);
      final controller = setup.container.read(
        companyOnboardingControllerProvider.notifier,
      );

      fillWizard(controller);

      final state = setup.container
          .read(companyOnboardingControllerProvider)
          .value!;
      expect(state.step, CompanyStep.notifications);
      expect(state.data.legalName, 'Gastro SA');
      expect(
        setup.onboarding.calls,
        isNot(contains('completeCompanyOnboarding')),
      );
    },
  );

  test(
    'terminar crea la empresa una sola vez aunque se toque dos veces',
    () async {
      final setup = makeContainer();
      await setup.container.read(companyOnboardingControllerProvider.future);
      setup.container.listen(onboardingResolutionProvider, (_, _) {});
      final controller = setup.container.read(
        companyOnboardingControllerProvider.notifier,
      );
      fillWizard(controller);

      setup.onboarding.pendingAction = Completer<void>();
      final first = controller.finish();
      final second = controller.finish();
      setup.onboarding.pendingAction!.complete();
      await Future.wait([first, second]);

      expect(setup.onboarding.completeCompanyCalls, 1);
      expect(setup.onboarding.lastCompanyData?.cuit, '30-71234567-8');
      expect(
        setup.onboarding.lastCompanyData?.applicantRelationship,
        CompanyRelationship.owner,
      );
    },
  );

  test('un CUIT duplicado llega como fallo tipado', () async {
    final setup = makeContainer();
    await setup.container.read(companyOnboardingControllerProvider.future);
    final controller = setup.container.read(
      companyOnboardingControllerProvider.notifier,
    );
    fillWizard(controller);

    setup.onboarding.nextFailure = const DataFailure(DataFailureCode.duplicate);
    await controller.finish();

    final state = setup.container
        .read(companyOnboardingControllerProvider)
        .value!;
    expect(state.failure?.code, DataFailureCode.duplicate);
    expect(state.submitting, isFalse);
  });

  test('sin consentimientos vigentes arranca pidiéndolos', () async {
    final setup = makeContainer(mandatoryGranted: false);
    final state = await setup.container.read(
      companyOnboardingControllerProvider.future,
    );
    expect(state.step, CompanyStep.consents);

    final controller = setup.container.read(
      companyOnboardingControllerProvider.notifier,
    );
    await controller.submitMandatoryConsents();
    expect(
      setup.consents.calls.where((c) => c.startsWith('grant:')).length,
      3,
      reason: 'terms + tratamiento de datos + mayoría de edad',
    );
    expect(
      setup.container.read(companyOnboardingControllerProvider).value!.step,
      CompanyStep.company,
    );
  });
}
