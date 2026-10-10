import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/providers/auth_providers.dart';
import 'package:talentflash_argentina/features/companies/providers/company_verification_providers.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_enums.dart';
import 'package:talentflash_argentina/features/jobs/providers/job_offer_actions_controller.dart';
import 'package:talentflash_argentina/features/jobs/providers/job_offers_providers.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_company_verification_repository.dart';
import '../../../support/fake_job_offers_repository.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeJobOffersRepository jobs;
  late ProviderContainer container;

  final borrador = testJobOffer(id: testJobId(1));
  final activa = testJobOffer(id: testJobId(2), status: JobStatus.active);
  final pausada = testJobOffer(id: testJobId(3), status: JobStatus.paused);
  final vencida = testJobOffer(id: testJobId(4), status: JobStatus.expired);
  final cerrada = testJobOffer(id: testJobId(5), status: JobStatus.closed);

  JobOfferActionsController actions() =>
      container.read(jobOfferActionsControllerProvider.notifier);

  AsyncValue<JobOfferActionOutcome?> estado() =>
      container.read(jobOfferActionsControllerProvider);

  Matcher falloTipado(DataFailureCode code) =>
      isA<DataFailure>().having((f) => f.code, 'code', code);

  List<String> escrituras() => jobs.calls
      .where(
        (call) =>
            call.startsWith('changeStatus') || call.startsWith('discardDraft'),
      )
      .toList();

  JobStatus? estadoEnBase(String id) =>
      jobs.jobs.where((job) => job.id == id).singleOrNull?.status;

  setUp(() {
    auth = FakeAuthRepository();
    addTearDown(auth.dispose);
    jobs = FakeJobOffersRepository(
      jobs: [borrador, activa, pausada, vencida, cerrada],
    );
    container = ProviderContainer.test(
      // Igual que el harness: sin el retry automático de Riverpod 3, los
      // errores de providers son finales y el test es determinista.
      retry: (retryCount, error) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        companyVerificationRepositoryProvider.overrideWithValue(
          FakeCompanyVerificationRepository(),
        ),
        jobOffersRepositoryProvider.overrideWithValue(jobs),
        jobClockProvider.overrideWithValue(() => testJobNow),
      ],
    );
  });

  group('transiciones permitidas', () {
    test('publicar un borrador lo pasa a activa', () async {
      await actions().publish(borrador, localityHasNeighborhoods: true);

      expect(escrituras(), ['changeStatus:${testJobId(1)}:active']);
      expect(estadoEnBase(testJobId(1)), JobStatus.active);
      expect(estado().value, JobOfferActionOutcome.published);
    });

    test('pausar una activa', () async {
      await actions().pause(activa);

      expect(escrituras(), ['changeStatus:${testJobId(2)}:paused']);
      expect(estado().value, JobOfferActionOutcome.paused);
    });

    test('reanudar una pausada', () async {
      await actions().resume(pausada);

      expect(escrituras(), ['changeStatus:${testJobId(3)}:active']);
      expect(estado().value, JobOfferActionOutcome.resumed);
    });

    test('cerrar una activa, una pausada o una vencida', () async {
      for (final offer in [activa, pausada, vencida]) {
        actions().reset();
        await actions().close(offer);
        expect(estado().value, JobOfferActionOutcome.closed);
        expect(estadoEnBase(offer.id), JobStatus.closed);
      }
    });

    test('descartar un borrador usa la RPC de borrado lógico', () async {
      await actions().discard(borrador);

      expect(escrituras(), ['discardDraft:${testJobId(1)}']);
      expect(estadoEnBase(testJobId(1)), isNull);
      expect(estado().value, JobOfferActionOutcome.discarded);
    });

    test('tras el cambio se recarga la lista de la empresa', () async {
      container.listen(companyJobsProvider, (_, _) {});
      await container.read(companyJobsProvider.future);

      await actions().pause(activa);
      final lista = await container.read(companyJobsProvider.future);

      expect(
        jobs.calls.where((call) => call.startsWith('fetchCompanyJobs')),
        hasLength(2),
      );
      expect(
        lista.singleWhere((job) => job.id == testJobId(2)).status,
        JobStatus.paused,
      );
    });

    test('si esa recarga falla, la lista conserva lo que el servidor ya '
        'confirmó (estado nuevo o borrador descartado)', () async {
      container.listen(companyJobsProvider, (_, _) {});
      await container.read(companyJobsProvider.future);

      jobs.nextFetchFailure = const DataFailure(DataFailureCode.network);
      await actions().pause(activa);
      await pumpEventQueue();
      var lista = container.read(companyJobsProvider);
      expect(lista.hasError, isTrue, reason: 'la recarga falló');
      expect(estado().value, JobOfferActionOutcome.paused);
      expect(
        lista.requireValue.singleWhere((job) => job.id == testJobId(2)).status,
        JobStatus.paused,
      );

      actions().reset();
      jobs.nextFetchFailure = const DataFailure(DataFailureCode.network);
      await actions().discard(borrador);
      await pumpEventQueue();
      lista = container.read(companyJobsProvider);
      expect(lista.hasError, isTrue, reason: 'la recarga falló');
      expect(
        lista.requireValue.map((job) => job.id),
        isNot(contains(testJobId(1))),
      );
      expect(lista.requireValue, hasLength(4));
    });

    test('sin la lista en memoria, la acción no la carga para aplicarle el '
        'resultado', () async {
      await actions().pause(activa);

      expect(
        jobs.calls.where((call) => call.startsWith('fetchCompanyJobs')),
        isEmpty,
      );
    });
  });

  group('lo que el ciclo de vida no permite no sale a la red', () {
    final casos = <(String, JobOffer, Future<void> Function(JobOffer))>[
      ('descartar una activa', activa, (o) => actions().discard(o)),
      ('pausar un borrador', borrador, (o) => actions().pause(o)),
      ('cerrar un borrador', borrador, (o) => actions().close(o)),
      ('reanudar una activa', activa, (o) => actions().resume(o)),
      ('reanudar una vencida', vencida, (o) => actions().resume(o)),
      ('publicar una cerrada', cerrada, (o) => actions().publish(o)),
      ('cerrar una cerrada', cerrada, (o) => actions().close(o)),
    ];

    for (final (descripcion, offer, accion) in casos) {
      test(descripcion, () async {
        await accion(offer);

        expect(escrituras(), isEmpty);
        expect(estado().error, falloTipado(DataFailureCode.jobStateConflict));
      });
    }

    test('un estado desconocido no habilita nada (fail-closed)', () async {
      final rara = testJobOffer(id: testJobId(6), status: null);

      await actions().close(rara);

      expect(escrituras(), isEmpty);
      expect(estado().error, falloTipado(DataFailureCode.jobStateConflict));
    });
  });

  group('reglas de publicación antes de entrar a activa', () {
    test('un borrador con sueldo 0 no se publica', () async {
      await actions().publish(testJobOffer(id: testJobId(1), salaryMin: 0));

      expect(escrituras(), isEmpty);
      expect(estado().error, falloTipado(DataFailureCode.invalidData));
    });

    test('una pausada que venció mientras tanto no se reanuda', () async {
      await actions().resume(
        testJobOffer(
          id: testJobId(3),
          status: JobStatus.paused,
          expiresAt: testJobNow.subtract(const Duration(minutes: 1)),
        ),
      );

      expect(escrituras(), isEmpty);
      expect(estado().error, falloTipado(DataFailureCode.invalidData));
    });

    test(
      'D2 solo se adelanta si se sabe que la localidad tiene barrios',
      () async {
        final sinBarrio = testJobOffer(id: testJobId(1), barrioId: null);

        await actions().publish(sinBarrio, localityHasNeighborhoods: true);
        expect(escrituras(), isEmpty);

        actions().reset();
        await actions().publish(sinBarrio);
        expect(escrituras(), ['changeStatus:${testJobId(1)}:active']);
      },
    );

    test('pausar o cerrar no exige nada de eso', () async {
      final activaVencida = testJobOffer(
        id: testJobId(2),
        status: JobStatus.active,
        salaryMin: 0,
        expiresAt: testJobNow.subtract(const Duration(days: 1)),
      );

      await actions().close(activaVencida);

      expect(escrituras(), ['changeStatus:${testJobId(2)}:closed']);
    });
  });

  group('errores y doble tap', () {
    test('un TFJOB del servidor queda tipado y recarga la lista', () async {
      container.listen(companyJobsProvider, (_, _) {});
      await container.read(companyJobsProvider.future);
      jobs.nextStatusFailure = const DataFailure(
        DataFailureCode.jobStateConflict,
      );

      await actions().pause(activa);
      await container.read(companyJobsProvider.future);

      expect(estado().error, falloTipado(DataFailureCode.jobStateConflict));
      expect(
        jobs.calls.where((call) => call.startsWith('fetchCompanyJobs')),
        hasLength(2),
      );
    });

    test('publicar sin verificación (42501) es notAllowed', () async {
      jobs.nextStatusFailure = const DataFailure(
        DataFailureCode.notAllowed,
        debugDetail: 'postgrest:42501',
      );

      await actions().publish(borrador);

      expect(estado().error, falloTipado(DataFailureCode.notAllowed));
    });

    test('un error crudo se envuelve en DataFailure', () async {
      jobs.nextDiscardFailure = Exception('cualquier cosa');

      await actions().discard(borrador);

      expect(estado().error, isA<DataFailure>());
    });

    test('el doble tap no manda dos cambios de estado', () async {
      final gate = Completer<void>();
      jobs.pendingWrite = gate;

      final primera = actions().pause(activa);
      final segunda = actions().pause(activa);
      final otra = actions().close(pausada);
      gate.complete();
      await Future.wait([primera, segunda, otra]);

      expect(escrituras(), ['changeStatus:${testJobId(2)}:paused']);
    });

    test('reset limpia el resultado anterior', () async {
      await actions().discard(activa);
      expect(estado().hasError, isTrue);

      actions().reset();

      expect(estado().hasError, isFalse);
      expect(estado().value, isNull);
    });
  });
}
