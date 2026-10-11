import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/authenticated_user.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/authentication/domain/session_assurance.dart';
import 'package:talentflash_argentina/features/authentication/providers/auth_providers.dart';

import '../../../support/fake_auth_repository.dart';

/// Propagación del nivel de la sesión: verificar el segundo factor cambia el
/// token, no la identidad, y la app tiene que enterarse igual.
void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;

  const admin = AuthenticatedUser(
    id: 'admin-1',
    email: 'admin@dev.talentflash.test',
    role: BusinessRole.admin,
  );

  Future<void> settle() async {
    // Dos vueltas del event loop: una para el stream de sesión y otra para
    // que Riverpod propague a los providers derivados.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    repository = FakeAuthRepository(
      initialStatus: const AuthStatusSignedIn(
        admin,
        assurance: SessionAssurance.aal1,
      ),
    );
    container = ProviderContainer.test(
      retry: (retryCount, error) => null,
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() => repository.dispose());

  test(
    'de aal1 a aal2 con el mismo usuario: la identidad no cambia y el nivel sí',
    () async {
      final users = <AuthenticatedUser?>[];
      final levels = <SessionAssurance>[];
      final verified = <bool>[];
      container.listen(
        currentAuthUserProvider,
        (_, next) => users.add(next),
        fireImmediately: true,
      );
      container.listen(
        sessionAssuranceProvider,
        (_, next) => levels.add(next),
        fireImmediately: true,
      );
      container.listen(
        secondFactorVerifiedProvider,
        (_, next) => verified.add(next),
        fireImmediately: true,
      );
      await settle();
      expect(container.read(sessionAssuranceProvider), SessionAssurance.aal1);
      expect(container.read(secondFactorVerifiedProvider), isFalse);

      // Lo que emite el SDK tras `mfaChallengeVerified`: misma cuenta, token
      // nuevo con `aal2`.
      repository.emit(
        const AuthStatusSignedIn(admin, assurance: SessionAssurance.aal2),
      );
      await settle();

      expect(container.read(sessionAssuranceProvider), SessionAssurance.aal2);
      expect(container.read(secondFactorVerifiedProvider), isTrue);
      expect(container.read(currentAuthUserProvider), admin);
      expect(container.read(businessRoleProvider), BusinessRole.admin);
      expect(levels, contains(SessionAssurance.aal2));
      expect(verified.last, isTrue);
      expect(
        users.where((user) => user == admin).length,
        1,
        reason:
            'la identidad se notificó una sola vez: el cambio de nivel no la '
            'reconstruye',
      );
    },
  );

  test('un refresco de token con el mismo nivel no mueve nada', () async {
    var notificaciones = 0;
    container.listen(sessionAssuranceProvider, (_, _) => notificaciones++);
    await settle();
    final antes = notificaciones;

    repository.emit(
      const AuthStatusSignedIn(admin, assurance: SessionAssurance.aal1),
    );
    await settle();

    expect(notificaciones, antes);
    expect(container.read(sessionAssuranceProvider), SessionAssurance.aal1);
  });

  test('cerrar sesión vuelve el nivel a desconocido', () async {
    container.listen(secondFactorVerifiedProvider, (_, _) {});
    repository.emit(
      const AuthStatusSignedIn(admin, assurance: SessionAssurance.aal2),
    );
    await settle();
    expect(container.read(secondFactorVerifiedProvider), isTrue);

    repository.emit(const AuthStatusSignedOut());
    await settle();

    expect(container.read(sessionAssuranceProvider), SessionAssurance.unknown);
    expect(container.read(secondFactorVerifiedProvider), isFalse);
    expect(container.read(currentAuthUserProvider), isNull);
  });

  test('un nuevo inicio de sesión arranca sin segundo factor', () async {
    container.listen(secondFactorVerifiedProvider, (_, _) {});
    repository.emit(
      const AuthStatusSignedIn(admin, assurance: SessionAssurance.aal2),
    );
    await settle();
    repository.emit(const AuthStatusSignedOut());
    await settle();

    // La cuenta tiene un factor verificado, pero ESTA sesión todavía no lo
    // confirmó: GoTrue emite aal1 y hay que desafiar de nuevo.
    repository.emit(
      const AuthStatusSignedIn(admin, assurance: SessionAssurance.aal1),
    );
    await settle();

    expect(container.read(secondFactorVerifiedProvider), isFalse);
  });

  test(
    'un claim ilegible o inconsistente nunca habilita el segundo factor',
    () async {
      container.listen(secondFactorVerifiedProvider, (_, _) {});
      repository.emit(
        const AuthStatusSignedIn(admin, assurance: SessionAssurance.unknown),
      );
      await settle();
      expect(container.read(secondFactorVerifiedProvider), isFalse);

      repository.emit(const AuthStatusInconsistent(userId: 'admin-1'));
      await settle();
      expect(container.read(secondFactorVerifiedProvider), isFalse);
      expect(
        container.read(sessionAssuranceProvider),
        SessionAssurance.unknown,
      );
    },
  );
}
