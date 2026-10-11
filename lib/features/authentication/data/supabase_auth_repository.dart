import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_failure.dart';
import '../domain/auth_status.dart';
import '../domain/auth_validation.dart';
import '../domain/authenticated_user.dart';
import '../domain/business_role.dart';
import '../domain/second_factor.dart';
import '../domain/session_assurance.dart';
import 'auth_repository.dart';
import 'jwt_claims.dart';
import 'second_factor_cleanup_policy.dart';

/// Implementación sobre Supabase Auth (GoTrue).
///
/// Recibe el `GoTrueClient` por constructor para poder ejercitarla en tests
/// contra un cliente HTTP falso, sin ningún proyecto remoto.
///
/// Las operaciones de segundo factor quedan **atadas a la sesión que las
/// inició** en dos capas que se complementan:
///
/// * acá, una operación de varios pasos captura la sesión al empezar
///   ([_requireSession]) y la vuelve a comprobar después de cada espera y
///   justo antes de la siguiente llamada al SDK ([_ensureSameSession]): una
///   continuación nunca manda una solicitud con credenciales de otra cuenta
///   (ni de otra sesión de la misma cuenta);
/// * en el cliente HTTP (`SessionScopedHttpClient`, cableado en
///   `bootstrap.dart`), la **respuesta** de una solicitud de segundo factor se
///   descarta si la sesión cambió mientras viajaba, antes de que el SDK pueda
///   guardarla como sesión o emitir eventos por ella. Hace falta porque
///   `mfa.verify` guarda la sesión y notifica antes de devolver el control.
///
/// Las dos capas contestan la **misma** pregunta, cada una en su punto:
/// «¿sigue siendo la misma sesión?». Y hay una **segunda** pregunta que la
/// identidad de sesión **no puede** contestar, porque una verificación
/// legítima cambia el nivel sin cambiar de sesión: «¿esta operación
/// destructiva todavía tiene sentido?».
///
/// Para las **bajas automáticas de factores** esa pregunta no se contesta:
/// se evita. [SecondFactorCleanupPolicy] es donde está escrita la garantía, y
/// la garantía es **no mandar ninguna baja automática**, porque el endpoint
/// de GoTrue no permite borrar de forma condicional y atómica. Los dos
/// caminos de limpieza de esta clase —la del alta y
/// [discardPendingSecondFactor]— conservan su recorrido, pero **ninguno
/// manda hoy un `DELETE`**. [_canUnenroll] sigue existiendo como segunda
/// barrera y hoy queda cortocircuitado; nunca hay que apoyarse en él: lee el
/// claim del token, y el servidor decide por el nivel de la sesión.
class SupabaseAuthRepository implements AuthRepository {
  /// [cleanup] es **obligatoria y tiene que ser la misma instancia** que usa
  /// `SecondFactorAttemptRecorder` en el transporte. Con dos instancias, las
  /// altas se anotarían en una y los intentos de verificación en la otra, y
  /// la política vería un factor propio sin intentos: el defecto de D1-bis,
  /// otra vez y en silencio. Por eso no hay valor por omisión.
  SupabaseAuthRepository(this._auth, this._cleanup);

  final GoTrueClient _auth;

  /// Quién puede darse de baja sola.
  ///
  /// **La misma instancia la comparten el transporte y este repositorio**
  /// (se arma en `bootstrap.dart` y llega por `secondFactorCleanupPolicyProvider`):
  /// el transporte anota cada pedido de verificación que sale, y acá se
  /// consulta antes de cada baja. Vive lo que vive el cliente de Supabase, así
  /// que sobrevive a que la pantalla de segundo factor se destruya y se vuelva
  /// a crear —que es justo lo que una marca en el controller `autoDispose` no
  /// hace— y se descarta al cerrar sesión o cambiar de cuenta.
  final SecondFactorCleanupPolicy _cleanup;

  /// Emisor que muestra la app de autenticación junto a la cuenta.
  static const totpIssuer = 'TalentFlash Argentina';

  @override
  AuthStatus get currentStatus => statusFromSession(_auth.currentSession);

