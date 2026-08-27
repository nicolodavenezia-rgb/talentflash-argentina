import 'dart:async';

import 'package:talentflash_argentina/features/authentication/data/auth_repository.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_failure.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/authenticated_user.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';

/// Doble de prueba del repositorio de autenticación.
///
/// Permite ejercitar providers, guards y pantallas sin Supabase: los tests
/// deciden qué estado emite y qué acción falla.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthStatus initialStatus = const AuthStatusUnknown()})
    : _status = initialStatus;

  final StreamController<AuthStatus> _controller =
      StreamController<AuthStatus>.broadcast();

  AuthStatus _status;

  /// Llamadas registradas, para verificar qué pidió la UI.
  final List<String> calls = <String>[];

  /// Correo y contraseña de la última llamada.
  String? lastEmail;
  String? lastPassword;
  SignUpRole? lastSignUpRole;

  /// Error a lanzar en la próxima acción (se consume al usarse).
  AuthFailure? nextFailure;

  /// Resultado del próximo alta.
  SignUpOutcome signUpOutcome = SignUpOutcome.signedIn;

  /// Retiene la próxima acción hasta que el test la complete, para poder
  /// observar el estado de carga.
  Completer<void>? pendingAction;

  @override
  AuthStatus get currentStatus => _status;

  @override
  Stream<AuthStatus> statusChanges() async* {
    yield _status;
    yield* _controller.stream;
  }

  /// Simula un evento del proveedor de identidad.
  void emit(AuthStatus status) {
    _status = status;
    _controller.add(status);
  }

  void emitSignedIn(
    BusinessRole role, {
    String email = 'persona@dev.talentflash.test',
  }) {
    emit(
      AuthStatusSignedIn(
        AuthenticatedUser(id: 'user-${role.claim}', email: email, role: role),
      ),
    );
  }

  Future<void> dispose() => _controller.close();

  @override
  Future<SignUpOutcome> signUpWithEmail({
    required String email,
    required String password,
    required SignUpRole role,
  }) async {
    calls.add('signUp');
    lastEmail = email;
    lastPassword = password;
    lastSignUpRole = role;
    await _awaitPending();
    _throwIfProgrammed();
    if (signUpOutcome == SignUpOutcome.signedIn) {
      emitSignedIn(role.businessRole, email: email);
    }
    return signUpOutcome;
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    calls.add('signIn');
    lastEmail = email;
    lastPassword = password;
    await _awaitPending();
    _throwIfProgrammed();
  }

  @override
  Future<void> sendPasswordRecoveryEmail(String email) async {
    calls.add('recover');
    lastEmail = email;
    await _awaitPending();
    _throwIfProgrammed();
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    await _awaitPending();
    _throwIfProgrammed();
    emit(const AuthStatusSignedOut());
  }

  Future<void> _awaitPending() async {
    final pending = pendingAction;
    if (pending != null) {
      await pending.future;
    }
  }

  void _throwIfProgrammed() {
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
  }
}
