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

/// T-028 / avance parcial de T-077: la cola `/admin/verificaciones`.
///
/// El guard de AAL2 que se prueba acá es VISUAL. El que decide de verdad es
/// `private.require_verification_reviewer()` en la migración 0028, y sus casos
/// —claim ausente, aal1, 'AAL2' con la caja equivocada, aal3, y AAL2 sin rol
/// admin— viven en `017_company_verification_test.sql`.
void main() {
  CompanyVerificationRequest solicitud({
    String requestId = 'req-1',
    String companyName = 'Parrilla Don Julio Dev',
    CompanyVerificationStatus status = CompanyVerificationStatus.pending,
    String? documentPath = 'c-1/constancia-arca.pdf',
    VerificationRejectionReason? reason,
  }) {
    return CompanyVerificationRequest(
      requestId: requestId,
      companyId: 'c-1',
      companyName: companyName,
      requestStatus: status,
      cuitSubmitted: '30-70000001-6',
      companyStatus: status,
      documentPath: documentPath,
      rejectionReason: reason,
    );
  }

  Future<TalentFlashHarness> entrarComoAdmin(
    WidgetTester tester, {
    required FakeCompanyVerificationRepository repository,
  }) async {
    final auth = FakeAuthRepository(initialStatus: const AuthStatusSignedOut());
    final harness = await pumpTalentFlashApp(
      tester,
      authRepository: auth,
      companyVerificationRepository: repository,
    );
    await tester.pumpAndSettle();
    auth.emitSignedIn(BusinessRole.admin);
    await tester.pumpAndSettle();
    harness.router.go('/admin/verificaciones');
    await tester.pumpAndSettle();
    return harness;
  }

  String textoVisible(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? '')
      .join('\n');

  testWidgets('sin segundo factor no se muestra ni un dato de la cola', (
    tester,
  ) async {
    final repository = FakeCompanyVerificationRepository(
      secondFactor: false,
      queue: [solicitud()],
    );
    await entrarComoAdmin(tester, repository: repository);

    expect(textoVisible(tester), contains('Necesitás segundo factor'));
    expect(
      textoVisible(tester),
      isNot(contains('Parrilla Don Julio Dev')),
      reason: 'sin AAL2 no se filtra el nombre de ninguna empresa',
    );
    expect(find.text('Aprobar'), findsNothing);
    expect(
      repository.calls.where((c) => c.startsWith('fetchVerificationQueue')),
      isEmpty,
      reason: 'ni siquiera se pide la cola',
    );
  });

  testWidgets('con segundo factor se lista la cola pendiente', (tester) async {
    final repository = FakeCompanyVerificationRepository(
      queue: [
        solicitud(),
        solicitud(requestId: 'req-2', companyName: 'Hotel Dev'),
      ],
    );
    await entrarComoAdmin(tester, repository: repository);

    expect(find.text('Parrilla Don Julio Dev'), findsOneWidget);
    expect(find.text('Hotel Dev'), findsOneWidget);
    expect(textoVisible(tester), contains('CUIT declarado: 30-70000001-6'));
    expect(repository.calls, contains('fetchVerificationQueue:pending'));
  });

  testWidgets('una cola vacía se explica en vez de quedar en blanco', (
    tester,
  ) async {
    await entrarComoAdmin(
      tester,
      repository: FakeCompanyVerificationRepository(),
    );
    expect(textoVisible(tester), contains('No hay solicitudes en este estado'));
  });

  testWidgets('cambiar el filtro vuelve a pedir la cola con ese estado', (
    tester,
  ) async {
    final repository = FakeCompanyVerificationRepository(
      queue: [
        solicitud(),
        solicitud(
          requestId: 'req-3',
          companyName: 'Aprobada Dev',
          status: CompanyVerificationStatus.approved,
        ),
      ],
    );
    await entrarComoAdmin(tester, repository: repository);
    expect(find.text('Aprobada Dev'), findsNothing);

    await ensureAndTap(tester, find.text('Aprobadas'));

    expect(repository.calls, contains('fetchVerificationQueue:approved'));
    expect(find.text('Aprobada Dev'), findsOneWidget);
    expect(find.text('Parrilla Don Julio Dev'), findsNothing);
  });

  testWidgets('una solicitud ya resuelta no ofrece botones de decisión', (
    tester,
  ) async {
    final repository = FakeCompanyVerificationRepository(
      queue: [
        solicitud(
          status: CompanyVerificationStatus.rejected,
          reason: VerificationRejectionReason.constanciaVencida,
        ),
      ],
    );
    await entrarComoAdmin(tester, repository: repository);
    await ensureAndTap(tester, find.text('Rechazadas'));

    expect(textoVisible(tester), contains('la constancia está vencida'));
    expect(
      find.text('Aprobar'),
      findsNothing,
      reason: 'ningún botón falso: la RPC rechazaría resolverla otra vez',
    );
    expect(find.text('Rechazar'), findsNothing);
  });

  testWidgets('aprobar manda la decisión y refresca la cola', (tester) async {
    final repository = FakeCompanyVerificationRepository(queue: [solicitud()]);
    await entrarComoAdmin(tester, repository: repository);

    await ensureAndTap(tester, find.text('Aprobar'));

    expect(repository.lastReviewedRequestId, 'req-1');
    expect(repository.lastApprove, isTrue);
    expect(repository.lastReason, isNull);
    expect(find.text('Solicitud resuelta.'), findsOneWidget);
    expect(
      repository.calls
          .where((c) => c.startsWith('fetchVerificationQueue'))
          .length,
      greaterThan(1),
      reason: 'tras resolver, la cola se vuelve a pedir',
    );
  });

  testWidgets('rechazar exige elegir un motivo de la lista cerrada', (
    tester,
  ) async {
    final repository = FakeCompanyVerificationRepository(queue: [solicitud()]);
    await entrarComoAdmin(tester, repository: repository);

    await ensureAndTap(tester, find.text('Rechazar'));

    // El diálogo ofrece exactamente los seis motivos que acepta la RPC.
    expect(find.text('¿Por qué se rechaza?'), findsOneWidget);
    expect(find.byType(SimpleDialogOption), findsNWidgets(6));
    expect(
      repository.calls,
      isNot(contains('reviewVerification')),
      reason: 'todavía no se decidió nada',
    );

    await tester.tap(find.text('la constancia no se lee bien.'));
    await tester.pumpAndSettle();

    expect(repository.lastApprove, isFalse);
    expect(
      repository.lastReason,
      VerificationRejectionReason.constanciaIlegible,
    );
  });

  testWidgets('cerrar el diálogo sin elegir motivo no rechaza nada', (
    tester,
  ) async {
    final repository = FakeCompanyVerificationRepository(queue: [solicitud()]);
    await entrarComoAdmin(tester, repository: repository);

    await ensureAndTap(tester, find.text('Rechazar'));
    // Tap fuera del diálogo: lo cierra sin resultado.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(repository.calls, isNot(contains('reviewVerification')));
  });

  testWidgets('si el servidor pide segundo factor se explica con copy propio', (
    tester,
  ) async {
    // El cliente creía tener AAL2 y el servidor dice que no: gana el servidor.
    final repository = FakeCompanyVerificationRepository(queue: [solicitud()])
      ..nextReviewFailure = const DataFailure(
        DataFailureCode.secondFactorRequired,
        debugDetail: 'postgrest:TFMFA',
      );
    await entrarComoAdmin(tester, repository: repository);

    await ensureAndTap(tester, find.text('Aprobar'));

    final texto = textoVisible(tester);
    expect(texto, contains('segundo factor'));
    expect(texto, isNot(contains('TFMFA')));
    expect(texto, isNot(contains('postgrest')));
  });

  testWidgets('un rechazo por permisos se explica sin filtrar el detalle', (
    tester,
  ) async {
    final repository = FakeCompanyVerificationRepository(queue: [solicitud()])
      ..nextReviewFailure = const DataFailure(
        DataFailureCode.notAllowed,
        debugDetail: 'postgrest:42501',
      );
    await entrarComoAdmin(tester, repository: repository);

    await ensureAndTap(tester, find.text('Aprobar'));

    final texto = textoVisible(tester);
    expect(texto, contains('Tu cuenta no puede hacer esta acción'));
    expect(texto, isNot(contains('42501')));
  });

  testWidgets('si la cola falla se explica y no se inventan solicitudes', (
    tester,
  ) async {
    final repository = FakeCompanyVerificationRepository(queue: [solicitud()])
      ..nextQueueFailure = const DataFailure(DataFailureCode.network);
    await entrarComoAdmin(tester, repository: repository);

    expect(textoVisible(tester), contains('No pudimos conectarnos'));
    expect(find.text('Parrilla Don Julio Dev'), findsNothing);
    expect(find.text('Aprobar'), findsNothing);
  });
}
