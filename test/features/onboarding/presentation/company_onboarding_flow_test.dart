import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/companies/presentation/company_home_screen.dart';
import 'package:talentflash_argentina/features/onboarding/domain/company_onboarding_data.dart';
import 'package:talentflash_argentina/features/onboarding/presentation/company_onboarding_screen.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_onboarding_repositories.dart';
import '../../../support/gestures.dart';
import '../../../support/pump_app.dart';

/// Recorrido del wizard de empresa (T-017): los datos viajan en memoria y la
/// empresa nace atómica y en estado pendiente al final.
void main() {
  Future<({FakeAuthRepository auth, FakeOnboardingRepository onboarding})>
  startWizard(WidgetTester tester) async {
    final auth = FakeAuthRepository(initialStatus: const AuthStatusSignedOut());
    final onboarding = FakeOnboardingRepository(onboardingCompleted: false);
    await pumpTalentFlashApp(
      tester,
      authRepository: auth,
      onboardingRepository: onboarding,
    );
    await tester.pumpAndSettle();
    auth.emitSignedIn(BusinessRole.company);
    await tester.pumpAndSettle();
    expect(find.byType(CompanyOnboardingScreen), findsOneWidget);
    return (auth: auth, onboarding: onboarding);
  }

  testWidgets('el recorrido completo crea la empresa al final', (tester) async {
    final setup = await startWizard(tester);

    // Con los consentimientos ya vigentes arranca en los datos.
    expect(find.text('Paso 2 de 6'), findsOneWidget);

    // El CUIT se valida por formato antes de avanzar.
    await tester.enterText(find.byType(TextFormField).at(0), 'Gastro SA');
    await tester.enterText(find.byType(TextFormField).at(1), 'La Fantasía');
    await tester.enterText(find.byType(TextFormField).at(2), '123');
    await selectDropdownOption(
      tester,
      find.text('Sector o rubro'),
      'Gastronomía y hotelería',
    );
    await selectDropdownOption(
      tester,
      find.text('Tamaño de la empresa'),
      '11 a 50 personas',
    );
    await ensureAndTap(tester, find.text('Continuar'));
    expect(find.text('El CUIT debe tener 11 números.'), findsOneWidget);
    expect(find.text('Paso 2 de 6'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(2), '30 71234567 8');
    await ensureAndTap(tester, find.text('Continuar'));

    // Paso 3 — ubicación + web opcional.
    expect(find.text('Paso 3 de 6'), findsOneWidget);
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
    await tester.enterText(
      find.byType(TextFormField).last,
      'lafantasia.com.ar',
    );
    await ensureAndTap(tester, find.text('Continuar'));

    // Paso 4 — datos del solicitante.
    expect(find.text('Paso 4 de 6'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Dueña Prueba');
    await tester.enterText(find.byType(TextFormField).at(1), 'Dueña');
    await selectDropdownOption(
      tester,
      find.text('Tu relación con la empresa'),
      'Dueño/a',
    );
    await ensureAndTap(tester, find.text('Continuar'));

    // Paso 5 — avisos (defaults apagados).
    expect(find.text('Paso 5 de 6'), findsOneWidget);
    await ensureAndTap(tester, find.text('Continuar'));

    // Paso 6 — resumen: dice honesto que la empresa nace sin verificar, y
    // hasta acá NADA se creó.
    expect(find.text('Paso 6 de 6'), findsOneWidget);
    expect(find.textContaining('no verificada'), findsOneWidget);
    expect(
      setup.onboarding.calls,
      isNot(contains('completeCompanyOnboarding')),
    );

    await ensureAndTap(tester, find.text('Terminar'));

    expect(setup.onboarding.completeCompanyCalls, 1);
    final data = setup.onboarding.lastCompanyData!;
    expect(data.legalName, 'Gastro SA');
    expect(data.tradeName, 'La Fantasía');
    expect(data.cuit, '30-71234567-8');
    expect(data.sizeRange, CompanySizeRange.from11To50);
    expect(data.applicantRelationship, CompanyRelationship.owner);
    expect(data.website, 'https://lafantasia.com.ar');
    expect(find.byType(CompanyHomeScreen), findsOneWidget);
  });

  testWidgets(
    'un CUIT ya registrado muestra el error tipado y permite seguir',
    (tester) async {
      final setup = await startWizard(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'Gastro SA');
      await tester.enterText(find.byType(TextFormField).at(1), 'La Fantasía');
      await tester.enterText(find.byType(TextFormField).at(2), '30-70000001-1');
      await selectDropdownOption(
        tester,
        find.text('Sector o rubro'),
        'Gastronomía y hotelería',
      );
      await selectDropdownOption(
        tester,
        find.text('Tamaño de la empresa'),
        '1 a 10 personas',
      );
      await ensureAndTap(tester, find.text('Continuar'));
      await selectDropdownOption(
        tester,
        find.text('Provincia'),
        'Buenos Aires',
      );
      await selectDropdownOption(tester, find.text('Localidad'), 'La Plata');
      await ensureAndTap(tester, find.text('Continuar'));
      await tester.enterText(find.byType(TextFormField).at(0), 'Dueña Prueba');
      await tester.enterText(find.byType(TextFormField).at(1), 'Dueña');
      await selectDropdownOption(
        tester,
        find.text('Tu relación con la empresa'),
        'Dueño/a',
      );
      await ensureAndTap(tester, find.text('Continuar'));
      await ensureAndTap(tester, find.text('Continuar'));

      setup.onboarding.nextFailure = const DataFailure(
        DataFailureCode.duplicate,
      );
      await ensureAndTap(tester, find.text('Terminar'));

      expect(
        find.textContaining('Ese CUIT ya está registrado'),
        findsOneWidget,
      );
      expect(find.byType(CompanyOnboardingScreen), findsOneWidget);
      expect(find.byType(CompanyHomeScreen), findsNothing);
    },
  );
}
