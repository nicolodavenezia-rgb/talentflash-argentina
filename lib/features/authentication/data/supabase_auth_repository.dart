import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_failure.dart';
import '../domain/auth_status.dart';
import '../domain/auth_validation.dart';
import '../domain/authenticated_user.dart';
import '../domain/business_role.dart';
import 'auth_repository.dart';

/// Implementación sobre Supabase Auth (GoTrue).
///
/// Recibe el `GoTrueClient` por constructor para poder ejercitarla en tests
/// contra un cliente HTTP falso, sin ningún proyecto remoto.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final GoTrueClient _auth;

  @override
  AuthStatus get currentStatus => statusFromSession(_auth.currentSession);

  @override
  Stream<AuthStatus> statusChanges() {
    return _auth.onAuthStateChange
        .map((authState) => statusFromSession(authState.session))
        .handleError(_ignoreTransientStreamError);
  }

  @override
  Future<SignUpOutcome> signUpWithEmail({
    required String email,
    required String password,
    required SignUpRole role,
  }) {
    return _guard(() async {
      final response = await _auth.signUp(
        email: AuthValidation.normalizeEmail(email),
        password: password,
        // Único dato de metadata que manda el cliente. El trigger lo sanea y
        // copia el valor confiable a `app_metadata` (migración 0004).
        data: {'role': role.claim},
      );
      return response.session == null
          ? SignUpOutcome.emailConfirmationRequired
          : SignUpOutcome.signedIn;
    });
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _guard(() async {
      await _auth.signInWithPassword(
        email: AuthValidation.normalizeEmail(email),
        password: password,
      );
    });
  }

  @override
  Future<void> sendPasswordRecoveryEmail(String email) {
    return _guard(() async {
      // Sin `redirectTo`: el enlace usa el `site_url` del proyecto. La pantalla
      // in-app de cambio de contraseña depende del deep link de T-013, todavía
      // sin definir (ver README y docs/SECURITY.md §2).
      await _auth.resetPasswordForEmail(AuthValidation.normalizeEmail(email));
    });
  }

  @override
  Future<void> signOut() => _guard(() => _auth.signOut());

  /// Traduce sesión del SDK a estado de dominio.
  ///
  /// El rol sale **solo** de `app_metadata`, que escribe el servidor.
  /// `user_metadata` es input del cliente y se ignora para autorizar.
  static AuthStatus statusFromSession(Session? session) {
    final user = session?.user;
    if (session == null || user == null) {
      return const AuthStatusSignedOut();
    }
    final claim = user.appMetadata['role'] as Object?;
    final role = BusinessRole.fromClaim(claim);
    if (role == null) {
      return AuthStatusInconsistent(userId: user.id, rawClaim: claim);
    }
    return AuthStatusSignedIn(
      AuthenticatedUser(id: user.id, email: user.email ?? '', role: role),
    );
  }

  /// Un fallo de refresco puntual no debe desloguear: cuando la sesión es
  /// irrecuperable, GoTrue emite `signedOut` por el mismo stream.
  static void _ignoreTransientStreamError(
    Object error,
    StackTrace stackTrace,
  ) {}

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }
}
