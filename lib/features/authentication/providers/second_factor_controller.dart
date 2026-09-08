import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_status.dart';
import '../domain/second_factor.dart';
import 'auth_providers.dart';

/// Reloj inyectable: los tests fijan la hora para probar el vencimiento del
/// desafío sin esperar de verdad.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Estado de la pantalla de segundo factor. Tipo cerrado: la pantalla tiene
/// que dibujar cada caso, incluidos los que no son felices.
sealed class SecondFactorFlow {
  const SecondFactorFlow();
}

/// Todavía no se pidió nada al servidor.
final class SecondFactorIdle extends SecondFactorFlow {
  const SecondFactorIdle();
}

/// Leyendo los factores de la cuenta o creando el alta.
final class SecondFactorPreparing extends SecondFactorFlow {
  const SecondFactorPreparing();
}

/// La sesión ya tenía `aal2` al entrar: no hay nada que hacer acá.
final class SecondFactorAlreadyVerified extends SecondFactorFlow {
  const SecondFactorAlreadyVerified();
}

/// El servidor aceptó el código y la sesión subió a `aal2`.
final class SecondFactorVerified extends SecondFactorFlow {
  const SecondFactorVerified();
}

/// No se pudo ni empezar (red, sesión perdida, TOTP deshabilitado…).
final class SecondFactorUnavailable extends SecondFactorFlow {
  const SecondFactorUnavailable(this.failure);

  final AuthFailure failure;
}

/// Hay más de un factor verificado: la persona elige con cuál desafiar.
final class SecondFactorChoosing extends SecondFactorFlow {
  const SecondFactorChoosing(this.factors);

  final List<SecondFactor> factors;
}

/// Estados con un campo de código: comparten desafío, envío en curso y
/// último error para que la pantalla los trate igual.
sealed class SecondFactorCodeEntry extends SecondFactorFlow {
  const SecondFactorCodeEntry({
    required this.factorId,
    this.challenge,
    this.isSubmitting = false,
    this.failure,
  });

  final String factorId;

  /// Desafío vigente contra el que se manda el próximo código, o `null` si
  /// hay que pedir uno (primer envío, o el anterior venció).
  final SecondFactorChallenge? challenge;

  /// Bloquea el doble toque: mientras es `true` no se manda otro código.
  final bool isSubmitting;

  /// Último rechazo, ya tipado. Se limpia al reintentar.
  final AuthFailure? failure;

  SecondFactorCodeEntry copyWith({
    SecondFactorChallenge? challenge,
    bool clearChallenge = false,
    bool? isSubmitting,
    AuthFailure? failure,
    bool clearFailure = false,
  });
}

/// Alta en curso: se muestra el QR y la clave manual y se espera el primer
/// código. El factor sigue **pendiente** hasta que el servidor lo acepte.
final class SecondFactorEnrolling extends SecondFactorCodeEntry {
  SecondFactorEnrolling({
    required this.enrollment,
    super.challenge,
    super.isSubmitting,
    super.failure,
  }) : super(factorId: enrollment.factorId);

  final TotpEnrollment enrollment;

