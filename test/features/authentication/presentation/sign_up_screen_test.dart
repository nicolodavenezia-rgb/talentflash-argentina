import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/data/auth_repository.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_failure.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/authentication/presentation/account_type_screen.dart';
import 'package:talentflash_argentina/features/authentication/presentation/sign_up_screen.dart';
import 'package:talentflash_argentina/features/companies/presentation/company_home_screen.dart';
import 'package:talentflash_argentina/features/profiles/presentation/candidate_home_screen.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/pump_app.dart';

Finder emailField() => find.byType(TextFormField).at(0);
Finder passwordField() => find.byType(TextFormField).at(1);
Finder confirmationField() => find.byType(TextFormField).at(2);

TextField innerField(WidgetTester tester, int index) =>
    tester.widget<TextField>(find.byType(TextField).at(index));

/// El formulario de alta es más alto que la pantalla de test: se desplaza
/// hasta el control antes de tocarlo, igual que haría una persona en un
/// celular chico.
Future<void> ensureAndTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> acceptConsents(WidgetTester tester) async {
  await ensureAndTap(tester, find.byType(CheckboxListTile).at(0));
  await tester.pump();
  await ensureAndTap(tester, find.byType(CheckboxListTile).at(1));
  await tester.pump();
}

Future<void> submitForm(WidgetTester tester) =>
    ensureAndTap(tester, find.text('Crear cuenta'));

Future<void> fillValidForm(WidgetTester tester, String email) async {
  await tester.enterText(emailField(), email);
  await tester.enterText(passwordField(), 'password12345');
  await tester.enterText(confirmationField(), 'password12345');
  await tester.pump();
}

