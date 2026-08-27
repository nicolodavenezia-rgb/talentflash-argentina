import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/core/routing/app_entry_point.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/presentation/login_screen.dart';
import 'package:talentflash_argentina/features/authentication/presentation/sign_up_screen.dart';
import 'package:talentflash_argentina/features/onboarding/presentation/welcome_screen.dart';

import 'support/fake_auth_repository.dart';
import 'support/pump_app.dart';

/// Recorrido público de entrada: bienvenida → alta o login.
void main() {
  Future<TalentFlashHarness> pumpWelcome(
    WidgetTester tester, {
    AppEntryPoint entryPoint = AppEntryPoint.chooser,
  }) async {
    final harness = await pumpTalentFlashApp(
      tester,
      authRepository: FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      ),
      entryPoint: entryPoint,
    );
    await tester.pumpAndSettle();
    return harness;
  }

  testWidgets('la bienvenida muestra los dos recorridos en es-AR', (
    tester,
  ) async {
    await pumpWelcome(tester);

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Bienvenido a TalentFlash'), findsOneWidget);
    expect(find.text('Soy candidato'), findsOneWidget);
    expect(find.text('Soy empresa'), findsOneWidget);
    expect(find.text('Ya tengo cuenta: iniciar sesión'), findsOneWidget);
  });

  testWidgets('elegir candidato abre su registro', (tester) async {
    await pumpWelcome(tester);

    await tester.tap(find.text('Soy candidato'));
    await tester.pumpAndSettle();

    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(find.text('Crear cuenta de candidato'), findsWidgets);
  });

  testWidgets('elegir empresa abre su registro', (tester) async {
    await pumpWelcome(tester);

    await tester.tap(find.text('Soy empresa'));
    await tester.pumpAndSettle();

    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(find.text('Crear cuenta de empresa'), findsWidgets);
  });

  testWidgets('quien ya tiene cuenta va al login', (tester) async {
    await pumpWelcome(tester);

    await tester.tap(find.text('Ya tengo cuenta: iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('los entrypoints por rol saltean la bienvenida', (tester) async {
    await pumpWelcome(tester, entryPoint: AppEntryPoint.candidate);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
    expect(
      find.text('Entrá para seguir tus postulaciones y descubrir ofertas.'),
      findsOneWidget,
    );
  });
}
