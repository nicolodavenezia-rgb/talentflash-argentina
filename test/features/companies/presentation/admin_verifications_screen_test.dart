import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/authentication/domain/session_assurance.dart';
import 'package:talentflash_argentina/features/authentication/presentation/second_factor_screen.dart';
import 'package:talentflash_argentina/features/authentication/providers/auth_providers.dart';
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
/// admin— viven en `017_company_verification_test.sql`. El flujo de alta y
/// verificación TOTP se prueba en `second_factor_screen_test.dart`.
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
    SessionAssurance assurance = SessionAssurance.aal2,
  }) async {
    final auth = FakeAuthRepository(initialStatus: const AuthStatusSignedOut());
    final harness = await pumpTalentFlashApp(
      tester,
      authRepository: auth,
      companyVerificationRepository: repository,
    );
    await tester.pumpAndSettle();
    auth.emitSignedIn(BusinessRole.admin, assurance: assurance);
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
    final repository = FakeCompanyVerificationRepository(queue: [solicitud()]);
    await entrarComoAdmin(
      tester,
      repository: repository,
      assurance: SessionAssurance.aal1,
    );

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

  testWidgets('un claim aal ilegible vale lo mismo que no tener AAL2', (
    tester,
  ) async {
    final repository = FakeCompanyVerificationRepository(queue: [solicitud()]);
    await entrarComoAdmin(
      tester,
      repository: repository,
      assurance: SessionAssurance.unknown,
    );

    expect(textoVisible(tester), contains('Necesitás segundo factor'));
    expect(find.text('Aprobar'), findsNothing);
  });

  testWidgets(
    'sin AAL2 hay una acción para configurar o verificar el factor sin '
    'cerrar sesión',
    (tester) async {
      final repository = FakeCompanyVerificationRepository(
        queue: [solicitud()],
      );
      final harness = await entrarComoAdmin(
        tester,
        repository: repository,
        assurance: SessionAssurance.aal1,
      );

      await ensureAndTap(tester, find.text('Verificar segundo factor'));

      expect(harness.location, '/admin/segundo-factor');
      expect(find.byType(SecondFactorScreen), findsOneWidget);
      expect(
        harness.authRepository.calls,
        isNot(contains('signOut')),
        reason: 'la acción no cierra la sesión',
      );
    },
  );

  testWidgets(
    'al verificar el factor la cola aparece sola, con el mismo usuario',
    (tester) async {
      final repository = FakeCompanyVerificationRepository(
        queue: [solicitud()],
      );
      final harness = await entrarComoAdmin(
        tester,
        repository: repository,
        assurance: SessionAssurance.aal1,
      );
      expect(find.text('Parrilla Don Julio Dev'), findsNothing);
      // Identidad según la APP (provider), no según el fake.
      final antes = harness.container.read(currentAuthUserProvider);
      expect(antes, isNotNull);

      // Lo que emite el SDK tras `mfaChallengeVerified`: misma cuenta, token
      // nuevo con aal2. Ningún reinicio ni cambio de usuario.
      harness.authRepository.emitSignedIn(
        BusinessRole.admin,
        assurance: SessionAssurance.aal2,
      );
      await tester.pumpAndSettle();

      expect(harness.container.read(currentAuthUserProvider), antes);
      expect(
        harness.container.read(sessionAssuranceProvider),
        SessionAssurance.aal2,
      );
      expect(harness.location, '/admin/verificaciones');
      expect(find.text('Parrilla Don Julio Dev'), findsOneWidget);
      expect(repository.calls, contains('fetchVerificationQueue:pending'));
    },
  );

  testWidgets('cerrar sesión descarta la cola y un nuevo login vuelve a pedir '
      'el factor', (tester) async {
    final repository = FakeCompanyVerificationRepository(queue: [solicitud()]);
    final harness = await entrarComoAdmin(tester, repository: repository);
    expect(find.text('Parrilla Don Julio Dev'), findsOneWidget);

    harness.authRepository.emit(const AuthStatusSignedOut());
    await tester.pumpAndSettle();
    expect(find.text('Parrilla Don Julio Dev'), findsNothing);

    // Nuevo inicio de sesión de la misma cuenta: la sesión nueva es aal1
    // aunque la cuenta tenga un factor verificado.
    harness.authRepository.emitSignedIn(BusinessRole.admin);
    await tester.pumpAndSettle();
    harness.router.go('/admin/verificaciones');
    await tester.pumpAndSettle();

    expect(textoVisible(tester), contains('Necesitás segundo factor'));
    expect(find.text('Parrilla Don Julio Dev'), findsNothing);
  });

  testWidgets(
    'una respuesta tardía de la cuenta anterior no se muestra a la siguiente',
    (tester) async {
      final repository = FakeCompanyVerificationRepository(
        queue: [solicitud(companyName: 'Empresa de la cuenta A')],
      );
      // La primera lectura queda colgada hasta que el test la libere.
      final gate = Completer<void>();
      repository.pendingQueueFetch = gate;
      final auth = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      final harness = await pumpTalentFlashApp(
        tester,
        authRepository: auth,
        companyVerificationRepository: repository,
      );
      await tester.pumpAndSettle();
      auth.emitSignedIn(BusinessRole.admin, assurance: SessionAssurance.aal2);
      await tester.pumpAndSettle();
      harness.router.go('/admin/verificaciones');
      // Sin pumpAndSettle: el indicador de carga anima mientras la lectura
      // sigue en vuelo.
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        repository.calls.where((c) => c.startsWith('fetchVerificationQueue')),
        hasLength(1),
      );

      // Cambio de cuenta con la lectura todavía en vuelo.
      auth.emit(const AuthStatusSignedOut());
      await tester.pumpAndSettle();
      repository.pendingQueueFetch = null;
      repository.queue = [solicitud(companyName: 'Empresa de la cuenta B')];
      auth.emitSignedIn(
        BusinessRole.admin,
        id: 'user-admin-b',
        assurance: SessionAssurance.aal2,
      );
      await tester.pumpAndSettle();
      harness.router.go('/admin/verificaciones');
      await tester.pumpAndSettle();
      expect(find.text('Empresa de la cuenta B'), findsOneWidget);

      // Recién ahora responde la lectura de la cuenta A.
      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Empresa de la cuenta A'), findsNothing);
      expect(find.text('Empresa de la cuenta B'), findsOneWidget);
    },
  );

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

  testWidgets('ver la constancia pide una URL firmada de vida corta', (
    tester,
  ) async {
    final repository = FakeCompanyVerificationRepository(queue: [solicitud()]);
    await entrarComoAdmin(tester, repository: repository);

    await ensureAndTap(tester, find.text('Ver la constancia'));

    expect(
      repository.calls,
      contains('createConstanciaSignedUrl:c-1/constancia-arca.pdf'),
      reason: 'el enlace se pide al servidor, no se arma en el cliente',
    );
    expect(
      find.text('https://storage.local/firmada/c-1/constancia-arca.pdf'),
      findsOneWidget,
    );
    expect(textoVisible(tester), contains('Vence en 5 minutos'));
  });

  testWidgets('sin constancia adjunta no se ofrece verla', (tester) async {
    final repository = FakeCompanyVerificationRepository(
      queue: [solicitud(documentPath: null)],
    );
    await entrarComoAdmin(tester, repository: repository);

    expect(textoVisible(tester), contains('Sin constancia adjunta'));
    expect(
      find.text('Ver la constancia'),
      findsNothing,
      reason: 'ningún botón falso: no hay nada que abrir',
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
