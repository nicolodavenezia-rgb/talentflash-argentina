import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/authenticated_user.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';

void main() {
  group('BusinessRole.fromClaim', () {
    test('traduce los tres claims del enum user_role', () {
      expect(BusinessRole.fromClaim('candidate'), BusinessRole.candidate);
      expect(BusinessRole.fromClaim('company'), BusinessRole.company);
      expect(BusinessRole.fromClaim('admin'), BusinessRole.admin);
    });

    test('los claims coinciden con el enum de Postgres', () {
      expect(BusinessRole.values.map((role) => role.claim).toList(), <String>[
        'candidate',
        'company',
        'admin',
      ]);
    });

    test('devuelve null si el claim falta', () {
      expect(BusinessRole.fromClaim(null), isNull);
    });

    test(
      'devuelve null ante valores desconocidos, nunca un rol por defecto',
      () {
        for (final invalid in <Object?>[
          '',
          'candidato',
          'empresa',
          'moderator',
          'superadmin',
          'CANDIDATE',
          ' admin',
          'admin ',
          42,
          true,
          <String>['admin'],
          <String, String>{'role': 'admin'},
        ]) {
          expect(
            BusinessRole.fromClaim(invalid),
            isNull,
            reason: 'no debería resolver un rol para $invalid',
          );
        }
      },
    );

    test('nunca asume admin: un claim ilegible no habilita nada', () {
      expect(BusinessRole.fromClaim('adm1n'), isNot(BusinessRole.admin));
      expect(BusinessRole.fromClaim('adm1n'), isNull);
    });
  });

  group('AuthStatus', () {
    const user = AuthenticatedUser(
      id: 'abc',
      email: 'persona@dev.talentflash.test',
      role: BusinessRole.company,
    );

    test('solo el estado inicial queda sin resolver', () {
      expect(const AuthStatusUnknown().isResolved, isFalse);
      expect(const AuthStatusSignedOut().isResolved, isTrue);
      expect(const AuthStatusSignedIn(user).isResolved, isTrue);
      expect(const AuthStatusInconsistent(userId: 'abc').isResolved, isTrue);
    });

    test('solo una sesión válida expone rol y usuario', () {
      expect(const AuthStatusSignedIn(user).role, BusinessRole.company);
      expect(const AuthStatusSignedIn(user).user, user);
      expect(const AuthStatusUnknown().role, isNull);
      expect(const AuthStatusSignedOut().user, isNull);
      expect(
        const AuthStatusInconsistent(userId: 'abc', rawClaim: 'x').role,
        isNull,
      );
      expect(
        const AuthStatusInconsistent(userId: 'abc', rawClaim: 'x').user,
        isNull,
      );
    });
  });
}
