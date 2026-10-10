import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/authentication/providers/auth_providers.dart';
import 'package:talentflash_argentina/features/companies/data/company_access_repository.dart';
import 'package:talentflash_argentina/features/companies/domain/company_verification.dart';
import 'package:talentflash_argentina/features/companies/providers/company_verification_providers.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_enums.dart';
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

  /// Lee un provider autoDispose manteniéndolo escuchado: sin oyente, Riverpod
  /// puede descartarlo antes de que termine la carga.
  Future<T> mantener<T>(ProviderListenable<Future<T>> provider) =>
      container.listen(provider, (_, _) {}).read();

  setUp(() {
    auth = FakeAuthRepository();
    addTearDown(auth.dispose);
    verification = FakeCompanyVerificationRepository();
    jobs = FakeJobOffersRepository(
      jobs: [
        testJobOffer(id: testJobId(1)),
        testJobOffer(id: testJobId(2), status: JobStatus.active),
        // De otra empresa: nunca puede aparecer entre "mis ofertas".
        testJobOffer(
          id: testJobId(3),
          companyId: 'c0000000-0000-4000-8000-000000000002',
          status: JobStatus.active,
        ),
      ],
    );
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

  group('myCompanyIdProvider', () {
    test('sale de la verificación propia, resuelta por el servidor', () async {
      expect(
        await container.read(myCompanyIdProvider.future),
        testJobCompanyId,
      );
    });

    test('un company_id vacío falla cerrado', () async {
      verification.verification = const CompanyVerification(
        companyId: '',
        companyStatus: CompanyVerificationStatus.approved,
      );

      await expectLater(
        container.read(myCompanyIdProvider.future),
        throwsA(
          isA<DataFailure>().having(
            (f) => f.code,
            'code',
            DataFailureCode.notAllowed,
          ),
        ),
      );
    });
  });

  group('companyJobsProvider', () {
    test('lista solo las ofertas de MI empresa', () async {
      final list = await container.read(companyJobsProvider.future);

      expect(list.map((job) => job.id), [testJobId(1), testJobId(2)]);
      expect(jobs.calls, contains('fetchCompanyJobs:$testJobCompanyId'));
    });

    test('refresh conserva la lista si la recarga falla', () async {
      await container.read(companyJobsProvider.future);
      jobs.nextFetchFailure = const DataFailure(DataFailureCode.network);

      await container.read(companyJobsProvider.notifier).refresh();

      final state = container.read(companyJobsProvider);
      expect(state.hasError, isFalse);
      expect(state.value, hasLength(2));
    });

    test('refresh trae lo nuevo cuando la recarga anda', () async {
      await container.read(companyJobsProvider.future);
      jobs.jobs = [testJobOffer(id: testJobId(9))];

      await container.read(companyJobsProvider.notifier).refresh();

      expect(
        container.read(companyJobsProvider).value?.single.id,
        testJobId(9),
      );
    });

    test('si no se puede resolver la empresa, el error queda tipado', () async {
      verification.nextFetchFailure = const DataFailure(
        DataFailureCode.ambiguousCompany,
      );

      await expectLater(
        container.read(companyJobsProvider.future),
        throwsA(
          isA<DataFailure>().having(
            (f) => f.code,
            'code',
            DataFailureCode.ambiguousCompany,
          ),
        ),
      );
      expect(
        container.read(companyJobsProvider).error,
        isA<DataFailure>(),
        reason:
            'Riverpod 3 envuelve el error de la dependencia en '
            'ProviderException; la pantalla necesita el DataFailure',
      );
      expect(
        jobs.calls.where((call) => call.startsWith('fetchCompanyJobs')),
        isEmpty,
        reason: 'sin empresa no se pide ninguna lista',
      );
    });

    test('un cambio de sesión vuelve a pedir la lista (nada se arrastra de '
        'la cuenta anterior)', () async {
      container.listen(companyJobsProvider, (_, _) {});
      await container.read(companyJobsProvider.future);
      final antes = jobs.calls
          .where((call) => call.startsWith('fetchCompanyJobs'))
          .length;

      auth.emitSignedIn(BusinessRole.company);
      await Future<void>.delayed(Duration.zero);
      await container.read(companyJobsProvider.future);

      expect(
        jobs.calls.where((call) => call.startsWith('fetchCompanyJobs')).length,
        greaterThan(antes),
      );
    });
  });

  group('canWriteCompanyJobsProvider', () {
    test('pregunta por MI empresa', () async {
      expect(await mantener(canWriteCompanyJobsProvider.future), isTrue);
      expect(jobs.calls, contains('canWriteCompanyJobs:$testJobCompanyId'));
    });

    test('un viewer recibe false', () async {
      jobs.canWrite = false;

      expect(await mantener(canWriteCompanyJobsProvider.future), isFalse);
    });

    test('sin empresa resuelta el error llega tipado, no envuelto', () async {
      verification.nextFetchFailure = const DataFailure(
        DataFailureCode.network,
      );

      await expectLater(
        mantener(canWriteCompanyJobsProvider.future),
        throwsA(
          isA<DataFailure>().having(
            (f) => f.code,
            'code',
            DataFailureCode.network,
          ),
        ),
      );
    });
  });

  group('myCompanySummaryProvider', () {
    test('lee la fila de MI empresa', () async {
      final summary = await mantener(myCompanySummaryProvider.future);

      expect(summary, testJobCompany);
      expect(jobs.calls, contains('fetchCompanySummary:$testJobCompanyId'));
    });

    test('si la lectura falla, el error llega tipado (la vista previa sigue '
        'con un nombre provisorio)', () async {
      jobs.nextCompanySummaryFailure = const DataFailure(
        DataFailureCode.network,
      );

      await expectLater(
        mantener(myCompanySummaryProvider.future),
        throwsA(
          isA<DataFailure>().having(
            (f) => f.code,
            'code',
            DataFailureCode.network,
          ),
        ),
      );
    });
  });

  group('jobOfferProvider', () {
    test('devuelve la oferta pedida', () async {
      final offer = await mantener(jobOfferProvider(testJobId(2)).future);

      expect(offer?.status, JobStatus.active);
    });

    test('una oferta inexistente o no visible es null', () async {
      expect(await mantener(jobOfferProvider(testJobId(99)).future), isNull);
    });
  });
}
