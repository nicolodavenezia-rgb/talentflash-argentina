import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/app.dart';
import 'package:talentflash_argentina/core/config/env_config.dart';

void main() {
  const testConfig = EnvConfig(
    environment: AppEnvironment.dev,
    supabaseUrl: 'http://127.0.0.1:54321',
    supabaseAnonKey: 'test-anon-key',
    sentryDsn: '',
  );

  Widget buildApp() => ProviderScope(
    overrides: [envConfigProvider.overrideWithValue(testConfig)],
    child: const TalentFlashApp(),
  );

  testWidgets('la bienvenida muestra los dos puntos de entrada en es-AR', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido a TalentFlash'), findsOneWidget);
    expect(find.text('Soy candidato'), findsOneWidget);
    expect(find.text('Soy empresa'), findsOneWidget);
  });

  testWidgets('elegir candidato navega a su punto de entrada', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Soy candidato'));
    await tester.pumpAndSettle();

    expect(find.text('Inicio — Candidato'), findsOneWidget);
  });

  testWidgets('elegir empresa navega a su punto de entrada', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Soy empresa'));
    await tester.pumpAndSettle();

    expect(find.text('Inicio — Empresa'), findsOneWidget);
  });
}
