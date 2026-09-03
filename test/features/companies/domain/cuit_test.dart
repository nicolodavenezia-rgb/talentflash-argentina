import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/companies/domain/cuit.dart';

/// T-027 — value object de CUIT.
///
/// Todos los CUIT de este archivo son sintéticos: se construyeron a partir de
/// prefijos y cuerpos arbitrarios calculando el dígito verificador con el
/// propio algoritmo. Ninguno pertenece a una empresa ni a una persona real.
void main() {
  // Válidos "normales": el verificador sale del camino 11 - (suma % 11).
  const validos = <String>[
    '30-71234567-1',
    '20-12345678-6',
    '33-99999999-4',
    '30-70000001-6',
    '30-70000005-9',
  ];

  group('dígito verificador (módulo 11)', () {
    test('acepta CUIT sintéticos con verificador correcto', () {
      for (final cuit in validos) {
        expect(Cuit.isValid(cuit), isTrue, reason: '$cuit debería ser válido');
      }
    });

    test('rechaza el mismo CUIT con cualquier otro verificador', () {
      // Control negativo apareado con el positivo de arriba: si `isValid`
      // devolviera true a ciegas, este bloque lo delataría.
      for (final cuit in validos) {
        final correcto = int.parse(cuit[cuit.length - 1]);
        for (var d = 0; d <= 9; d++) {
          if (d == correcto) {
            continue;
          }
          final alterado = '${cuit.substring(0, cuit.length - 1)}$d';
          expect(
            Cuit.isValid(alterado),
            isFalse,
            reason: '$alterado no debería ser válido',
          );
          expect(Cuit.validate(alterado), CuitIssue.checkDigit);
        }
      }
    });

    test('caso especial: 11 se informa como 0', () {
      // Suma múltiplo de 11 -> 11 - 0 = 11 -> el verificador es 0.
      expect(Cuit.checkDigitOf('2712345678'), 0);
      expect(Cuit.isValid('27-12345678-0'), isTrue);
      expect(Cuit.checkDigitOf('2000000006'), 0);
      expect(Cuit.isValid('20-00000006-0'), isTrue);
    });

    test('caso especial: 10 se informa como 9', () {
      // Suma ≡ 1 (mod 11) -> 11 - 1 = 10 -> el verificador es 9.
      expect(Cuit.checkDigitOf('2000000001'), 9);
      expect(Cuit.isValid('20-00000001-9'), isTrue);
      // Y el 0 que produciría confundir 10 con 0 se rechaza.
      expect(Cuit.isValid('20-00000001-0'), isFalse);
    });

    test('checkDigitOf exige exactamente 10 dígitos', () {
      expect(Cuit.checkDigitOf('307123456'), isNull);
      expect(Cuit.checkDigitOf('30712345678'), isNull);
      expect(Cuit.checkDigitOf('30712345A7'), isNull);
      expect(Cuit.checkDigitOf(''), isNull);
    });

    test('no usa aritmética de punto flotante', () {
      // Un CUIT entero supera 2^53 en JS si se lo convierte a número. El
      // algoritmo trabaja dígito a dígito, así que dos CUIT que colisionarían
      // como double se distinguen igual.
      expect(Cuit.checkDigitOf('9999999999'), isNotNull);
      expect(Cuit.parse('30-71234567-1')!.digits, '30712345671');
    });
  });

  group('normalización y forma canónica', () {
    test('acepta las tres escrituras del mismo CUIT', () {
      for (final entrada in <String>[
        '30712345671',
        '30-71234567-1',
        '30 71234567 1',
        '  30-71234567-1  ',
      ]) {
        final cuit = Cuit.parse(entrada);
        expect(cuit, isNotNull, reason: '$entrada debería parsear');
        expect(cuit!.formatted, '30-71234567-1');
        expect(cuit.digits, '30712345671');
      }
    });

    test('conserva los ceros iniciales', () {
      final cuit = Cuit.parse('20-00000006-0');
      expect(cuit, isNotNull);
      expect(cuit!.digits, '20000000060');
      expect(cuit.formatted, '20-00000006-0');
      expect(cuit.prefix, '20');
    });

    test('rechaza el separador fuera de posición', () {
      // Once dígitos y verificador correcto, pero los guiones están corridos:
      // casi siempre es un dígito mal tipeado.
      expect(Cuit.validate('30-7123456-71'), CuitIssue.wrongLength);
      expect(Cuit.validate('3-071234567-1'), CuitIssue.wrongLength);
      expect(Cuit.validate('307-1234567-1'), CuitIssue.wrongLength);
    });

    test('formatPartial agrupa sin validar', () {
      expect(Cuit.formatPartial('30712345678'), '30-71234567-8');
      expect(Cuit.formatPartial('307'), '307');
      expect(Cuit.formatPartial('30-7123'), '307123');
      expect(Cuit.formatPartial(''), '');
    });
  });

  group('motivos de rechazo', () {
    test('vacío', () {
      expect(Cuit.validate(''), CuitIssue.empty);
      expect(Cuit.validate('   '), CuitIssue.empty);
      expect(Cuit.validate('--'), CuitIssue.empty);
    });

    test('caracteres no admitidos', () {
      expect(Cuit.validate('30-7123456A-1'), CuitIssue.invalidCharacters);
      expect(Cuit.validate('30.71234567.1'), CuitIssue.invalidCharacters);
      expect(Cuit.validate('CUIT 30-71234567-1'), CuitIssue.invalidCharacters);
      expect(Cuit.validate('30-71234567-1;'), CuitIssue.invalidCharacters);
    });

    test('largo distinto de 11', () {
      expect(Cuit.validate('123'), CuitIssue.wrongLength);
      expect(Cuit.validate('3071234567'), CuitIssue.wrongLength);
      expect(Cuit.validate('307123456712'), CuitIssue.wrongLength);
    });

    test('verificador incorrecto', () {
      expect(Cuit.validate('30-71234567-8'), CuitIssue.checkDigit);
      expect(Cuit.validate('20-12345678-9'), CuitIssue.checkDigit);
    });

    test('parse devuelve null exactamente cuando validate falla', () {
      for (final entrada in <String>[
        '',
        '123',
        '30-71234567-8',
        '30-7123456A-1',
        '30-7123456-71',
        '30-71234567-1',
        '20-00000001-9',
      ]) {
        expect(
          Cuit.parse(entrada) == null,
          Cuit.validate(entrada) != null,
          reason: 'parse y validate discrepan para "$entrada"',
        );
      }
    });
  });

  group('identidad del value object', () {
    test('dos CUIT con los mismos dígitos son iguales', () {
      final a = Cuit.parse('30-71234567-1');
      final b = Cuit.parse('30712345671');
      final c = Cuit.parse('30 71234567 1');
      expect(a, b);
      expect(b, c);
      expect(a.hashCode, b.hashCode);
    });

    test('CUIT distintos no son iguales', () {
      expect(Cuit.parse('30-71234567-1'), isNot(Cuit.parse('20-12345678-6')));
    });

    test('toString devuelve la forma canónica', () {
      expect(Cuit.parse('30712345671').toString(), '30-71234567-1');
    });
  });
}
