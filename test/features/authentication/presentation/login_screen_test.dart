import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/core/routing/app_entry_point.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_failure.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/authentication/presentation/account_type_screen.dart';
import 'package:talentflash_argentina/features/authentication/presentation/login_screen.dart';
import 'package:talentflash_argentina/features/authentication/presentation/password_recovery_screen.dart';
import 'package:talentflash_argentina/features/authentication/presentation/sign_up_screen.dart';
import 'package:talentflash_argentina/features/profiles/presentation/candidate_home_screen.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/pump_app.dart';

Finder emailField() => find.byType(TextFormField).at(0);
Finder passwordField() => find.byType(TextFormField).at(1);

/// `TextFormField` delega en un `TextField`: las propiedades de teclado, foco
/// y autocompletado se verifican sobre ese widget interno.
TextField innerField(WidgetTester tester, int index) =>
    tester.widget<TextField>(find.byType(TextField).at(index));

void main() {
  Future<TalentFlashHarness> pumpLogin(
    WidgetTester tester, {
    FakeAuthRepository? repository,
    AppEntryPoint entryPoint = AppEntryPoint.chooser,
  }) async {
    final harness = await pumpTalentFlashApp(
      tester,
      authRepository:
          repository ??
          FakeAuthRepository(initialStatus: const AuthStatusSignedOut()),
      entryPoint: entryPoint,
    );
    await tester.pumpAndSettle();
    harness.router.go('/auth/login');
    await tester.pumpAndSettle();
    return harness;
  }

  testWidgets('presenta los campos con label visible en es-AR', (tester) async {
    await pumpLogin(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('los campos declaran teclado y autocompletado apropiados', (
    tester,
  ) async {
    await pumpLogin(tester);

    final email = innerField(tester, 0);
    expect(email.keyboardType, TextInputType.emailAddress);
    expect(email.autofillHints, contains(AutofillHints.username));
    expect(email.textInputAction, TextInputAction.next);

    final password = innerField(tester, 1);
    expect(password.obscureText, isTrue);
    expect(password.autofillHints, contains(AutofillHints.password));
    expect(password.textInputAction, TextInputAction.done);
  });

  testWidgets('un submit vacío muestra errores y no llama al backend', (
    tester,
  ) async {
    final repository = FakeAuthRepository(
      initialStatus: const AuthStatusSignedOut(),
    );
    await pumpLogin(tester, repository: repository);

    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresá tu correo electrónico.'), findsOneWidget);
    expect(find.text('Ingresá tu contraseña.'), findsOneWidget);
    expect(repository.calls, isEmpty);
  });

  testWidgets('valida el formato del correo y el largo de la contraseña', (
    tester,
  ) async {
    final repository = FakeAuthRepository(
      initialStatus: const AuthStatusSignedOut(),
    );
    await pumpLogin(tester, repository: repository);

    await tester.enterText(emailField(), 'no-es-un-correo');
    await tester.enterText(passwordField(), 'corta');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ese correo no parece válido. Revisalo y probá de nuevo.'),
      findsOneWidget,
    );
    expect(
      find.text('La contraseña necesita al menos 10 caracteres.'),
      findsOneWidget,
    );
    expect(repository.calls, isEmpty);
  });

  testWidgets('el foco va al primer campo con error', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(passwordField(), 'password12345');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(innerField(tester, 0).focusNode?.hasFocus, isTrue);
  });

  testWidgets('un login válido llega al repositorio', (tester) async {
    final repository = FakeAuthRepository(
      initialStatus: const AuthStatusSignedOut(),
    );
    await pumpLogin(tester, repository: repository);

    await tester.enterText(emailField(), 'candidato1@dev.talentflash.test');
    await tester.enterText(passwordField(), 'password123');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(repository.calls, <String>['signIn']);
    expect(repository.lastEmail, 'candidato1@dev.talentflash.test');
    expect(repository.lastPassword, 'password123');
  });

  testWidgets('tras autenticarse el router lleva al shell del rol', (
    tester,
  ) async {
    final repository = FakeAuthRepository(
      initialStatus: const AuthStatusSignedOut(),
    );
    await pumpLogin(tester, repository: repository);

    await tester.enterText(emailField(), 'candidato1@dev.talentflash.test');
    await tester.enterText(passwordField(), 'password123');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    repository.emitSignedIn(BusinessRole.candidate);
    await tester.pumpAndSettle();

    expect(find.byType(CandidateHomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('un error se muestra traducido, sin el detalle interno', (
    tester,
  ) async {
    final repository =
        FakeAuthRepository(initialStatus: const AuthStatusSignedOut())
          ..nextFailure = const AuthFailure(
            AuthFailureCode.invalidCredentials,
            debugDetail:
                'AuthException(code: invalid_credentials, status: 400)',
          );
    await pumpLogin(tester, repository: repository);

    await tester.enterText(emailField(), 'candidato1@dev.talentflash.test');
    await tester.enterText(passwordField(), 'incorrecta1');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(
      find.text('El correo o la contraseña no coinciden. Probá de nuevo.'),
      findsOneWidget,
    );
    expect(find.textContaining('AuthException'), findsNothing);
    expect(find.textContaining('invalid_credentials'), findsNothing);
  });

  testWidgets('durante el envío el botón se bloquea y no duplica la llamada', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = FakeAuthRepository(
      initialStatus: const AuthStatusSignedOut(),
    )..pendingAction = gate;
    await pumpLogin(tester, repository: repository);

    await tester.enterText(emailField(), 'candidato1@dev.talentflash.test');
    await tester.enterText(passwordField(), 'password123');
    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(repository.calls, <String>['signIn']);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('se puede mostrar y ocultar la contraseña', (tester) async {
    await pumpLogin(tester);

    expect(innerField(tester, 1).obscureText, isTrue);
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pumpAndSettle();
    expect(innerField(tester, 1).obscureText, isFalse);

    await tester.tap(find.byTooltip('Ocultar contraseña'));
    await tester.pumpAndSettle();
    expect(innerField(tester, 1).obscureText, isTrue);
  });

  testWidgets('enlaza a recuperación y a registro', (tester) async {
    final harness = await pumpLogin(tester);

    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();
    expect(find.byType(PasswordRecoveryScreen), findsOneWidget);

    harness.router.go('/auth/login');
    await tester.pumpAndSettle();
    await tester.tap(find.text('¿No tenés cuenta? Registrate'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountTypeScreen), findsOneWidget);
  });

  testWidgets('el binario de empresa abre el login con su copy y su registro', (
    tester,
  ) async {
    await pumpTalentFlashApp(
      tester,
      authRepository: FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      ),
      entryPoint: AppEntryPoint.company,
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.text('Entrá para gestionar tus búsquedas y tus candidatos.'),
      findsOneWidget,
    );

    await tester.tap(find.text('¿No tenés cuenta? Registrá tu empresa'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(find.text('Crear cuenta de empresa'), findsWidgets);
  });
}
