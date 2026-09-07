import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/companies/data/company_access_repository.dart';
import 'package:talentflash_argentina/features/profiles/presentation/candidate_home_screen.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_profile_repositories.dart';
import '../../../support/gestures.dart';
import '../../../support/pump_app.dart';

/// Vista de candidato para empresa (T-024): whitelist estricta, fail-closed
/// indistinguible y estado explícito para la empresa pendiente.
void main() {
  const candidateId = '11111111-2222-4333-8444-555555555555';

  Future<TalentFlashHarness> pumpCompanyView(
    WidgetTester tester, {
    FakeProfileRepository? profileRepository,
    FakeCompanyAccessRepository? companyAccessRepository,
    String id = candidateId,
  }) async {
    final auth = FakeAuthRepository(initialStatus: const AuthStatusSignedOut());
    final harness = await pumpTalentFlashApp(
      tester,
      authRepository: auth,
      profileRepository: profileRepository,
      companyAccessRepository: companyAccessRepository,
    );
    await tester.pumpAndSettle();
    auth.emitSignedIn(BusinessRole.company);
    await tester.pumpAndSettle();
    harness.router.go('/empresa/candidatos/$id');
    await tester.pumpAndSettle();
    return harness;
  }

  /// Snapshot determinista del texto visible: la lista completa de strings
  /// renderizados, para poder afirmar qué está y qué NO está.
  List<String> visibleTexts(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? '')
      .where((value) => value.isNotEmpty)
      .toList();

  testWidgets('muestra la proyección pública y JAMÁS datos privados', (
    tester,
  ) async {
    final repository = FakeProfileRepository()
      ..publicProfile = testPublicProfile();
    await pumpCompanyView(tester, profileRepository: repository);

    final texts = visibleTexts(tester);
    final joined = texts.join('\n');

    // Whitelist visible: nombre de pila, titular, zona, sector, experiencia.
    expect(texts, contains('Ana'));
    expect(joined, contains('Moza de salón con experiencia'));
    expect(joined, contains('CABA'));
    expect(joined, contains('Gastronomía y hotelería'));
    expect(joined, contains('Parrilla de Prueba'));

    // Datos privados que NUNCA pueden aparecer en esta vista:
    expect(texts, isNot(contains('Ana María Prueba'))); // nombre completo
    expect(joined, isNot(contains('@'))); // ningún correo
    expect(joined, isNot(contains('ARS'))); // expectativa salarial
    expect(joined, isNot(contains('% completo'))); // score interno
    expect(joined.toLowerCase(), isNot(contains('nacimiento')));
    expect(repository.calls, contains('fetchPublic:$candidateId'));
  });

  testWidgets('candidato no disponible: mensaje genérico fail-closed', (
    tester,
  ) async {
    await pumpCompanyView(tester);

    expect(find.text('Candidato no disponible'), findsWidgets);
    expect(
      find.textContaining('Puede haber dejado de estar publicado'),
      findsOneWidget,
    );
  });

  testWidgets('empresa pendiente: estado explícito, no pantalla vacía', (
    tester,
  ) async {
    await pumpCompanyView(
      tester,
      companyAccessRepository: FakeCompanyAccessRepository(
        status: CompanyVerificationStatus.pending,
      ),
    );

    expect(find.text('Tu empresa está en verificación'), findsWidgets);
    expect(
      find.textContaining('no podés ver perfiles de candidatos'),
      findsOneWidget,
    );
  });

  testWidgets('empresa rechazada: estado propio, sin datos del candidato', (
    tester,
  ) async {
    await pumpCompanyView(
      tester,
      companyAccessRepository: FakeCompanyAccessRepository(
        status: CompanyVerificationStatus.rejected,
      ),
    );

    expect(
      find.text('La verificación de tu empresa fue rechazada'),
      findsWidgets,
    );
  });

  testWidgets(
    'cuenta en más de una empresa: se explica, no se esconde en el genérico',
    (tester) async {
      // `TFMUL` (0031): el servidor se niega a elegir una empresa. Es un
      // estado sin salida por la app, así que la pantalla tiene que decir cuál
      // es el problema en vez de mostrar el "no disponible" de siempre, que
      // invitaría a reintentar para siempre.
      await pumpCompanyView(
        tester,
        companyAccessRepository: FakeCompanyAccessRepository()
          ..nextFailure = const DataFailure(DataFailureCode.ambiguousCompany),
      );

      expect(
        find.textContaining('figura en más de una empresa'),
        findsOneWidget,
      );
      // Y no se filtra ningún dato del candidato ni el detalle de Postgres.
      expect(find.textContaining('postgrest'), findsNothing);
    },
  );

  testWidgets('cualquier otro fallo sigue cayendo en el mensaje genérico', (
    tester,
  ) async {
    await pumpCompanyView(
      tester,
      companyAccessRepository: FakeCompanyAccessRepository()
        ..nextFailure = const DataFailure(DataFailureCode.network),
    );

    expect(find.textContaining('figura en más de una empresa'), findsNothing);
    expect(find.text('Candidato no disponible'), findsWidgets);
    expect(
      find.textContaining('Puede haber dejado de estar publicado'),
      findsOneWidget,
    );
  });

  testWidgets('un id malformado ni siquiera llega al servidor', (tester) async {
    final repository = FakeProfileRepository()
      ..publicProfile = testPublicProfile();
    await pumpCompanyView(
      tester,
      profileRepository: repository,
      id: 'no-es-un-uuid',
    );

    expect(find.text('Candidato no disponible'), findsWidgets);
    expect(
      repository.calls.where((call) => call.startsWith('fetchPublic')),
      isEmpty,
    );
  });

  testWidgets('un corte de red ofrece reintentar', (tester) async {
    final repository = FakeProfileRepository()
      ..publicProfile = testPublicProfile()
      ..nextFailure = const DataFailure(DataFailureCode.network);
    await pumpCompanyView(tester, profileRepository: repository);

    expect(find.textContaining('No pudimos cargar el perfil'), findsOneWidget);
    await ensureAndTap(tester, find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('un candidato no alcanza la vista empresarial', (tester) async {
    final auth = FakeAuthRepository(initialStatus: const AuthStatusSignedOut());
    final harness = await pumpTalentFlashApp(tester, authRepository: auth);
    await tester.pumpAndSettle();
    auth.emitSignedIn(BusinessRole.candidate);
    await tester.pumpAndSettle();

    harness.router.go('/empresa/candidatos/$candidateId');
    await tester.pumpAndSettle();

    expect(harness.location, '/candidato');
    expect(find.byType(CandidateHomeScreen), findsOneWidget);
  });

  testWidgets('Volver regresa al inicio de la empresa', (tester) async {
    final harness = await pumpCompanyView(tester);

    await ensureAndTap(tester, find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(harness.location, '/empresa');
  });
}
