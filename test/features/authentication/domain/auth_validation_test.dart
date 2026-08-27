import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_validation.dart';

void main() {
  group('normalizeEmail', () {
    test('recorta espacios y pasa a minúsculas', () {
      expect(
        AuthValidation.normalizeEmail('  Persona@Dev.TalentFlash.Test '),
        'persona@dev.talentflash.test',
      );
    });

    test('deja intacto un correo ya normalizado', () {
      expect(
        AuthValidation.normalizeEmail('persona@dev.talentflash.test'),
        'persona@dev.talentflash.test',
      );
    });
  });

  group('validateEmail', () {
    test(
      'acepta correos válidos, incluidos los que traen espacios al borde',
      () {
        expect(AuthValidation.validateEmail('persona@ejemplo.com'), isNull);
        expect(AuthValidation.validateEmail('  persona@ejemplo.com  '), isNull);
        expect(
          AuthValidation.validateEmail('nombre.apellido@sub.ejemplo.com.ar'),
          isNull,
        );
        expect(
          AuthValidation.validateEmail('mozo+turno.noche@ejemplo.com'),
          isNull,
        );
      },
    );

    test('marca el campo vacío como requerido', () {
      expect(AuthValidation.validateEmail(''), EmailIssue.required);
      expect(AuthValidation.validateEmail('   '), EmailIssue.required);
    });

    test('rechaza formatos imposibles', () {
      for (final invalid in <String>[
        'persona',
        'persona@',
        '@ejemplo.com',
        'persona@ejemplo',
        'persona ejemplo@correo.com',
        'persona@@ejemplo.com',
      ]) {
        expect(
          AuthValidation.validateEmail(invalid),
          EmailIssue.invalidFormat,
          reason: 'debería rechazar "$invalid"',
        );
      }
    });
  });

  group('validatePassword', () {
    test('el mínimo es el mismo que exige Supabase (SECURITY.md §2)', () {
      expect(AuthValidation.minPasswordLength, 10);
    });

    test('acepta desde el mínimo exacto', () {
      expect(AuthValidation.validatePassword('1234567890'), isNull);
      expect(AuthValidation.validatePassword('contraseña larga'), isNull);
    });

    test('rechaza vacía y corta', () {
      expect(AuthValidation.validatePassword(''), PasswordIssue.required);
      expect(
        AuthValidation.validatePassword('123456789'),
        PasswordIssue.tooShort,
      );
    });

    test('no recorta espacios: son caracteres válidos de la contraseña', () {
      expect(
        AuthValidation.validatePassword('         '),
        PasswordIssue.tooShort,
      );
      expect(AuthValidation.validatePassword('          '), isNull);
    });

    test('no impone reglas de composición arbitrarias', () {
      expect(AuthValidation.validatePassword('aaaaaaaaaa'), isNull);
    });
  });

  group('validatePasswordConfirmation', () {
    test('acepta la repetición exacta', () {
      expect(
        AuthValidation.validatePasswordConfirmation(
          'contra12345',
          'contra12345',
        ),
        isNull,
      );
    });

    test('pide completar la confirmación vacía', () {
      expect(
        AuthValidation.validatePasswordConfirmation('contra12345', ''),
        PasswordConfirmationIssue.required,
      );
    });

    test('detecta diferencias, incluida la de mayúsculas', () {
      expect(
        AuthValidation.validatePasswordConfirmation(
          'contra12345',
          'Contra12345',
        ),
        PasswordConfirmationIssue.mismatch,
      );
    });
  });
}
