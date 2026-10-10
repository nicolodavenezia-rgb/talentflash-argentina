import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/providers/auth_providers.dart';
import 'package:talentflash_argentina/features/companies/providers/company_verification_providers.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_enums.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_input.dart';
import 'package:talentflash_argentina/features/jobs/providers/job_offer_editor_controller.dart';
import 'package:talentflash_argentina/features/jobs/providers/job_offers_providers.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_company_verification_repository.dart';
import '../../../support/fake_job_offers_repository.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeCompanyVerificationRepository verification;
  late FakeJobOffersRepository jobs;
  late ProviderContainer container;

  JobOfferEditorController editor() =>
      container.read(jobOfferEditorControllerProvider.notifier);

  AsyncValue<JobOfferEditorOutcome?> estado() =>
      container.read(jobOfferEditorControllerProvider);

  Matcher falloTipado(DataFailureCode code) =>
      isA<DataFailure>().having((f) => f.code, 'code', code);

  List<String> escrituras() => jobs.calls
      .where(
        (call) =>
            call.startsWith('createJob') ||
            call.startsWith('updateJob') ||
            call.startsWith('changeStatus'),
      )
      .toList();

  setUp(() {
    auth = FakeAuthRepository();
    addTearDown(auth.dispose);
    verification = FakeCompanyVerificationRepository();
    jobs = FakeJobOffersRepository();
    container = ProviderContainer.test(
      // Igual que el harness: sin el retry automático de Riverpod 3, los
      // errores de providers son finales y el test es determinista.
      retry: (retryCount, error) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        companyVerificationRepositoryProvider.overrideWithValue(verification),
        jobOffersRepositoryProvider.overrideWithValue(jobs),
        jobClockProvider.overrideWithValue(() => testJobNow),
      ],
    );
  });

  group('alta', () {
    test(
      'guardar borrador crea la oferta en MI empresa y la devuelve',
      () async {
        final saved = await editor().saveDraft(testJobOfferInput());

        expect(saved?.status, JobStatus.draft);
        expect(jobs.calls, contains('createJob:draft'));
        expect(jobs.lastCompanyId, testJobCompanyId);
        expect(jobs.lastPublish, isFalse);
        expect(estado().value, JobOfferEditorOutcome.draftSaved);
      },
    );

    test('publicar crea la oferta directamente activa', () async {
      final saved = await editor().publish(
        testJobOfferInput(),
        localityHasNeighborhoods: true,
      );

      expect(saved?.status, JobStatus.active);
      expect(jobs.calls, contains('createJob:active'));
      expect(estado().value, JobOfferEditorOutcome.published);
    });

    test(
      'después de guardar, la lista de la empresa se vuelve a pedir',
      () async {
        container.listen(companyJobsProvider, (_, _) {});
        await container.read(companyJobsProvider.future);

        await editor().saveDraft(testJobOfferInput());
        await container.read(companyJobsProvider.future);

        expect(
          jobs.calls.where((call) => call.startsWith('fetchCompanyJobs')),
          hasLength(2),
        );
        expect(container.read(companyJobsProvider).value, hasLength(1));
      },
    );

    test('un formulario incompleto no viaja al servidor', () async {
      final saved = await editor().saveDraft(const JobOfferInput());

      expect(saved, isNull);
      expect(escrituras(), isEmpty);
      expect(estado().error, falloTipado(DataFailureCode.invalidData));
    });

    test('sueldo 0 alcanza para un borrador pero no para publicar', () async {
      final input = testJobOfferInput(salaryMin: 0);

      expect(await editor().saveDraft(input), isNotNull);
      editor().reset();
      expect(await editor().publish(input), isNull);

      expect(jobs.calls.where((call) => call == 'createJob:active'), isEmpty);
      expect(estado().error, falloTipado(DataFailureCode.invalidData));
    });

    test('publicar fuera de la ventana de 60 días se frena antes', () async {
      final saved = await editor().publish(
        testJobOfferInput(expiresAt: testJobNow.add(const Duration(days: 61))),
      );

      expect(saved, isNull);
      expect(escrituras(), isEmpty);
    });

    test('D2: sin barrio en una localidad con barrios no se publica; si el '
        'catálogo no se sabe, decide el servidor', () async {
      final sinBarrio = testJobOfferInput(barrioId: null);

      expect(
        await editor().publish(sinBarrio, localityHasNeighborhoods: true),
        isNull,
      );
      expect(escrituras(), isEmpty);

      editor().reset();
      expect(await editor().publish(sinBarrio), isNotNull);
      expect(jobs.calls, contains('createJob:active'));
    });

    test(
      'sin empresa resuelta el error llega tipado y no se escribe',
      () async {
        verification.nextFetchFailure = const DataFailure(
          DataFailureCode.ambiguousCompany,
        );

        final saved = await editor().saveDraft(testJobOfferInput());

        expect(saved, isNull);
        expect(escrituras(), isEmpty);
        expect(estado().error, falloTipado(DataFailureCode.ambiguousCompany));
      },
    );

    test('el rechazo del servidor queda como DataFailure tipado', () async {
      jobs.nextCreateFailure = const DataFailure(
        DataFailureCode.notAllowed,
        debugDetail: 'postgrest:42501',
      );

      final saved = await editor().publish(testJobOfferInput());

      expect(saved, isNull);
      expect(estado().error, falloTipado(DataFailureCode.notAllowed));
    });

    test('un error crudo se envuelve igual en DataFailure', () async {
      jobs.nextCreateFailure = Exception('cualquier cosa');

      await editor().saveDraft(testJobOfferInput());

      expect(estado().error, isA<DataFailure>());
    });

    test('el doble tap no crea dos ofertas', () async {
      final gate = Completer<void>();
      jobs.pendingWrite = gate;

      final primera = editor().saveDraft(testJobOfferInput());
      final segunda = editor().saveDraft(testJobOfferInput());
      gate.complete();
      final resultados = await Future.wait([primera, segunda]);

      expect(jobs.calls.where((call) => call.startsWith('createJob')), [
        'createJob:draft',
      ]);
      expect(resultados.last, isNull, reason: 'el segundo tap se ignora');
    });

    test('reset limpia el resultado anterior', () async {
      await editor().saveDraft(const JobOfferInput());
      expect(estado().hasError, isTrue);

      editor().reset();

      expect(estado().hasError, isFalse);
      expect(estado().value, isNull);
    });
  });

  group('edición', () {
    test('guardar cambios de un borrador reescribe esa oferta', () async {
      final draft = testJobOffer(id: testJobId(5));
      jobs.jobs = [draft];

      final saved = await editor().saveChanges(
        draft,
        JobOfferInput.fromOffer(draft).copyWith(title: 'Bachero/a'),
      );

      expect(saved?.title, 'Bachero/a');
      expect(jobs.calls, contains('updateJob:${testJobId(5)}'));
      expect(estado().value, JobOfferEditorOutcome.changesSaved);
    });

    test('una activa vencida (cron pendiente) igual acepta cambiar el '
        'título: el vencimiento no se tocó', () async {
      final activa = testJobOffer(
        id: testJobId(6),
        status: JobStatus.active,
        expiresAt: testJobNow.subtract(const Duration(hours: 1)),
      );
      jobs.jobs = [activa];

      final saved = await editor().saveChanges(
        activa,
        JobOfferInput.fromOffer(activa).copyWith(title: 'Mozo/a de salón'),
      );

      expect(saved, isNotNull);
      expect(jobs.calls, contains('updateJob:${testJobId(6)}'));
    });

    test(
      'mover el vencimiento de una activa más allá de 60 días se frena',
      () async {
        final activa = testJobOffer(id: testJobId(6), status: JobStatus.active);
        jobs.jobs = [activa];

        final saved = await editor().saveChanges(
          activa,
          JobOfferInput.fromOffer(
            activa,
          ).copyWith(expiresAt: () => testJobNow.add(const Duration(days: 90))),
        );

        expect(saved, isNull);
        expect(escrituras(), isEmpty);
        expect(estado().error, falloTipado(DataFailureCode.invalidData));
      },
    );

    test('una pausada se edita con reglas de borrador', () async {
      final pausada = testJobOffer(id: testJobId(7), status: JobStatus.paused);
      jobs.jobs = [pausada];

      final saved = await editor().saveChanges(
        pausada,
        JobOfferInput.fromOffer(
          pausada,
        ).copyWith(expiresAt: () => testJobNow.add(const Duration(days: 200))),
      );

      expect(saved, isNotNull, reason: 'se vuelve a chequear al reanudar');
    });

    test('una cerrada no se edita y no se llama al servidor', () async {
      final cerrada = testJobOffer(id: testJobId(8), status: JobStatus.closed);
      jobs.jobs = [cerrada];

      final saved = await editor().saveChanges(
        cerrada,
        JobOfferInput.fromOffer(cerrada),
      );

      expect(saved, isNull);
      expect(escrituras(), isEmpty);
      expect(estado().error, falloTipado(DataFailureCode.jobStateConflict));
    });

    test(
      'publicar un borrador manda cambios y estado en una escritura',
      () async {
        final draft = testJobOffer(id: testJobId(9));
        jobs.jobs = [draft];

        final saved = await editor().publishDraft(
          draft,
          JobOfferInput.fromOffer(draft).copyWith(title: 'Cocinero/a'),
          localityHasNeighborhoods: true,
        );

        expect(saved?.status, JobStatus.active);
        expect(saved?.title, 'Cocinero/a');
        expect(escrituras(), ['updateJob:${testJobId(9)}:publish']);
        expect(estado().value, JobOfferEditorOutcome.published);
      },
    );

    test('si el servidor dice que la oferta cambió de estado (TFJOB), se '
        'recarga la lista y el detalle', () async {
      final draft = testJobOffer(id: testJobId(10));
      jobs.jobs = [draft];
      container.listen(companyJobsProvider, (_, _) {});
      await container.read(companyJobsProvider.future);
      jobs.nextUpdateFailure = const DataFailure(
        DataFailureCode.jobStateConflict,
      );

      await editor().saveChanges(draft, JobOfferInput.fromOffer(draft));
      await container.read(companyJobsProvider.future);

      expect(estado().error, falloTipado(DataFailureCode.jobStateConflict));
      expect(
        jobs.calls.where((call) => call.startsWith('fetchCompanyJobs')),
        hasLength(2),
      );
    });
  });
}
