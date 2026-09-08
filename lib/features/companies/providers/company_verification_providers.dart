import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/supabase_client_provider.dart';
import '../../../shared/models/data_failure.dart';
import '../../authentication/providers/auth_providers.dart';
import '../data/company_access_repository.dart';
import '../data/company_verification_repository.dart';
import '../data/file_selector_constancia_picker.dart';
import '../data/supabase_company_verification_repository.dart';
import '../domain/company_verification.dart';

/// Repositorio del circuito de verificación. En tests se sobreescribe con un
/// fake: ninguna pantalla toca el SDK.
final companyVerificationRepositoryProvider =
    Provider<CompanyVerificationRepository>((ref) {
      return SupabaseCompanyVerificationRepository(
        ref.watch(supabaseClientProvider),
      );
    });

/// Selector de la constancia, inyectable para tests de widgets.
final constanciaPickerProvider = Provider<ConstanciaPicker>(
  (ref) => const FileSelectorConstanciaPicker(),
);

/// Estado de verificación de MI empresa. Se refresca tras cada envío.
class MyCompanyVerificationController
    extends AsyncNotifier<CompanyVerification> {
  @override
  Future<CompanyVerification> build() {
    // Depender del estado de sesión NO es decorativo: este provider no es
    // autoDispose y vive en el único ProviderScope del proceso, así que sin
    // esta dependencia sobreviviría a un cierre de sesión y la cuenta
    // siguiente vería el estado de verificación de la anterior — incluido un
    // "Empresa verificada" que no le corresponde.
    ref.watch(authStatusProvider);
    return ref
        .watch(companyVerificationRepositoryProvider)
        .fetchMyVerification();
  }

  /// Recarga sin descartar el valor anterior: la pantalla no "pierde" el
  /// estado por un corte puntual de red.
  Future<void> refresh() async {
    final previous = state;
    final next = await AsyncValue.guard(
      () =>
          ref.read(companyVerificationRepositoryProvider).fetchMyVerification(),
    );
    state = next.hasError && previous.hasValue ? previous : next;
  }
}

final myCompanyVerificationProvider =
    AsyncNotifierProvider<MyCompanyVerificationController, CompanyVerification>(
      MyCompanyVerificationController.new,
    );

/// URL firmada de corta vida para mirar una constancia ya subida.
/// autoDispose: al salir de la pantalla se descarta y se renueva al volver.
final constanciaSignedUrlProvider = FutureProvider.autoDispose
    .family<String, String>((ref, path) {
      return ref
          .watch(companyVerificationRepositoryProvider)
          .createConstanciaSignedUrl(path);
    });

// El guard visual de AAL2 del panel es `secondFactorVerifiedProvider`
// (feature de autenticación): se deriva del estado de sesión y cambia solo al
// verificar el segundo factor.

// ---------------------------------------------------------------------------
// Envío de la solicitud (lado empresa)
// ---------------------------------------------------------------------------

/// Qué terminó de pasar tras la última acción del formulario.
enum VerificationActionOutcome { constanciaAttached, submitted, reviewed }

/// Acciones del formulario de verificación, con estado de carga y errores
/// tipados. `loading` bloquea el doble submit.
class CompanyVerificationController
    extends AsyncNotifier<VerificationActionOutcome?> {
  @override
  FutureOr<VerificationActionOutcome?> build() => null;

  /// Abre el selector y sube la constancia. Devuelve el formato adjuntado, o
  /// null si la persona canceló el diálogo.
  Future<ConstanciaFormat?> attachConstancia() async {
    if (state.isLoading) {
      return null;
    }
    final picked = await ref.read(constanciaPickerProvider).pickDocument();
    if (picked == null) {
      return null;
    }
    ConstanciaFormat? adjuntado;
    await _run(() async {
      final format = picked.format;
      if (format == null) {
        throw const DataFailure(
          DataFailureCode.invalidData,
          debugDetail: 'constancia: extensión no admitida',
        );
      }
      if (picked.isTooLarge) {
        throw const DataFailure(
          DataFailureCode.invalidData,
          debugDetail: 'constancia: supera el límite',
        );
      }
      await ref
          .read(companyVerificationRepositoryProvider)
          .uploadConstancia(picked);
      adjuntado = format;
      return VerificationActionOutcome.constanciaAttached;
    });
    return adjuntado;
  }

  /// Envía la solicitud con el CUIT tipeado y, si hay, el formato de la
  /// constancia recién subida.
  Future<void> submit({required String cuit, ConstanciaFormat? format}) {
    return _run(() async {
      await ref
          .read(companyVerificationRepositoryProvider)
          .requestVerification(cuit: cuit, format: format);
      await ref.read(myCompanyVerificationProvider.notifier).refresh();
      return VerificationActionOutcome.submitted;
    });
  }

  /// Limpia el resultado anterior al entrar a la pantalla o reintentar.
  void reset() {
    if (state.isLoading) {
      return;
    }
    state = const AsyncValue<VerificationActionOutcome?>.data(null);
  }

  Future<void> _run(Future<VerificationActionOutcome> Function() action) async {
    if (state.isLoading) {
      // Segundo tap sobre el mismo botón: se ignora en vez de duplicar.
      return;
    }
    state = const AsyncValue<VerificationActionOutcome?>.loading();
    try {
      final outcome = await action();
      state = AsyncValue<VerificationActionOutcome?>.data(outcome);
    } catch (error, stackTrace) {
      state = AsyncValue<VerificationActionOutcome?>.error(
        error is DataFailure ? error : DataFailure.from(error),
        stackTrace,
      );
    }
  }
}

