import '../domain/auth_status.dart';
import '../domain/business_role.dart';

/// Roles que el registro público puede **solicitar**.
///
/// El tipo es el primer candado contra la escalada de privilegios: no existe
/// una variante `admin`, así que ninguna pantalla ni parámetro libre puede
/// pedirla. El segundo candado es el trigger `handle_new_user` (migración
/// 0004), que sanea `raw_user_meta_data.role` en el servidor
/// (`SECURITY.md` §3).
enum SignUpRole {
  candidate(BusinessRole.candidate),
  company(BusinessRole.company);

  const SignUpRole(this.businessRole);

  final BusinessRole businessRole;

  /// Valor que viaja en `data: {'role': ...}` del signup.
  String get claim => businessRole.claim;
}

/// Resultado de un alta de cuenta.
enum SignUpOutcome {
  /// El proyecto no exige confirmación de correo: quedó sesión iniciada.
  signedIn,

  /// El proyecto exige confirmar el correo: todavía no hay sesión.
  emailConfirmationRequired,
}

/// Frontera entre la app y el proveedor de identidad.
///
/// Todo lo que la app sabe de autenticación pasa por acá: ningún widget ni
/// notifier toca `Supabase.instance` (`ARCHITECTURE.md` §2 — la única clase que
/// habla con el SDK es el repositorio de la feature). Esta interfaz es también
/// la palanca de salida de Supabase (`ARCHITECTURE.md` §11).
abstract interface class AuthRepository {
  /// Estado conocido en este instante, sin esperar al stream.
  AuthStatus get currentStatus;

  /// Emite cada cambio de sesión (alta, login, refresh, logout, expiración).
  Stream<AuthStatus> statusChanges();

  /// Alta con correo y contraseña.
  ///
  /// Envía en metadata únicamente `{'role': <candidate|company>}`. El rol
  /// definitivo lo decide el servidor.
  Future<SignUpOutcome> signUpWithEmail({
    required String email,
    required String password,
    required SignUpRole role,
  });

  /// Inicio de sesión con correo y contraseña.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  /// Primera etapa de la recuperación: dispara el correo de restablecimiento.
  ///
  /// Nunca informa si la cuenta existe (`SECURITY.md` §2).
  Future<void> sendPasswordRecoveryEmail(String email);

  /// Cierra la sesión de este dispositivo.
  Future<void> signOut();
}