  @override
  Stream<AuthStatus> statusChanges() {
    // Cada evento del SDK se traduce de nuevo desde la sesión que trae: eso
    // incluye `mfaChallengeVerified`, que cambia el claim `aal` del token sin
    // cambiar de usuario, y `tokenRefreshed`, que lo conserva.
    return _auth.onAuthStateChange
        .map((authState) => statusFromSession(authState.session))
        .handleError(_ignoreTransientStreamError);
  }

  @override
  Future<SignUpOutcome> signUpWithEmail({
    required String email,
    required String password,
    required SignUpRole role,
  }) {
    return _guard(() async {
      final response = await _auth.signUp(
        email: AuthValidation.normalizeEmail(email),
        password: password,
        // Único dato de metadata que manda el cliente. El trigger lo sanea y
        // copia el valor confiable a `app_metadata` (migración 0004).
        data: {'role': role.claim},
      );
      return response.session == null
          ? SignUpOutcome.emailConfirmationRequired
          : SignUpOutcome.signedIn;
    });
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _guard(() async {
      await _auth.signInWithPassword(
        email: AuthValidation.normalizeEmail(email),
        password: password,
      );
    });
  }

  @override
  Future<void> sendPasswordRecoveryEmail(String email) {
    return _guard(() async {
      // Sin `redirectTo`: el enlace usa el `site_url` del proyecto. La pantalla
      // in-app de cambio de contraseña depende del deep link de T-013, todavía
      // sin definir (ver README y docs/SECURITY.md §2).
      await _auth.resetPasswordForEmail(AuthValidation.normalizeEmail(email));
    });
  }

  @override
  Future<void> signOut() => _guard(() => _auth.signOut());

  @override
  Future<List<SecondFactor>> listVerifiedSecondFactors() {
    return _guard(() async {
      final factors = await _serverFactors(_requireSession());
      return [
        for (final factor in factors)
          if (factor.factorType == FactorType.totp &&
              factor.status == FactorStatus.verified)
            SecondFactor(
              id: factor.id,
              friendlyName: _nonEmpty(factor.friendlyName),
              createdAt: factor.createdAt,
            ),
      ];
    });
  }

