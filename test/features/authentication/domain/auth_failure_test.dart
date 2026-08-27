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
