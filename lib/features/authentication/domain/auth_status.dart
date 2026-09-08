import 'authenticated_user.dart';
import 'business_role.dart';
import 'session_assurance.dart';

/// Estado de autenticación observable por la UI y por los guards de ruta.
///
/// Es un tipo cerrado a propósito: el router debe contemplar los cuatro casos
/// y no puede "olvidarse" del arranque ni de la sesión inconsistente.
sealed class AuthStatus {
  const AuthStatus();

  /// `true` mientras todavía no se sabe si hay sesión. Ninguna pantalla
  /// privada puede renderizarse en este estado (UX_FLOWS.md §1.5).
  bool get isResolved => this is! AuthStatusUnknown;

  /// Rol confiable, o `null` si no hay sesión válida.
  BusinessRole? get role => switch (this) {
    AuthStatusSignedIn(:final authUser) => authUser.role,
    _ => null,
  };

  /// Usuario autenticado con rol válido, o `null`.
  AuthenticatedUser? get user => switch (this) {
    AuthStatusSignedIn(:final authUser) => authUser,
    _ => null,
  };

  /// Nivel de garantía de la sesión. Sin sesión válida es [SessionAssurance.unknown].
  SessionAssurance get assurance => switch (this) {
    AuthStatusSignedIn(:final assurance) => assurance,
    _ => SessionAssurance.unknown,
  };

  /// `true` solo con sesión válida **y** claim `aal2` exacto. Es el único
  /// dato que habilita a dibujar la cola administrativa; la autorización real
  /// sigue siendo de las RPC (migración 0028).
  bool get hasSecondFactorVerified => assurance.isSecondFactorVerified;
}

/// Sesión todavía no restaurada (primer frame, rehidratación del SDK).
final class AuthStatusUnknown extends AuthStatus {
  const AuthStatusUnknown();

  @override
  bool operator ==(Object other) => other is AuthStatusUnknown;

  @override
  int get hashCode => (AuthStatusUnknown).hashCode;

  @override
  String toString() => 'AuthStatusUnknown()';
}

/// No hay sesión.
final class AuthStatusSignedOut extends AuthStatus {
  const AuthStatusSignedOut();

  @override
  bool operator ==(Object other) => other is AuthStatusSignedOut;

  @override
  int get hashCode => (AuthStatusSignedOut).hashCode;

  @override
  String toString() => 'AuthStatusSignedOut()';
}

/// Sesión válida con rol confiable resuelto.
///
/// [assurance] forma parte de la igualdad a propósito: verificar el segundo
/// factor cambia el token pero no la identidad, y sin este campo el estado
/// "mismo usuario, ahora con aal2" sería igual al anterior y nadie se
/// enteraría (ni el router, ni la cola administrativa).
final class AuthStatusSignedIn extends AuthStatus {
  const AuthStatusSignedIn(
    this.authUser, {
    this.assurance = SessionAssurance.unknown,
  });

  final AuthenticatedUser authUser;

  /// Nivel de **esta** sesión, leído del claim `aal` del token vigente.
  @override
  final SessionAssurance assurance;

  @override
  bool operator ==(Object other) =>
      other is AuthStatusSignedIn &&
      other.authUser == authUser &&
      other.assurance == assurance;

  @override
  int get hashCode => Object.hash(AuthStatusSignedIn, authUser, assurance);

  @override
  String toString() => 'AuthStatusSignedIn($authUser, ${assurance.name})';
}

/// Hay sesión pero el claim `app_metadata.role` falta o no es válido.
///
/// Estado seguro: no se elige un rol por defecto ni se degrada a candidato.
/// La única salida desde la UI es cerrar sesión.
final class AuthStatusInconsistent extends AuthStatus {
  const AuthStatusInconsistent({required this.userId, this.rawClaim});

  final String userId;

  /// Valor recibido (para diagnóstico interno; nunca se muestra al usuario).
  final Object? rawClaim;

  @override
  bool operator ==(Object other) =>
      other is AuthStatusInconsistent &&
      other.userId == userId &&
      other.rawClaim == rawClaim;

  @override
  int get hashCode => Object.hash(AuthStatusInconsistent, userId, rawClaim);

  @override
  String toString() => 'AuthStatusInconsistent(userId: $userId)';
}
