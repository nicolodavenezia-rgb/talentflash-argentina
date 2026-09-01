import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/authentication/presentation/session_loading_screen.dart';
import 'package:talentflash_argentina/features/companies/presentation/company_home_screen.dart';
import 'package:talentflash_argentina/features/legal/presentation/legal_document_screen.dart';
import 'package:talentflash_argentina/features/moderation/presentation/admin_home_screen.dart';
import 'package:talentflash_argentina/features/onboarding/domain/candidate_onboarding_data.dart';
import 'package:talentflash_argentina/features/onboarding/presentation/candidate_onboarding_screen.dart';
import 'package:talentflash_argentina/features/onboarding/presentation/company_onboarding_screen.dart';
import 'package:talentflash_argentina/features/onboarding/presentation/reconsent_screen.dart';
import 'package:talentflash_argentina/features/profiles/presentation/candidate_home_screen.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_onboarding_repositories.dart';
import '../../support/gestures.dart';
import '../../support/pump_app.dart';

/// Guard 4 (onboarding) y guard 6 (consentimientos) de UX_FLOWS.md §1.5.
/// El estado viene SIEMPRE de la base (fakes acá); los guards son UX y la
/// autorización real sigue siendo RLS (suite pgTAP 007–009).
void main() {
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

  testWidgets('un candidato con onboarding incompleto aterriza en su wizard', (
    tester,
  ) async {
    final repository = FakeAuthRepository(
      initialStatus: const AuthStatusSignedOut(),
    );
    final harness = await pumpTalentFlashApp(
      tester,
      authRepository: repository,
      onboardingRepository: FakeOnboardingRepository(
        onboardingCompleted: false,
      ),
    );
    await tester.pumpAndSettle();
    repository.emitSignedIn(BusinessRole.candidate);
    await tester.pumpAndSettle();

    expect(find.byType(CandidateOnboardingScreen), findsOneWidget);
    expect(find.byType(CandidateHomeScreen), findsNothing);
    expect(harness.location, '/candidato/onboarding');

    // Intentar irse a otra pantalla vuelve al wizard.
    harness.router.go('/candidato');
    await tester.pumpAndSettle();
    expect(find.byType(CandidateOnboardingScreen), findsOneWidget);
  });

  testWidgets('una empresa con onboarding incompleto aterriza en su wizard', (
    tester,
  ) async {
    final repository = FakeAuthRepository(
      initialStatus: const AuthStatusSignedOut(),
    );
    final harness = await pumpTalentFlashApp(
      tester,
      authRepository: repository,
      onboardingRepository: FakeOnboardingRepository(
        onboardingCompleted: false,
      ),
    );
    await tester.pumpAndSettle();
    repository.emitSignedIn(BusinessRole.company);
    await tester.pumpAndSettle();

    expect(find.byType(CompanyOnboardingScreen), findsOneWidget);
    expect(find.byType(CompanyHomeScreen), findsNothing);
    expect(harness.location, '/empresa/onboarding');
  });

  testWidgets(
    'mientras el estado de onboarding se resuelve no se ve el shell',
    (tester) async {
      final repository = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      final onboarding = FakeOnboardingRepository()
        ..pendingAction = Completer<void>();
      await pumpTalentFlashApp(
        tester,
        authRepository: repository,
        onboardingRepository: onboarding,
      );
      await tester.pumpAndSettle();
      repository.emitSignedIn(BusinessRole.candidate);
      // El estado de onboarding sigue pendiente (Completer). El spinner de la
      // pantalla de carga anima para siempre, así que nada de pumpAndSettle:
      // frames explícitos hasta que el router asienta en la carga.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SessionLoadingScreen), findsOneWidget);
      expect(find.byType(CandidateHomeScreen), findsNothing);
      expect(find.byType(CandidateOnboardingScreen), findsNothing);

      onboarding.pendingAction!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CandidateHomeScreen), findsOneWidget);
    },
  );

  testWidgets('admin no pasa por ningún wizard', (tester) async {
    final repository = FakeAuthRepository(
      initialStatus: const AuthStatusSignedOut(),
    );
    await pumpTalentFlashApp(
      tester,
      authRepository: repository,
      onboardingRepository: FakeOnboardingRepository(
        onboardingCompleted: false,
      ),
    );
    await tester.pumpAndSettle();
    repository.emitSignedIn(BusinessRole.admin);
    await tester.pumpAndSettle();

    expect(find.byType(AdminHomeScreen), findsOneWidget);
    expect(find.byType(CandidateOnboardingScreen), findsNothing);
  });

  testWidgets('con todo al día, el wizard deja de ser un destino', (
    tester,
  ) async {
    final repository = FakeAuthRepository(
      initialStatus: const AuthStatusSignedOut(),
    );
    final harness = await pumpTalentFlashApp(
      tester,
      authRepository: repository,
    );
    await tester.pumpAndSettle();
    repository.emitSignedIn(BusinessRole.candidate);
    await tester.pumpAndSettle();

    harness.router.go('/candidato/onboarding');
    await tester.pumpAndSettle();
    expect(find.byType(CandidateHomeScreen), findsOneWidget);
    expect(harness.location, '/candidato');
  });

  testWidgets(
    'terminar el wizard (paso final) lleva al shell sin tocar nada más',
    (tester) async {
      final repository = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      final onboarding = FakeOnboardingRepository(onboardingCompleted: false)
        ..draft = completeDraft;
      final harness = await pumpTalentFlashApp(
        tester,
        authRepository: repository,
        onboardingRepository: onboarding,
      );
      await tester.pumpAndSettle();
      repository.emitSignedIn(BusinessRole.candidate);
      await tester.pumpAndSettle();

      // Con el avance completo el wizard retoma en el resumen.
      expect(find.byType(CandidateOnboardingScreen), findsOneWidget);
      expect(find.text('Revisá y confirmá'), findsWidgets);

      await ensureAndTap(tester, find.text('Terminar'));

      expect(onboarding.calls, contains('completeCandidateOnboarding'));
      expect(find.byType(CandidateHomeScreen), findsOneWidget);
      expect(harness.location, '/candidato');
    },
  );

  testWidgets(
    'onboarding completo + versión obligatoria vieja → reconsentimiento',
    (tester) async {
      final repository = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      final consents = FakeConsentsRepository(mandatoryGranted: false);
      final harness = await pumpTalentFlashApp(
        tester,
        authRepository: repository,
        consentsRepository: consents,
      );
      await tester.pumpAndSettle();
      repository.emitSignedIn(BusinessRole.candidate);
      await tester.pumpAndSettle();

      expect(find.byType(ReconsentScreen), findsOneWidget);
      expect(find.byType(CandidateHomeScreen), findsNothing);
      expect(harness.location, '/candidato/consentimientos');

      // Nada viene premarcado: hay que aceptar cada punto por separado.
      await ensureAndTap(tester, find.text('Aceptar y continuar'));
      expect(find.byType(ReconsentScreen), findsOneWidget);

      await ensureAndTap(
        tester,
        find.text('Leí y acepto los Términos y condiciones.'),
      );
      await ensureAndTap(
        tester,
        find.textContaining('Acepto el tratamiento de mis datos'),
      );
      await ensureAndTap(tester, find.text('Declaro ser mayor de 18 años.'));
      await ensureAndTap(tester, find.text('Aceptar y continuar'));

      expect(consents.calls.where((c) => c.startsWith('grant:')).length, 3);
      expect(find.byType(CandidateHomeScreen), findsOneWidget);
    },
  );

  testWidgets('los documentos legales se leen sin sesión', (tester) async {
    final repository = FakeAuthRepository(
      initialStatus: const AuthStatusSignedOut(),
    );
    final harness = await pumpTalentFlashApp(
      tester,
      authRepository: repository,
    );
    await tester.pumpAndSettle();

    harness.router.go('/legal/terminos');
    await tester.pumpAndSettle();

    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(find.text('Términos y condiciones de TalentFlash'), findsWidgets);
    expect(find.textContaining('Versión vigente:'), findsOneWidget);

    harness.router.go('/legal/privacidad');
    await tester.pumpAndSettle();
    expect(find.text('Política de privacidad de TalentFlash'), findsWidgets);
  });
}
