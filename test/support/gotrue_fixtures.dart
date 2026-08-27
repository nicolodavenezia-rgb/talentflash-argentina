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

  static Map<String, dynamic> user({
    Object? appRole = 'candidate',
    String requestedRole = 'candidate',
    String email = 'persona@dev.talentflash.test',
    bool includeAppRole = true,
  }) {
    return <String, dynamic>{
      'id': userId,
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
      'created_at': '2026-08-26T22:49:42Z',
      'updated_at': '2026-08-26T22:49:42Z',
    };
  }

  /// Respuesta de `/token?grant_type=password` y de `/signup` con sesión.
  static String sessionJson({
    Object? appRole = 'candidate',
    String requestedRole = 'candidate',
    String email = 'persona@dev.talentflash.test',
    bool includeAppRole = true,
  }) {
    final expiresAt =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000;
    return jsonEncode(<String, dynamic>{
      'access_token': accessToken,
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': expiresAt,
      'refresh_token': 'refresh-de-utileria',
      'user': user(
        appRole: appRole,
        requestedRole: requestedRole,
        email: email,
        includeAppRole: includeAppRole,
      ),
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
