import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/data/auth_repository.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_failure.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/authentication/providers/auth_controller.dart';
import 'package:talentflash_argentina/features/authentication/providers/auth_providers.dart';

import '../../../support/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeAuthRepository();
    container = ProviderContainer.test(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() => repository.dispose());

  AuthController controller() =>
      container.read(authControllerProvider.notifier);
  AsyncValue<AuthActionOutcome?> state() =>
      container.read(authControllerProvider);

  group('estado del controlador', () {
    test('arranca sin resultado ni error', () {
      expect(state(), const AsyncValue<AuthActionOutcome?>.data(null));
    });

    test('un login exitoso deja el resultado signedIn', () async {
      await controller().signIn(
        email: 'candidato1@dev.talentflash.test',
        password: 'password123',
      );

      expect(state().value, AuthActionOutcome.signedIn);
      expect(state().hasError, isFalse);
      expect(repository.calls, <String>['signIn']);
    });

    test(
      'un fallo queda como AuthFailure tipado, no como excepción del SDK',
      () async {
        repository.nextFailure = const AuthFailure(
          AuthFailureCode.invalidCredentials,
        );

        await controller().signIn(
          email: 'candidato1@dev.talentflash.test',
          password: 'incorrecta1',
        );

        expect(state().hasError, isTrue);
        expect(state().error, isA<AuthFailure>());
        expect(
          (state().error! as AuthFailure).code,
          AuthFailureCode.invalidCredentials,
        );
      },
    );

    test('mientras la acción corre el estado es loading', () async {
      final gate = Completer<void>();
      repository.pendingAction = gate;

      final pending = controller().signIn(
        email: 'candidato1@dev.talentflash.test',
        password: 'password123',
      );
      expect(state().isLoading, isTrue);

      gate.complete();
      await pending;
      expect(state().isLoading, isFalse);
    });

    test('un segundo submit durante la carga no duplica la llamada', () async {
      final gate = Completer<void>();
      repository.pendingAction = gate;

      final first = controller().signIn(
        email: 'candidato1@dev.talentflash.test',
        password: 'password123',
      );
      await controller().signIn(
        email: 'candidato1@dev.talentflash.test',
        password: 'password123',
      );

      gate.complete();
      await first;
      expect(repository.calls, <String>['signIn']);
    });

    test('reset limpia el error anterior', () async {
      repository.nextFailure = const AuthFailure(AuthFailureCode.network);
      await controller().signIn(email: 'a@b.com', password: 'password123');
      expect(state().hasError, isTrue);

      controller().reset();

      expect(state().hasError, isFalse);
      expect(state().value, isNull);
    });
  });

  group('alta de cuenta', () {
    test('propaga el rol pedido al repositorio', () async {
      await controller().signUp(
        email: 'empresa@dev.talentflash.test',
        password: 'password12345',
        role: SignUpRole.company,
      );

      expect(repository.lastSignUpRole, SignUpRole.company);
      expect(state().value, AuthActionOutcome.signedUpAndSignedIn);
    });

    test('distingue el alta que necesita confirmar el correo', () async {
      repository.signUpOutcome = SignUpOutcome.emailConfirmationRequired;

      await controller().signUp(
        email: 'nueva@dev.talentflash.test',
        password: 'password12345',
        role: SignUpRole.candidate,
      );

      expect(state().value, AuthActionOutcome.signUpNeedsEmailConfirmation);
    });
  });

  group('recuperación y cierre de sesión', () {
    test('la recuperación informa que el correo fue solicitado', () async {
      await controller().sendPasswordRecoveryEmail(
        'candidato1@dev.talentflash.test',
      );

      expect(state().value, AuthActionOutcome.recoveryEmailSent);
      expect(repository.calls, <String>['recover']);
    });

    test('cerrar sesión deja el estado sin sesión', () async {
      repository.emitSignedIn(BusinessRole.candidate);
      await controller().signOut();

      expect(state().value, AuthActionOutcome.signedOut);
      expect(repository.currentStatus, isA<AuthStatusSignedOut>());
    });
  });

  group('providers derivados', () {
    test('el estado inicial no está resuelto y no expone rol', () {
      expect(container.read(authStatusProvider), isA<AuthStatusUnknown>());
      expect(container.read(authResolvedProvider), isFalse);
      expect(container.read(businessRoleProvider), isNull);
      expect(container.read(currentAuthUserProvider), isNull);
    });

    test('siguen los eventos del repositorio', () async {
      // Suscribe los providers antes de emitir.
      container.listen(authStatusProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      repository.emitSignedIn(BusinessRole.company);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(authResolvedProvider), isTrue);
      expect(container.read(businessRoleProvider), BusinessRole.company);
      expect(
        container.read(currentAuthUserProvider)?.role,
        BusinessRole.company,
      );

      repository.emit(
        const AuthStatusInconsistent(userId: 'x', rawClaim: 'moderator'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(container.read(businessRoleProvider), isNull);
      expect(container.read(authResolvedProvider), isTrue);
    });
  });
}