  @override
  Future<TotpEnrollment> enrollTotp({required String friendlyName}) {
    return _guard(() async {
      final scope = _requireSession();
      // Un alta interrumpida (pestaña cerrada, app matada, sesión perdida)
      // deja un factor pendiente que el servidor cuenta para el tope de
      // factores y que choca por nombre. Este recorrido **existía** para
      // darlos de baja antes de crear otro; hoy **no da de baja ninguno**,
      // porque [SecondFactorCleanupPolicy.canAutoUnenroll] devuelve siempre
      // `false`. Se conserva entero —la lectura, el filtro y las dos
      // barreras— como la precondición que habría que volver a cumplir el
      // día que exista una baja usable, y para que encender la constante no
      // exija reconstruir nada. Quién recolecta los pendientes hoy: el
      // servidor los barre solo si nunca pidieron desafío, y una
      // verificación exitosa se lleva a todos los demás.
      //
      // La lectura sigue siendo del SERVIDOR (`/user`) y no de la copia del
      // usuario que guarda la sesión, que es la foto del último login o
      // refresco. Hoy su único consumidor es este bucle, así que **cuesta un
      // `GET /user` que no cambia nada**: se paga a propósito, para no
      // desarmar la precondición y para que la abstención se vea donde se
      // decide, en vez de esconderla borrando el recorrido. Lo que NO se
      // tolera es que la sesión cambie en el medio: cada paso vuelve a
      // comprobar la sesión, así el POST de alta nunca sale con el token de
      // otra cuenta aunque una espera haya tardado.
      final stale = await _serverFactors(scope);
      for (final factor in stale) {
        if (factor.factorType != FactorType.totp ||
            factor.status != FactorStatus.unverified) {
          continue;
        }
        _ensureSameSession(scope);
        // Acá se abstiene, siempre, y conviene ver por qué el `continue` no
        // es una precaución más sino el único desenlace posible.
        //
        // La lectura de arriba pudo quedar vieja: mientras viajaba, el
        // servidor pudo aceptar el código de ese mismo factor, y entonces
        // esto ya no es un pendiente sino el segundo factor de la cuenta.
        // Releer no arregla nada —la verificación puede entrar entre la
        // relectura y el DELETE—, y el rechazo del servidor tampoco, porque
        // no es una baja condicional. Sin forma de decidir sin carrera, no
        // se manda ninguna baja: [SecondFactorCleanupPolicy.canAutoUnenroll]
        // devuelve `false` para todo mientras `automaticUnenrollEnabled` esté
        // apagado, así que **este `if` corta siempre y el `unenroll` de abajo
        // no se ejecuta nunca**.
        if (!_cleanup.canAutoUnenroll(factor.id)) {
          // `continue` y no `break`: la condición se evalúa por factor, que
          // es como tendría que volver a evaluarse si algún día se enciende.
          continue;
        }
        // Inalcanzable hoy, por lo de arriba. Segunda barrera, subordinada:
        // cuando la app YA se enteró de que su sesión subió de nivel,
        // tampoco insiste. No sustituye a la política, y nunca sustituyó a
        // la garantía: lee el claim del token y el servidor decide por el
        // nivel de la sesión.
        if (!_canUnenroll()) {
          continue;
        }
        try {
          await _auth.mfa.unenroll(factor.id);
          _cleanup.recordGone(factor.id);
        } on AuthException catch (error) {
          if (error.code == AuthFailureCode.staleSession.wireCode) {
            rethrow;
          }
          if (error.code == 'mfa_factor_not_found') {
            _cleanup.recordGone(factor.id);
          }
          // Ya no existe o no se pudo: sigue el alta igual.
        }
      }
      _ensureSameSession(scope);
      // Si la sesión ya subió a `aal2`, esta alta perdió sentido: la cuenta
      // acaba de verificar su segundo factor en esta misma sesión. El servidor
      // NO la rechaza: con `aal2` un alta nueva devuelve 200 (el rechazo
      // `insufficient_aal` es para `aal1`, y eso sí lo fija `npm run mfa:test`),
      // así que seguir dejaría un factor
      // pendiente de más que nadie va a verificar. Se corta con un fallo
      // propio, no con `staleSession`: la sesión es la misma.
      if (_currentAssurance() == SessionAssurance.aal2) {
        throw const AuthFailure(
          AuthFailureCode.mfaAlreadyVerified,
          debugDetail: 'la sesión subió a aal2 durante el alta',
        );
      }
      final response = await _auth.mfa.enroll(
        issuer: totpIssuer,
        friendlyName: friendlyName,
      );
      final totp = response.totp;
      if (totp == null) {
        throw const AuthFailure(
          AuthFailureCode.unknown,
          debugDetail: 'enroll: respuesta sin datos totp',
        );
      }
      // El factor queda anotado como propio de esta instancia. Es una
      // condición para poder darlo de baja sola, NO el motivo por el que eso
      // sería seguro: el secreto se muestra en pantalla y cualquiera que lo
      // copie puede verificar el factor. Hoy no habilita nada —no hay baja
      // automática que habilitar—; se anota para no perder la precondición.
      // Ver [SecondFactorCleanupPolicy].
      _cleanup.recordEnrolled(response.id);
      // El SVG del QR que manda el servidor se descarta: el QR se dibuja en
      // el cliente a partir de la URI, así hay una sola copia del secreto
      // dando vueltas en memoria.
      return TotpEnrollment(
        factorId: response.id,
        friendlyName: friendlyName,
        secret: totp.secret,
        uri: totp.uri,
      );
    });
  }

  @override
  Future<SecondFactorChallenge> challengeSecondFactor(String factorId) {
    return _guard(() async {
      _requireSession();
      final response = await _auth.mfa.challenge(factorId: factorId);
      return SecondFactorChallenge(
        id: response.id,
        factorId: factorId,
        expiresAt: response.expiresAt,
      );
    });
  }

  @override
  Future<void> verifySecondFactor({
    required String factorId,
    required String challengeId,
    required String code,
  }) {
    return _guard(() async {
      _requireSession();
      // Al aceptar, el SDK guarda la sesión nueva (token `aal2`) y emite
      // `mfaChallengeVerified` por `onAuthStateChange`: el cambio de nivel
      // llega a la app por el mismo stream que cualquier otro evento. Si la
      // sesión cambió mientras la respuesta viajaba, el cliente HTTP la
      // convierte en `stale_session` y el SDK no guarda nada.
      //
      // El intento NO se anota acá. Lo anota el transporte
      // ([SecondFactorAttemptRecorder]), que es el único punto que ve cada
      // pedido que sale: acá se ve una invocación, y una invocación puede
      // convertirse en varios pedidos si alguien intercala un cliente que
      // reintente.
      try {
        await _auth.mfa.verify(
          factorId: factorId,
          challengeId: challengeId,
          code: code,
        );
      } on AuthException catch (error) {
        if (error.code == 'mfa_factor_not_found') {
          _cleanup.recordGone(factorId);
        }
        rethrow;
      }
    });
  }

