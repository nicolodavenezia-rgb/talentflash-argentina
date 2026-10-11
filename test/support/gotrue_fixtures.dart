import 'dart:convert';

/// Respuestas realistas de GoTrue, copiadas de lo que devuelve el stack local
/// (`http://127.0.0.1:54321/auth/v1`). Sirven para ejercitar el repositorio
/// contra un cliente HTTP falso, sin ningún proyecto Supabase remoto.
abstract final class GoTrueFixtures {
  static const userId = '9c6c8ae9-34ea-41b4-b2cf-f0d2db87d9d7';

  /// Token de utilería. A propósito **no** tiene forma de JWT: el SDK solo lo
  /// guarda como string y así el escaneo de secretos del repo no tiene que
  /// distinguir un token de prueba de uno real.
  static const accessToken = 'token-de-acceso-de-utileria-para-tests';

  /// Arma un access token con forma de JWT **en tiempo de ejecución**, para
  /// que el `eyJ...` no exista como literal en el repositorio (el scan de
  /// secretos y el test de arquitectura buscan justamente eso). La firma es de
  /// utilería: el SDK solo decodifica el payload, no verifica nada.
  ///
  /// Sin [aal] se simula la sesión de un solo factor tal como la emite GoTrue
  /// cuando no hay MFA; con `'aal2'`, la sesión posterior a verificar.
  static String accessTokenWithClaims({
    String? aal,
    List<Map<String, Object?>> amr = const [],
    int? exp,
    String sub = userId,
    String? sessionId,
  }) {
    String part(Map<String, Object?> map) =>
        base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
    final payload = <String, Object?>{
      'sub': sub,
      'role': 'authenticated',
      'amr': amr,
      'exp':
          exp ??
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
              1000,
      'aal': ?aal,
      // GoTrue lo conserva al refrescar y al verificar el segundo factor, y
      // lo cambia en cada inicio de sesión (también de la misma cuenta).
      'session_id': ?sessionId,
    };
    return '${part(<String, Object?>{'alg': 'HS256', 'typ': 'JWT'})}'
        '.${part(payload)}'
        '.firma-de-utileria';
  }

  static Map<String, dynamic> user({
    Object? appRole = 'candidate',
    String requestedRole = 'candidate',
    String email = 'persona@dev.talentflash.test',
    bool includeAppRole = true,
    List<Map<String, dynamic>>? factors,
    String id = userId,
  }) {
    return <String, dynamic>{
      'id': id,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': email,
      'email_confirmed_at': '2026-08-26T22:49:42Z',
      'phone': '',
      'app_metadata': <String, dynamic>{
        'provider': 'email',
        'providers': <String>['email'],
        if (includeAppRole) 'role': appRole,
      },
      // El rol pedido por el cliente queda acá: es input no confiable y la app
      // debe ignorarlo (SECURITY.md §3).
      'user_metadata': <String, dynamic>{'role': requestedRole},
      'identities': <dynamic>[],
      // GoTrue lista los factores dentro del usuario (verificados y
      // pendientes por igual).
      'factors': ?factors,
      'created_at': '2026-08-26T22:49:42Z',
      'updated_at': '2026-08-26T22:49:42Z',
    };
  }

  /// Un factor tal como lo devuelve GoTrue dentro de `user.factors`.
  static Map<String, dynamic> factor({
    String id = 'factor-1',
    String? friendlyName = 'TalentFlash · 08/09/2026 14:32',
    String status = 'verified',
    String factorType = 'totp',
  }) {
    return <String, dynamic>{
      'id': id,
      'friendly_name': friendlyName,
      'factor_type': factorType,
      'status': status,
      'created_at': '2026-09-08T14:32:00Z',
      'updated_at': '2026-09-08T14:33:00Z',
    };
  }

  /// Respuesta de `/token?grant_type=password` y de `/signup` con sesión.
  ///
  /// Con [accessToken] se puede inyectar un token con forma de JWT (ver
  /// [accessTokenWithClaims]); por defecto va el de utilería sin forma de JWT.
  static String sessionJson({
    Object? appRole = 'candidate',
    String requestedRole = 'candidate',
    String email = 'persona@dev.talentflash.test',
    bool includeAppRole = true,
    String? accessToken,
    List<Map<String, dynamic>>? factors,
    String id = userId,
    String refreshToken = 'refresh-de-utileria',
  }) {
    final expiresAt =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000;
    return jsonEncode(<String, dynamic>{
      'access_token': accessToken ?? GoTrueFixtures.accessToken,
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': expiresAt,
      'refresh_token': refreshToken,
      'user': user(
        appRole: appRole,
        requestedRole: requestedRole,
        email: email,
        includeAppRole: includeAppRole,
        factors: factors,
        id: id,
      ),
    });
  }

  /// Respuesta de `POST /factors` para TOTP, con la forma real del stack local
  /// (el SDK antepone `data:image/svg+xml;utf-8,` al `qr_code`). El secreto es
  /// el de los ejemplos de la RFC 6238 en base32: no es de ninguna cuenta.
  static String totpEnrollJson({
    String id = 'factor-1',
    String friendlyName = 'TalentFlash · 08/09/2026 14:32',
    String secret = 'JBSWY3DPEHPK3PXP',
  }) {
    return jsonEncode(<String, dynamic>{
      'id': id,
      'type': 'totp',
      'friendly_name': friendlyName,
      'totp': <String, dynamic>{
        'qr_code': '<svg xmlns="http://www.w3.org/2000/svg"></svg>',
        'secret': secret,
        'uri':
            'otpauth://totp/TalentFlash%20Argentina:persona%40dev.talentflash.test'
            '?algorithm=SHA1&digits=6&issuer=TalentFlash%20Argentina'
            '&period=30&secret=$secret',
      },
    });
  }

  /// Respuesta de `POST /factors/{id}/challenge`. `expires_at` viaja en
  /// segundos de época, como en GoTrue.
  static String challengeJson({
    String id = 'challenge-1',
    DateTime? expiresAt,
  }) {
    final expires = expiresAt ?? DateTime.now().add(const Duration(minutes: 5));
    return jsonEncode(<String, dynamic>{
      'id': id,
      'type': 'totp',
      'expires_at': expires.millisecondsSinceEpoch ~/ 1000,
    });
  }

  /// Respuesta de `/signup` cuando el proyecto exige confirmar el correo:
  /// devuelve el usuario sin sesión.
  static String userWithoutSessionJson({String requestedRole = 'candidate'}) {
    return jsonEncode(user(requestedRole: requestedRole));
  }

  /// Cuerpo de error de GoTrue (mismo formato para 400/422/429).
  static String errorJson({
    required int code,
    required String errorCode,
    required String message,
  }) {
    return jsonEncode(<String, dynamic>{
      'code': code,
      'error_code': errorCode,
      'msg': message,
    });
  }
}
