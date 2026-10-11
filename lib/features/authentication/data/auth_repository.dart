import '../domain/auth_status.dart';
import '../domain/business_role.dart';
import '../domain/second_factor.dart';

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

  /// Emite cada cambio de sesión (alta, login, refresh, logout, expiración y
  /// verificación del segundo factor, que cambia el nivel sin cambiar de
  /// usuario).
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

  // --- Segundo factor TOTP ---------------------------------------------------
  //
  // Alcance deliberado: alta y verificación. No hay baja ni reemplazo de un
  // factor verificado, ni códigos de recuperación, ni recuperación por
  // pérdida del autenticador (ver SECURITY.md §2, y el README en «Probar la
  // autenticación en local»; no hay ninguna sección del README que se llame
  // «Segundo factor», como decía antes esta línea).

  /// Factores TOTP **verificados** de la cuenta, según el servidor
  /// (`GET /user`), **sin** refrescar la sesión: refrescar rota el refresh
  /// token y le movería la sesión a las demás pestañas. Solo se refresca si el
  /// access token ya venció, para poder llamar. Vacío si nunca terminó un
  /// alta.
  Future<List<SecondFactor>> listVerifiedSecondFactors();

  /// Inicia un alta TOTP: crea un factor **pendiente** y devuelve su secreto
  /// y URI para el QR. No cambia el nivel de la sesión.
  ///
  /// El servidor rechaza esto con `insufficient_aal` cuando ya hay un factor
  /// verificado y la sesión es `aal1`: en ese caso corresponde desafiar el
  /// existente, no crear otro.
  Future<TotpEnrollment> enrollTotp({required String friendlyName});

  /// Emite un desafío para [factorId] (pendiente o verificado). Vence solo.
  Future<SecondFactorChallenge> challengeSecondFactor(String factorId);

  /// Verifica [code] contra un desafío. Al aceptarlo, el servidor marca el
  /// factor como verificado (si era pendiente), emite un token `aal2` y el
  /// cambio llega por [statusChanges] con el **mismo** usuario y rol.
  Future<void> verifySecondFactor({
    required String factorId,
    required String challengeId,
    required String code,
  });

  /// Pide descartar un factor **pendiente** creado por un alta que no se
  /// terminó (cancelación, salida de la pantalla). Si el factor ya no existe,
  /// no es un error.
  ///
  /// **El contrato es «pedí», no «se borró», y la implementación de
  /// Supabase hoy no borra nada.** No manda ninguna baja automática, porque
  /// el endpoint de GoTrue no permite borrar de forma condicional y atómica;
  /// volver sin haber tocado el servidor es su comportamiento normal, no un
  /// fallo silencioso. Quien llame a esto **no puede asumir** que el
  /// pendiente desapareció: lo recolecta el servidor si nunca pidió un
  /// desafío, y si lo pidió, lo barre la próxima verificación exitosa. El
  /// motivo completo está en `SecondFactorCleanupPolicy` y en SECURITY.md §2.
  ///
  /// Un factor verificado no se toca desde acá, y tampoco se ofrece darlo de
  /// baja: no es parte de este alcance.
  Future<void> discardPendingSecondFactor(String factorId);
}
