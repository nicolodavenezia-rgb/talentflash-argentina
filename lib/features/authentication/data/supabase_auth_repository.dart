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
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final GoTrueClient _auth;

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
      // factores y que choca por nombre. Antes de crear otro se descartan los
      // pendientes de la cuenta según el SERVIDOR (`/user`), no según la copia
      // del usuario que guarda la sesión, que es la foto del último login o
      // refresco. Es best-effort: si uno no se puede borrar, el servidor dirá
      // lo suyo en el enroll. Lo que NO se tolera es que la sesión cambie en
      // el medio: cada paso vuelve a comprobar la sesión, así el POST de alta
      // nunca sale con el token de otra cuenta aunque un DELETE haya tardado.
      final stale = await _serverFactors(scope);
      for (final factor in stale) {
        if (factor.factorType != FactorType.totp ||
            factor.status != FactorStatus.unverified) {
          continue;
        }
        _ensureSameSession(scope);
        try {
          await _auth.mfa.unenroll(factor.id);
        } on AuthException catch (error) {
          if (error.code == AuthFailureCode.staleSession.wireCode) {
            rethrow;
          }
          // Ya no existe o no se pudo: sigue el alta igual.
        }
      }
      _ensureSameSession(scope);
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
      await _auth.mfa.verify(
        factorId: factorId,
        challengeId: challengeId,
        code: code,
      );
    });
  }

  @override
  Future<void> discardPendingSecondFactor(String factorId) {
    return _guard(() async {
      _requireSession();
      try {
        await _auth.mfa.unenroll(factorId);
      } on AuthException catch (error) {
        // Ya no existe (lo venció el servidor o lo borró otra sesión): el
        // objetivo —que no quede un factor pendiente— está cumplido igual.
        if (error.code == 'mfa_factor_not_found') {
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
