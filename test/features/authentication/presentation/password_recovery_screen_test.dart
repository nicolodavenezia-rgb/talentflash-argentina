import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_failure.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/presentation/login_screen.dart';
import 'package:talentflash_argentina/features/authentication/presentation/password_recovery_screen.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/pump_app.dart';

const neutralAnswer =
    'Si hay una cuenta con ese correo, te enviamos las instrucciones para '
    'restablecer la contraseña. Revisá tu bandeja de entrada y el correo no '
    'deseado.';

void main() {
  Future<FakeAuthRepository> pumpRecovery(
    WidgetTester tester, {
    FakeAuthRepository? repository,
  }) async {
    final authRepository =
        repository ??
        FakeAuthRepository(initialStatus: const AuthStatusSignedOut());
    final harness = await pumpTalentFlashApp(
      tester,
      authRepository: authRepository,
    );
    await tester.pumpAndSettle();
    harness.router.go('/auth/recuperar');
    await tester.pumpAndSettle();
    return authRepository;
  }

  testWidgets('pide solo el correo y explica el paso pendiente', (
    tester,
  ) async {
    await pumpRecovery(tester);

    expect(find.byType(PasswordRecoveryScreen), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Enviar instrucciones'), findsOneWidget);
    // No se dibuja un formulario de nueva contraseña que no podría funcionar.
    expect(find.text('Contraseña'), findsNothing);
    expect(
      find.text(
        'El cambio de contraseña dentro de la app todavía no está '
        'disponible: falta definir el enlace profundo (T-013 del ROADMAP).',
      ),
      findsOneWidget,
    );
  });

  testWidgets('valida el correo antes de llamar al backend', (tester) async {
    final repository = await pumpRecovery(tester);

    await tester.tap(find.text('Enviar instrucciones'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresá tu correo electrónico.'), findsOneWidget);
    expect(repository.calls, isEmpty);
  });

  testWidgets('con una cuenta existente responde de forma neutra', (
    tester,
  ) async {
    final repository = await pumpRecovery(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      'candidato1@dev.talentflash.test',
    );
    await tester.tap(find.text('Enviar instrucciones'));
    await tester.pumpAndSettle();

    expect(repository.calls, <String>['recover']);
    expect(find.text(neutralAnswer), findsOneWidget);
  });

  testWidgets('con una cuenta inexistente responde exactamente igual', (
    tester,
  ) async {
    final repository = await pumpRecovery(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      'no-existe-jamas@dev.talentflash.test',
    );
    await tester.tap(find.text('Enviar instrucciones'));
    await tester.pumpAndSettle();

    expect(repository.calls, <String>['recover']);
    expect(find.text(neutralAnswer), findsOneWidget);
    // Nada en pantalla insinúa si el correo estaba registrado.
    expect(find.textContaining('no existe'), findsNothing);
    expect(find.textContaining('no encontramos'), findsNothing);
  });

  testWidgets('el límite de envíos se explica sin revelar nada de la cuenta', (
    tester,
  ) async {
    final repository = FakeAuthRepository(
      initialStatus: const AuthStatusSignedOut(),
    )..nextFailure = const AuthFailure(AuthFailureCode.rateLimited);
    await pumpRecovery(tester, repository: repository);

    await tester.enterText(
      find.byType(TextFormField).first,
      'candidato1@dev.talentflash.test',
    );
    await tester.tap(find.text('Enviar instrucciones'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Hiciste muchos intentos seguidos. Esperá unos minutos y volvé a '
        'probar.',
      ),
      findsOneWidget,
    );
    expect(find.text(neutralAnswer), findsNothing);
  });

  testWidgets('vuelve al login', (tester) async {
    await pumpRecovery(tester);

    await tester.tap(find.text('Volver al inicio de sesión'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
