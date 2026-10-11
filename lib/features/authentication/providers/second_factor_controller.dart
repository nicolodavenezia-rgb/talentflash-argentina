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
    this.restarted = false,
    super.challenge,
    super.isSubmitting,
    super.failure,
  }) : super(factorId: enrollment.factorId);

  final TotpEnrollment enrollment;

  /// El alta anterior venció del lado del servidor y esta la reemplaza.
  ///
  /// La pantalla tiene que decirlo: el QR **cambió**, y lo que la persona ya
  /// guardó en su autenticador no sirve. Nunca se reutiliza el secreto ni el
  /// código anteriores.
  final bool restarted;

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
      restarted: restarted,
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
/// * Un alta interrumpida deja un factor pendiente en el servidor. Al
///   cancelar o al salir se **pide** descartarlo, siempre que la misma sesión
///   siga viva (se relee del repositorio en ese instante, no de una copia
///   guardada) y salvo que su código ya esté viajando. Pero **el pedido hoy
///   no borra nada**: el repositorio se abstiene de mandar bajas automáticas
///   (`SecondFactorCleanupPolicy`), así que el pendiente queda en el servidor
///   y lo recolecta él —solo si nunca llegó a pedir un desafío, y por eso el
///   desafío se pide recién al mandar el código—. Las dos condiciones de acá
///   se conservan porque son parte de la precondición: el día que exista una
///   baja usable tienen que seguir valiendo.
class SecondFactorController extends Notifier<SecondFactorFlow> {
  static final _codePattern = RegExp(r'^\d{6}$');

  late AuthRepository _repository;
  late DateTime Function() _now;

  /// Sesión dueña del flujo en curso; `null` si no hay flujo.
  _SessionKey? _flowSession;

  /// Factor creado por este flujo y todavía no verificado.
  String? _pendingFactorId;

  /// Factor cuyo código ya viaja hacia el servidor.
  ///
  /// Un `unenroll` disparado mientras esa verificación está en vuelo correría
  /// contra ella y podría borrar un factor que el servidor acaba de aceptar,
  /// dejando a la cuenta sin el segundo factor que la persona acaba de
  /// configurar y sin poder operar la cola hasta que lo configure de nuevo
  /// (comprobado contra el servidor: con **cero** factores verificados se
  /// puede volver a dar de alta TOTP desde `aal1` y recuperar `aal2`; no se
  /// afirma nada sobre otros escenarios de pérdida del autenticador, que no
  /// se probaron). Dentro de un life-cycle no se puede leer `state`, así que
  /// `isSubmitting` se espeja acá.
  ///
  /// **Hoy ese `unenroll` no llega a salir**, porque el repositorio no manda
  /// bajas automáticas. Esta marca dejó de ser lo que evita el daño y pasó a
  /// ser la barrera de más arriba: se conserva porque el día que exista una
  /// baja usable vuelve a hacer falta, y porque abstenerse antes es más
  /// barato que abstenerse después.
  ///
  /// Este campo cubre el flujo **vivo**. El caso en el que la pantalla se
  /// destruye y se vuelve a crear lo cubre el repositorio, que no depende de
  /// que ningún campo sobreviva al `autoDispose`.
  String? _verifyingFactorId;

  /// Sube cada vez que el flujo se invalida (cancelar, cambiar de cuenta,
  /// verificar). Las continuaciones comparan su época con la vigente.
  int _epoch = 0;

