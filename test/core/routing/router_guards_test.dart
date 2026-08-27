import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/core/routing/app_entry_point.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/authentication/presentation/login_screen.dart';
import 'package:talentflash_argentina/features/authentication/presentation/session_issue_screen.dart';
import 'package:talentflash_argentina/features/authentication/presentation/session_loading_screen.dart';
import 'package:talentflash_argentina/features/companies/presentation/company_home_screen.dart';
import 'package:talentflash_argentina/features/moderation/presentation/admin_home_screen.dart';
import 'package:talentflash_argentina/features/onboarding/presentation/welcome_screen.dart';
import 'package:talentflash_argentina/features/profiles/presentation/candidate_home_screen.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/pump_app.dart';

/// Los guards son UX: evitan mostrar una pantalla que no corresponde. La
/// autorización real la aplica RLS en Postgres y está cubierta por la suite
/// pgTAP (`supabase/tests/database/`).
void main() {
  group('arranque', () {
    testWidgets('mientras la sesión no se resuelve no se ve nada privado', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      await pumpTalentFlashApp(tester, authRepository: repository);
      await tester.pump();

      expect(find.byType(SessionLoadingScreen), findsOneWidget);
      expect(find.text('Cargando tu sesión…'), findsOneWidget);
      expect(find.byType(CandidateHomeScreen), findsNothing);
      expect(find.byType(CompanyHomeScreen), findsNothing);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets('el binario de candidato no parpadea contenido privado', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      await pumpTalentFlashApp(
        tester,
        authRepository: repository,
        entryPoint: AppEntryPoint.candidate,
      );
      await tester.pump();

      expect(find.byType(SessionLoadingScreen), findsOneWidget);
      expect(find.byType(CandidateHomeScreen), findsNothing);

      repository.emit(const AuthStatusSignedOut());
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('con sesión restaurada entra directo al shell del rol', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      await pumpTalentFlashApp(tester, authRepository: repository);
      await tester.pump();

      repository.emitSignedIn(BusinessRole.company);
      await tester.pumpAndSettle();

      expect(find.byType(CompanyHomeScreen), findsOneWidget);
      expect(find.byType(SessionLoadingScreen), findsNothing);
    });
  });

  group('sin sesión', () {
    testWidgets('el binario general muestra la bienvenida', (tester) async {
      final repository = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      await pumpTalentFlashApp(tester, authRepository: repository);
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('una ruta privada manda al login y conserva el destino', (
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

      harness.router.go('/empresa');
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(CompanyHomeScreen), findsNothing);
      expect(harness.location, '/auth/login?destino=%2Fempresa');

      repository.emitSignedIn(BusinessRole.company);
      await tester.pumpAndSettle();
      expect(find.byType(CompanyHomeScreen), findsOneWidget);
    });

    testWidgets('el binario de empresa abre su login', (tester) async {
      await pumpTalentFlashApp(
        tester,
        authRepository: FakeAuthRepository(
          initialStatus: const AuthStatusSignedOut(),
        ),
        entryPoint: AppEntryPoint.company,
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('separación de shells por rol', () {
    testWidgets('un candidato no entra al shell de empresa', (tester) async {
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

      harness.router.go('/empresa');
      await tester.pumpAndSettle();

      expect(find.byType(CompanyHomeScreen), findsNothing);
      expect(find.byType(CandidateHomeScreen), findsOneWidget);
      expect(harness.location, '/candidato');
    });

    testWidgets('una empresa no entra al shell de candidato', (tester) async {
      final repository = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      final harness = await pumpTalentFlashApp(
        tester,
        authRepository: repository,
      );
      await tester.pumpAndSettle();
      repository.emitSignedIn(BusinessRole.company);
      await tester.pumpAndSettle();

      harness.router.go('/candidato');
      await tester.pumpAndSettle();

      expect(find.byType(CandidateHomeScreen), findsNothing);
      expect(find.byType(CompanyHomeScreen), findsOneWidget);
    });

    testWidgets('el panel admin responde con una negativa explícita', (
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

      harness.router.go('/admin');
      await tester.pumpAndSettle();

      expect(find.byType(AdminHomeScreen), findsNothing);
      expect(find.byType(SessionIssueScreen), findsOneWidget);
      expect(find.text('No tenés permiso para esta sección'), findsWidgets);

      await tester.tap(find.text('Ir a mi inicio'));
      await tester.pumpAndSettle();
      expect(find.byType(CandidateHomeScreen), findsOneWidget);
    });

    testWidgets('una cuenta de administración no se degrada a otro shell', (
      tester,
    ) async {
      final repository = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      final harness = await pumpTalentFlashApp(
        tester,
        authRepository: repository,
        entryPoint: AppEntryPoint.candidate,
      );
      await tester.pumpAndSettle();
      repository.emitSignedIn(BusinessRole.admin);
      await tester.pumpAndSettle();

      expect(find.byType(AdminHomeScreen), findsOneWidget);
      expect(find.byType(CandidateHomeScreen), findsNothing);

      harness.router.go('/candidato');
      await tester.pumpAndSettle();
      expect(find.byType(AdminHomeScreen), findsOneWidget);
      expect(harness.location, '/admin');
    });

    testWidgets('con sesión no se vuelve al login ni al registro', (
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

      for (final path in <String>['/auth/login', '/auth/registro', '/']) {
        harness.router.go(path);
        await tester.pumpAndSettle();
        expect(
          find.byType(CandidateHomeScreen),
          findsOneWidget,
          reason: 'desde $path debería quedarse en su shell',
        );
      }
    });
  });

  group('sesión inconsistente', () {
    testWidgets('un claim ilegible lleva al estado seguro, no a un shell', (
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

      repository.emit(
        const AuthStatusInconsistent(userId: 'user-1', rawClaim: 'moderator'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SessionIssueScreen), findsOneWidget);
      expect(find.text('No pudimos verificar tu tipo de cuenta'), findsWidgets);
      expect(find.byType(CandidateHomeScreen), findsNothing);
      expect(find.byType(CompanyHomeScreen), findsNothing);
      expect(find.byType(AdminHomeScreen), findsNothing);

      // Sin rol confiable la única salida ofrecida es cerrar sesión.
      expect(find.text('Ir a mi inicio'), findsNothing);
      expect(find.text('Cerrar sesión'), findsOneWidget);

      harness.router.go('/candidato');
      await tester.pumpAndSettle();
      expect(find.byType(SessionIssueScreen), findsOneWidget);
    });

    testWidgets('una sesión sin claim tampoco se degrada a candidato', (
      tester,
    ) async {
      final repository = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      await pumpTalentFlashApp(tester, authRepository: repository);
      await tester.pumpAndSettle();

      repository.emit(const AuthStatusInconsistent(userId: 'user-1'));
      await tester.pumpAndSettle();

      expect(find.byType(SessionIssueScreen), findsOneWidget);
      expect(find.byType(CandidateHomeScreen), findsNothing);
    });

    testWidgets('cerrar sesión desde el estado seguro devuelve al arranque', (
      tester,
    ) async {
      final repository = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      await pumpTalentFlashApp(tester, authRepository: repository);
      await tester.pumpAndSettle();
      repository.emit(
        const AuthStatusInconsistent(userId: 'user-1', rawClaim: 'moderator'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('signOut'));
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(SessionIssueScreen), findsNothing);
    });
  });

  group('cierre de sesión', () {
    // Al cerrar sesión la ruta actual es privada, así que el guard aplica la
    // misma regla que a cualquier visita sin sesión: login, conservando el
    // destino por si la persona vuelve a entrar con la misma cuenta.
    testWidgets('desde el shell del candidato vuelve al login', (tester) async {
      final repository = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      await pumpTalentFlashApp(tester, authRepository: repository);
      await tester.pumpAndSettle();
      repository.emitSignedIn(BusinessRole.candidate);
      await tester.pumpAndSettle();
      expect(find.byType(CandidateHomeScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(repository.calls, <String>['signOut']);
      expect(find.byType(CandidateHomeScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('desde el binario de empresa vuelve a su login', (
      tester,
    ) async {
      final repository = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      await pumpTalentFlashApp(
        tester,
        authRepository: repository,
        entryPoint: AppEntryPoint.company,
      );
      await tester.pumpAndSettle();
      repository.emitSignedIn(BusinessRole.company);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(find.byType(CompanyHomeScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('el shell muestra con qué cuenta se entró', (tester) async {
      final repository = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      await pumpTalentFlashApp(tester, authRepository: repository);
      await tester.pumpAndSettle();
      repository.emitSignedIn(
        BusinessRole.company,
        email: 'empresa1@dev.talentflash.test',
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Sesión iniciada como empresa1@dev.talentflash.test'),
        findsOneWidget,
      );
    });
  });

  group('rutas inexistentes', () {
    testWidgets('sin sesión no se ofrece cerrar una sesión que no existe', (
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

      harness.router.go('/ruta-que-no-existe');
      await tester.pumpAndSettle();

      expect(find.byType(SessionIssueScreen), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsNothing);
      expect(find.text('Ir a mi inicio'), findsNothing);

      await tester.tap(find.text('Volver al inicio'));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('una ruta desconocida no expone contenido privado', (
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

      harness.router.go('/ruta-que-no-existe');
      await tester.pumpAndSettle();

      expect(find.byType(SessionIssueScreen), findsOneWidget);
      expect(find.text('No encontramos esa pantalla'), findsWidgets);
    });
  });

  group('instancia del router', () {
    testWidgets('hay un solo GoRouter y sobrevive a los cambios de sesión', (
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
      final initialRouter = harness.router;

      repository.emitSignedIn(BusinessRole.candidate);
      await tester.pumpAndSettle();
      repository.emit(const AuthStatusSignedOut());
      await tester.pumpAndSettle();

      expect(identical(harness.router, initialRouter), isTrue);
      expect(find.byType(Router<Object>), findsOneWidget);
    });
  });
}
