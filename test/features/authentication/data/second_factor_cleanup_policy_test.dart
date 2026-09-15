import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/data/second_factor_cleanup_policy.dart';

/// El clasificador de respuestas y el registro de intentos, por separado del
/// repositorio.
///
/// Lo que se fija acá es la **dirección del error**: ante cualquier duda, el
/// intento tiene que quedar sin resolver. Resolverlo de más es lo que habilita
/// una baja; dejarlo sin resolver solo deja un factor pendiente.
void main() {
  List<int> cuerpo(Object? json) => utf8.encode(jsonEncode(json));
  final rechazo = {
    'code': 422,
    'error_code': 'mfa_verification_failed',
    'msg': 'Invalid TOTP code entered',
  };

  group('isDefinitiveRejectionResponse: solo 4xx con un código conocido', () {
    test('un 422 con un código de la lista SÍ es un rechazo', () {
      expect(isDefinitiveRejectionResponse(422, cuerpo(rechazo)), isTrue);
      for (final codigo in const [
        'mfa_verification_failed',
        'mfa_challenge_expired',
        'mfa_verification_rejected',
        'mfa_ip_address_mismatch',
      ]) {
        expect(
          isDefinitiveRejectionResponse(422, cuerpo({'error_code': codigo})),
          isTrue,
          reason: '$codigo es un rechazo explícito del servidor',
        );
      }
    });

    test('un 5xx NO lo es, aunque el cuerpo traiga un código conocido: el '
        'servidor pudo haber verificado y caerse después', () {
      for (final status in const [500, 502, 503, 504]) {
        expect(
          isDefinitiveRejectionResponse(status, cuerpo(rechazo)),
          isFalse,
          reason: '$status es incertidumbre, no un rechazo',
        );
      }
    });

    test('una redirección tampoco: el cuerpo de un 3xx no es el desenlace', () {
      for (final status in const [301, 302, 307, 308]) {
        expect(isDefinitiveRejectionResponse(status, cuerpo(rechazo)), isFalse);
      }
    });

    test('un 2xx con un cuerpo contradictorio tampoco', () {
      expect(isDefinitiveRejectionResponse(200, cuerpo(rechazo)), isFalse);
      expect(isDefinitiveRejectionResponse(204, cuerpo(rechazo)), isFalse);
    });

    test('un 4xx con un código desconocido o sin código no resuelve', () {
      expect(
        isDefinitiveRejectionResponse(422, cuerpo({'error_code': 'otro'})),
        isFalse,
      );
      expect(isDefinitiveRejectionResponse(400, cuerpo({})), isFalse);
      expect(
        isDefinitiveRejectionResponse(429, cuerpo({'code': 429})),
        isFalse,
        reason: 'un `code` numérico no es un código de error',
      );
    });

    test('un cuerpo ilegible o que no es un objeto no resuelve', () {
      expect(isDefinitiveRejectionResponse(422, utf8.encode('')), isFalse);
      expect(
        isDefinitiveRejectionResponse(422, utf8.encode('{no json')),
        isFalse,
      );
      expect(isDefinitiveRejectionResponse(422, cuerpo([1, 2, 3])), isFalse);
      expect(isDefinitiveRejectionResponse(422, const [0xff, 0xfe]), isFalse);
    });

    test('la forma nueva, con el código en `code` como texto, sí resuelve', () {
      expect(
        isDefinitiveRejectionResponse(
          422,
          cuerpo({'code': 'mfa_verification_failed'}),
        ),
        isTrue,
      );
    });
  });

  group(
    'consecuencia: un estado que no resuelve deja el intento protegido',
    () {
      test(
        'tras un 503 con cuerpo de rechazo, el intento sigue sin resolver',
        () {
          final politica = SecondFactorCleanupPolicy()..recordEnrolled('F');
          final intento = politica.beginVerifyAttempt('F');
          expect(politica.unresolvedVerifications('F'), 1);

          if (isDefinitiveRejectionResponse(503, cuerpo(rechazo))) {
            politica.rejectVerifyAttempt(intento);
          }

          expect(
            politica.unresolvedVerifications('F'),
            1,
            reason: 'un 5xx no puede dar por rechazado un intento',
          );
        },
      );

      test('tras un 422 legítimo, el intento sí queda resuelto', () {
        final politica = SecondFactorCleanupPolicy()..recordEnrolled('F');
        final intento = politica.beginVerifyAttempt('F');

        if (isDefinitiveRejectionResponse(422, cuerpo(rechazo))) {
          politica.rejectVerifyAttempt(intento);
        }

        expect(politica.unresolvedVerifications('F'), 0);
      });

      test('un rechazo resuelve SOLO su intento, nunca uno anterior', () {
        final politica = SecondFactorCleanupPolicy()..recordEnrolled('F');
        politica.beginVerifyAttempt('F'); // se pierde la respuesta
        final segundo = politica.beginVerifyAttempt('F');

        politica.rejectVerifyAttempt(segundo);

        expect(politica.unresolvedVerifications('F'), 1);
      });

      test('resolver dos veces el mismo intento no cuenta dos veces', () {
        final politica = SecondFactorCleanupPolicy()..recordEnrolled('F');
        final a = politica.beginVerifyAttempt('F');
        politica.beginVerifyAttempt('F');

        politica
          ..rejectVerifyAttempt(a)
          ..rejectVerifyAttempt(a);

        expect(politica.unresolvedVerifications('F'), 1);
      });
    },
  );

  group('la app no autoriza ninguna baja automática', () {
    test('ni siquiera con todas las precondiciones cumplidas: el endpoint de '
        'baja no es condicional', () {
      final politica = SecondFactorCleanupPolicy()..recordEnrolled('F');

      expect(SecondFactorCleanupPolicy.automaticUnenrollEnabled, isFalse);
      expect(
        politica.canAutoUnenroll('F'),
        isFalse,
        reason:
            'factor propio y sin intentos sin resolver, y aun así no se '
            'autoriza: ver automaticUnenrollEnabled',
      );
    });

    test('cambiar de cuenta descarta todo lo aprendido', () {
      final politica = SecondFactorCleanupPolicy()
        ..onSessionUser('usuario-1')
        ..recordEnrolled('F');
      politica.beginVerifyAttempt('F');
      expect(politica.unresolvedVerifications('F'), 1);

      politica.onSessionUser('usuario-2');

      expect(politica.unresolvedVerifications('F'), 0);
      expect(
        politica.canAutoUnenroll('F'),
        isFalse,
        reason: 'olvidar nunca puede habilitar una baja',
      );
    });
  });
}
