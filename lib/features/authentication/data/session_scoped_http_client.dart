import 'dart:convert';

import 'package:http/http.dart' as http;

import 'jwt_claims.dart';

/// Cliente HTTP que ata cada solicitud de segundo factor a la sesión que la
/// emitió y descarta la respuesta si esa sesión dejó de ser la vigente.
///
/// **Por qué existe.** En la versión instalada de GoTrue, `mfa.verify` guarda
/// la sesión que trae la respuesta y emite `mfaChallengeVerified` **antes** de
/// devolver el control: cualquier comprobación posterior en el repositorio o
/// en el controller llega tarde. Si la persona cerró sesión (o entró con otra
/// cuenta) mientras la respuesta viajaba, el SDK restauraría la sesión
/// anterior o pisaría la nueva. La única capa que ve la respuesta antes que
/// el SDK es esta: el cliente HTTP que Supabase recibe en `initialize`.
///
/// **Qué hace.** Solo para las rutas de segundo factor (`/auth/v1/factors…`),
/// toma la identidad de sesión del `Authorization: Bearer` de la solicitud
/// ([sessionIdentityOf]) y la compara con la sesión vigente del SDK, dos
/// veces:
///
/// * **antes de enviar**: si el token ya no es el de la sesión vigente, la
///   solicitud no sale (ninguna continuación manda credenciales de otra
///   cuenta);
/// * **al recibir el cuerpo completo**: si la sesión cambió mientras la
///   respuesta viajaba, el cuerpo se descarta y el SDK recibe un `401` con
///   `error_code` `stale_session`, que el repositorio traduce a un fallo
///   tipado. El SDK nunca ve la sesión de la respuesta, así que no la guarda
///   ni emite eventos por ella. La decisión se toma con el cuerpo ya leído a
///   propósito: con un cliente real `send` resuelve al llegar las cabeceras y
///   el SDK recién guarda la sesión cuando termina de leer el cuerpo; decidir
///   antes dejaría esa ventana abierta.
///
/// Una renovación legítima del token no cambia el `session_id`, así que no
/// se confunde con un cambio de sesión. El resto del tráfico (login, logout,
/// refresh, `/user`, PostgREST, Storage) pasa tal cual: el refresco ya lo
/// protege el propio SDK (descarta el resultado si la sesión cambió mientras
/// esperaba), `/user` no muta la sesión, y guardarlo rompería los flujos del
/// SDK que consultan `/user` con un token que todavía no es el vigente.
class SessionScopedHttpClient extends http.BaseClient {
  SessionScopedHttpClient(this._inner, {required this.currentAccessToken});

  final http.Client _inner;

  /// Access token de la sesión vigente del SDK en este instante, o `null`
  /// sin sesión. Se lee en cada solicitud, nunca se guarda.
  final String? Function() currentAccessToken;

  /// `error_code` con el que el SDK ve una respuesta descartada.
  static const staleSessionCode = 'stale_session';

  /// Rutas cuya respuesta puede mutar la sesión del SDK a partir de una
  /// operación de segundo factor.
  static bool isGuarded(Uri url) => url.path.contains('/auth/v1/factors');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!isGuarded(request.url)) {
      return _inner.send(request);
    }
    final requestSession = sessionIdentityOf(_bearerOf(request));
    if (requestSession == null || requestSession != _currentSession()) {
      return _staleResponse(request);
    }
    final response = await _inner.send(request);
    final body = await response.stream.toBytes();
    if (requestSession != _currentSession()) {
      // El cuerpo ya se consumió (la conexión queda libre) y no llega a nadie.
      return _staleResponse(request);
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(body),
      response.statusCode,
      contentLength: body.length,
      request: request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();

  String? _currentSession() => sessionIdentityOf(currentAccessToken());

  static String? _bearerOf(http.BaseRequest request) {
    for (final entry in request.headers.entries) {
      if (entry.key.toLowerCase() == 'authorization') {
        const prefix = 'Bearer ';
        if (entry.value.startsWith(prefix)) {
          return entry.value.substring(prefix.length);
        }
        return null;
      }
    }
    return null;
  }

  /// Misma forma que un error de GoTrue: `code` numérico, `error_code` y
  /// `msg`, sin cabecera de versión de API, para que el SDK lo convierta en
  /// una `AuthApiException` con `code == stale_session`.
  static http.StreamedResponse _staleResponse(http.BaseRequest request) {
    final body = utf8.encode(
      jsonEncode(<String, Object>{
        'code': 401,
        'error_code': staleSessionCode,
        'msg': 'La sesión que inició esta operación ya no es la vigente',
      }),
    );
    return http.StreamedResponse(
      Stream<List<int>>.value(body),
      401,
      contentLength: body.length,
      request: request,
      headers: const {'content-type': 'application/json'},
      reasonPhrase: 'Unauthorized',
    );
  }
}
