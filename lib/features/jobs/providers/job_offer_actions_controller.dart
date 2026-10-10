import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/data_failure.dart';
import '../domain/job_offer.dart';
import '../domain/job_offer_enums.dart';
import '../domain/job_offer_lifecycle.dart';
import '../domain/job_offer_validation.dart';
import 'job_offers_providers.dart';

/// Qué terminó de pasar tras la última acción de ciclo de vida.
enum JobOfferActionOutcome { published, paused, resumed, closed, discarded }

/// Acciones de ciclo de vida sobre una oferta ya guardada (desde la lista o
/// el detalle): publicar un borrador sin editarlo, pausar, reanudar, cerrar y
/// descartar.
///
/// Una acción a la vez: mientras una está en vuelo, cualquier otra (sobre la
/// misma oferta o sobre otra) se ignora, así un doble tap no manda dos
/// cambios de estado. Tras cada éxito el resultado se aplica a la lista de la
/// empresa y se recargan esa lista y el detalle de la oferta. Recibe la oferta entera y no solo el id para
/// comprobar el ciclo de vida con el estado que la pantalla está mostrando.
class JobOfferActionsController extends AsyncNotifier<JobOfferActionOutcome?> {
  @override
  FutureOr<JobOfferActionOutcome?> build() => null;

  /// Borrador → activa, tal como está. [localityHasNeighborhoods] alimenta
  /// la regla del barrio (D2); null = no se sabe y decide el servidor.
  Future<void> publish(JobOffer offer, {bool? localityHasNeighborhoods}) {
    return _run(
      offer,
      JobOfferAction.publish,
      JobOfferActionOutcome.published,
      localityHasNeighborhoods: localityHasNeighborhoods,
    );
  }

  Future<void> pause(JobOffer offer) {
    return _run(offer, JobOfferAction.pause, JobOfferActionOutcome.paused);
  }

  /// Pausada → activa. Conserva `published_at` (no "sube" en el feed) y
  /// vuelve a exigir las reglas de publicación: si venció mientras estaba
  /// pausada, falla con `invalidData` hasta que se edite el vencimiento.
  Future<void> resume(JobOffer offer, {bool? localityHasNeighborhoods}) {
    return _run(
      offer,
      JobOfferAction.resume,
      JobOfferActionOutcome.resumed,
      localityHasNeighborhoods: localityHasNeighborhoods,
    );
  }

  Future<void> close(JobOffer offer) {
    return _run(offer, JobOfferAction.close, JobOfferActionOutcome.closed);
  }

  /// Descarta un borrador (borrado lógico). Las publicadas no se descartan:
  /// se cierran.
  Future<void> discard(JobOffer offer) {
    return _run(offer, JobOfferAction.discard, JobOfferActionOutcome.discarded);
  }

  /// Limpia el resultado anterior al entrar a la pantalla o reintentar.
  void reset() {
    if (state.isLoading) {
      return;
    }
    state = const AsyncValue<JobOfferActionOutcome?>.data(null);
  }

  Future<void> _run(
    JobOffer offer,
    JobOfferAction action,
    JobOfferActionOutcome outcome, {
    bool? localityHasNeighborhoods,
  }) async {
    if (state.isLoading) {
      // Segundo tap (sobre esta u otra oferta): se ignora en vez de duplicar.
      return;
    }
    state = const AsyncValue<JobOfferActionOutcome?>.loading();
    try {
      if (!JobOfferLifecycle.allows(offer.status, action)) {
        throw DataFailure(
          DataFailureCode.jobStateConflict,
          debugDetail:
              'ciclo de vida local: ${offer.status?.wireName ?? 'desconocido'}'
              ' no admite ${action.name}',
        );
      }
      final target = action.targetStatus;
      if (target == JobStatus.active) {
        // Entrar a `active` re-chequea en el servidor las reglas de
        // publicación; se adelantan para no ir y volver por algo ya sabido.
        final issues = JobOfferValidation.validatePublication(
          offer,
          now: ref.read(jobClockProvider)(),
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
      }
      final repository = ref.read(jobOffersRepositoryProvider);
      JobOffer? updated;
      if (target == null) {
        await repository.discardDraft(offer.id);
      } else {
        updated = await repository.changeStatus(offer.id, target);
      }
      if (!ref.mounted) {
        return;
      }
      _applyToList(offer.id, updated);
      _reload(offer.id);
      state = AsyncValue<JobOfferActionOutcome?>.data(outcome);
    } catch (error, stackTrace) {
      final failure = error is DataFailure ? error : DataFailure.from(error);
      if (!ref.mounted) {
        return;
      }
      if (failure.code == DataFailureCode.jobStateConflict) {
        // La oferta cambió en el servidor (otra persona, vencimiento o
        // descarte): se recarga para que la pantalla muestre lo real.
        _reload(offer.id);
      }
      state = AsyncValue<JobOfferActionOutcome?>.error(failure, stackTrace);
    }
  }

  /// Lo que el servidor confirmó pasa a la lista antes de recargarla: si la
  /// recarga falla, la tarjeta igual muestra el estado nuevo ([updated], o
  /// ya no está si se descartó), el mismo que anuncia el resultado.
  void _applyToList(String jobId, JobOffer? updated) {
    // Solo si la lista ya está en memoria: leer su notifier la construiría
    // (y pediría las ofertas) sin que nadie la mire.
    if (ref.exists(companyJobsProvider)) {
      ref
          .read(companyJobsProvider.notifier)
          .applyConfirmedWrite(jobId, updated);
    }
  }

  void _reload(String jobId) {
    ref.invalidate(companyJobsProvider);
    ref.invalidate(jobOfferProvider(jobId));
  }
}

final jobOfferActionsControllerProvider =
    AsyncNotifierProvider<JobOfferActionsController, JobOfferActionOutcome?>(
      JobOfferActionsController.new,
    );
