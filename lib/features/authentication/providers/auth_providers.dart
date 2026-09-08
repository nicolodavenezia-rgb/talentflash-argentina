import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/supabase_client_provider.dart';
import '../data/auth_repository.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/auth_status.dart';
import '../domain/authenticated_user.dart';
import '../domain/business_role.dart';
import '../domain/session_assurance.dart';

/// Repositorio de autenticación. En tests se sobreescribe con un fake, de modo
/// que ninguna prueba necesita un Supabase remoto ni el singleton del SDK.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider).auth);
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
