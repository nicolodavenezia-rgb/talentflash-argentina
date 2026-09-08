import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_failure.dart';

void main() {
  group('AuthFailure.from', () {
    test('traduce los error_code que devuelve GoTrue', () {
      final cases = <String, AuthFailureCode>{
        'invalid_credentials': AuthFailureCode.invalidCredentials,
        'invalid_grant': AuthFailureCode.invalidCredentials,
        'user_already_exists': AuthFailureCode.emailAlreadyRegistered,
        'email_exists': AuthFailureCode.emailAlreadyRegistered,
        'weak_password': AuthFailureCode.weakPassword,
        'email_not_confirmed': AuthFailureCode.emailNotConfirmed,
        'over_request_rate_limit': AuthFailureCode.rateLimited,
        'over_email_send_rate_limit': AuthFailureCode.rateLimited,
      };
      cases.forEach((errorCode, expected) {
        final failure = AuthFailure.from(
          AuthApiException('mensaje interno', code: errorCode),
        );
        expect(failure.code, expected, reason: 'para $errorCode');
      });
    });

    test(
      'traduce los error_code del segundo factor (verificados en local)',
      () {
        // Los códigos y estados de abajo son los que devolvió el GoTrue del
        // stack local en `npm run mfa:test`.
        final cases = <(String, String), AuthFailureCode>{
          ('mfa_verification_failed', '422'): AuthFailureCode.mfaInvalidCode,
          ('mfa_challenge_expired', '422'): AuthFailureCode.mfaChallengeExpired,
          ('mfa_factor_not_found', '404'): AuthFailureCode.mfaFactorNotFound,
          ('mfa_factor_name_conflict', '422'):
              AuthFailureCode.mfaFactorNameConflict,
          ('too_many_enrolled_mfa_factors', '422'):
              AuthFailureCode.mfaTooManyFactors,
          ('insufficient_aal', '403'): AuthFailureCode.mfaInsufficientAssurance,
          ('mfa_totp_enroll_not_enabled', '422'): AuthFailureCode.mfaNotEnabled,
          ('mfa_totp_verify_not_enabled', '422'): AuthFailureCode.mfaNotEnabled,
          ('mfa_verification_rejected', '403'): AuthFailureCode.mfaRejected,
          ('mfa_ip_address_mismatch', '403'): AuthFailureCode.mfaRejected,
          ('session_not_found', '403'): AuthFailureCode.sessionMissing,
          ('refresh_token_already_used', '400'): AuthFailureCode.sessionMissing,
        };
        cases.forEach((input, expected) {
          final failure = AuthFailure.from(
            AuthApiException(
              'mensaje interno',
              code: input.$1,
              statusCode: input.$2,
            ),
          );
          expect(failure.code, expected, reason: 'para ${input.$1}');
        });
      },
    );

    test('sin sesión en el SDK es un error de sesión, no de credenciales', () {
      final failure = AuthFailure.from(AuthSessionMissingException());
      expect(failure.code, AuthFailureCode.sessionMissing);
    });

    test('cualquier 429 se trata como límite de intentos', () {
      final failure = AuthFailure.from(
        AuthApiException('too many', statusCode: '429'),
      );
      expect(failure.code, AuthFailureCode.rateLimited);
    });

    test('un fallo de red del SDK es un error de red', () {
      final failure = AuthFailure.from(AuthRetryableFetchException());
      expect(failure.code, AuthFailureCode.network);
    });

    test('un timeout es un error de red', () {
      final failure = AuthFailure.from(TimeoutException('sin respuesta'));
      expect(failure.code, AuthFailureCode.network);
    });

    test('un error_code desconocido no se inventa: cae en genérico', () {
      final failure = AuthFailure.from(
        AuthApiException('algo raro', code: 'code_inedito', statusCode: '500'),
      );
      expect(failure.code, AuthFailureCode.unknown);
    });

    test('cualquier objeto ajeno al SDK cae en genérico', () {
      expect(
        AuthFailure.from(StateError('boom')).code,
        AuthFailureCode.unknown,
      );
      expect(AuthFailure.from('texto suelto').code, AuthFailureCode.unknown);
    });

    test('no re-envuelve un AuthFailure ya construido', () {
      const original = AuthFailure(AuthFailureCode.weakPassword);
      expect(identical(AuthFailure.from(original), original), isTrue);
    });

    test(
      'el mensaje interno de Supabase queda fuera de lo que ve el usuario',
      () {
        final failure = AuthFailure.from(
          AuthApiException(
            'Database error querying schema',
            code: 'unexpected_failure',
            statusCode: '500',
          ),
        );
        expect(failure.code, AuthFailureCode.unknown);
        // El detalle sirve para logs; la UI muestra el texto del ARB.
        expect(failure.debugDetail, contains('unexpected_failure'));
        expect(failure.toString(), 'AuthFailure(unknown)');
        expect(
          failure.toString(),
          isNot(contains('Database error querying schema')),
        );
      },
    );
  });
}
