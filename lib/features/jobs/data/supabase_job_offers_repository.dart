import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/data_failure.dart';
import '../domain/job_feed_page.dart';
import '../domain/job_offer.dart';
import '../domain/job_offer_enums.dart';
import '../domain/job_offer_input.dart';
import 'job_offers_repository.dart';

/// Implementación sobre PostgREST (`public.jobs`) y las RPC de 0032.
///
/// Recibe el `SupabaseClient` por constructor para ejercitarla en tests con un
/// cliente HTTP falso, sin proyecto remoto, y el reloj para fijar el "ahora"
/// con el que el feed descarta las ofertas vencidas.
class SupabaseJobOffersRepository implements JobOffersRepository {
  SupabaseJobOffersRepository(this._client, {this.clock = DateTime.now});

  final SupabaseClient _client;

  /// "Ahora" con el que el feed descarta las ofertas vencidas.
  final DateTime Function() clock;

  static const _table = 'jobs';

  /// Columnas que lee la app. Fuera a propósito: `created_by` (uid de quien
  /// cargó la oferta, ninguna pantalla lo necesita), `video_id` (T-032) y
  /// `deleted_at` (las descartadas no se leen nunca).
  static const _columns =
      'id, company_id, title, description, sector_id, salary_min, salary_max, '
      'salary_currency, salary_period, contract_type, jornada, schedule_days, '
      'schedule_detail, work_mode, provincia_id, localidad_id, barrio_id, '
      'experience, availability, benefits, expires_at, vacancies, status, '
      'published_at, closed_at, created_at, updated_at';

  /// Lo mismo más el resumen de la empresa (nombre y verificación) para el
  /// feed y el detalle. `jobs` tiene una sola FK a `company_profiles`, así
  /// que el embed no es ambiguo.
  static const _columnsWithCompany =
      '$_columns, company:company_profiles(name, verification_status)';

  /// Código de PostgREST para `.single()` sin filas: en una escritura
  /// significa que la fila no existe o que RLS no la deja tocar (USING de la
  /// policy de UPDATE, o la fila nueva no visible). Para la app las dos cosas
  /// son "no podés", nunca un error desconocido.
  static const _noRowsCode = 'PGRST116';

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Forma de un `timestamptz` serializado por PostgREST. El cursor viaja
  /// dentro de un filtro `or=(...)`: cualquier otra cosa no se interpola.
  static final _timestampPattern = RegExp(r'^[0-9T:.+\- Z]+$');

