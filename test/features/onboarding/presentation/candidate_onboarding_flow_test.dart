import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/notifications/domain/notification_prefs.dart';
import 'package:talentflash_argentina/features/onboarding/domain/candidate_onboarding_data.dart';
import 'package:talentflash_argentina/features/onboarding/presentation/candidate_onboarding_screen.dart';
import 'package:talentflash_argentina/features/profiles/presentation/candidate_home_screen.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_onboarding_repositories.dart';
import '../../../support/gestures.dart';
import '../../../support/pump_app.dart';

/// Recorrido del wizard de candidato (T-016): consentimientos → datos →
/// cascada geo → preferencias → privacidad → avisos → resumen → fin.
void main() {
  Future<
    ({
      FakeAuthRepository auth,
      FakeOnboardingRepository onboarding,
      FakeConsentsRepository consents,
      FakeNotificationPrefsRepository prefs,
    })
  >
  startWizard(
    WidgetTester tester, {
    bool mandatoryGranted = false,
    CandidateOnboardingData draft = const CandidateOnboardingData(),
  }) async {
    final auth = FakeAuthRepository(initialStatus: const AuthStatusSignedOut());
    final onboarding = FakeOnboardingRepository(onboardingCompleted: false)
      ..draft = draft;
    final consents = FakeConsentsRepository(mandatoryGranted: mandatoryGranted);
    final prefs = FakeNotificationPrefsRepository();
    await pumpTalentFlashApp(
      tester,
      authRepository: auth,
      onboardingRepository: onboarding,
      consentsRepository: consents,
      notificationPrefsRepository: prefs,
    );
    await tester.pumpAndSettle();
    auth.emitSignedIn(BusinessRole.candidate);
    await tester.pumpAndSettle();
    expect(find.byType(CandidateOnboardingScreen), findsOneWidget);
    return (
      auth: auth,
      onboarding: onboarding,
      consents: consents,
      prefs: prefs,
    );
  }

  testWidgets('el recorrido completo termina con el onboarding cerrado', (
    tester,
  ) async {
    final setup = await startWizard(tester);

    // Paso 1 — consentimientos: nada premarcado y sin avanzar sin aceptar.
    expect(find.text('Paso 1 de 7'), findsOneWidget);
    expect(
      tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .where((tile) => tile.value ?? false),
      isEmpty,
      reason: 'ningún consentimiento viene premarcado (PRIVACY §4)',
    );
    await ensureAndTap(tester, find.text('Continuar'));
    expect(
      find.text('Necesitamos tu confirmación para poder crear la cuenta.'),
      findsWidgets,
    );
    expect(setup.consents.calls.where((c) => c.startsWith('grant:')), isEmpty);

    await ensureAndTap(
      tester,
      find.text('Leí y acepto los Términos y condiciones.'),
    );
    await ensureAndTap(
      tester,
      find.textContaining('Acepto el tratamiento de mis datos'),
    );
    await ensureAndTap(tester, find.text('Declaro ser mayor de 18 años.'));
    await ensureAndTap(tester, find.text('Continuar'));

    expect(setup.consents.calls.where((c) => c.startsWith('grant:')).length, 3);

    // Paso 2 — sobre vos.
    expect(find.text('Paso 2 de 7'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Ana Pérez');
    await tester.enterText(find.byType(TextFormField).at(1), '10/04/1995');
    await ensureAndTap(tester, find.text('Continuar'));
    expect(setup.onboarding.lastSavedData?.fullName, 'Ana Pérez');

    // Paso 3 — cascada provincia → localidad → barrio.
    expect(find.text('Paso 3 de 7'), findsOneWidget);
    await selectDropdownOption(
      tester,
      find.text('Provincia'),
      'Ciudad Autónoma de Buenos Aires',
    );
    await selectDropdownOption(
      tester,
      find.text('Localidad'),
      'Ciudad Autónoma de Buenos Aires',
    );
    // La localidad tiene barrios cargados: el barrio es obligatorio.
    await ensureAndTap(tester, find.text('Continuar'));
    expect(find.text('Paso 3 de 7'), findsOneWidget);
    expect(find.text('Elegí una opción.'), findsWidgets);
    await selectDropdownOption(tester, find.text('Barrio'), 'Palermo');
    await ensureAndTap(tester, find.text('Continuar'));
    expect(
      setup.onboarding.lastSavedData?.neighborhoodId,
      FakeCatalogRepository.palermoId,
    );

    // Paso 4 — sector, disponibilidad y modalidad.
    expect(find.text('Paso 4 de 7'), findsOneWidget);
    await selectDropdownOption(
      tester,
      find.text('Sector o rubro'),
      'Gastronomía y hotelería',
    );
    await selectDropdownOption(
      tester,
      find.text('Disponibilidad'),
      'Inmediata',
    );
    await ensureAndTap(tester, find.text('Presencial'));
    await ensureAndTap(tester, find.text('Continuar'));
    expect(setup.onboarding.lastSavedData?.workModes, {
      CandidateWorkMode.presencial,
    });

    // Paso 5 — privacidad opcional: se activa solo la publicación.
    expect(find.text('Paso 5 de 7'), findsOneWidget);
    await ensureAndTap(
      tester,
      find.textContaining('Quiero que las empresas descubran mi perfil'),
    );
    await ensureAndTap(tester, find.text('Continuar'));
    expect(
      setup.consents.calls,
      contains('grant:video_profile_publication@$testConsentVersion'),
    );
    expect(
      setup.consents.calls.where((c) => c.startsWith('grant:ai_features')),
      isEmpty,
    );

    // Paso 6 — avisos: nada activado de fábrica.
    expect(find.text('Paso 6 de 7'), findsOneWidget);
    await ensureAndTap(tester, find.text('Continuar'));
    final saved = setup.prefs.stored;
    expect(saved, isNotEmpty);
    for (final pref in saved) {
      if (pref.category != NotificationCategory.system) {
        expect(pref.pushEnabled, isFalse);
        expect(pref.emailEnabled, isFalse);
      }
    }

    // Paso 7 — resumen honesto + fin.
    expect(find.text('Paso 7 de 7'), findsOneWidget);
    expect(find.textContaining('Ana Pérez'), findsWidgets);
    expect(
      find.text('Tu perfil va a ser visible para las empresas verificadas.'),
      findsOneWidget,
    );
    await ensureAndTap(tester, find.text('Terminar'));

    expect(setup.onboarding.calls, contains('completeCandidateOnboarding'));
    expect(find.byType(CandidateHomeScreen), findsOneWidget);
  });

  testWidgets('una persona menor queda bloqueada y nada extra se persiste', (
    tester,
  ) async {
    final setup = await startWizard(tester, mandatoryGranted: true);

    expect(find.text('Paso 2 de 7'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Persona Menor');
    await tester.enterText(find.byType(TextFormField).at(1), '01/01/2015');
    await ensureAndTap(tester, find.text('Continuar'));

    expect(find.text('TalentFlash es solo para mayores de 18'), findsWidgets);
    expect(setup.onboarding.calls, isNot(contains('saveCandidateData')));

    // La única salida es cerrar sesión.
    await ensureAndTap(tester, find.text('Cerrar sesión'));
    expect(setup.auth.calls, contains('signOut'));
  });

  testWidgets('el wizard retoma en el paso pendiente al volver a entrar', (
    tester,
  ) async {
    await startWizard(
      tester,
      mandatoryGranted: true,
      draft: CandidateOnboardingData(
        fullName: 'Ana Pérez',
        birthDate: DateTime(1995, 4, 10),
      ),
    );

    // Identidad ya guardada: retoma directo en la ubicación.
    expect(find.text('Paso 3 de 7'), findsOneWidget);
    expect(find.text('Provincia'), findsOneWidget);
  });

  testWidgets('el resumen es honesto cuando NO se publica el perfil', (
    tester,
  ) async {
    final completeDraft = CandidateOnboardingData(
      fullName: 'Ana Pérez',
      birthDate: DateTime(1995, 4, 10),
      provinceId: FakeCatalogRepository.cabaProvinceId,
      localityId: FakeCatalogRepository.cabaLocalityId,
      neighborhoodId: FakeCatalogRepository.palermoId,
      sectorId: FakeCatalogRepository.gastronomiaSectorId,
      availability: CandidateAvailability.inmediata,
      workModes: const {CandidateWorkMode.presencial},
    );
    await startWizard(tester, mandatoryGranted: true, draft: completeDraft);

    expect(find.text('Paso 7 de 7'), findsOneWidget);
    expect(
      find.textContaining('Tu perfil NO va a ser visible'),
      findsOneWidget,
    );
  });
}
