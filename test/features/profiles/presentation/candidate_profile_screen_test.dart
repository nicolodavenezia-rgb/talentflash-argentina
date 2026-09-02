import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/profiles/domain/candidate_profile.dart';
import 'package:talentflash_argentina/features/profiles/presentation/candidate_profile_edit_screen.dart';
import 'package:talentflash_argentina/features/profiles/presentation/candidate_profile_screen.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_profile_repositories.dart';
import '../../../support/gestures.dart';
import '../../../support/pump_app.dart';

/// Perfil propio (T-021/T-023/T-025): datos, score solo para el dueño y
/// estado de presentación honesto sin botones falsos.
void main() {
  Future<TalentFlashHarness> pumpProfile(
    WidgetTester tester, {
    FakeProfileRepository? profileRepository,
  }) async {
    final auth = FakeAuthRepository(initialStatus: const AuthStatusSignedOut());
    final harness = await pumpTalentFlashApp(
      tester,
      authRepository: auth,
      profileRepository: profileRepository,
    );
    await tester.pumpAndSettle();
    auth.emitSignedIn(BusinessRole.candidate);
    await tester.pumpAndSettle();
    harness.router.go('/candidato/perfil');
    await tester.pumpAndSettle();
    return harness;
  }

  testWidgets('muestra los datos del perfil y el score para el dueño', (
    tester,
  ) async {
    await pumpProfile(tester);

    expect(find.text('Mi perfil'), findsWidgets);
    expect(find.text('Ana María Prueba'), findsOneWidget);
    expect(find.text('Moza de salón con experiencia'), findsOneWidget);
    // testCandidateProfile: base 25 + titular 10 + bio 10 + experiencia 15 +
    // 3 habilidades 10 + idioma 5 = 75 (sin franjas/educación/foto/video).
    expect(find.text('75 % completo'), findsOneWidget);
    expect(
      find.text(
        'Es una guía solo para vos: las empresas no la ven y no '
        'cambia ningún orden de resultados.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('muestra los distintivos de publicación y preparación', (
    tester,
  ) async {
    await pumpProfile(tester);

    expect(find.text('Visible para empresas verificadas'), findsOneWidget);
    expect(
      find.text('Tenés los datos mínimos para postularte'),
      findsOneWidget,
    );
  });

  testWidgets('sin presentación: mensaje honesto y CERO botones falsos', (
    tester,
  ) async {
    await pumpProfile(tester);

    expect(
      find.text('Todavía no tenés una presentación cargada.'),
      findsOneWidget,
    );
    expect(find.textContaining('etapa posterior'), findsOneWidget);
    // Nada que simule grabar/subir un video que no existe (T-023).
    expect(find.textContaining('Grabar'), findsNothing);
    expect(find.textContaining('Subir video'), findsNothing);
  });

  testWidgets('con video en proceso el estado cambia y sigue sin CTA', (
    tester,
  ) async {
    await pumpProfile(
      tester,
      profileRepository: FakeProfileRepository(
        profile: testCandidateProfile(
          presentationStatus: PresentationStatus.processing,
        ),
      ),
    );

    expect(
      find.text('Tu video de presentación se está procesando.'),
      findsOneWidget,
    );
    expect(find.textContaining('Grabar'), findsNothing);
  });

  testWidgets('un error de carga ofrece reintentar', (tester) async {
    final repository = FakeProfileRepository()
      ..nextFailure = const DataFailure(DataFailureCode.network);
    await pumpProfile(tester, profileRepository: repository);

    expect(find.textContaining('No pudimos cargar tu perfil'), findsOneWidget);
    await ensureAndTap(tester, find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Ana María Prueba'), findsOneWidget);
  });

  testWidgets('Editar navega a la pantalla de edición', (tester) async {
    final harness = await pumpProfile(tester);

    await ensureAndTap(tester, find.text('Editar perfil'));
    await tester.pumpAndSettle();

    expect(harness.location, '/candidato/perfil/editar');
    expect(find.byType(CandidateProfileEditScreen), findsOneWidget);
  });

  testWidgets('con avatar pide una URL firmada de corta vida', (tester) async {
    final repository = FakeProfileRepository(
      profile: testCandidateProfile(avatarPath: 'cand-prueba-id/avatar.jpg'),
    );
    await pumpProfile(tester, profileRepository: repository);

    expect(
      repository.calls.any((call) => call.startsWith('signedUrl:')),
      isTrue,
      reason: 'la foto solo se sirve con URL firmada (T-022)',
    );
  });

  testWidgets('desde el home del candidato hay entrada accesible al perfil', (
    tester,
  ) async {
    final auth = FakeAuthRepository(initialStatus: const AuthStatusSignedOut());
    final harness = await pumpTalentFlashApp(tester, authRepository: auth);
    await tester.pumpAndSettle();
    auth.emitSignedIn(BusinessRole.candidate);
    await tester.pumpAndSettle();

    await ensureAndTap(tester, find.text('Mi perfil'));
    await tester.pumpAndSettle();

    expect(harness.location, '/candidato/perfil');
    expect(find.byType(CandidateProfileScreen), findsOneWidget);
  });
}
