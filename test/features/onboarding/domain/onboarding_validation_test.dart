import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/onboarding/domain/onboarding_validation.dart';

void main() {
  group('mayoría de edad por fecha calendario', () {
    // Referencia fija para que los casos frontera no dependan del reloj.
    final today = DateTime(2026, 8, 31);

    test('quien cumple 18 exactamente HOY puede', () {
      expect(
        OnboardingValidation.isAdult(DateTime(2008, 8, 31), on: today),
        isTrue,
      );
      expect(
        OnboardingValidation.validateBirthDate('31/08/2008', today: today),
        isNull,
      );
    });

    test('quien cumple 18 MAÑANA todavía no puede', () {
      expect(
        OnboardingValidation.isAdult(DateTime(2008, 9, 1), on: today),
        isFalse,
      );
      expect(
        OnboardingValidation.validateBirthDate('01/09/2008', today: today),
        BirthDateIssue.underage,
      );
    });

    test('29 de febrero: los 18 caen el 1/3 de un año no bisiesto', () {
      final birth = DateTime(2008, 2, 29);
      expect(
        OnboardingValidation.isAdult(birth, on: DateTime(2026, 2, 28)),
        isFalse,
        reason: 'el 28/2 todavía no cumplió (mismo redondeo que el servidor)',
      );
      expect(
        OnboardingValidation.isAdult(birth, on: DateTime(2026, 3, 1)),
        isTrue,
      );
    });

    test('una fecha futura se señala como tal', () {
      expect(
        OnboardingValidation.validateBirthDate('01/01/2030', today: today),
        BirthDateIssue.inFuture,
      );
    });

    test('fechas inexistentes o mal tipeadas no pasan', () {
      expect(OnboardingValidation.parseBirthDate('31/02/2000'), isNull);
      expect(OnboardingValidation.parseBirthDate('2000-01-01'), isNull);
      expect(OnboardingValidation.parseBirthDate('touche'), isNull);
      expect(
        OnboardingValidation.validateBirthDate('31/02/2000', today: today),
        BirthDateIssue.invalidFormat,
      );
      expect(
        OnboardingValidation.validateBirthDate('', today: today),
        BirthDateIssue.empty,
      );
    });

    test('el formato DD/MM/AAAA estricto sí parsea', () {
      expect(
        OnboardingValidation.parseBirthDate('05/11/1993'),
        DateTime(1993, 11, 5),
      );
      expect(
        OnboardingValidation.parseBirthDate(' 5/1/1993 '),
        DateTime(1993, 1, 5),
      );
    });
  });

  group('CUIT: normalización y formato aprobado', () {
    test('se normaliza a XX-XXXXXXXX-X', () {
      expect(
        OnboardingValidation.normalizeCuit('30 71234567 1'),
        '30-71234567-1',
      );
      expect(
        OnboardingValidation.normalizeCuit('30712345671'),
        '30-71234567-1',
      );
      expect(
        OnboardingValidation.normalizeCuit('30-71234567-1'),
        '30-71234567-1',
      );
    });

    test('largo incorrecto se rechaza', () {
      expect(OnboardingValidation.validateCuit(''), CuitIssue.empty);
      expect(OnboardingValidation.validateCuit('123'), CuitIssue.wrongLength);
      expect(
        OnboardingValidation.validateCuit('30-71234567-19'),
        CuitIssue.wrongLength,
      );
      expect(OnboardingValidation.validateCuit('30-71234567-1'), isNull);
    });

    // T-027: el wizard delega en `Cuit`, así que el dígito verificador se
    // valida ya en el formulario. La cobertura exhaustiva del algoritmo vive
    // en test/features/companies/domain/cuit_test.dart.
    test('el dígito verificador se valida desde el wizard', () {
      expect(
        OnboardingValidation.validateCuit('30-71234567-8'),
        CuitIssue.checkDigit,
      );
      expect(OnboardingValidation.validateCuit('30-71234567-1'), isNull);
    });
  });

  group('sitio web opcional', () {
    test('vacío es válido y queda en null', () {
      expect(OnboardingValidation.normalizeWebsite('  '), isNull);
      expect(OnboardingValidation.validateWebsite(''), isNull);
    });

    test('sin esquema se completa https://', () {
      expect(
        OnboardingValidation.normalizeWebsite('talentflash.com.ar'),
        'https://talentflash.com.ar',
      );
      expect(
        OnboardingValidation.validateWebsite('talentflash.com.ar'),
        isNull,
      );
    });

    test('una no-URL se rechaza', () {
      expect(
        OnboardingValidation.validateWebsite('no es una url'),
        WebsiteIssue.invalid,
      );
    });
  });

  group('nombre', () {
    test('vacío o de una letra no alcanza', () {
      expect(OnboardingValidation.validateFullName('  '), FullNameIssue.empty);
      expect(
        OnboardingValidation.validateFullName('A'),
        FullNameIssue.tooShort,
      );
      expect(OnboardingValidation.validateFullName('Ana Pérez'), isNull);
    });
  });
}