  @override
  Future<void> discardPendingSecondFactor(String factorId) {
    return _guard(() async {
      _requireSession();
      // Misma abstención que la limpieza del alta, y por el mismo motivo:
      // este camino tampoco mira el estado del factor, y mirarlo no
      // serviría. El caso que lo hacía peligroso es el central de D1: la app
      // mandó el código, el servidor lo aceptó y la respuesta se perdió. La
      // app cree que el factor sigue pendiente, su token sigue diciendo
      // `aal1`, y el servidor —que decide por el nivel de la SESIÓN, ya en
      // `aal2`— aceptaba la baja y borraba el segundo factor recién
      // configurado.
      //
      // Hoy no llega a pasar nada de eso: `canAutoUnenroll` devuelve `false`
      // para todo, así que **el método sale acá sin mandar un solo `DELETE`**
      // y salir en silencio es su comportamiento normal, no un error. Lo que
      // el llamador pierde es la limpieza inmediata del pendiente; quién lo
      // recolecta después está en [SecondFactorCleanupPolicy] y en
      // SECURITY.md §2.
      if (!_cleanup.canAutoUnenroll(factorId)) {
        return;
      }
      // Inalcanzable hoy. Segunda barrera, subordinada: ver [_canUnenroll].
      if (!_canUnenroll()) {
        return;
      }
      try {
        await _auth.mfa.unenroll(factorId);
        _cleanup.recordGone(factorId);
      } on AuthException catch (error) {
        // Ya no existe (lo venció el servidor o lo borró otra sesión): el
        // objetivo —que no quede un factor pendiente— está cumplido igual.
        if (error.code == 'mfa_factor_not_found') {
          _cleanup.recordGone(factorId);
          return;
        }
        rethrow;
      }
    });
  }

  /// Factores de la cuenta según el servidor (`GET /user`), que no toca la
  /// sesión del SDK. Si el access token ya venció (la app estuvo dormida y el
  /// refresco automático todavía no corrió) se refresca antes: el SDK ya
  /// descarta por su cuenta un refresco cuya sesión cambió mientras esperaba.
  /// [scope] es la sesión que inició la operación; se vuelve a comprobar tras
  /// cada espera.
  Future<List<Factor>> _serverFactors(String scope) async {
    if (_auth.currentSession?.isExpired ?? false) {
      await _auth.refreshSession();
      _ensureSameSession(scope);
    }
    final response = await _auth.getUser();
    _ensureSameSession(scope);
    return response.user?.factors ?? const <Factor>[];
  }

  /// Identidad de la sesión vigente ([sessionIdentityOf]), o `null` sin
  /// sesión.
  String? _sessionScope() =>
      sessionIdentityOf(_auth.currentSession?.accessToken);

  /// Sesión que inicia una operación de segundo factor. Sin sesión no hay
  /// operación posible. Se llama justo antes de la llamada al SDK: el SDK
  /// toma la sesión en ese mismo instante, sin ningún `await` entre medio.
  String _requireSession() {
    final scope = _sessionScope();
    if (scope == null) {
      throw const AuthFailure(
        AuthFailureCode.sessionMissing,
        debugDetail: 'operación de segundo factor sin sesión',
      );
    }
    return scope;
  }

  /// Nivel de la sesión vigente, leído del token **en este instante**.
  ///
  /// Sin sesión o con un token ilegible da [SessionAssurance.unknown], que
  /// nunca vale por `aal1` ni por una verificación exitosa.
  SessionAssurance _currentAssurance() {
    final accessToken = _auth.currentSession?.accessToken;
    if (accessToken == null) {
      return SessionAssurance.unknown;
    }
    return assuranceFromAccessToken(accessToken);
  }

