import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/authenticated_user.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/authentication/domain/session_assurance.dart';

/// El nivel de la sesión se compara igual que `private.caller_is_aal2()` en
/// la migración 0028: exacto y fail-closed.
void main() {
  group('SessionAssurance.fromClaim', () {
    test('solo aal1 y aal2 exactos se reconocen', () {
      expect(SessionAssurance.fromClaim('aal1'), SessionAssurance.aal1);
      expect(SessionAssurance.fromClaim('aal2'), SessionAssurance.aal2);
    });

    test('la caja equivocada, espacios y niveles inventados no cuentan', () {
      for (final raw in <Object?>[
        'AAL2',
        'aal2 ',
        ' aal2',
        'aal3',
        'aal',
        '',
        null,
        2,
        <String>['aal2'],
      ]) {
        expect(
          SessionAssurance.fromClaim(raw),
          SessionAssurance.unknown,
          reason: 'para $raw',
        );
      }
    });

    test('solo aal2 habilita el segundo factor', () {
      expect(SessionAssurance.aal2.isSecondFactorVerified, isTrue);
      expect(SessionAssurance.aal1.isSecondFactorVerified, isFalse);
      expect(SessionAssurance.unknown.isSecondFactorVerified, isFalse);
    });
  });

  group('AuthStatus y el nivel de la sesión', () {
    const user = AuthenticatedUser(
      id: 'abc',
      email: 'admin@dev.talentflash.test',
      role: BusinessRole.admin,
    );

    test('sin sesión válida el nivel es desconocido', () {
      expect(const AuthStatusUnknown().assurance, SessionAssurance.unknown);
      expect(const AuthStatusSignedOut().assurance, SessionAssurance.unknown);
      expect(
        const AuthStatusInconsistent(userId: 'abc').assurance,
        SessionAssurance.unknown,
      );
      expect(const AuthStatusSignedOut().hasSecondFactorVerified, isFalse);
    });

    test('una sesión sin nivel declarado no tiene segundo factor', () {
      const status = AuthStatusSignedIn(user);
      expect(status.assurance, SessionAssurance.unknown);
      expect(status.hasSecondFactorVerified, isFalse);
    });

    test(
      'mismo usuario con aal1 y con aal2 son estados DISTINTOS: el cambio de '
      'nivel se propaga aunque la identidad no cambie',
      () {
        const aal1 = AuthStatusSignedIn(user, assurance: SessionAssurance.aal1);
        const aal2 = AuthStatusSignedIn(user, assurance: SessionAssurance.aal2);

        expect(aal1 == aal2, isFalse);
        expect(aal1.hashCode == aal2.hashCode, isFalse);
        // La identidad sí es la misma: nada que dependa del usuario se mueve.
        expect(aal1.user, aal2.user);
        expect(aal1.role, aal2.role);
        expect(aal1.hasSecondFactorVerified, isFalse);
        expect(aal2.hasSecondFactorVerified, isTrue);
      },
    );

    test('dos estados iguales siguen siendo iguales', () {
      const a = AuthStatusSignedIn(user, assurance: SessionAssurance.aal2);
      const b = AuthStatusSignedIn(user, assurance: SessionAssurance.aal2);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('aal2'));
    });
  });
}
