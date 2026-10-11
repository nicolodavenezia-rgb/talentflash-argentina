import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/supabase_client_provider.dart';
import '../data/auth_repository.dart';
import '../data/second_factor_cleanup_policy.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/auth_status.dart';
import '../domain/authenticated_user.dart';
import '../domain/business_role.dart';
import '../domain/session_assurance.dart';

/// Política de bajas automáticas de segundo factor.
///
/// **La instancia la crea `bootstrap.dart` y la sobreescribe acá**, porque el
/// transporte la necesita antes de que exista el `ProviderScope`: el
/// `SecondFactorAttemptRecorder` anota cada pedido de verificación que sale y
/// el repositorio consulta lo anotado antes de cada baja. Tienen que ser la
/// **misma** instancia o la garantía no vale.
///
/// **Sin override no hay valor por omisión, y es a propósito.** Una segunda
/// instancia no es «más conservadora»: es peligrosa. El repositorio es quien
/// llama a `recordEnrolled`, así que la política que él tenga **sí** ve nacer
/// los factores; los intentos, en cambio, los anota el transporte en la suya.
/// Con dos instancias quedaría un factor propio con cero intentos anotados,
/// que es exactamente `canAutoUnenroll == true` con una verificación en vuelo
/// —el defecto de D1-bis, otra vez, y en silencio—. Mejor que estalle.
final secondFactorCleanupPolicyProvider = Provider<SecondFactorCleanupPolicy>(
  (ref) => throw StateError(
    'secondFactorCleanupPolicyProvider no está sobreescrito. La instancia la '
    'crea bootstrap.dart y la comparte con SecondFactorAttemptRecorder; el '
    'repositorio tiene que recibir ESA, no otra.',
  ),
);

/// Repositorio de autenticación. En tests se sobreescribe con un fake, de modo
/// que ninguna prueba necesita un Supabase remoto ni el singleton del SDK.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(
    ref.watch(supabaseClientProvider).auth,
    ref.watch(secondFactorCleanupPolicyProvider),
  );
});

/// Estado de sesión de la app.
///
/// Arranca en [AuthStatusUnknown] y solo cambia cuando el repositorio emite:
/// así el primer frame nunca muestra contenido privado ni la pantalla de login
/// equivocada (UX_FLOWS.md §1.5).
class AuthStatusNotifier extends Notifier<AuthStatus> {
  StreamSubscription<AuthStatus>? _subscription;

  @override
  AuthStatus build() {
    final repository = ref.watch(authRepositoryProvider);
    _subscription = repository.statusChanges().listen((status) {
      state = status;
    });
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });
    return const AuthStatusUnknown();
  }
}

final authStatusProvider = NotifierProvider<AuthStatusNotifier, AuthStatus>(
  AuthStatusNotifier.new,
);

/// Usuario autenticado con rol válido, o `null` (sin sesión, todavía cargando
/// o con claim inconsistente).
///
/// Es identidad, no sesión: verificar el segundo factor **no** cambia este
/// valor (mismo id, correo y rol). Quien necesite el nivel de la sesión mira
/// [sessionAssuranceProvider].
final currentAuthUserProvider = Provider<AuthenticatedUser?>((ref) {
  return ref.watch(authStatusProvider).user;
});

/// Rol de negocio confiable, o `null`.
///
/// Es lo único que la UI puede usar para decidir qué mostrar. La autorización
/// real sigue siendo RLS en Postgres (`SECURITY.md` §3).
final businessRoleProvider = Provider<BusinessRole?>((ref) {
  return ref.watch(authStatusProvider).role;
});

/// `false` mientras la sesión todavía se está restaurando.
final authResolvedProvider = Provider<bool>((ref) {
  return ref.watch(authStatusProvider).isResolved;
});

/// Nivel de garantía de la sesión vigente (claim `aal` del token).
///
/// Se deriva del mismo stream que el resto del estado de sesión, así que
/// verificar el segundo factor lo actualiza sin reiniciar nada: el SDK emite
/// la sesión nueva, el repositorio la traduce y este provider cambia de
/// `aal1` a `aal2` con el mismo usuario.
final sessionAssuranceProvider = Provider<SessionAssurance>((ref) {
  return ref.watch(authStatusProvider).assurance;
});

/// Guard VISUAL de la cola administrativa: `true` solo con claim `aal2`
/// exacto en la sesión actual. Tener un factor verificado (`nextLevel`) no
/// alcanza. La autorización real la aplican las RPC (migración 0028).
final secondFactorVerifiedProvider = Provider<bool>((ref) {
  return ref.watch(authStatusProvider).hasSecondFactorVerified;
});
