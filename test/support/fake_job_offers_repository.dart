import 'dart:async';

import 'package:talentflash_argentina/features/companies/data/company_access_repository.dart';
import 'package:talentflash_argentina/features/jobs/data/job_offers_repository.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_feed_page.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_enums.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_input.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_lifecycle.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

import 'fake_onboarding_repositories.dart';

/// Empresa de los fakes: la misma que devuelve por defecto
/// `FakeCompanyVerificationRepository`.
const testJobCompanyId = 'c0000000-0000-4000-8000-000000000001';

/// "Ahora" fijo de los tests de ofertas (se inyecta con `jobClockProvider`).
final testJobNow = DateTime.utc(2026, 10, 10, 12);

/// Id de oferta de prueba con forma de UUID (namespace `95…` de T-030).
String testJobId(int n) =>
    '95000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

/// Formulario completo y válido para publicar con [testJobNow]: CABA con
/// barrio, sueldo positivo y vencimiento dentro de la ventana de 60 días.
JobOfferInput testJobOfferInput({
  String title = 'Mozo/a para salón',
  num? salaryMin = 900000,
  num? salaryMax = 1100000,
  String? barrioId = FakeCatalogRepository.palermoId,
  DateTime? expiresAt,
}) {
  return JobOfferInput(
    title: title,
    description: 'Atención de mesas en turno noche, con buena onda.',
    sectorId: FakeCatalogRepository.gastronomiaSectorId,
    salaryMin: salaryMin,
    salaryMax: salaryMax,
    contractType: ContractType.relacionDependencia,
    jornada: JornadaType.partTime,
    scheduleDays: const [WeekDay.jue, WeekDay.vie, WeekDay.sab],
    scheduleDetail: '19 a 1 hs',
    workMode: JobWorkMode.presencial,
    provinciaId: FakeCatalogRepository.cabaProvinceId,
    localidadId: FakeCatalogRepository.cabaLocalityId,
    barrioId: barrioId,
    experience: ExperienceLevel.hasta1Anio,
    availability: JobAvailability.inmediata,
    benefits: const ['Comida incluida', 'Propinas'],
    expiresAt: expiresAt ?? testJobNow.add(const Duration(days: 30)),
  );
}

/// Oferta de prueba con el contenido de [testJobOfferInput].
JobOffer testJobOffer({
  String? id,
  String companyId = testJobCompanyId,
  JobStatus? status = JobStatus.draft,
  String title = 'Mozo/a para salón',
  num salaryMin = 900000,
  String? barrioId = FakeCatalogRepository.palermoId,
  DateTime? expiresAt,
  DateTime? publishedAt,
  JobOfferCompany? company,
}) {
  final input = testJobOfferInput(
    title: title,
    salaryMin: salaryMin,
    barrioId: barrioId,
    expiresAt: expiresAt,
  );
  return _offerFrom(
    id: id ?? testJobId(1),
    companyId: companyId,
    input: input,
    status: status,
    publishedAt:
        publishedAt ??
        (status == JobStatus.draft ? null : DateTime.utc(2026, 10, 1, 12)),
    company: company,
  );
}

/// Empresa embebida como la ve un candidato.
const testJobCompany = JobOfferCompany(
  name: 'Parrilla de Prueba',
  verificationStatus: CompanyVerificationStatus.approved,
);

JobOffer _offerFrom({
  required String id,
  required String companyId,
  required JobOfferInput input,
  required JobStatus? status,
  DateTime? publishedAt,
  DateTime? closedAt,
  JobOfferCompany? company,
}) {
  return JobOffer(
    id: id,
    companyId: companyId,
    title: input.title.trim(),
    description: input.description.trim(),
    sectorId: input.sectorId,
    salaryMin: input.salaryMin ?? 0,
    salaryMax: input.salaryMax ?? 0,
    salaryPeriod: input.salaryPeriod,
    contractType: input.contractType,
    jornada: input.jornada,
    scheduleDays: input.scheduleDays,
    scheduleDetail: input.scheduleDetail.trim(),
    workMode: input.workMode,
    provinciaId: input.provinciaId ?? '',
    localidadId: input.localidadId ?? '',
    barrioId: input.barrioId,
    experience: input.experience,
    availability: input.availability,
    benefits: input.benefits,
    expiresAt: input.expiresAt,
    vacancies: input.vacancies ?? 1,
    status: status,
    publishedAt: publishedAt,
    closedAt: closedAt,
    createdAt: DateTime.utc(2026, 10, 1, 9),
    updatedAt: DateTime.utc(2026, 10, 1, 9),
    company: company,
  );
}

