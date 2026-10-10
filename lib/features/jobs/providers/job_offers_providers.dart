import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;

import '../../../core/networking/supabase_client_provider.dart';
import '../../../shared/models/data_failure.dart';
import '../../authentication/providers/auth_providers.dart';
import '../../companies/providers/company_verification_providers.dart';
import '../data/job_offers_repository.dart';
import '../data/supabase_job_offers_repository.dart';
import '../domain/job_offer.dart';

/// Espera el valor de un provider del que se depende y, si ese provider falló,
/// relanza SU error como [DataFailure].
///
/// Riverpod 3 envuelve en `ProviderException` el error de otro provider que se
/// espera con `.future`. Sin desenvolverlo, la pantalla recibiría algo que no
/// es un `DataFailure` y mostraría el texto genérico en vez del que
/// corresponde (p. ej. "tu cuenta figura en más de una empresa").
Future<T> awaitDependency<T>(Future<T> future) async {
  try {
    return await future;
  } on ProviderException catch (error) {
    var cause = error.exception;
    while (cause is ProviderException) {
      cause = cause.exception;
    }
    throw cause is DataFailure ? cause : DataFailure.from(cause);
  }
}

/// Reloj de la feature. La ventana de publicación (D1) y el corte de vencidas
/// del feed dependen de "ahora"; los tests lo fijan en vez de depender de la
/// hora de la máquina.
final jobClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Repositorio de ofertas. En tests se sobreescribe con un fake: ninguna
/// pantalla toca el SDK.
final jobOffersRepositoryProvider = Provider<JobOffersRepository>((ref) {
  return SupabaseJobOffersRepository(
    ref.watch(supabaseClientProvider),
    clock: ref.watch(jobClockProvider),
  );
});

/// Id de MI empresa, resuelto por el servidor (`my_company_verification`, que
/// usa la misma `private.caller_company()` que el resto de las RPC). Solo se
/// recalcula si cambia el id, no cada vez que se refresca la verificación.
///
/// Un id vacío no se usa para filtrar nada: falla cerrado.
final myCompanyIdProvider = FutureProvider<String>((ref) async {
  // Misma razón que en `myCompanyVerificationProvider`: no es autoDispose y
  // no puede sobrevivir a un cambio de sesión con el id de la cuenta anterior.
  ref.watch(authStatusProvider);
  final companyId = await awaitDependency(
    ref.watch(
      myCompanyVerificationProvider.selectAsync(
        (verification) => verification.companyId,
      ),
    ),
  );
  if (companyId.isEmpty) {
    throw const DataFailure(
      DataFailureCode.notAllowed,
      debugDetail: 'my_company_verification: sin company_id',
    );
  }
  return companyId;
});

/// Ofertas de MI empresa (todas salvo las descartadas). Se recarga tras cada
/// alta, edición o cambio de estado.
class CompanyJobsController extends AsyncNotifier<List<JobOffer>> {
  @override
  Future<List<JobOffer>> build() async {
    // Depender de la sesión NO es decorativo: este provider no es autoDispose
    // y vive en el único ProviderScope del proceso, así que sin esta
    // dependencia la cuenta siguiente vería las ofertas de la anterior.
    ref.watch(authStatusProvider);
    final repository = ref.watch(jobOffersRepositoryProvider);
    final companyId = await awaitDependency(
      ref.watch(myCompanyIdProvider.future),
    );
    return repository.fetchCompanyJobs(companyId);
  }

  /// Recarga sin descartar el valor anterior: la lista no "desaparece" por un
  /// corte puntual de red.
  Future<void> refresh() async {
    final previous = state;
    final next = await AsyncValue.guard(() async {
      final companyId = await awaitDependency(
        ref.read(myCompanyIdProvider.future),
      );
      return ref.read(jobOffersRepositoryProvider).fetchCompanyJobs(companyId);
    });
    if (!ref.mounted) {
      return;
    }
    state = next.hasError && previous.hasValue ? previous : next;
  }

  /// Refleja en la lista ya cargada una escritura que el servidor confirmó:
  /// [updated] es la fila que devolvió, o null si [jobId] se descartó (sale
  /// de la lista). Va antes de recargarla: si esa recarga falla, Riverpod
  /// conserva este valor, y la tarjeta muestra lo mismo que anunció el
  /// resultado de la acción (no una oferta "Activa" que se acaba de pausar).
  void applyConfirmedWrite(String jobId, JobOffer? updated) {
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncValue.data([
      for (final job in current)
        if (job.id != jobId) job else ?updated,
    ]);
  }
}

// Sin el reintento automático de Riverpod: con él, una recarga que falla
// queda "cargando" unos 38 segundos (10 reintentos con backoff) antes de
// que la pantalla se entere, y durante ese tiempo "Actualizar" no puede
// avisar nada. "Mis ofertas" ya ofrece "Actualizar" y "Reintentar", así que
// el fallo se informa enseguida y reintentar queda en manos de la persona.
final companyJobsProvider =
    AsyncNotifierProvider<CompanyJobsController, List<JobOffer>>(
      CompanyJobsController.new,
      retry: (retryCount, error) => null,
    );

/// ¿La cuenta puede crear y gestionar ofertas de su empresa? El rol `viewer`
/// ve las ofertas pero no las escribe (D3). Es el guard VISUAL de los
/// botones; la autorización real la aplican las policies. Mientras carga o
/// si falla, la UI tiene que tratarlo como `false`.
final canWriteCompanyJobsProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  ref.watch(authStatusProvider);
  final repository = ref.watch(jobOffersRepositoryProvider);
  final companyId = await awaitDependency(
    ref.watch(myCompanyIdProvider.future),
  );
  return repository.canWriteCompanyJobs(companyId);
});

/// Nombre y verificación de MI empresa, como los ve un candidato en una
/// oferta. Lo usa la vista previa de una oferta nueva, que todavía no tiene
/// la empresa embebida; si falla, la vista previa sigue con un nombre
/// provisorio en vez de bloquearse.
final myCompanySummaryProvider = FutureProvider.autoDispose<JobOfferCompany?>((
  ref,
) async {
  ref.watch(authStatusProvider);
  final repository = ref.watch(jobOffersRepositoryProvider);
  final companyId = await awaitDependency(
    ref.watch(myCompanyIdProvider.future),
  );
  return repository.fetchCompanySummary(companyId);
});

/// Una oferta por id (detalle, edición). Null = no existe, fue descartada o
/// no está visible para esta cuenta: indistinguibles a propósito.
final jobOfferProvider = FutureProvider.autoDispose.family<JobOffer?, String>((
  ref,
  jobId,
) {
  ref.watch(authStatusProvider);
  return ref.watch(jobOffersRepositoryProvider).fetchJob(jobId);
});
