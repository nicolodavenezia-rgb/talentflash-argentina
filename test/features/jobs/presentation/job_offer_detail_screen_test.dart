import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/companies/data/company_access_repository.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_enums.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

import '../../../support/fake_job_offers_repository.dart';
import '../../../support/gestures.dart';
import '../../../support/pump_app.dart';
import 'job_test_helpers.dart';

/// T-030, detalle de una oferta para el candidato (`/candidato/ofertas/:id`).
///
/// Qué puede leer el candidato lo decide RLS (pgTAP 019). La pantalla además
/// trata igual "no existe", "no está activa" y "venció": mismo mensaje.
void main() {
  String ruta(String id) => '/candidato/ofertas/$id';

  Future<TalentFlashHarness> entrar(
    WidgetTester tester,
    String id,
    FakeJobOffersRepository jobs,
  ) {
    return entrarA(tester, ruta(id), role: BusinessRole.candidate, jobs: jobs);
  }

  JobOffer activa({JobOfferCompany? company = testJobCompany}) =>
      testJobOffer(status: JobStatus.active, company: company);

  testWidgets('muestra todos los datos públicos de la oferta', (tester) async {
    final offer = activa();
    await entrar(tester, offer.id, FakeJobOffersRepository(jobs: [offer]));

    for (final texto in [
      'Mozo/a para salón',
      'Parrilla de Prueba',
      'Empresa verificada',
      'ARS 900.000 a 1.100.000 por mes',
      'Relación de dependencia',
      'Jornada parcial',
      'Jueves, Viernes, Sábado',
      '19 a 1 hs',
      'Presencial',
      'Palermo, Ciudad Autónoma de Buenos Aires',
      'Atención de mesas en turno noche, con buena onda.',
      'Hasta 1 año',
      'Inmediata',
      'Comida incluida',
      'Propinas',
      'Gastronomía y hotelería',
      '1 vacante',
    ]) {
      expect(find.text(texto), findsOneWidget, reason: texto);
    }
    // Honesto sobre lo que todavía no existe, y sin botones falsos.
    expect(
      find.textContaining('Todavía no podés postularte desde la app'),
      findsOneWidget,
    );
    expect(find.text('Postularme'), findsNothing);
    expect(find.textContaining('Compartir'), findsNothing);
  });

  testWidgets('se recorre por encabezados y anuncia el distintivo', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final offer = activa();
    await entrar(tester, offer.id, FakeJobOffersRepository(jobs: [offer]));

    expect(
      tester.getSemantics(find.text('Mozo/a para salón')),
      isSemantics(isHeader: true),
    );
    expect(
      tester.getSemantics(find.text('Sueldo')),
      isSemantics(isHeader: true),
    );
    expect(
      find.bySemanticsLabel(RegExp('Empresa verificada: verificamos su CUIT')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('sin empresa aprobada no hay distintivo', (tester) async {
    final offer = activa(
      company: const JobOfferCompany(
        name: 'Pendiente SA',
        verificationStatus: CompanyVerificationStatus.pending,
      ),
    );
    await entrar(tester, offer.id, FakeJobOffersRepository(jobs: [offer]));

    expect(find.text('Pendiente SA'), findsOneWidget);
    expect(find.text('Empresa verificada'), findsNothing);
  });

  testWidgets('si no existe, lo dice y vuelve al feed', (tester) async {
    final harness = await entrar(
      tester,
      testJobId(77),
      FakeJobOffersRepository(),
    );

    expect(find.text('Esta oferta no está disponible'), findsOneWidget);
    await ensureAndTap(tester, find.text('Volver a las ofertas'));
    expect(harness.location, '/candidato/feed');
  });

  testWidgets('un id malformado ni siquiera se pide', (tester) async {
    final jobs = FakeJobOffersRepository();
    await entrar(tester, 'no-es-un-uuid', jobs);

    expect(find.text('Esta oferta no está disponible'), findsOneWidget);
    expect(jobs.calls.where((call) => call.startsWith('fetchJob')), isEmpty);
  });

  testWidgets('pausada o con el vencimiento pasado: igual que inexistente', (
    tester,
  ) async {
    final pausada = testJobOffer(
      id: testJobId(2),
      status: JobStatus.paused,
      company: testJobCompany,
    );
    final vencida = testJobOffer(
      id: testJobId(3),
      status: JobStatus.active,
      expiresAt: testJobNow.subtract(const Duration(hours: 1)),
      company: testJobCompany,
    );
    final jobs = FakeJobOffersRepository(jobs: [pausada, vencida]);
    final harness = await entrar(tester, pausada.id, jobs);
    expect(find.text('Esta oferta no está disponible'), findsOneWidget);
    expect(find.text(pausada.title), findsNothing);

    harness.router.go(ruta(vencida.id));
    await tester.pumpAndSettle();
    expect(find.text('Esta oferta no está disponible'), findsOneWidget);
    expect(find.text(vencida.title), findsNothing);
  });

  testWidgets('un corte de red se puede reintentar', (tester) async {
    final offer = activa();
    final jobs = FakeJobOffersRepository(jobs: [offer])
      ..nextFetchJobFailure = const DataFailure(DataFailureCode.network);
    await entrar(tester, offer.id, jobs);

    expect(
      find.text('No pudimos cargar la oferta. Revisá tu conexión y reintentá.'),
      findsOneWidget,
    );
    await ensureAndTap(tester, find.text('Reintentar'));
    expect(find.text(offer.title), findsOneWidget);
  });
}