/// Doble del repositorio de ofertas. Escrito a mano, como el resto de los
/// fakes del proyecto: no hay mocktail ni mockito en el pubspec.
///
/// Guarda las ofertas en memoria y aplica el mismo ciclo de vida que el
/// servidor (una transición prohibida falla con `jobStateConflict`), así los
/// tests de pantalla ven lo mismo que verían contra la base. Registra cada
/// llamada en [calls] para afirmar QUÉ se pidió, y los `next*Failure` simulan
/// un rechazo del servidor una sola vez.
class FakeJobOffersRepository implements JobOffersRepository {
  FakeJobOffersRepository({
    List<JobOffer>? jobs,
    List<JobOffer>? feed,
    this.canWrite = true,
    this.companySummary = testJobCompany,
  }) : jobs = jobs ?? <JobOffer>[],
       feed = feed ?? <JobOffer>[];

  /// Ofertas "en la base", de cualquier empresa (sin las descartadas).
  List<JobOffer> jobs;

  /// Lo que devuelve el feed de candidatos, ya en el orden del servidor.
  List<JobOffer> feed;

  bool canWrite;

  /// Fila de `company_profiles` de la empresa del caller (null = sin fila
  /// visible).
  JobOfferCompany? companySummary;

  final List<String> calls = <String>[];

  /// Último formulario recibido, para afirmar qué viajó al servidor.
  JobOfferInput? lastInput;
  bool? lastPublish;
  String? lastCompanyId;
  JobFeedCursor? lastCursor;

  /// Fallo a devolver la próxima vez que se llame a ESE método (se consume
  /// al usarse).
  Object? nextFetchFailure;
  Object? nextFetchJobFailure;
  Object? nextCreateFailure;
  Object? nextUpdateFailure;
  Object? nextStatusFailure;
  Object? nextDiscardFailure;
  Object? nextCanWriteFailure;
  Object? nextFeedFailure;
  Object? nextCompanySummaryFailure;

  /// Fallo que devuelven SIEMPRE la lectura de las ofertas de la empresa o
  /// el feed mientras no sea null (no se consume). Con el reintento de
  /// Riverpod activo, como en producción, un `next*Failure` se curaría en el
  /// primer reintento.
  Object? persistentFetchFailure;
  Object? persistentFeedFailure;

  /// Retiene la próxima escritura (alta, edición, cambio de estado o
  /// descarte) hasta que el test lo complete: sirve para simular un segundo
  /// tap mientras la primera sigue en vuelo.
  Completer<void>? pendingWrite;

  /// Retiene la próxima página del feed.
  Completer<void>? pendingFeed;

  /// Retiene la lectura de las ofertas de la empresa (estado de carga de la
  /// lista en los tests de pantalla).
  Completer<void>? pendingCompanyJobs;

  int _created = 0;

  @override
  Future<List<JobOffer>> fetchCompanyJobs(String companyId) async {
    calls.add('fetchCompanyJobs:$companyId');
    await _awaitPending(pendingCompanyJobs);
    _maybeThrow(nextFetchFailure, () => nextFetchFailure = null);
    _maybeThrow(persistentFetchFailure, () {});
    return jobs
        .where((job) => job.companyId == companyId)
        .toList(growable: false);
  }

  @override
  Future<JobOffer?> fetchJob(String jobId) async {
    calls.add('fetchJob:$jobId');
    _maybeThrow(nextFetchJobFailure, () => nextFetchJobFailure = null);
    for (final job in jobs) {
      if (job.id == jobId) {
        return job;
      }
    }
    return null;
  }

  @override
  Future<JobOffer> createJob(
    String companyId,
    JobOfferInput input, {
    required bool publish,
  }) async {
    calls.add('createJob:${publish ? 'active' : 'draft'}');
    lastCompanyId = companyId;
    lastInput = input;
    lastPublish = publish;
    await _awaitPending(pendingWrite);
    _maybeThrow(nextCreateFailure, () => nextCreateFailure = null);
    _created++;
    final created = _offerFrom(
      id: testJobId(1000 + _created),
      companyId: companyId,
      input: input,
      status: publish ? JobStatus.active : JobStatus.draft,
      publishedAt: publish ? DateTime.utc(2026, 10, 10, 12) : null,
    );
    jobs = [created, ...jobs];
    return created;
  }