  @override
  SecondFactorFlow build() {
    _repository = ref.watch(authRepositoryProvider);
    _now = ref.watch(clockProvider);
    ref.listen(authStatusProvider, (_, next) => _onSessionChanged(next));
    // Al salir de la pantalla no queda el secreto en memoria, y se pide
    // descartar el factor pendiente. El pendiente en sí **puede quedar en el
    // servidor**: el repositorio no manda bajas automáticas, así que el
    // pedido no borra nada y lo recolecta GoTrue. Solo se usan campos:
    // dentro de un life-cycle no se puede leer `state` ni `ref`.
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
    final owner = _SessionKey.of(status);
    if (owner == null) {
      state = const SecondFactorUnavailable(
        AuthFailure(AuthFailureCode.sessionMissing),
      );
      return;
    }
    _flowSession = owner;
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
          _discardOrphan(enrollment.factorId, owner: owner);
          return;
        }
        _pendingFactorId = enrollment.factorId;
        state = SecondFactorEnrolling(enrollment: enrollment);
        // El desafío NO se pide acá: lo pide `submitCode` cuando la persona
        // manda el código. Es deliberado y tiene una razón medida.
        //
        // GoTrue limpia los factores pendientes de una cuenta **dentro del
        // handler del alta** —no hay ningún temporizador de fondo: un
        // pendiente sigue ahí a los ocho minutos si nadie da de alta nada—, y
        // solo borra los que **no tienen ningún desafío** y ya superaron el
        // umbral (~5 min). Pidiendo el desafío en el alta, todo intento
        // abandonado quedaba fuera de esa limpieza y se acumulaba contra el
        // tope de 10 factores por cuenta, sin salida desde la app.
        //
        // El costo del cambio es acotado y está cubierto: si la persona tarda
        // y el factor desaparece, `submitCode` lo detecta
        // (`mfa_factor_not_found`), rehace el alta UNA vez y avisa que el QR
        // cambió. Nunca se reutiliza el secreto ni el código anteriores.
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
        // Lo más frecuente cuando el nivel subió: el stream de sesión ya trajo
        // `aal2` y dejó el flujo en `SecondFactorVerified`. Ese estado no se
        // pisa: la persona ya vio que su verificación salió bien.
        return;
      }
      final failure = AuthFailure.from(error);
      if (failure.code == AuthFailureCode.mfaAlreadyVerified) {
        // La sesión subió a `aal2` mientras preparábamos el alta, y el
        // repositorio la cortó antes de crear un factor de más. La sesión
        // vigente ya está autorizada: no es un error que haya que explicar
        // ni un flujo para reintentar. Se termina como si se hubiera entrado
        // con la sesión ya verificada, que es exactamente lo que pasa ahora,
        // y la pantalla lleva a la cola.
        _pendingFactorId = null;
        _verifyingFactorId = null;
        state = const SecondFactorAlreadyVerified();
        return;
      }
      state = SecondFactorUnavailable(failure);
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
      // Desde acá y hasta que el servidor conteste, este factor no se descarta
      // aunque la pantalla se desmonte: ver [_verifyingFactorId].
      _verifyingFactorId = current.factorId;
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
      // El factor ya no existe: lo recolectó el servidor mientras la persona
      // se tomaba su tiempo (es el costo conocido de pedir el desafío recién
      // acá). Se rehace el alta UNA vez —no se reintenta el código ni se
      // reutiliza el secreto— y la pantalla avisa que el QR cambió. No hay
      // bucle posible: cada reintento exige que la persona mande otro código.
      if (failure.code == AuthFailureCode.mfaFactorNotFound &&
          current is SecondFactorEnrolling) {
        await _restartEnrollment(epoch: epoch, previo: current);
        return;
      }
      // Con el desafío vencido o rechazado (GoTrue lo ata a la IP con la que
      // se creó) el siguiente envío tiene que arrancar de cero; un código
      // incorrecto conserva el desafío.
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
    } finally {
      if (_verifyingFactorId == current.factorId) {
        _verifyingFactorId = null;
      }
    }
  }

  /// Abandona el flujo: descarta el estado sensible y, si había un alta en
  /// curso, **pide** descartar el factor pendiente del servidor —pedido que
  /// hoy no manda ningún `DELETE`, ver [_discardOrphan]—.
  void cancel() {
    final pending = _pendingFactorId;
    final owner = _flowSession;
    final verifying = _verifyingFactorId;
    _epoch++;
    _pendingFactorId = null;
    _flowSession = null;
    state = const SecondFactorIdle();
    // Mismo criterio que `_discardOnDispose`: un factor cuyo código ya viaja
    // no se borra, porque el servidor puede estar aceptándolo justo ahora.
    if (pending != null && owner != null && pending != verifying) {
      _discardOrphan(pending, owner: owner);
    }
  }

  bool _isCurrent(int epoch) => ref.mounted && epoch == _epoch;

  /// Rehace un alta cuyo factor el servidor ya recolectó.
  ///
  /// Se llama **una vez por envío de código**, nunca en cadena: si el alta
  /// nueva también fallara, se muestra el fallo y se corta. El secreto y el
  /// código anteriores no se reutilizan; el QR que se dibuja es el nuevo, y
  /// [SecondFactorEnrolling.restarted] hace que la pantalla lo diga.
  Future<void> _restartEnrollment({
    required int epoch,
    required SecondFactorEnrolling previo,
  }) async {
    final owner = _flowSession;
    try {
      final enrollment = await _repository.enrollTotp(
        friendlyName: previo.enrollment.friendlyName,
      );
      if (!_isCurrent(epoch)) {
        if (owner != null) {
          _discardOrphan(enrollment.factorId, owner: owner);
        }
        return;
      }
      _pendingFactorId = enrollment.factorId;
      state = SecondFactorEnrolling(enrollment: enrollment, restarted: true);
    } on Object catch (error) {
      if (!_isCurrent(epoch)) {
        return;
      }
      _updateEntry(
        (entry) => entry.copyWith(
          isSubmitting: false,
          failure: AuthFailure.from(error),
          clearChallenge: true,
        ),
      );
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
    final nextSession = _SessionKey.of(next);
    final owner = _flowSession;
    if (owner == null) {
      return;
    }
    if (nextSession != owner) {
      // Cierre de sesión, otra cuenta o la misma cuenta en una sesión nueva:
      // se descarta todo lo sensible y se invalida cualquier respuesta en
      // vuelo del flujo anterior. No se llama al servidor: la sesión de ese
      // flujo ya no está.
      _epoch++;
      _pendingFactorId = null;
      _verifyingFactorId = null;
      _flowSession = null;
      // Sin sesión, el router se lleva la pantalla y `Idle` no llega a
      // dibujarse. Con una sesión nueva todavía utilizable (la misma cuenta
      // reingresando, u otra cuenta admin) la pantalla SÍ se queda: `Idle` se
      // dibuja igual que «preparando» y nadie vuelve a llamar a `start()`, así
      // que anunciaría para siempre un trabajo que no existe. Se informa el
      // corte y se ofrece reintentar, que rearma el flujo con la sesión nueva.
      state = nextSession == null
          ? const SecondFactorIdle()
          : const SecondFactorUnavailable(
              AuthFailure(
                AuthFailureCode.staleSession,
                debugDetail: 'la sesión cambió durante el flujo',
              ),
            );
      return;
    }
    if (next.hasSecondFactorVerified && state is! SecondFactorVerified) {
      // Misma cuenta, ahora con `aal2`: es la propagación normal del
      // `mfaChallengeVerified` del SDK (o una verificación hecha en otra
      // pestaña). Nada de lo que vuelva después puede pisar este estado.
      _epoch++;
      _pendingFactorId = null;
      _verifyingFactorId = null;
      state = const SecondFactorVerified();
    }
  }

  void _discardOnDispose() {
    final pending = _pendingFactorId;
    final owner = _flowSession;
    final verifying = _verifyingFactorId;
    _pendingFactorId = null;
    if (pending == null || owner == null) {
      return;
    }
    if (pending == verifying) {
      // El código ya viaja: un alta con el código enviado no es un «alta
      // interrumpida». O la acepta el servidor —y borrarla dejaría a la cuenta
      // sin el segundo factor recién configurado, obligándola a configurarlo de
      // nuevo para volver a operar la cola— o no, y entonces queda un
      // pendiente que recolecta GoTrue: en este camino el factor ya pidió un
      // desafío, así que no lo alcanza la limpieza del alta y lo que lo barre
      // es la próxima verificación exitosa.
      return;
    }
    _discardOrphan(pending, owner: owner);
  }

  /// Pide descartar un factor pendiente **solo** si la sesión sigue siendo la
  /// que lo creó: el `unenroll` del SDK viajaría con el bearer de la sesión
  /// VIGENTE, así que con otra sesión el pedido saldría con un token ajeno.
  ///
  /// La sesión se lee del repositorio en este mismo instante y no de un campo:
  /// el caso que hay que cubrir es justamente el dispose, donde el
  /// `ref.listen` ya está cerrado y cualquier copia guardada quedó congelada
  /// en la sesión anterior.
  ///
  /// **Nombre honesto: pide, no borra.** El repositorio no manda bajas
  /// automáticas, así que `discardPendingSecondFactor` vuelve sin haber
  /// tocado nada y el pendiente sigue en el servidor. Que este camino no
  /// limpie no es un fallo silencioso: lo recolecta GoTrue si el factor
  /// nunca pidió un desafío —que es el caso normal al cancelar o salir,
  /// porque el desafío se pide recién al mandar el código— y, si lo pidió,
  /// lo barre la próxima verificación exitosa.
  void _discardOrphan(String factorId, {required _SessionKey owner}) {
    if (_SessionKey.of(_repository.currentStatus) != owner) {
      return;
    }
    unawaited(
      _repository
          .discardPendingSecondFactor(factorId)
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }
}

/// Sesión dueña de un flujo: la cuenta **y** la identidad de sesión. Comparar
/// solo la cuenta no alcanza: cerrar sesión y volver a entrar con la misma
/// cuenta es otra sesión, y un flujo empezado en la anterior no le pertenece.
/// Con tokens que no traen `session_id` (dobles de prueba) queda solo la
/// cuenta, y el cierre de sesión igual pasa por `SignedOut`.
class _SessionKey {
  const _SessionKey(this.userId, this.sessionId);

  final String userId;
  final String? sessionId;

  static _SessionKey? of(AuthStatus status) {
    final user = status.user;
    if (user == null) {
      return null;
    }
    return _SessionKey(user.id, status.sessionId);
  }

  @override
  bool operator ==(Object other) =>
      other is _SessionKey &&
      other.userId == userId &&
      other.sessionId == sessionId;

  @override
  int get hashCode => Object.hash(userId, sessionId);
}

final secondFactorControllerProvider =
    NotifierProvider.autoDispose<SecondFactorController, SecondFactorFlow>(
      SecondFactorController.new,
    );
