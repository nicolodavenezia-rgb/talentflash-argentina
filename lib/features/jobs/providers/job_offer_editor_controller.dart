import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/data_failure.dart';
import '../data/job_offers_repository.dart';
import '../domain/job_offer.dart';
import '../domain/job_offer_enums.dart';
import '../domain/job_offer_input.dart';
import '../domain/job_offer_lifecycle.dart';
import '../domain/job_offer_validation.dart';
import 'job_offers_providers.dart';

/// Qué terminó de pasar tras la última acción del formulario de oferta.
enum JobOfferEditorOutcome { draftSaved, published, changesSaved }

/// Acciones del formulario de oferta (alta, borrador, publicación, edición)
/// con estado de carga y errores tipados.
///
/// `AsyncValue<JobOfferEditorOutcome?>`: `loading` bloquea el doble submit y
/// el error es siempre un [DataFailure], nunca un mensaje de Postgres. Cada
/// acción devuelve la oferta guardada (o null si falló o se ignoró por doble
/// tap): tras el primer "Guardar borrador" la pantalla tiene que seguir con
/// [saveChanges] sobre esa oferta, no crear otra.
///
/// Antes de escribir se repiten las reglas del formulario
/// ([JobOfferValidation]) y del ciclo de vida ([JobOfferLifecycle]): si algo
/// ya se sabe inválido no se viaja al servidor. Es un respaldo; la pantalla
/// valida campo por campo antes de llamar.
class JobOfferEditorController extends AsyncNotifier<JobOfferEditorOutcome?> {
  @override
  FutureOr<JobOfferEditorOutcome?> build() => null;

  /// Crea la oferta como borrador.
  Future<JobOffer?> saveDraft(JobOfferInput input) {
    return _run(
      input: input,
      mode: JobOfferSaveMode.draft,
      outcome: JobOfferEditorOutcome.draftSaved,
      write: (repository) async =>
          repository.createJob(await _companyId(), input, publish: false),
    );
  }

  /// Crea la oferta ya publicada. [localityHasNeighborhoods] alimenta la
  /// regla del barrio (D2); null = no se sabe todavía y decide el servidor.
  Future<JobOffer?> publish(
    JobOfferInput input, {
    bool? localityHasNeighborhoods,
  }) {
    return _run(
      input: input,
      mode: JobOfferSaveMode.publish,
      localityHasNeighborhoods: localityHasNeighborhoods,
      outcome: JobOfferEditorOutcome.published,
      write: (repository) async =>
          repository.createJob(await _companyId(), input, publish: true),
    );
  }

  /// Guarda cambios de contenido de [offer] sin cambiar su estado (borrador,
  /// activa o pausada). Si sigue activa y cambió el sueldo mínimo, el
  /// vencimiento, la localidad o el barrio, valen otra vez las reglas de
  /// publicación (igual que en el servidor).
  Future<JobOffer?> saveChanges(
    JobOffer offer,
    JobOfferInput input, {
    bool? localityHasNeighborhoods,
  }) {
    return _run(
      offer: offer,
      action: JobOfferAction.edit,
      input: input,
      mode: offer.status == JobStatus.active
          ? JobOfferSaveMode.editActive
          : JobOfferSaveMode.draft,
      original: JobOfferInput.fromOffer(offer),
      localityHasNeighborhoods: localityHasNeighborhoods,
      outcome: JobOfferEditorOutcome.changesSaved,
      write: (repository) => repository.updateJob(offer.id, input),
    );
  }

  /// Publica el borrador [offer] con los cambios del formulario en UNA sola
  /// escritura: o queda publicado con esos datos, o no cambia nada.
  Future<JobOffer?> publishDraft(
    JobOffer offer,
    JobOfferInput input, {
    bool? localityHasNeighborhoods,
  }) {
    return _run(
      offer: offer,
      action: JobOfferAction.publish,
      input: input,
      mode: JobOfferSaveMode.publish,
      localityHasNeighborhoods: localityHasNeighborhoods,
      outcome: JobOfferEditorOutcome.published,
      write: (repository) =>
          repository.updateJob(offer.id, input, publish: true),
    );
  }

  /// Limpia el resultado anterior al entrar a la pantalla o reintentar.
  void reset() {
    if (state.isLoading) {
      return;
    }
    state = const AsyncValue<JobOfferEditorOutcome?>.data(null);
  }

  Future<String> _companyId() =>
      awaitDependency(ref.read(myCompanyIdProvider.future));

  Future<JobOffer?> _run({
    required JobOfferInput input,
    required JobOfferSaveMode mode,
    required JobOfferEditorOutcome outcome,
    required Future<JobOffer> Function(JobOffersRepository repository) write,
    JobOffer? offer,
    JobOfferAction? action,
    JobOfferInput? original,
    bool? localityHasNeighborhoods,
  }) async {
    if (state.isLoading) {
      // Segundo tap sobre el mismo botón: se ignora en vez de duplicar.
      return null;
    }
    state = const AsyncValue<JobOfferEditorOutcome?>.loading();
    try {
      if (offer != null &&
          action != null &&
          !JobOfferLifecycle.allows(offer.status, action)) {
        throw DataFailure(
          DataFailureCode.jobStateConflict,
          debugDetail:
              'ciclo de vida local: ${offer.status?.wireName ?? 'desconocido'}'
              ' no admite ${action.name}',
        );
      }
      final issues = JobOfferValidation.validate(
        input,
        mode: mode,
        now: ref.read(jobClockProvider)(),
        original: original,
        localityHasNeighborhoods: localityHasNeighborhoods,
      );
      if (!issues.isEmpty) {
        throw DataFailure(
          DataFailureCode.invalidData,
          debugDetail:
              'validación local: '
              '${issues.invalidFields.map((field) => field.name).join(',')}',
        );
      }
      final saved = await write(ref.read(jobOffersRepositoryProvider));
      if (!ref.mounted) {
        return saved;
      }
      ref.invalidate(companyJobsProvider);
      ref.invalidate(jobOfferProvider(saved.id));
      state = AsyncValue<JobOfferEditorOutcome?>.data(outcome);
      return saved;
    } catch (error, stackTrace) {
      final failure = error is DataFailure ? error : DataFailure.from(error);
      if (ref.mounted) {
        if (offer != null && failure.code == DataFailureCode.jobStateConflict) {
          // La oferta cambió en el servidor: lo que muestra la pantalla ya no
          // es la realidad, así que se recarga para poder explicarlo.
          ref.invalidate(companyJobsProvider);
          ref.invalidate(jobOfferProvider(offer.id));
        }
        state = AsyncValue<JobOfferEditorOutcome?>.error(failure, stackTrace);
      }
      return null;
    }
  }
}

final jobOfferEditorControllerProvider =
    AsyncNotifierProvider<JobOfferEditorController, JobOfferEditorOutcome?>(
      JobOfferEditorController.new,
    );