  String get _uid {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const DataFailure(
        DataFailureCode.notAllowed,
        debugDetail: 'sin sesión',
      );
    }
    return user.id;
  }

  @override
  Future<List<JobOffer>> fetchCompanyJobs(String companyId) {
    return _guard(() async {
      // Filtrar por empresa es obligatorio y no un detalle de eficiencia: la
      // policy de SELECT también devuelve las ofertas activas públicas de
      // OTRAS empresas, que no son "mis ofertas".
      final rows = await _client
          .from(_table)
          .select(_columns)
          .eq('company_id', companyId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .order('id', ascending: false);
      return [for (final row in rows) JobOffer.fromJson(row)];
    });
  }

  @override
  Future<JobOffer?> fetchJob(String jobId) {
    return _guard(() async {
      if (!_uuidPattern.hasMatch(jobId)) {
        // Un id malformado ni siquiera viaja al servidor.
        return null;
      }
      final row = await _client
          .from(_table)
          .select(_columnsWithCompany)
          .eq('id', jobId)
          .isFilter('deleted_at', null)
          .maybeSingle();
      return row == null ? null : JobOffer.fromJson(row);
    });
  }

  @override
  Future<JobOffer> createJob(
    String companyId,
    JobOfferInput input, {
    required bool publish,
  }) {
    return _guard(() async {
      final row = await _client
          .from(_table)
          .insert(
            input.toInsertJson(
              companyId: companyId,
              createdBy: _uid,
              status: publish ? JobStatus.active : JobStatus.draft,
            ),
          )
          .select(_columns)
          .single();
      return JobOffer.fromJson(row);
    });
  }

  @override
  Future<JobOffer> updateJob(
    String jobId,
    JobOfferInput input, {
    bool publish = false,
  }) {
    return _guard(() async {
      final row = await _client
          .from(_table)
          .update({
            ...input.toUpdateJson(),
            if (publish) 'status': JobStatus.active.wireName,
          })
          .eq('id', jobId)
          .select(_columns)
          .single();
      return JobOffer.fromJson(row);
    });
  }

  @override
  Future<JobOffer> changeStatus(String jobId, JobStatus target) {
    return _guard(() async {
      // Solo el estado: `published_at` y `closed_at` los deriva el servidor
      // y escribirlos desde acá es 42501.
      final row = await _client
          .from(_table)
          .update({'status': target.wireName})
          .eq('id', jobId)
          .select(_columns)
          .single();
      return JobOffer.fromJson(row);
    });
  }

  @override
  Future<void> discardDraft(String jobId) {
    return _guard(() async {
      // No hay DELETE: descartar es un borrado lógico que hace la RPC, la
      // única con permiso para escribir `deleted_at`.
      await _client.rpc<dynamic>(
        'discard_job_draft',
        params: {'p_job_id': jobId},
      );
    });
  }

  @override
  Future<bool> canWriteCompanyJobs(String companyId) {
    return _guard(() async {
      final raw = await _client.rpc<dynamic>(
        'can_write_company_jobs',
        params: {'p_company_id': companyId},
      );
      // Cualquier cosa que no sea exactamente `true` es "no": fail-closed.
      return raw == true;
    });
  }

  @override
  Future<JobOfferCompany?> fetchCompanySummary(String companyId) {
    return _guard(() async {
      // Las mismas dos columnas que embebe una oferta, así la vista previa
      // muestra exactamente lo que verá el candidato. RLS de
      // `company_profiles` deja a un miembro leer la fila de su empresa.
      final row = await _client
          .from('company_profiles')
          .select('name, verification_status')
          .eq('id', companyId)
          .maybeSingle();
      return JobOfferCompany.fromJson(row);
    });
  }

  @override
  Future<JobFeedPage> fetchActiveJobsPage({
    JobFeedCursor? cursor,
    int limit = jobFeedPageSize,
  }) {
    return _guard(() async {
      final pageSize = limit.clamp(1, jobFeedPageSize);
      // Las condiciones de visibilidad pública (empresa verificada, no
      // descartada, activa) ya las impone RLS; se repiten acá para que una
      // cuenta de empresa, que además ve TODAS las suyas, tampoco reciba sus
      // borradores en el feed. `expires_at` lo filtra solo la app hasta que
      // el cron de T-033 marque las vencidas.
      var query = _client
          .from(_table)
          .select(_columnsWithCompany)
          .eq('status', JobStatus.active.wireName)
          .isFilter('deleted_at', null)
          .gt('expires_at', clock().toUtc().toIso8601String())
          // Sin fecha de publicación no hay posición estable en el orden: no
          // debería existir ninguna activa así desde 0032, y si existiera
          // rompería el cursor.
          .not('published_at', 'is', null);
      if (cursor != null) {
        final publishedAt = cursor.publishedAt;
        final id = cursor.id;
        if (!_timestampPattern.hasMatch(publishedAt) ||
            !_uuidPattern.hasMatch(id)) {
          throw const DataFailure(
            DataFailureCode.invalidData,
            debugDetail: 'feed: cursor con forma inesperada',
          );
        }
        // Keyset sobre (published_at desc, id desc): lo publicado antes que
        // el último entregado, o en el mismo instante con un id menor. Las
        // comillas son necesarias porque el timestamp lleva `.`, `:` y `+`.
        query = query.or(
          'published_at.lt."$publishedAt",'
          'and(published_at.eq."$publishedAt",id.lt.$id)',
        );
      }
      final rows = await query
          .order('published_at', ascending: false)
          .order('id', ascending: false)
          .limit(pageSize);

      final items = [for (final row in rows) JobOffer.fromJson(row)];
      // Una página incompleta es la última. Una completa puede serlo
      // también: se pide la siguiente y, si vuelve vacía, ahí termina.
      JobFeedCursor? nextCursor;
      if (rows.length == pageSize) {
        final last = rows.last;
        final lastPublishedAt = last['published_at'];
        final lastId = last['id'];
        if (lastPublishedAt is String && lastId is String) {
          nextCursor = JobFeedCursor(publishedAt: lastPublishedAt, id: lastId);
        }
      }
      return JobFeedPage(items: items, nextCursor: nextCursor);
    });
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      if (error.code == _noRowsCode) {
        throw const DataFailure(
          DataFailureCode.notAllowed,
          debugDetail: 'jobs: la escritura no devolvió la fila',
        );
      }
      throw DataFailure.from(error);
    } catch (error) {
      if (error is DataFailure) {
        rethrow;
      }
      throw DataFailure.from(error);
    }
  }
}
