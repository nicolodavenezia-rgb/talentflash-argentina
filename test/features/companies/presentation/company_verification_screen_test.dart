import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/companies/data/company_access_repository.dart';
import 'package:talentflash_argentina/features/companies/domain/company_verification.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_company_verification_repository.dart';
import '../../../support/gestures.dart';
import '../../../support/pump_app.dart';

/// T-028, lado empresa: enviar la constancia y consultar el estado.
///
/// Todos los guards que se ven acá son UX. Lo que decide de verdad quién puede
/// solicitar está en la RPC `request_company_verification` y se prueba en
/// `supabase/tests/database/017_company_verification_test.sql`.
void main() {
  CompanyVerification verificacion({
    CompanyVerificationStatus? companyStatus =
        CompanyVerificationStatus.pending,
    CompanyVerificationStatus? requestStatus,
    VerificationRejectionReason? reason,
    String? documentPath,
  }) {
    return CompanyVerification(
      companyId: 'c-1',
      companyStatus: companyStatus,
      requestId: requestStatus == null ? null : 'req-1',
      requestStatus: requestStatus,
      rejectionReason: reason,
      documentPath: documentPath,
    );
  }

  Future<TalentFlashHarness> entrar(
    WidgetTester tester, {
    required FakeCompanyVerificationRepository repository,
    FakeConstanciaPicker? picker,
  }) async {
    final auth = FakeAuthRepository(initialStatus: const AuthStatusSignedOut());
    final harness = await pumpTalentFlashApp(
      tester,
      authRepository: auth,
      companyVerificationRepository: repository,
      constanciaPicker: picker,
    );
    await tester.pumpAndSettle();
    auth.emitSignedIn(BusinessRole.company);
    await tester.pumpAndSettle();
    harness.router.go('/empresa/verificacion');
    await tester.pumpAndSettle();
    return harness;
  }

  String textoVisible(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? '')
      .join('\n');

  testWidgets('estado pendiente: explica y ofrece el formulario', (
    tester,
  ) async {
    final repository = FakeCompanyVerificationRepository(
      verification: verificacion(),
    );
    await entrar(tester, repository: repository);

    expect(textoVisible(tester), contains('todavía no está verificada'));
    expect(find.text('Enviar solicitud'), findsOneWidget);
    expect(find.text('Adjuntar constancia de ARCA'), findsOneWidget);
    expect(repository.calls, contains('fetchMyVerification'));
  });

  testWidgets('con una solicitud abierta no se ofrece reenviar', (
    tester,
  ) async {
    await entrar(
      tester,
      repository: FakeCompanyVerificationRepository(
        verification: verificacion(
          requestStatus: CompanyVerificationStatus.pending,
        ),
      ),
    );

    expect(textoVisible(tester), contains('Estamos revisando tu solicitud'));
    expect(
      find.text('Enviar solicitud'),
      findsNothing,
      reason: 'ningún botón falso: reenviar acá lo rechazaría el servidor',
    );
  });

  testWidgets('estado aprobado: muestra el distintivo y no ofrece reenviar', (
    tester,
  ) async {
    await entrar(
      tester,
      repository: FakeCompanyVerificationRepository(
        verification: verificacion(
          companyStatus: CompanyVerificationStatus.approved,
          requestStatus: CompanyVerificationStatus.approved,
        ),
      ),
    );

    expect(textoVisible(tester), contains('Tu empresa está verificada'));
    expect(find.text('Empresa verificada'), findsOneWidget);
    expect(find.text('Enviar solicitud'), findsNothing);
  });

  testWidgets('estado rechazado: muestra el motivo y deja reintentar', (
    tester,
  ) async {
    await entrar(
      tester,
      repository: FakeCompanyVerificationRepository(
        verification: verificacion(
          companyStatus: CompanyVerificationStatus.rejected,
          requestStatus: CompanyVerificationStatus.rejected,
          reason: VerificationRejectionReason.constanciaIlegible,
        ),
      ),
    );

    final texto = textoVisible(tester);
    expect(texto, contains('La verificación fue rechazada'));
    expect(texto, contains('la constancia no se lee bien'));
    expect(find.text('Enviar solicitud'), findsOneWidget);
    expect(find.text('Empresa verificada'), findsNothing);
  });

  testWidgets('un estado desconocido no se muestra como verificada', (
    tester,
  ) async {
    await entrar(
      tester,
      repository: FakeCompanyVerificationRepository(
        verification: verificacion(companyStatus: null),
      ),
    );

    expect(find.text('Empresa verificada'), findsNothing);
    expect(textoVisible(tester), contains('todavía no está verificada'));
  });

  testWidgets('un CUIT con el dígito verificador mal no llega al servidor', (
    tester,
  ) async {
    final repository = FakeCompanyVerificationRepository(
      verification: verificacion(),
    );
    await entrar(tester, repository: repository);

    await tester.enterText(find.byType(TextFormField), '30-70000001-7');
    await ensureAndTap(tester, find.text('Enviar solicitud'));

    expect(
      repository.calls,
      isNot(contains('requestVerification')),
      reason: 'la validación local ahorra el viaje; el servidor igual valida',
    );
    expect(
      textoVisible(tester),
      contains('el último número no se corresponde'),
    );
  });

  testWidgets('un CUIT válido se envía y se avisa', (tester) async {
    final repository = FakeCompanyVerificationRepository(
      verification: verificacion(),
    );
    await entrar(tester, repository: repository);

    await tester.enterText(find.byType(TextFormField), '30-70000001-6');
    await ensureAndTap(tester, find.text('Enviar solicitud'));

    expect(repository.calls, contains('requestVerification'));
    expect(repository.lastCuit, '30-70000001-6');
    expect(
      repository.lastFormat,
      isNull,
      reason: 'sin adjuntar nada, no se declara formato',
    );
    expect(
      find.text('Recibimos tu solicitud. Te avisamos apenas la revisemos.'),
      findsOneWidget,
    );
  });

  testWidgets('adjuntar la constancia la sube y declara su formato al enviar', (
    tester,
  ) async {
    final repository = FakeCompanyVerificationRepository(
      verification: verificacion(),
    );
    final picker = FakeConstanciaPicker()
      ..next = PickedConstancia(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        fileName: 'constancia.PDF',
      );
    await entrar(tester, repository: repository, picker: picker);

    await ensureAndTap(tester, find.text('Adjuntar constancia de ARCA'));
    expect(picker.pickCount, 1);
    expect(repository.calls, contains('uploadConstancia:constancia.PDF'));
    expect(textoVisible(tester), contains('Constancia adjuntada (pdf)'));

    await tester.enterText(find.byType(TextFormField), '30-70000001-6');
    await ensureAndTap(tester, find.text('Enviar solicitud'));

    expect(repository.lastFormat, ConstanciaFormat.pdf);
  });

  testWidgets('cancelar el selector no sube nada ni rompe la pantalla', (
    tester,
  ) async {
    final repository = FakeCompanyVerificationRepository(
      verification: verificacion(),
    );
    final picker = FakeConstanciaPicker();
    await entrar(tester, repository: repository, picker: picker);

    await ensureAndTap(tester, find.text('Adjuntar constancia de ARCA'));

    expect(picker.pickCount, 1);
    expect(
      repository.calls.where((call) => call.startsWith('uploadConstancia')),
      isEmpty,
    );
    expect(find.text('Enviar solicitud'), findsOneWidget);
  });

  testWidgets('un archivo que no es PDF ni imagen se rechaza sin subir', (
    tester,
  ) async {
    final repository = FakeCompanyVerificationRepository(
      verification: verificacion(),
    );
    final picker = FakeConstanciaPicker()
      ..next = PickedConstancia(
        bytes: Uint8List.fromList(<int>[1]),
        fileName: 'virus.exe',
      );
    await entrar(tester, repository: repository, picker: picker);

    await ensureAndTap(tester, find.text('Adjuntar constancia de ARCA'));

    expect(
      repository.calls.where((call) => call.startsWith('uploadConstancia')),
      isEmpty,
    );
    expect(textoVisible(tester), contains('datos incompletos o inválidos'));
  });

  testWidgets(
    'un rechazo del servidor se muestra con copy propio, sin detalle interno',
    (tester) async {
      final repository =
          FakeCompanyVerificationRepository(verification: verificacion())
            ..nextRequestFailure = const DataFailure(
              DataFailureCode.notAllowed,
              debugDetail: 'postgrest:42501',
            );
      await entrar(tester, repository: repository);

      await tester.enterText(find.byType(TextFormField), '30-70000001-6');
      await ensureAndTap(tester, find.text('Enviar solicitud'));

      final texto = textoVisible(tester);
      expect(texto, contains('Solo quien creó la empresa'));
      expect(texto, isNot(contains('postgrest')));
      expect(texto, isNot(contains('42501')));
    },
  );

  testWidgets(
    'si el CUIT no pasa server-side se explica como dato de formulario',
    (tester) async {
      final repository = FakeCompanyVerificationRepository(
        verification: verificacion(),
      )..nextRequestFailure = const DataFailure(DataFailureCode.invalidCuit);
      await entrar(tester, repository: repository);

      await tester.enterText(find.byType(TextFormField), '30-70000001-6');
      await ensureAndTap(tester, find.text('Enviar solicitud'));

      expect(textoVisible(tester), contains('revisá el dígito verificador'));
    },
  );

  testWidgets('el estado NO sobrevive a un cambio de sesión', (tester) async {
    // Regresión: el provider no es autoDispose y vive en el único ProviderScope
    // del proceso. Sin depender del estado de sesión, la cuenta siguiente veía
    // el estado de verificación de la anterior — incluido un "Empresa
    // verificada" que no le correspondía.
    final repository = FakeCompanyVerificationRepository(
      verification: verificacion(
        companyStatus: CompanyVerificationStatus.approved,
        requestStatus: CompanyVerificationStatus.approved,
      ),
    );
    final auth = FakeAuthRepository(initialStatus: const AuthStatusSignedOut());
    final harness = await pumpTalentFlashApp(
      tester,
      authRepository: auth,
      companyVerificationRepository: repository,
    );
    await tester.pumpAndSettle();
    auth.emitSignedIn(BusinessRole.company);
    await tester.pumpAndSettle();
    harness.router.go('/empresa/verificacion');
    await tester.pumpAndSettle();
    expect(find.text('Empresa verificada'), findsOneWidget);

    // Cierra sesión y entra otra empresa, esta vez sin verificar.
    repository.verification = verificacion();
    auth.emit(const AuthStatusSignedOut());
    await tester.pumpAndSettle();
    auth.emitSignedIn(BusinessRole.company);
    await tester.pumpAndSettle();
    harness.router.go('/empresa/verificacion');
    await tester.pumpAndSettle();

    expect(
      find.text('Empresa verificada'),
      findsNothing,
      reason: 'la cuenta nueva no puede heredar el estado de la anterior',
    );
    expect(textoVisible(tester), contains('todavía no está verificada'));
    expect(
      repository.calls.where((c) => c == 'fetchMyVerification').length,
      greaterThan(1),
      reason: 'el cambio de sesión tiene que forzar una relectura',
    );
  });

  testWidgets('si falla la carga del estado se explica y no se inventa nada', (
    tester,
  ) async {
    final repository = FakeCompanyVerificationRepository()
      ..nextFetchFailure = const DataFailure(DataFailureCode.network);
    await entrar(tester, repository: repository);

    expect(textoVisible(tester), contains('No pudimos conectarnos'));
    expect(find.text('Enviar solicitud'), findsNothing);
    expect(find.text('Empresa verificada'), findsNothing);
  });
}
