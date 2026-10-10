import 'job_offer_enums.dart';

/// Acciones que la empresa puede pedir sobre una oferta.
enum JobOfferAction {
  edit,
  publish,
  pause,
  resume,
  close,
  discard,
  duplicate;

  /// Estado al que lleva la acción, o null si no cambia el estado (editar,
  /// descartar —borrado lógico— y duplicar, que crea otra oferta).
  JobStatus? get targetStatus => switch (this) {
    JobOfferAction.publish || JobOfferAction.resume => JobStatus.active,
    JobOfferAction.pause => JobStatus.paused,
    JobOfferAction.close => JobStatus.closed,
    JobOfferAction.edit ||
    JobOfferAction.discard ||
    JobOfferAction.duplicate => null,
  };

  /// Entrar a `active` exige además que la empresa esté verificada: la policy
  /// de `jobs` lo rechaza con 42501 si no (`company_can_publish`, 0031). La
  /// UI lo puede explicar antes con el estado de verificación propio.
  bool get requiresApprovedCompany => targetStatus == JobStatus.active;
}

/// Ciclo de vida de la oferta visto desde el cliente: espejo exacto de
/// `private.protect_job_lifecycle` (0032). Es UX: decide qué botones se
/// ofrecen; la autoridad sigue siendo el servidor, que responde `TFJOB`
/// (→ `DataFailureCode.jobStateConflict`) o 42501 ante cualquier otra cosa.
///
/// Que una acción esté disponible por estado no dice que la cuenta pueda
/// hacerla: el rol `viewer` no escribe ofertas (D3) y eso lo informa
/// `canWriteCompanyJobsProvider`.
abstract final class JobOfferLifecycle {
  /// Estados con los que el cliente puede crear una oferta.
  static const insertableStatuses = {JobStatus.draft, JobStatus.active};

  /// Estados cuyo contenido se puede editar sin cambiar de estado.
  static const editableStatuses = {
    JobStatus.draft,
    JobStatus.active,
    JobStatus.paused,
  };

  /// ¿El cliente puede pasar una oferta de [from] a [to]?
  ///
  /// Mismo estado en {draft, active, paused} es una edición de contenido.
  /// Pares permitidos: draft→active, active→paused, paused→active,
  /// active→closed, paused→closed y expired→closed. Todo lo demás lo rechaza
  /// el servidor (pasar a `expired` lo hace solo el sistema, T-033).
  static bool canTransition(JobStatus from, JobStatus to) {
    if (from == to) {
      return editableStatuses.contains(from);
    }
    return switch ((from, to)) {
      (JobStatus.draft, JobStatus.active) ||
      (JobStatus.active, JobStatus.paused) ||
      (JobStatus.paused, JobStatus.active) ||
      (JobStatus.active, JobStatus.closed) ||
      (JobStatus.paused, JobStatus.closed) ||
      (JobStatus.expired, JobStatus.closed) => true,
      _ => false,
    };
  }

  /// Acciones disponibles para una oferta en [status]. Un estado desconocido
  /// (null) no habilita ninguna: fail-closed.
  static Set<JobOfferAction> actionsFor(JobStatus? status) {
    return switch (status) {
      JobStatus.draft => const {
        JobOfferAction.edit,
        JobOfferAction.publish,
        JobOfferAction.discard,
        JobOfferAction.duplicate,
      },
      JobStatus.active => const {
        JobOfferAction.edit,
        JobOfferAction.pause,
        JobOfferAction.close,
        JobOfferAction.duplicate,
      },
      JobStatus.paused => const {
        JobOfferAction.edit,
        JobOfferAction.resume,
        JobOfferAction.close,
        JobOfferAction.duplicate,
      },
      JobStatus.expired => const {
        JobOfferAction.close,
        JobOfferAction.duplicate,
      },
      JobStatus.closed => const {JobOfferAction.duplicate},
      null => const {},
    };
  }

  static bool allows(JobStatus? status, JobOfferAction action) =>
      actionsFor(status).contains(action);
}
