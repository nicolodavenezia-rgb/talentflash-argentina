import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Causas de fallo que la UI sabe explicar en es-AR.
///
/// La UI mapea el código a un texto de `AppLocalizations`; el mensaje crudo de
/// Supabase nunca llega a la pantalla (`SECURITY.md` §5: respuestas de error
/// genéricas hacia afuera, detalle solo en logs).
enum AuthFailureCode {
  invalidCredentials,
  emailAlreadyRegistered,
  weakPassword,
  emailNotConfirmed,
  rateLimited,
  network,

  /// No hay sesión (o el servidor ya no la reconoce): hay que volver a
  /// iniciar sesión. Distinto de [invalidCredentials].
  sessionMissing,

  /// La operación pertenecía a una sesión que dejó de ser la vigente mientras
  /// viajaba (cierre de sesión, otra cuenta, reingreso): se descartó antes de
  /// que el SDK pudiera aplicarla. La UI no la muestra como error de la
  /// sesión nueva; el flujo que la pidió ya no existe.
  staleSession,

  // --- Segundo factor (TOTP). Los `error_code` de GoTrue de abajo se
  // --- verificaron contra el stack local con `npm run mfa:test`.

  /// El código no corresponde al factor (`mfa_verification_failed`).
  mfaInvalidCode,

  /// El desafío venció antes de mandar el código (`mfa_challenge_expired`).
  mfaChallengeExpired,

  /// El factor ya no existe (`mfa_factor_not_found`), p. ej. lo descartó
  /// otra sesión.
  mfaFactorNotFound,

  /// Ya hay un factor con ese nombre (`mfa_factor_name_conflict`): suele ser
  /// un alta anterior interrumpida.
  mfaFactorNameConflict,

  /// La cuenta llegó al máximo de factores (`too_many_enrolled_mfa_factors`).
  mfaTooManyFactors,

  /// La acción exige `aal2` y la sesión está en `aal1` (`insufficient_aal`):
  /// con un factor verificado no se puede dar de alta otro sin desafiar el
  /// existente.
  mfaInsufficientAssurance,

  /// TOTP deshabilitado en el proyecto (`mfa_totp_*_not_enabled`).
  mfaNotEnabled,

  /// El servidor rechazó la verificación por política o por cambio de red
  /// (`mfa_verification_rejected`, `mfa_ip_address_mismatch`).
  mfaRejected,

  unknown;

  /// `error_code` con el que `SessionScopedHttpClient` descarta una respuesta
  /// de una sesión que ya no es la vigente. No lo emite GoTrue.
  String? get wireCode => switch (this) {
    AuthFailureCode.staleSession => 'stale_session',
    _ => null,
  };
}

/// Error tipado de la capa de autenticación.
///
/// No se importa `dart:io` a propósito: este código también compila para Web,
/// donde ese import no existe. Los fallos de red llegan como
/// `AuthRetryableFetchException` desde el SDK.
class AuthFailure implements Exception {
  const AuthFailure(this.code, {this.debugDetail});

  /// Traduce una excepción del SDK a un código propio.
  ///
  /// Los `error_code` de GoTrue contemplados acá fueron verificados contra el
  /// stack local (ver `docs/SECURITY.md` §2).
  factory AuthFailure.from(Object error) {
    if (error is AuthFailure) {
      return error;
    }
    if (error is AuthRetryableFetchException) {
      // Sin `$error`: ante un 2xx con JSON malformado el SDK mete en el
      // mensaje un fragmento del cuerpo, que en el alta TOTP contendría el
      // secreto. El tipo alcanza para diagnosticar.
      return const AuthFailure(
        AuthFailureCode.network,
        debugDetail: 'AuthRetryableFetchException',
      );
    }
    if (error is AuthSessionMissingException) {
      return AuthFailure(
        AuthFailureCode.sessionMissing,
        debugDetail: 'AuthSessionMissingException',
      );
    }
    if (error is AuthException) {
      return AuthFailure(
        _codeFromAuthException(error),
        debugDetail:
            'AuthException(code: ${error.code}, status: ${error.statusCode})',
      );
    }
    if (error is TimeoutException) {
      return const AuthFailure(
        AuthFailureCode.network,
        debugDetail: 'TimeoutException',
      );
    }
    // Solo el tipo: un `toString` ajeno puede arrastrar datos de la
    // respuesta, y este detalle termina en logs.
    return AuthFailure(
      AuthFailureCode.unknown,
      debugDetail: error.runtimeType.toString(),
    );
  }

  final AuthFailureCode code;

  /// Detalle técnico para logs/Sentry. **No mostrar en la UI.**
  final String? debugDetail;

  static AuthFailureCode _codeFromAuthException(AuthException error) {
    switch (error.code) {
      case 'invalid_credentials':
      case 'invalid_grant':
        return AuthFailureCode.invalidCredentials;
      case 'user_already_exists':
      case 'email_exists':
        return AuthFailureCode.emailAlreadyRegistered;
      case 'weak_password':
        return AuthFailureCode.weakPassword;
      case 'email_not_confirmed':
        return AuthFailureCode.emailNotConfirmed;
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return AuthFailureCode.rateLimited;
      case 'session_not_found':
      case 'session_expired':
      case 'refresh_token_not_found':
      case 'refresh_token_already_used':
        return AuthFailureCode.sessionMissing;
      // Lo emite `SessionScopedHttpClient`, no GoTrue: la respuesta llegó
      // para una sesión que ya no es la vigente.
      case 'stale_session':
        return AuthFailureCode.staleSession;
      case 'mfa_verification_failed':
        return AuthFailureCode.mfaInvalidCode;
      case 'mfa_challenge_expired':
        return AuthFailureCode.mfaChallengeExpired;
      case 'mfa_factor_not_found':
        return AuthFailureCode.mfaFactorNotFound;
      case 'mfa_factor_name_conflict':
        return AuthFailureCode.mfaFactorNameConflict;
      case 'too_many_enrolled_mfa_factors':
        return AuthFailureCode.mfaTooManyFactors;
      case 'insufficient_aal':
        return AuthFailureCode.mfaInsufficientAssurance;
      case 'mfa_totp_enroll_not_enabled':
      case 'mfa_totp_verify_not_enabled':
        return AuthFailureCode.mfaNotEnabled;
      case 'mfa_verification_rejected':
      case 'mfa_ip_address_mismatch':
        return AuthFailureCode.mfaRejected;
    }
    if (error.statusCode == '429') {
      return AuthFailureCode.rateLimited;
    }
    return AuthFailureCode.unknown;
  }

  @override
  String toString() => 'AuthFailure(${code.name})';
}
