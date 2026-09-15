import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'second_factor_cleanup_policy.dart';

/// Registra **cada pedido de verificación de segundo factor que sale hacia el
/// servidor**, y resuelve ese pedido con su propia respuesta.
///
/// ## Por qué tiene que estar acá y no en el repositorio
///
/// La versión anterior contaba intentos en el repositorio, o sea contaba
/// *invocaciones* de `verifySecondFactor`. Alcanza hoy porque nada reintenta,
/// pero es un supuesto invisible: cualquier cliente que reintente convierte
/// una invocación en varios pedidos, el servidor puede aceptar el primero, y
/// el rechazo del segundo «paga» por el primero. Contando acá se cuenta lo
/// único que importa, que es lo que el servidor pudo haber procesado.
///
/// ## La composición, y por qué este es el lugar más interno
///
/// ```
/// GoTrueClient
///   └─ SessionScopedHttpClient        descarta respuestas de otra sesión
///        └─ SecondFactorAttemptRecorder   ← registra cada pedido
///             └─ cliente terminal (socket)
/// ```
///
/// **Este objeto crea su propio cliente terminal** y no acepta uno en el
/// constructor de producción. Es a propósito: así no se puede meter nada
/// —un `RetryClient`, por ejemplo— *debajo* suyo, que es la única posición
/// desde la que un reintento quedaría sin registrar. Todo lo que se agregue
/// por encima pasa igual por acá, pedido por pedido.
/// [SecondFactorAttemptRecorder.withInnerClient] existe solo para las pruebas.
///
/// El orden con el guard también importa y es el que está: si el guard
/// **no manda** la solicitud (sesión cambiada antes de salir), nunca llega
/// acá y no se cuenta, que es correcto porque el servidor no la vio. Y si el
/// guard **descarta la respuesta** de una solicitud que sí salió, acá ya se
/// vio la respuesta real, así que el desenlace se evalúa sobre lo que
/// contestó el servidor y no sobre el `401` sintetizado.
class SecondFactorAttemptRecorder extends http.BaseClient {
  /// Constructor de producción: el cliente terminal es propio.
  SecondFactorAttemptRecorder(this._policy) : _inner = http.Client();

  /// Solo para pruebas: permite inyectar el cliente de más abajo.
  @visibleForTesting
  SecondFactorAttemptRecorder.withInnerClient(this._policy, this._inner);

  final http.Client _inner;
  final SecondFactorCleanupPolicy _policy;

  /// Id del factor si [request] es un pedido de verificación, o `null`.
  ///
  /// La forma es `…/auth/v1/factors/{id}/verify` con `POST`. Se mira la ruta,
  /// no el cuerpo: el cuerpo de una solicitud ya enviada no se puede releer.
  static String? verifyFactorId(http.BaseRequest request) {
    if (request.method != 'POST') return null;
    final segmentos = request.url.pathSegments;
    if (segmentos.length < 3) return null;
    if (segmentos.last != 'verify') return null;
    if (segmentos[segmentos.length - 3] != 'factors') return null;
    return segmentos[segmentos.length - 2];
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final factorId = verifyFactorId(request);
    if (factorId == null) return _inner.send(request);

    // Se anota ANTES de soltar el pedido: si esto muere acá, o la respuesta
    // se pierde, lo que queda escrito es «no sé cómo terminó».
    final intento = _policy.beginVerifyAttempt(factorId);

    final respuesta = await _inner.send(request);
    // El cuerpo se lee entero para poder clasificarlo. Si la lectura falla,
    // la excepción sale y el intento queda sin resolver, que es el lado
    // seguro.
    final cuerpo = await respuesta.stream.toBytes();
    if (isDefinitiveRejectionResponse(respuesta.statusCode, cuerpo)) {
      _policy.rejectVerifyAttempt(intento);
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(cuerpo),
      respuesta.statusCode,
      contentLength: cuerpo.length,
      request: request,
      headers: respuesta.headers,
      reasonPhrase: respuesta.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}