void main() {
  Future<TalentFlashHarness> pumpSignUp(
    WidgetTester tester,
    String path, {
    FakeAuthRepository? repository,
  }) async {
    final harness = await pumpTalentFlashApp(
      tester,
      authRepository:
          repository ??
          FakeAuthRepository(initialStatus: const AuthStatusSignedOut()),
    );
    await tester.pumpAndSettle();
    harness.router.go(path);
    await tester.pumpAndSettle();
    return harness;
  }

  group('elección de tipo de cuenta', () {
    testWidgets('bifurca a candidato y a empresa', (tester) async {
      final harness = await pumpSignUp(tester, '/auth/registro');
      expect(find.byType(AccountTypeScreen), findsOneWidget);

      await tester.tap(find.text('Soy candidato'));
      await tester.pumpAndSettle();
      expect(find.text('Crear cuenta de candidato'), findsWidgets);

      harness.router.go('/auth/registro');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Soy empresa'));
      await tester.pumpAndSettle();
      expect(find.text('Crear cuenta de empresa'), findsWidgets);
    });
  });

  group('registro de candidato', () {
    testWidgets('muestra el formulario con sus consentimientos', (
      tester,
    ) async {
      await pumpSignUp(tester, '/auth/registro/candidato');

      expect(find.byType(SignUpScreen), findsOneWidget);
      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Repetir contraseña'), findsOneWidget);
      expect(find.text('Mínimo 10 caracteres.'), findsOneWidget);
      expect(
        find.text(
          'Acepto el tratamiento de mis datos personales para operar mi '
          'cuenta (Ley 25.326).',
        ),
        findsOneWidget,
      );
      expect(find.text('Declaro ser mayor de 18 años.'), findsOneWidget);
    });

    testWidgets('los consentimientos nunca vienen premarcados', (tester) async {
      await pumpSignUp(tester, '/auth/registro/candidato');

      final boxes = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .toList();
      expect(boxes, hasLength(2));
      expect(boxes.every((box) => box.value == false), isTrue);
    });

    testWidgets('la contraseña nueva usa el hint de autocompletado correcto', (
      tester,
    ) async {
      await pumpSignUp(tester, '/auth/registro/candidato');

      expect(
        innerField(tester, 1).autofillHints,
        contains(AutofillHints.newPassword),
      );
      expect(
        innerField(tester, 2).autofillHints,
        contains(AutofillHints.newPassword),
      );
    });

    testWidgets('sin consentimientos no se crea la cuenta', (tester) async {
      final repository = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      await pumpSignUp(
        tester,
        '/auth/registro/candidato',
        repository: repository,
      );

      await fillValidForm(tester, 'nueva@dev.talentflash.test');
      await submitForm(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('Necesitamos tu confirmación para poder crear la cuenta.'),
        findsNWidgets(2),
      );
      expect(repository.calls, isEmpty);
    });

    testWidgets('con un solo consentimiento tampoco alcanza', (tester) async {
      final repository = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      await pumpSignUp(
        tester,
        '/auth/registro/candidato',
        repository: repository,
      );

      await fillValidForm(tester, 'nueva@dev.talentflash.test');
      await ensureAndTap(tester, find.byType(CheckboxListTile).at(0));
      await tester.pump();
      await submitForm(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('Necesitamos tu confirmación para poder crear la cuenta.'),
        findsOneWidget,
      );
      expect(repository.calls, isEmpty);
    });

    testWidgets('detecta contraseñas que no coinciden', (tester) async {
      final repository = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      await pumpSignUp(
        tester,
        '/auth/registro/candidato',
        repository: repository,
      );

      await tester.enterText(emailField(), 'nueva@dev.talentflash.test');
      await tester.enterText(passwordField(), 'password12345');
      await tester.enterText(confirmationField(), 'password54321');
      await acceptConsents(tester);
      await submitForm(tester);
      await tester.pumpAndSettle();

      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('un alta válida pide el rol candidate', (tester) async {
      final repository = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      await pumpSignUp(
        tester,
        '/auth/registro/candidato',
        repository: repository,
      );

      await fillValidForm(tester, 'nueva@dev.talentflash.test');
      await acceptConsents(tester);
      await submitForm(tester);
      await tester.pumpAndSettle();

      expect(repository.calls, <String>['signUp']);
      expect(repository.lastSignUpRole, SignUpRole.candidate);
      expect(repository.lastEmail, 'nueva@dev.talentflash.test');
      expect(find.byType(CandidateHomeScreen), findsOneWidget);
    });

    testWidgets('si falta confirmar el correo lo dice y no navega', (
      tester,
    ) async {
      final repository = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      )..signUpOutcome = SignUpOutcome.emailConfirmationRequired;
      await pumpSignUp(
        tester,
        '/auth/registro/candidato',
        repository: repository,
      );

      await fillValidForm(tester, 'nueva@dev.talentflash.test');
      await acceptConsents(tester);
      await submitForm(tester);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Te enviamos un correo para confirmar tu cuenta. Abrí el enlace y '
          'volvé a iniciar sesión.',
        ),
        findsOneWidget,
      );
      expect(find.byType(SignUpScreen), findsOneWidget);
      expect(find.byType(CandidateHomeScreen), findsNothing);
    });

    testWidgets('un correo ya registrado se explica en es-AR', (tester) async {
      final repository =
          FakeAuthRepository(initialStatus: const AuthStatusSignedOut())
            ..nextFailure = const AuthFailure(
              AuthFailureCode.emailAlreadyRegistered,
              debugDetail:
                  'AuthException(code: user_already_exists, status: 422)',
            );
      await pumpSignUp(
        tester,
        '/auth/registro/candidato',
        repository: repository,
      );

      await fillValidForm(tester, 'candidato1@dev.talentflash.test');
      await acceptConsents(tester);
      await submitForm(tester);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Ya existe una cuenta con ese correo. Iniciá sesión o recuperá tu '
          'contraseña.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('user_already_exists'), findsNothing);
    });

    testWidgets('bloquea el doble submit mientras crea la cuenta', (
      tester,
    ) async {
      final gate = Completer<void>();
      final repository = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      )..pendingAction = gate;
      await pumpSignUp(
        tester,
        '/auth/registro/candidato',
        repository: repository,
      );

      await fillValidForm(tester, 'nueva@dev.talentflash.test');
      await acceptConsents(tester);
      await submitForm(tester);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pump();
      expect(repository.calls, <String>['signUp']);

      gate.complete();
      await tester.pumpAndSettle();
    });
  });

  group('registro de empresa', () {
    testWidgets('pide el rol company y aclara que la empresa viene después', (
      tester,
    ) async {
      final repository = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      await pumpSignUp(
        tester,
        '/auth/registro/empresa',
        repository: repository,
      );

      expect(
        find.text(
          'Creá primero tu usuario. Los datos de la empresa y la verificación '
          'de CUIT vienen en el paso siguiente.',
        ),
        findsOneWidget,
      );

      await fillValidForm(tester, 'nueva-empresa@dev.talentflash.test');
      await acceptConsents(tester);
      await submitForm(tester);
      await tester.pumpAndSettle();

      expect(repository.lastSignUpRole, SignUpRole.company);
      expect(find.byType(CompanyHomeScreen), findsOneWidget);
    });

    testWidgets('el alta de empresa nunca deriva en rol de candidato', (
      tester,
    ) async {
      final repository = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      await pumpSignUp(
        tester,
        '/auth/registro/empresa',
        repository: repository,
      );

      await fillValidForm(tester, 'nueva-empresa@dev.talentflash.test');
      await acceptConsents(tester);
      await submitForm(tester);
      await tester.pumpAndSettle();

      expect(repository.currentStatus.role, BusinessRole.company);
      expect(find.byType(CandidateHomeScreen), findsNothing);
    });
  });
}
