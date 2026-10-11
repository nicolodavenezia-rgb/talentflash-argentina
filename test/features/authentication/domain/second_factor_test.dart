import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/second_factor.dart';

void main() {
  group('TotpEnrollment', () {
    const enrollment = TotpEnrollment(
      factorId: 'factor-1',
      friendlyName: 'TalentFlash · 08/09/2026 14:32',
      secret: 'JBSWY3DPEHPK3PXP',
      uri: 'otpauth://totp/TalentFlash?secret=JBSWY3DPEHPK3PXP',
    );

    test('agrupa la clave de a cuatro para la carga manual', () {
      expect(enrollment.secretGrouped, 'JBSW Y3DP EHPK 3PXP');
    });

    test('deletrea la clave para el lector de pantalla', () {
      expect(enrollment.secretSpelled, 'J B S W Y 3 D P E H P K 3 P X P');
    });

    test('toString no revela el secreto ni la URI (puede caer en un log)', () {
      final text = enrollment.toString();
      expect(text, contains('factor-1'));
      expect(text, isNot(contains('JBSWY3DPEHPK3PXP')));
      expect(text, isNot(contains('otpauth')));
    });
  });

  group('SecondFactorChallenge', () {
    final expiresAt = DateTime(2026, 9, 8, 14, 35);
    final challenge = SecondFactorChallenge(
      id: 'challenge-1',
      factorId: 'factor-1',
      expiresAt: expiresAt,
    );

    test('vigente con margen de sobra', () {
      expect(
        challenge.isExpiredAt(expiresAt.subtract(const Duration(minutes: 1))),
        isFalse,
      );
    });

    test('se considera vencido dentro del margen de seguridad', () {
      expect(
        challenge.isExpiredAt(expiresAt.subtract(const Duration(seconds: 5))),
        isTrue,
        reason: 'un desafío que vence en el viaje no sirve',
      );
      expect(challenge.isExpiredAt(expiresAt), isTrue);
      expect(
        challenge.isExpiredAt(expiresAt.add(const Duration(minutes: 1))),
        isTrue,
      );
    });

    test('igualdad por valor', () {
      expect(
        challenge,
        SecondFactorChallenge(
          id: 'challenge-1',
          factorId: 'factor-1',
          expiresAt: expiresAt,
        ),
      );
      expect(
        challenge,
        isNot(
          SecondFactorChallenge(
            id: 'challenge-2',
            factorId: 'factor-1',
            expiresAt: expiresAt,
          ),
        ),
      );
    });
  });

  group('SecondFactor', () {
    test('igualdad por valor', () {
      final created = DateTime(2026, 9, 8);
      expect(
        SecondFactor(id: 'f', friendlyName: 'a', createdAt: created),
        SecondFactor(id: 'f', friendlyName: 'a', createdAt: created),
      );
      expect(const SecondFactor(id: 'f'), isNot(const SecondFactor(id: 'g')));
    });
  });
}