final companyVerificationControllerProvider =
    AsyncNotifierProvider<
      CompanyVerificationController,
      VerificationActionOutcome?
    >(CompanyVerificationController.new);

// ---------------------------------------------------------------------------
// Cola administrativa (avance parcial de T-077)
// ---------------------------------------------------------------------------

/// Estado que se está mirando en el panel. Riverpod 3 no trae `StateProvider`,
/// así que es un Notifier mínimo con un único setter explícito.
class VerificationQueueFilter extends Notifier<CompanyVerificationStatus> {
  @override
  CompanyVerificationStatus build() => CompanyVerificationStatus.pending;

  void select(CompanyVerificationStatus status) => state = status;
}

final verificationQueueFilterProvider =
    NotifierProvider<VerificationQueueFilter, CompanyVerificationStatus>(
      VerificationQueueFilter.new,
    );

final verificationQueueProvider =
    FutureProvider.autoDispose<List<CompanyVerificationRequest>>((ref) {
      // Atada a la cuenta: si la sesión cambia mientras la lista viaja, el
      // provider se reconstruye y la respuesta tardía de la cuenta anterior
      // se descarta en vez de mostrarse a la siguiente. Sin sesión no se pide
      // nada: la pantalla ya no está y una RPC sin JWT solo haría ruido.
      final user = ref.watch(currentAuthUserProvider);
      if (user == null) {
        return const <CompanyVerificationRequest>[];
      }
      final status = ref.watch(verificationQueueFilterProvider);
      return ref
          .watch(companyVerificationRepositoryProvider)
          .fetchVerificationQueue(status);
    });

/// Aprobar o rechazar desde el panel.
class VerificationReviewController
    extends AsyncNotifier<VerificationActionOutcome?> {
  @override
  FutureOr<VerificationActionOutcome?> build() {
    // Misma regla que la cola: un resultado (o un error) de una revisión en
    // vuelo no puede quedar colgado de la cuenta siguiente.
    ref.watch(currentAuthUserProvider);
    return null;
  }

  Future<void> approve(String requestId) {
    return _run(requestId: requestId, approve: true);
  }

  Future<void> reject(String requestId, VerificationRejectionReason reason) {
    return _run(requestId: requestId, approve: false, reason: reason);
  }

  void reset() {
    if (state.isLoading) {
      return;
    }
    state = const AsyncValue<VerificationActionOutcome?>.data(null);
  }

  Future<void> _run({
    required String requestId,
    required bool approve,
    VerificationRejectionReason? reason,
  }) async {
    if (state.isLoading) {
      return;
    }
    // Cuenta dueña de esta revisión. Riverpod 3 reutiliza la instancia del
    // notifier cuando el provider se reconstruye, así que `ref.mounted` no
    // distingue un cambio de cuenta: se compara la identidad a la vuelta.
    final owner = ref.read(currentAuthUserProvider)?.id;
    state = const AsyncValue<VerificationActionOutcome?>.loading();
    try {
      await ref
          .read(companyVerificationRepositoryProvider)
          .reviewVerification(
            requestId: requestId,
            approve: approve,
            reason: reason,
          );
      if (!_stillOwnedBy(owner)) {
        return;
      }
      ref.invalidate(verificationQueueProvider);
      state = const AsyncValue<VerificationActionOutcome?>.data(
        VerificationActionOutcome.reviewed,
      );
    } catch (error, stackTrace) {
      if (!_stillOwnedBy(owner)) {
        return;
      }
      state = AsyncValue<VerificationActionOutcome?>.error(
        error is DataFailure ? error : DataFailure.from(error),
        stackTrace,
      );
    }
  }

  /// `false` si el notifier ya no existe o si la sesión pasó a otra cuenta
  /// (o a ninguna) mientras la revisión viajaba: ese resultado no le
  /// pertenece a nadie y no se muestra.
  bool _stillOwnedBy(String? owner) {
    if (!ref.mounted) {
      return false;
    }
    return owner != null && ref.read(currentAuthUserProvider)?.id == owner;
  }
}

final verificationReviewControllerProvider =
    AsyncNotifierProvider<
      VerificationReviewController,
      VerificationActionOutcome?
    >(VerificationReviewController.new);