  /// Segunda barrera de las bajas automáticas: no mandar una baja cuando la
  /// app **ya se enteró** de que su sesión subió de nivel.
  ///
  /// **Hoy no se llega hasta acá.** La primera puerta
  /// ([SecondFactorCleanupPolicy.canAutoUnenroll]) devuelve siempre `false`
  /// porque la app no manda bajas automáticas, así que esto queda
  /// cortocircuitado. Se conserva junto con el resto de la precondición, y
  /// vuelve a tener efecto solo si alguna vez se enciende
  /// `automaticUnenrollEnabled`.
  ///
  /// **Esto NO es la garantía, y no hay que tratarlo como si lo fuera.** Lee
  /// el claim `aal` del token que el cliente tiene en la mano; el servidor
  /// resuelve el `insufficient_aal` por el nivel de la **sesión**, que es otra
  /// cosa. Medido contra el GoTrue local
  /// (`test_integration/d1bis_limpieza_automatica_test.dart`): un `DELETE`
  /// hecho con un token cuyo claim todavía dice `aal1`, sobre una sesión que
  /// el servidor ya subió a `aal2`, responde 200 y borra el factor. O sea que
  /// en la ventana central de D1 —el servidor aceptó el código y la respuesta
  /// se perdió— este método devuelve `true` y deja pasar la baja.
  ///
  /// Lo que sí aporta: cuando la app observó el ascenso (por el evento del
  /// SDK o por un refresco), abstenerse es gratis y correcto. Lo que da la
  /// garantía es [SecondFactorCleanupPolicy], que se consulta antes.
  ///
  /// Con [SessionAssurance.unknown] tampoco se manda: un nivel ilegible nunca
  /// se interpreta como `aal1`.
  ///
  /// **No** reemplaza a la identidad de sesión: [_ensureSameSession] sigue
  /// comparando `session_id`, que es lo que distingue una sesión de otra.
  bool _canUnenroll() => _currentAssurance() == SessionAssurance.aal1;

  /// Corta una operación de varios pasos si la sesión que la inició
  /// ([scope]) ya no es la vigente. Se llama después de cada espera y justo
  /// antes de la siguiente llamada al SDK.
  void _ensureSameSession(String scope) {
    if (_sessionScope() != scope) {
      throw const AuthFailure(
        AuthFailureCode.staleSession,
        debugDetail: 'la sesión cambió durante la operación',
      );
    }
  }

  /// Traduce sesión del SDK a estado de dominio.
  ///
  /// El rol sale **solo** de `app_metadata`, que escribe el servidor.
  /// `user_metadata` es input del cliente y se ignora para autorizar. El nivel
  /// de garantía y la identidad de sesión salen de los claims del propio
  /// token.
  static AuthStatus statusFromSession(Session? session) {
    final user = session?.user;
    if (session == null || user == null) {
      return const AuthStatusSignedOut();
    }
    final claim = user.appMetadata['role'] as Object?;
    final role = BusinessRole.fromClaim(claim);
    if (role == null) {
      return AuthStatusInconsistent(userId: user.id, rawClaim: claim);
    }
    final claims = decodeJwtClaims(session.accessToken);
    final sessionId = claims?['session_id'];
    return AuthStatusSignedIn(
      AuthenticatedUser(id: user.id, email: user.email ?? '', role: role),
      assurance: assuranceFromAccessToken(session.accessToken),
      sessionId: sessionId is String && sessionId.isNotEmpty ? sessionId : null,
    );
  }

  /// Lee el claim `aal` del access token sin verificar la firma (la verifica
  /// el servidor en cada llamada; acá solo se decide qué mostrar).
  ///
  /// Fail-closed: un token que no tiene forma de JWT, un payload que no es
  /// JSON o un claim con otro valor dan [SessionAssurance.unknown], que vale
  /// lo mismo que no tener segundo factor.
  static SessionAssurance assuranceFromAccessToken(String accessToken) {
    final claims = decodeJwtClaims(accessToken);
    if (claims == null) {
      return SessionAssurance.unknown;
    }
    return SessionAssurance.fromClaim(claims['aal']);
  }

  static String? _nonEmpty(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value;
  }

  /// Un fallo de refresco puntual no debe desloguear: cuando la sesión es
  /// irrecuperable, GoTrue emite `signedOut` por el mismo stream.
  static void _ignoreTransientStreamError(
    Object error,
    StackTrace stackTrace,
  ) {}

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }
}
