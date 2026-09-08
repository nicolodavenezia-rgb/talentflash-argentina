import 'dart:convert';

/// Lectura local de un access token, sin verificar la firma: la verifica el
/// servidor en cada llamada; acá solo se decide qué mostrar y a qué sesión
/// pertenece una operación.
///
/// Devuelve `null` ante cualquier cosa que no tenga forma de JWT o cuyo
/// payload no sea un objeto JSON. Nunca lanza.
Map<String, dynamic>? decodeJwtClaims(String? token) {
  if (token == null) {
    return null;
  }
  final parts = token.split('.');
  if (parts.length != 3) {
    return null;
  }
  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final claims = jsonDecode(payload);
    return claims is Map<String, dynamic> ? claims : null;
  } on FormatException {
    return null;
  }
}

/// Identidad de **una sesión** del SDK, para saber si una operación en vuelo
/// todavía pertenece a la sesión vigente.
///
/// Es el claim `session_id` del access token: GoTrue lo conserva al refrescar
/// el token y al verificar el segundo factor (misma sesión, nivel nuevo), y
/// emite uno distinto en cada inicio de sesión, también de la misma cuenta.
/// Por eso sirve donde el id de usuario no alcanza: cerrar sesión y volver a
/// entrar con la misma cuenta es otra sesión.
///
/// Si el token no tiene forma de JWT o no trae el claim (tokens de
/// utilería), la identidad es el token entero: distinto token, distinta
/// sesión. Sin token no hay identidad (`null`).
String? sessionIdentityOf(String? accessToken) {
  if (accessToken == null || accessToken.isEmpty) {
    return null;
  }
  final sessionId = decodeJwtClaims(accessToken)?['session_id'];
  if (sessionId is String && sessionId.isNotEmpty) {
    return sessionId;
  }
  return accessToken;
}