  @override
  SecondFactorEnrolling copyWith({
    SecondFactorChallenge? challenge,
    bool clearChallenge = false,
    bool? isSubmitting,
    AuthFailure? failure,
    bool clearFailure = false,
  }) {
    return SecondFactorEnrolling(
      enrollment: enrollment,
      challenge: clearChallenge ? null : (challenge ?? this.challenge),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// Desafío sobre un factor que **ya está verificado**: solo se pide el
/// código. Nunca se crea otro factor desde acá.
final class SecondFactorChallenging extends SecondFactorCodeEntry {
  SecondFactorChallenging({
    required this.factor,
    required this.alternatives,
    super.challenge,
    super.isSubmitting,
    super.failure,
  }) : super(factorId: factor.id);

  final SecondFactor factor;

  /// Todos los factores verificados de la cuenta ([factor] incluido). Con más
  /// de uno, la pantalla ofrece volver a elegir.
  final List<SecondFactor> alternatives;

  bool get canChooseAnother => alternatives.length > 1;

  @override
  SecondFactorChallenging copyWith({
    SecondFactorChallenge? challenge,
    bool clearChallenge = false,
    bool? isSubmitting,
    AuthFailure? failure,
    bool clearFailure = false,
  }) {
    return SecondFactorChallenging(
      factor: factor,
      alternatives: alternatives,
      challenge: clearChallenge ? null : (challenge ?? this.challenge),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// Máquina de estados del alta y la verificación TOTP.
///
/// Reglas que sostiene, todas probadas en `second_factor_controller_test`:
///
/// * **Sin factor verificado** se inicia un alta; **con uno**, se desafía ese
///   y no se crea otro; **con varios**, se pide elegir.
/// * `start` es idempotente: una reconstrucción de la pantalla o un doble
///   toque no duplican el alta.
/// * El estado sensible (secreto, URI, desafío) vive solo acá, en memoria, y
///   se descarta al cerrar sesión, cambiar de cuenta o salir de la pantalla
///   (el provider es `autoDispose`).
/// * Una respuesta tardía de un flujo anterior (otra cuenta, cancelado) no se
///   aplica: cada operación lleva el número de época en que arrancó.
/// * Un alta interrumpida deja un factor pendiente en el servidor; se
///   descarta al cancelar o al salir, siempre que la misma sesión siga viva.
class SecondFactorController extends Notifier<SecondFactorFlow> {
  static final _codePattern = RegExp(r'^\d{6}$');

  late AuthRepository _repository;
  late DateTime Function() _now;

  /// Cuenta dueña del flujo en curso; `null` si no hay flujo.
  String? _flowUserId;

  /// Última cuenta vista en el stream de sesión (puede ser `null`).
  String? _sessionUserId;

  /// Factor creado por este flujo y todavía no verificado.
  String? _pendingFactorId;

  /// Sube cada vez que el flujo se invalida (cancelar, cambiar de cuenta,
  /// verificar). Las continuaciones comparan su época con la vigente.
  int _epoch = 0;

  @override
  SecondFactorFlow build() {
    _repository = ref.watch(authRepositoryProvider);
    _now = ref.watch(clockProvider);
    _sessionUserId = ref.read(authStatusProvider).user?.id;
    ref.listen(authStatusProvider, (_, next) => _onSessionChanged(next));
    // Al salir de la pantalla no queda ni el secreto en memoria ni un factor
    // pendiente en el servidor. Solo se usan campos: dentro de un
    // life-cycle no se puede leer `state` ni `ref`.
    ref.onDispose(_discardOnDispose);
    return const SecondFactorIdle();
  }

  /// Arranca (o reintenta) el flujo. [friendlyName] es la etiqueta con la que
  /// se guarda un factor nuevo si hace falta darlo de alta.
  Future<void> start({required String friendlyName}) async {
    if (state is! SecondFactorIdle && state is! SecondFactorUnavailable) {
      // Ya hay un flujo en curso: una reconstrucción de la pantalla no debe
      // crear un segundo factor pendiente.
      return;
    }
    final status = ref.read(authStatusProvider);
    final user = status.user;
    if (user == null) {
      state = const SecondFactorUnavailable(
        AuthFailure(AuthFailureCode.sessionMissing),
      );
      return;
    }
    _flowUserId = user.id;
    _sessionUserId = user.id;
    if (status.hasSecondFactorVerified) {
      state = const SecondFactorAlreadyVerified();
      return;
    }
    final epoch = ++_epoch;
    state = const SecondFactorPreparing();
    try {
      final factors = await _repository.listVerifiedSecondFactors();
      if (!_isCurrent(epoch)) {
        return;
      }
      if (factors.isEmpty) {
        final enrollment = await _repository.enrollTotp(
          friendlyName: friendlyName,
        );
        if (!_isCurrent(epoch)) {
          // El flujo se canceló mientras el servidor creaba el factor: no se
          // muestra y, si la sesión sigue siendo la misma, se descarta.
          _discardOrphan(enrollment.factorId, owner: user.id);
          return;
        }
        _pendingFactorId = enrollment.factorId;
        state = SecondFactorEnrolling(enrollment: enrollment);
        // El desafío se pide ya, como en el flujo documentado (alta → desafío
        // → verificación): GoTrue borra a los cinco minutos los factores
        // pendientes que no tienen NINGÚN desafío, en cuanto cualquier cuenta
        // hace un alta, y el QR quedaría muerto mientras la persona lo
        // escanea con calma. Si el desafío vence antes de que mande el
        // código, `submitCode` pide otro. Que falle acá no corta el alta.
        final challenge = await _tryChallenge(enrollment.factorId);
        if (!_isCurrent(epoch) || challenge == null) {
          return;
        }
        _updateEntry((entry) => entry.copyWith(challenge: challenge));
      } else if (factors.length == 1) {
        state = SecondFactorChallenging(
          factor: factors.single,
          alternatives: factors,
        );
      } else {
        state = SecondFactorChoosing(factors);
      }
    } on Object catch (error) {
      if (!_isCurrent(epoch)) {
        return;
      }
      state = SecondFactorUnavailable(AuthFailure.from(error));
    }
  }

  /// Con varios factores verificados, fija contra cuál se va a desafiar.
  void chooseFactor(String factorId) {
    final current = state;
    if (current is! SecondFactorChoosing) {
      return;
    }
    for (final factor in current.factors) {
      if (factor.id == factorId) {
        state = SecondFactorChallenging(
          factor: factor,
          alternatives: current.factors,
        );
        return;
      }
    }
  }

  /// Vuelve a la elección de factor (solo si hay más de uno).
  void chooseAnother() {
    final current = state;
    if (current is SecondFactorChallenging &&
        current.canChooseAnother &&
        !current.isSubmitting) {
      state = SecondFactorChoosing(current.alternatives);
    }
  }

  /// Manda el código de la app de autenticación.
  ///
  /// Pide un desafío si no hay uno vigente (o si el anterior venció), verifica
  /// y deja el resultado en el estado. Un segundo toque mientras el primero
  /// viaja se ignora.
  Future<void> submitCode(String code) async {
    final current = state;
    if (current is! SecondFactorCodeEntry || current.isSubmitting) {
      return;
    }
    final digits = code.trim();
    if (!_codePattern.hasMatch(digits)) {
      state = current.copyWith(
        failure: const AuthFailure(
          AuthFailureCode.mfaInvalidCode,
          debugDetail: 'formato: se esperaban 6 dígitos',
        ),
      );
      return;
    }
    final epoch = _epoch;
    state = current.copyWith(isSubmitting: true, clearFailure: true);
    try {
      var challenge = current.challenge;
      if (challenge == null || challenge.isExpiredAt(_now())) {
        challenge = await _repository.challengeSecondFactor(current.factorId);
        if (!_isCurrent(epoch)) {
          return;
        }
        _updateEntry((entry) => entry.copyWith(challenge: challenge));
      }
      await _repository.verifySecondFactor(
        factorId: current.factorId,
        challengeId: challenge.id,
        code: digits,
      );
      if (!_isCurrent(epoch)) {
        // Lo normal: el stream de sesión ya trajo `aal2` y marcó el flujo
        // como verificado antes de que esta llamada volviera.
        return;
      }
      _pendingFactorId = null;
      state = const SecondFactorVerified();
    } on Object catch (error) {
      if (!_isCurrent(epoch)) {
        return;
      }
      final failure = AuthFailure.from(error);
      // Con el desafío vencido, rechazado (GoTrue lo ata a la IP con la que
      // se creó) o el factor desaparecido, el siguiente envío tiene que
      // arrancar de cero; un código incorrecto conserva el desafío.
      final dropChallenge =
          failure.code == AuthFailureCode.mfaChallengeExpired ||
          failure.code == AuthFailureCode.mfaRejected ||
          failure.code == AuthFailureCode.mfaFactorNotFound;
      _updateEntry(
        (entry) => entry.copyWith(
          isSubmitting: false,
          failure: failure,
          clearChallenge: dropChallenge,
        ),
      );
    }
  }

  /// Abandona el flujo: descarta el estado sensible y, si había un alta en
  /// curso, el factor pendiente del servidor.
  void cancel() {
    final pending = _pendingFactorId;
    final owner = _flowUserId;
    _epoch++;
    _pendingFactorId = null;
    _flowUserId = null;
    state = const SecondFactorIdle();
    if (pending != null && owner != null) {
      _discardOrphan(pending, owner: owner);
    }
  }

  bool _isCurrent(int epoch) => ref.mounted && epoch == _epoch;

  /// Desafío anticipado del alta: `null` si el servidor no lo dio (el envío
  /// del código lo vuelve a intentar y ahí sí se muestra el error).
  Future<SecondFactorChallenge?> _tryChallenge(String factorId) async {
    try {
      return await _repository.challengeSecondFactor(factorId);
    } on Object catch (_) {
      return null;
    }
  }

  void _updateEntry(
    SecondFactorCodeEntry Function(SecondFactorCodeEntry entry) update,
  ) {
    final current = state;
    if (current is SecondFactorCodeEntry) {
      state = update(current);
    }
  }

  void _onSessionChanged(AuthStatus next) {
    final nextUserId = next.user?.id;
    _sessionUserId = nextUserId;
    final owner = _flowUserId;
    if (owner == null) {
      return;
    }
    if (nextUserId != owner) {
      // Cierre de sesión o cambio de cuenta: se descarta todo lo sensible y
      // se invalida cualquier respuesta en vuelo del flujo anterior. No se
      // llama al servidor: la sesión de esa cuenta ya no está.
      _epoch++;
      _pendingFactorId = null;
      _flowUserId = null;
      state = const SecondFactorIdle();
      return;
    }
    if (next.hasSecondFactorVerified && state is! SecondFactorVerified) {
      // Misma cuenta, ahora con `aal2`: es la propagación normal del
      // `mfaChallengeVerified` del SDK (o una verificación hecha en otra
      // pestaña). Nada de lo que vuelva después puede pisar este estado.
      _epoch++;
      _pendingFactorId = null;
      state = const SecondFactorVerified();
    }
  }

  void _discardOnDispose() {
    final pending = _pendingFactorId;
    final owner = _flowUserId;
    _pendingFactorId = null;
    if (pending != null && owner != null) {
      _discardOrphan(pending, owner: owner);
    }
  }

  /// Borra un factor pendiente **solo** si la sesión sigue siendo de la
  /// cuenta que lo creó: con otra cuenta el pedido iría con un token ajeno.
  void _discardOrphan(String factorId, {required String owner}) {
    if (_sessionUserId != owner) {
      return;
    }
    unawaited(
      _repository
          .discardPendingSecondFactor(factorId)
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }
}

final secondFactorControllerProvider =
    NotifierProvider.autoDispose<SecondFactorController, SecondFactorFlow>(
      SecondFactorController.new,
    );