  @override
  Future<JobOffer> updateJob(
    String jobId,
    JobOfferInput input, {
    bool publish = false,
  }) async {
    calls.add('updateJob:$jobId${publish ? ':publish' : ''}');
    lastInput = input;
    lastPublish = publish;
    await _awaitPending(pendingWrite);
    _maybeThrow(nextUpdateFailure, () => nextUpdateFailure = null);
    final current = _find(jobId);
    final status = current.status;
    final target = publish ? JobStatus.active : status;
    if (status == null ||
        target == null ||
        !JobOfferLifecycle.canTransition(status, target)) {
      throw const DataFailure(
        DataFailureCode.jobStateConflict,
        debugDetail: 'fake: transición no permitida',
      );
    }
    final updated = _offerFrom(
      id: jobId,
      companyId: current.companyId,
      input: input,
      status: target,
      publishedAt: current.publishedAt ?? (publish ? testJobNow : null),
      closedAt: current.closedAt,
    );
    _replace(updated);
    return updated;
  }

  @override
  Future<JobOffer> changeStatus(String jobId, JobStatus target) async {
    calls.add('changeStatus:$jobId:${target.wireName}');
    await _awaitPending(pendingWrite);
    _maybeThrow(nextStatusFailure, () => nextStatusFailure = null);
    final current = _find(jobId);
    final status = current.status;
    if (status == null || !JobOfferLifecycle.canTransition(status, target)) {
      throw const DataFailure(
        DataFailureCode.jobStateConflict,
        debugDetail: 'fake: transición no permitida',
      );
    }
    final updated = _offerFrom(
      id: jobId,
      companyId: current.companyId,
      input: JobOfferInput.fromOffer(current),
      status: target,
      publishedAt:
          current.publishedAt ??
          (target == JobStatus.active ? testJobNow : null),
      closedAt: target == JobStatus.closed ? testJobNow : current.closedAt,
    );
    _replace(updated);
    return updated;
  }

  @override
  Future<void> discardDraft(String jobId) async {
    calls.add('discardDraft:$jobId');
    await _awaitPending(pendingWrite);
    _maybeThrow(nextDiscardFailure, () => nextDiscardFailure = null);
    final current = _find(jobId);
    if (current.status != JobStatus.draft) {
      throw const DataFailure(
        DataFailureCode.jobStateConflict,
        debugDetail: 'fake: solo se descartan borradores',
      );
    }
    jobs = jobs.where((job) => job.id != jobId).toList();
  }

  @override
  Future<bool> canWriteCompanyJobs(String companyId) async {
    calls.add('canWriteCompanyJobs:$companyId');
    _maybeThrow(nextCanWriteFailure, () => nextCanWriteFailure = null);
    return canWrite;
  }

  @override
  Future<JobOfferCompany?> fetchCompanySummary(String companyId) async {
    calls.add('fetchCompanySummary:$companyId');
    _maybeThrow(
      nextCompanySummaryFailure,
      () => nextCompanySummaryFailure = null,
    );
    return companySummary;
  }

  @override
  Future<JobFeedPage> fetchActiveJobsPage({
    JobFeedCursor? cursor,
    int limit = jobFeedPageSize,
  }) async {
    calls.add('fetchActiveJobsPage:${cursor?.id ?? 'inicio'}');
    lastCursor = cursor;
    await _awaitPending(pendingFeed);
    _maybeThrow(nextFeedFailure, () => nextFeedFailure = null);
    _maybeThrow(persistentFeedFailure, () {});
    final pageSize = limit.clamp(1, jobFeedPageSize);
    var start = 0;
    if (cursor != null) {
      final index = feed.indexWhere((job) => job.id == cursor.id);
      start = index < 0 ? feed.length : index + 1;
    }
    final items = feed.skip(start).take(pageSize).toList(growable: false);
    // Misma regla que el repositorio real: página completa → hay cursor.
    final last = items.isEmpty ? null : items.last;
    final nextCursor = items.length == pageSize && last != null
        ? JobFeedCursor(
            publishedAt:
                last.publishedAt?.toUtc().toIso8601String() ??
                '2026-10-01T12:00:00Z',
            id: last.id,
          )
        : null;
    return JobFeedPage(items: items, nextCursor: nextCursor);
  }

  JobOffer _find(String jobId) {
    for (final job in jobs) {
      if (job.id == jobId) {
        return job;
      }
    }
    // Igual que la base: una fila que RLS no deja ver ni tocar es "no podés".
    throw const DataFailure(
      DataFailureCode.notAllowed,
      debugDetail: 'fake: la escritura no devolvió la fila',
    );
  }

  void _replace(JobOffer updated) {
    jobs = [for (final job in jobs) job.id == updated.id ? updated : job];
  }

  Future<void> _awaitPending(Completer<void>? pending) async {
    if (pending != null) {
      await pending.future;
    }
  }

  void _maybeThrow(Object? failure, void Function() clear) {
    if (failure != null) {
      clear();
      // ignore: only_throw_errors -- los fakes relanzan los failures tipados.
      throw failure;
    }
  }
}
