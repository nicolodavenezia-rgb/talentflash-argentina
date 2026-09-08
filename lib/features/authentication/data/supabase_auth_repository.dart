import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_failure.dart';
import '../domain/auth_status.dart';
import '../domain/auth_validation.dart';
import '../domain/authenticated_user.dart';
import '../domain/business_role.dart';
import '../domain/second_factor.dart';
import '../domain/session_assurance.dart';
import 'auth_repository.dart';

/// Implementación sobre Supabase Auth (GoTrue).
///
/// Recibe el `GoTrueClient` por constructor para poder ejercitarla en tests
/// contra un cliente HTTP falso, sin ningún proyecto remoto.
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
      // `listFactors` refresca la sesión antes de leer: la lista sale del
      // servidor y no de un token viejo. Solo se devuelven los TOTP que ya
      // están `verified`; un alta interrumpida no cuenta como configurada.
      final factors = await _auth.mfa.listFactors();
      return [
        for (final factor in factors.totp)
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
      // Un alta interrumpida (pestaña cerrada, app matada, sesión perdida)
      // deja un factor pendiente que el servidor cuenta para el tope de
      // factores y que choca por nombre. Antes de crear otro se descartan los
      // pendientes de la cuenta; la lista viene fresca porque el flujo acaba
      // de refrescar la sesión al listar los verificados. Es best-effort: si
      // uno no se puede borrar, el servidor dirá lo suyo en el enroll.
      final stale = _auth.currentUser?.factors ?? const <Factor>[];
      for (final factor in stale) {
        if (factor.factorType == FactorType.totp &&
            factor.status == FactorStatus.unverified) {
          try {
            await _auth.mfa.unenroll(factor.id);
          } on AuthException catch (_) {
            // Ya no existe o no se pudo: sigue el alta igual.
          }
        }
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
      // Al aceptar, el SDK guarda la sesión nueva (token `aal2`) y emite
      // `mfaChallengeVerified` por `onAuthStateChange`: el cambio de nivel
      // llega a la app por el mismo stream que cualquier otro evento.
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

  /// Traduce sesión del SDK a estado de dominio.
  ///
  /// El rol sale **solo** de `app_metadata`, que escribe el servidor.
  /// `user_metadata` es input del cliente y se ignora para autorizar. El nivel
  /// de garantía sale del claim `aal` del propio token.
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
    return AuthStatusSignedIn(
      AuthenticatedUser(id: user.id, email: user.email ?? '', role: role),
      assurance: assuranceFromAccessToken(session.accessToken),
    );
  }

  /// Lee el claim `aal` del access token sin verificar la firma (la verifica
  /// el servidor en cada llamada; acá solo se decide qué mostrar).
  ///
  /// Fail-closed: un token que no tiene forma de JWT, un payload que no es
  /// JSON o un claim con otro valor dan [SessionAssurance.unknown], que vale
  /// lo mismo que no tener segundo factor.
  static SessionAssurance assuranceFromAccessToken(String accessToken) {
    final parts = accessToken.split('.');
    if (parts.length != 3) {
      return SessionAssurance.unknown;
    }
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload);
      if (claims is! Map<String, dynamic>) {
        return SessionAssurance.unknown;
      }
      return SessionAssurance.fromClaim(claims['aal']);
    } on FormatException {
      return SessionAssurance.unknown;
    }
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
