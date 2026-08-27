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
  unknown,
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
      return AuthFailure(AuthFailureCode.network, debugDetail: '$error');
    }
    if (error is AuthException) {
      return AuthFailure(
        _codeFromAuthException(error),
        debugDetail:
            'AuthException(code: ${error.code}, status: ${error.statusCode})',
      );
    }
    if (error is TimeoutException) {
      return AuthFailure(AuthFailureCode.network, debugDetail: '$error');
    }
    return AuthFailure(AuthFailureCode.unknown, debugDetail: '$error');
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
    }
    if (error.statusCode == '429') {
      return AuthFailureCode.rateLimited;
    }
    return AuthFailureCode.unknown;
  }

  @override
  String toString() => 'AuthFailure(${code.name})';
}
