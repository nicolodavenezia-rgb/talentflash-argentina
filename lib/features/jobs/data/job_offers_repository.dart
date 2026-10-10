import '../domain/job_feed_page.dart';
import '../domain/job_offer.dart';
import '../domain/job_offer_enums.dart';
import '../domain/job_offer_input.dart';

/// Frontera de la feature de ofertas (T-030): ninguna pantalla ni notifier
/// toca el SDK de Supabase; todo pasa por acá (ARCHITECTURE.md §2).
///
/// La autorización real vive en las policies de `public.jobs` y en los
/// triggers de 0032 (`protect_job_lifecycle`, `validate_job_content`): escribe
/// solo un miembro owner/admin/recruiter de la empresa (D3), y publicar exige
/// la empresa verificada. Todo lo que se compruebe del lado del cliente es UX.
/// Los errores llegan siempre como `DataFailure`.
abstract interface class JobOffersRepository {
  /// Ofertas de la empresa [companyId] en cualquier estado salvo las
  /// descartadas, de la más nueva a la más vieja.
  Future<List<JobOffer>> fetchCompanyJobs(String companyId);

  /// Una oferta, con la empresa embebida. Devuelve null si no existe, fue
  /// descartada o el caller no la puede ver (indistinguibles a propósito).
  Future<JobOffer?> fetchJob(String jobId);

  /// Crea una oferta de [companyId] como borrador o, con [publish], ya
  /// activa. `created_by` sale de la sesión. Devuelve la fila creada, con
  /// `published_at` derivado por el servidor.
  Future<JobOffer> createJob(
    String companyId,
    JobOfferInput input, {
    required bool publish,
  });

  /// Reescribe el contenido de [jobId]. Con [publish] la misma escritura la
  /// pasa a `active` (borrador → activa con los cambios, todo o nada).
  Future<JobOffer> updateJob(
    String jobId,
    JobOfferInput input, {
    bool publish = false,
  });

  /// Cambia solo el estado (publicar, pausar, reanudar, cerrar).
  Future<JobOffer> changeStatus(String jobId, JobStatus target);

  /// Descarta un borrador (borrado lógico, RPC `discard_job_draft`).
  Future<void> discardDraft(String jobId);

  /// ¿La cuenta puede escribir ofertas de [companyId]? (RPC
  /// `can_write_company_jobs`). Pista de UX: no autoriza nada.
  Future<bool> canWriteCompanyJobs(String companyId);

  /// Nombre y estado de verificación de la empresa [companyId], tal como lo
  /// ve un candidato en una oferta (la vista previa de una oferta nueva lo
  /// necesita). Un miembro lee la fila de SU empresa por RLS. Null si no hay
  /// fila visible.
  Future<JobOfferCompany?> fetchCompanySummary(String companyId);

  /// Página del feed de candidatos: ofertas activas, no descartadas y sin
  /// vencer, de empresas que pueden publicar (eso último lo filtra RLS), en
  /// orden `published_at desc, id desc`. [limit] se acota a
  /// [jobFeedPageSize].
  Future<JobFeedPage> fetchActiveJobsPage({
    JobFeedCursor? cursor,
    int limit = jobFeedPageSize,
  });
}
