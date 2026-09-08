import 'dart:async';

import 'package:talentflash_argentina/features/authentication/data/auth_repository.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_failure.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/authenticated_user.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/authentication/domain/second_factor.dart';
import 'package:talentflash_argentina/features/authentication/domain/session_assurance.dart';

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

  // --- Segundo factor ---------------------------------------------------------

  /// Factores verificados que devuelve `listVerifiedSecondFactors`.
  List<SecondFactor> verifiedFactors = <SecondFactor>[];

  /// Alta que devuelve el próximo `enrollTotp` (el fake no genera secretos).
  TotpEnrollment nextEnrollment = const TotpEnrollment(
    factorId: 'factor-pendiente',
    friendlyName: 'TalentFlash · 08/09/2026 14:32',
    secret: 'JBSWY3DPEHPK3PXP',
    uri: 'otpauth://totp/TalentFlash%20Argentina:persona?secret=JBSWY3DPEHPK3PXP',
  );

  /// Vencimiento que se asigna al próximo desafío.
  DateTime nextChallengeExpiresAt = DateTime(2030);

  /// Fallos por método, consumidos al usarse. Un `nextFailure` global se lo
  /// comería la primera lectura del flujo y probaría el caso equivocado.
  AuthFailure? nextListFactorsFailure;
  AuthFailure? nextEnrollFailure;
  AuthFailure? nextChallengeFailure;
  AuthFailure? nextVerifyFailure;
  AuthFailure? nextDiscardFailure;

  /// Retiene la próxima operación de segundo factor.
  Completer<void>? pendingSecondFactorAction;

  int challengeCounter = 0;
  String? lastFriendlyName;
  String? lastChallengedFactorId;
  String? lastVerifiedFactorId;
  String? lastVerifiedChallengeId;
  String? lastVerifiedCode;
  final List<String> discardedFactorIds = <String>[];

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
    SessionAssurance assurance = SessionAssurance.aal1,
    String? id,
  }) {
    emit(
      AuthStatusSignedIn(
        AuthenticatedUser(
          id: id ?? 'user-${role.claim}',
          email: email,
          role: role,
        ),
        assurance: assurance,
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

  @override
  Future<List<SecondFactor>> listVerifiedSecondFactors() async {
    calls.add('listVerifiedSecondFactors');
    await _awaitPendingSecondFactor();
    _throwIf(nextListFactorsFailure, () => nextListFactorsFailure = null);
    return List<SecondFactor>.unmodifiable(verifiedFactors);
  }

  @override
  Future<TotpEnrollment> enrollTotp({required String friendlyName}) async {
    calls.add('enrollTotp');
    lastFriendlyName = friendlyName;
    await _awaitPendingSecondFactor();
    _throwIf(nextEnrollFailure, () => nextEnrollFailure = null);
    return nextEnrollment;
  }

  @override
  Future<SecondFactorChallenge> challengeSecondFactor(String factorId) async {
    calls.add('challengeSecondFactor:$factorId');
    lastChallengedFactorId = factorId;
    await _awaitPendingSecondFactor();
    _throwIf(nextChallengeFailure, () => nextChallengeFailure = null);
    challengeCounter++;
    return SecondFactorChallenge(
      id: 'challenge-$challengeCounter',
      factorId: factorId,
      expiresAt: nextChallengeExpiresAt,
    );
  }

  @override
  Future<void> verifySecondFactor({
    required String factorId,
    required String challengeId,
    required String code,
  }) async {
    calls.add('verifySecondFactor:$factorId');
    lastVerifiedFactorId = factorId;
    lastVerifiedChallengeId = challengeId;
    lastVerifiedCode = code;
    await _awaitPendingSecondFactor();
    _throwIf(nextVerifyFailure, () => nextVerifyFailure = null);
    // Igual que el SDK con `mfaChallengeVerified`: la sesión vigente vuelve a
    // emitirse con `aal2`, mismo usuario.
    final current = _status;
    if (current is AuthStatusSignedIn) {
      emit(
        AuthStatusSignedIn(current.authUser, assurance: SessionAssurance.aal2),
      );
    }
  }

  @override
  Future<void> discardPendingSecondFactor(String factorId) async {
    calls.add('discardPendingSecondFactor:$factorId');
    discardedFactorIds.add(factorId);
    _throwIf(nextDiscardFailure, () => nextDiscardFailure = null);
  }

  Future<void> _awaitPending() async {
    final pending = pendingAction;
    if (pending != null) {
      await pending.future;
    }
  }

  Future<void> _awaitPendingSecondFactor() async {
    final pending = pendingSecondFactorAction;
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

  void _throwIf(AuthFailure? failure, void Function() clear) {
    if (failure != null) {
      clear();
      throw failure;
    }
  }
}
