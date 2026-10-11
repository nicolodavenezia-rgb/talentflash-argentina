// D1-bis · La limpieza automática no destruye un factor VERIFICADO.
//
// Estos tests nacieron reproduciendo el defecto sobre `3abeae2`, donde la app
// sí mandaba bajas automáticas. Hoy no manda ninguna, y quedan como regresión.
//
// **No corre con `flutter test`.** Vive fuera de `test/` a propósito: necesita
// el stack levantado. Ejecución explícita:
//
//     npm run db:start          # si el stack no está levantado
//     npm run mfa:test:flutter  # == flutter test test_integration
//
// Si el stack no responde, los tests **fallan** con un mensaje de bloqueo: una
// integración que no se pudo correr nunca se informa como aprobada.
//
// **Qué distingue este archivo del de D1.** `d1_regresion_servidor_test.dart`
// cubre la ventana en la que el cliente YA SE ENTERÓ de que su sesión subió a
// `aal2`. Acá se cubre la que no: el servidor aceptó el código y la respuesta
// nunca llegó, así que el cliente conserva el access token original, cuyo
// claim sigue diciendo `aal1`. El nivel del token no lo protege, porque el
// servidor resuelve el `insufficient_aal` por el nivel de la **sesión**.
//
// Los tests están separados a propósito, y la distinción importa:
//
//   CONTRATO DEL ENDPOINT (llamada directa, sin la app)
//   1. Token viejo con claim `aal1` sobre una sesión ya elevada: el servidor
//      ACEPTA la baja. Es el hecho que obliga a todo lo demás.
//   2. Sesión NUEVA, genuinamente `aal1`: el servidor la RECHAZA. Es un caso
//      distinto del anterior y no hay que confundirlos.
//   Los dos pasan sobre 3abeae2: describen el servidor, no la app.
//
//   RECORRIDO POR LA APP (repositorio y SDK reales)
//   3. Respuesta perdida y descarte automático.          Falla sobre 3abeae2.
//   4. Reintento tras la respuesta perdida.              Falla sobre 3abeae2.
//   5. Composición con `RetryClient`: dos pedidos por una invocación.
//   6. Lectura de factores desactualizada.               Falla sobre 3abeae2.
//   7. Otro cliente de la misma cuenta verifica con el secreto mostrado,
//      SECUENCIALMENTE. Documenta que el secreto no es exclusivo.
//
// Nada se fabrica: los tokens, el `aal2`, el cuerpo de `/user` y el estado
// final son del servidor. Lo único que controla el test es el momento en que
// viajan los mensajes, y qué respuesta se pierde. Y lo que se asevera es el
// **estado del factor en el servidor**, nunca que se haya llamado a un
// callback.
//
// **QUÉ CAMBIÓ Y POR QUÉ ESTOS TESTS SON MÁS DÉBILES DE LO QUE PARECEN.**
// Desde que la app dejó de mandar bajas automáticas
// (`SecondFactorCleanupPolicy.automaticUnenrollEnabled == false`), del 3 al 7
// pasan **porque no sale ningún pedido**, no porque la política haya decidido
// bien en cada caso. Siguen valiendo como regresión —si alguien vuelve a
// encender las bajas sin arreglar el endpoint, caen— pero la decisión fina
// (qué intento queda sin resolver y cuál no) se prueba en
// `test/features/authentication/data/second_factor_cleanup_policy_test.dart` y
// en el de assurance, que miran el registro y no solo el resultado.
//
// Ninguno de estos tests ejercita solicitudes CONCURRENTES: los pasos son
// secuenciales. La carrera del `UnenrollFactor` de GoTrue —el chequeo de
// estado fuera de la transacción que borra— está señalada por lectura del
// código y **no reproducida acá**.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

// `crypto` llega como dependencia transitiva del SDK y se usa solo acá, para
// calcular un código TOTP de verdad.
// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http/retry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentflash_argentina/features/authentication/data/jwt_claims.dart';
import 'package:talentflash_argentina/features/authentication/data/second_factor_attempt_recorder.dart';
import 'package:talentflash_argentina/features/authentication/data/second_factor_cleanup_policy.dart';
import 'package:talentflash_argentina/features/authentication/data/session_scoped_http_client.dart';
import 'package:talentflash_argentina/features/authentication/data/supabase_auth_repository.dart';

// --- Compuertas sobre el transporte ----------------------------------------

/// Qué hacer con una solicitud que coincide.
enum _Efecto {
  /// Retener la **respuesta ya recibida** hasta que el test la libere. El
  /// servidor ya la procesó; el cliente todavía no la vio.
  retenerRespuesta,

  /// Dejar que la solicitud llegue al servidor, leer la respuesta completa
  /// (para que no queden dudas de que el servidor terminó) y **perderla**: el
  /// cliente recibe un error de transporte. Es la «respuesta perdida».
  perderRespuesta,
}

class _Compuerta {
  _Compuerta(this.coincide, {required this.efecto});

  final bool Function(http.BaseRequest request) coincide;
  final _Efecto efecto;

  final _capturada = Completer<void>();
  final _abierta = Completer<void>();
  bool _armada = true;

  /// Se completa cuando el servidor ya respondió y la compuerta la retuvo.
  Future<void> get capturada => _capturada.future;

  void liberar() {
    if (!_abierta.isCompleted) _abierta.complete();
  }
}

/// Cliente de red real que solo demora o pierde mensajes. No altera bytes,
/// estado ni cabeceras.
class _ClienteConCompuertas extends http.BaseClient {
  _ClienteConCompuertas(this._inner);

  final http.Client _inner;
  final List<_Compuerta> compuertas = [];

  /// `MÉTODO ruta | aal del bearer`. Nunca el token.
  final List<String> enviadas = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bearer = request.headers.entries
        .firstWhere(
          (e) => e.key.toLowerCase() == 'authorization',
          orElse: () => const MapEntry('', ''),
        )
        .value;
    final token = bearer.startsWith('Bearer ') ? bearer.substring(7) : null;
    enviadas.add(
      '${request.method} ${request.url.path} '
      '| aal=${decodeJwtClaims(token)?['aal'] ?? '(sin aal)'}',
    );

    final respuesta = await _inner.send(request);

    for (final compuerta in compuertas) {
      if (!compuerta._armada || !compuerta.coincide(request)) continue;
      compuerta._armada = false;
      // El cuerpo se lee SIEMPRE: así el servidor terminó de procesar antes de
      // que el test decida qué hacer con la respuesta.
      final cuerpo = await respuesta.stream.toBytes();
      if (!compuerta._capturada.isCompleted) compuerta._capturada.complete();
      if (compuerta.efecto == _Efecto.perderRespuesta) {
        throw http.ClientException(
          'respuesta perdida a propósito por el test',
          request.url,
        );
      }
      await compuerta._abierta.future;
      return http.StreamedResponse(
        Stream<List<int>>.value(cuerpo),
        respuesta.statusCode,
        contentLength: cuerpo.length,
        request: request,
        headers: respuesta.headers,
        reasonPhrase: respuesta.reasonPhrase,
      );
    }
    return respuesta;
  }

  @override
  void close() => _inner.close();
}

// --- TOTP real (RFC 6238) ---------------------------------------------------
List<int> _base32Decode(String input) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  final clean = input.toUpperCase().replaceAll(RegExp(r'[=\s]'), '');
  var bits = 0;
  var value = 0;
  final out = <int>[];
  for (final char in clean.split('')) {
    final index = alphabet.indexOf(char);
    if (index < 0) throw const FormatException('base32 inválido');
    value = (value << 5) | index;
    bits += 5;
    if (bits >= 8) {
      out.add((value >>> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return out;
}

String _totpCode(String secret, int step) {
  final counter = List<int>.filled(8, 0);
  var value = step;
  for (var i = 7; i >= 0; i--) {
    counter[i] = value & 0xff;
    value = value >> 8;
  }
  final digest = Hmac(sha1, _base32Decode(secret)).convert(counter).bytes;
  final offset = digest[digest.length - 1] & 0x0f;
  final binary =
      ((digest[offset] & 0x7f) << 24) |
      ((digest[offset + 1] & 0xff) << 16) |
      ((digest[offset + 2] & 0xff) << 8) |
      (digest[offset + 3] & 0xff);
  return (binary % 1000000).toString().padLeft(6, '0');
}

int _totpStep() => DateTime.now().millisecondsSinceEpoch ~/ 1000 ~/ 30;

/// Espera a que empiece un paso TOTP distinto de [usado]: un código ya
/// consumido no se puede reutilizar.
Future<void> _esperarPasoNuevo(int usado) async {
  final limite = DateTime.now().add(const Duration(seconds: 45));
  while (_totpStep() == usado) {
    if (DateTime.now().isAfter(limite)) {
      fail('se agotó el tiempo esperando un paso TOTP nuevo');
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}

// --- Respuesta cruda --------------------------------------------------------

class _Respuesta {
  _Respuesta(this.status, this.json);
  final int status;
  final Map<String, dynamic>? json;

  /// `true` solo si es un **200 con cuerpo de usuario de GoTrue**. Sin esto,
  /// `json?['factors'] ?? []` convierte un 401 en una lista vacía y una
  /// comprobación del tipo «el factor sigue ahí» se cae, o peor, una del tipo
  /// «desapareció» se aprueba sola.
  bool get esUsuario =>
      status == 200 && json?['id'] is String && json?['aud'] is String;

  List<Map<String, dynamic>> get factores =>
      (json?['factors'] as List? ?? []).cast<Map<String, dynamic>>();
}

void main() {
  final envFile = File('env/dev.json');
  if (!envFile.existsSync()) {
    test('BLOQUEO: falta env/dev.json para la integración real', () {
      fail('no se encontró env/dev.json: la integración NO se ejecutó');
    });
    return;
  }
  final env = jsonDecode(envFile.readAsStringSync()) as Map<String, dynamic>;
  final baseUrl = env['SUPABASE_URL'] as String;
  final anonKey = env['SUPABASE_ANON_KEY'] as String;
  const container = 'supabase_db_talentflash_argentina';
  const password = 'password123';

  if (!RegExp(r'^https?://(127\.0\.0\.1|localhost)(:\d+)?$')
      .hasMatch(baseUrl)) {
    test('BLOQUEO: el destino configurado no es local', () {
      fail(
        'destino "$baseUrl": la integración real solo corre contra el '
        'stack local',
      );
    });
    return;
  }

  final crudo = IOClient();

  Future<_Respuesta> pedir(
    String path, {
    String? token,
    String metodo = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final headers = <String, String>{
      'apikey': anonKey,
      'Content-Type': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final uri = Uri.parse('$baseUrl$path');
    final respuesta = await switch (metodo) {
      'POST' => crudo.post(uri, headers: headers, body: jsonEncode(body ?? {})),
      'DELETE' => crudo.delete(uri, headers: headers),
      _ => crudo.get(uri, headers: headers),
    }.timeout(const Duration(seconds: 15));
    Map<String, dynamic>? json;
    try {
      final decodificado = jsonDecode(respuesta.body);
      if (decodificado is Map<String, dynamic>) json = decodificado;
    } on FormatException {
      json = null;
    }
    return _Respuesta(respuesta.statusCode, json);
  }

  ProcessResult psql(String sql) => Process.runSync('docker', [
    'exec',
    '-i',
    container,
    'psql',
    '-X',
    '-U',
    'postgres',
    '-d',
    'postgres',
    '-v',
    'ON_ERROR_STOP=1',
    '-At',
    '-c',
    sql,
  ], runInShell: true);

  /// Cuenta sintética propia de cada test, con su limpieza registrada en
  /// `addTearDown` y **no** en un `finally`: una excepción lanzada desde un
  /// `finally` reemplazaría a la falla real del test.
  Future<String> cuentaNueva(String prefijo) async {
    final runId = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final email = '$prefijo-$runId@tests.local';
    addTearDown(() {
      final borrado = psql("delete from auth.users where email = '$email';");
      expect(
        borrado.exitCode,
        0,
        reason: 'la limpieza de $email falló: ${borrado.stderr}',
      );
      final quedan = psql(
        "select count(*) from auth.users where email = '$email';",
      );
      expect(quedan.exitCode, 0, reason: 'no se pudo verificar la limpieza');
      expect(
        quedan.stdout.toString().trim(),
        '0',
        reason: 'quedaron datos de la cuenta sintética $email',
      );
    });
    final alta = await pedir(
      '/auth/v1/signup',
      metodo: 'POST',
      body: {
        'email': email,
        'password': password,
        'data': {'role': 'candidate'},
      },
    );
    expect(alta.status, 200, reason: 'no se pudo crear la cuenta sintética');
    return email;
  }

  Future<Map<String, String>> ingresar(String email) async {
    final res = await pedir(
      '/auth/v1/token?grant_type=password',
      metodo: 'POST',
      body: {'email': email, 'password': password},
    );
    expect(res.status, 200, reason: 'el login falló');
    return {
      'token': res.json!['access_token'] as String,
      'refresh': res.json!['refresh_token'] as String,
    };
  }

  Future<void> exigirStack() async {
    http.Response probe;
    try {
      probe = await crudo
          .get(Uri.parse('$baseUrl/auth/v1/health'))
          .timeout(const Duration(seconds: 5));
    } on Object catch (error) {
      fail(
        'BLOQUEO: el stack local no responde en $baseUrl ($error). '
        'La integración NO se ejecutó: levantalo con `npm run db:start`.',
      );
    }
    if (probe.statusCode != 200) {
      fail(
        'BLOQUEO: el stack local respondió ${probe.statusCode}. '
        'La integración NO se ejecutó.',
      );
    }
  }

  /// Alta + desafío + verificación de un factor TOTP, **por HTTP crudo**, con
  /// el token [token]. El SDK no se entera: esa es justamente la situación que
  /// se quiere reproducir.
  Future<String> factorVerificadoCrudo(String token) async {
    final alta = await pedir(
      '/auth/v1/factors',
      token: token,
      metodo: 'POST',
      body: {'factor_type': 'totp', 'friendly_name': 'F-${_totpStep()}'},
    );
    expect(alta.status, 200, reason: 'el alta del factor falló');
    final factorId = alta.json!['id'] as String;
    final secreto = (alta.json!['totp'] as Map)['secret'] as String;
    final desafio = await pedir(
      '/auth/v1/factors/$factorId/challenge',
      token: token,
      metodo: 'POST',
    );
    expect(desafio.status, 200, reason: 'el desafío falló');
    final paso = _totpStep();
    final verificacion = await pedir(
      '/auth/v1/factors/$factorId/verify',
      token: token,
      metodo: 'POST',
      body: {
        'challenge_id': desafio.json!['id'],
        'code': _totpCode(secreto, paso),
      },
    );
    expect(
      verificacion.status,
      200,
      reason: 'la verificación falló: ${verificacion.json}',
    );
    return factorId;
  }

  group('CONTRATO del endpoint (llamada directa, sin pasar por la app)', () {
    test(
      'un token VIEJO cuyo claim dice aal1, sobre una sesión que el servidor '
      'YA subió a aal2, puede borrar un factor verificado',
      () async {
        await exigirStack();
        final email = await cuentaNueva('d1bis-contrato-viejo');
        final sesion = await ingresar(email);
        final tokenViejo = sesion['token']!;
        expect(
          decodeJwtClaims(tokenViejo)?['aal'],
          'aal1',
          reason: 'una sesión de contraseña sola arranca en aal1',
        );

        final factorId = await factorVerificadoCrudo(tokenViejo);

        // El token no cambió: el que tiene el cliente sigue diciendo aal1.
        expect(decodeJwtClaims(tokenViejo)?['aal'], 'aal1');

        final baja = await pedir(
          '/auth/v1/factors/$factorId',
          token: tokenViejo,
          metodo: 'DELETE',
        );
        expect(
          baja.status,
          200,
          reason:
              'HECHO DEL SERVIDOR: el insufficient_aal se resuelve por el '
              'nivel de la SESIÓN, no por el claim del token. Si esto dejara '
              'de ser 200, la corrección de D1-bis se puede simplificar.',
        );

        final despues = await pedir('/auth/v1/user', token: tokenViejo);
        expect(
          despues.esUsuario,
          isTrue,
          reason: 'la consulta posterior tiene que ser un 200 de usuario',
        );
        expect(
          despues.factores.where((f) => f['id'] == factorId),
          isEmpty,
          reason: 'y el factor verificado desapareció de verdad',
        );
      },
    );

    test(
      'una sesión NUEVA, genuinamente en aal1, NO puede borrar un factor '
      'verificado (caso distinto del anterior: acá el servidor sí protege)',
      () async {
        await exigirStack();
        final email = await cuentaNueva('d1bis-contrato-nueva');
        final primera = await ingresar(email);
        final factorId = await factorVerificadoCrudo(primera['token']!);

        // Sesión NUEVA: otro login. El servidor la tiene en aal1 de verdad,
        // no solo el claim del token.
        final segunda = await ingresar(email);
        expect(decodeJwtClaims(segunda['token'])?['aal'], 'aal1');
        expect(
          decodeJwtClaims(segunda['token'])?['session_id'],
          isNot(decodeJwtClaims(primera['token'])?['session_id']),
          reason: 'un login nuevo es otra sesión',
        );

        final baja = await pedir(
          '/auth/v1/factors/$factorId',
          token: segunda['token'],
          metodo: 'DELETE',
        );
        expect(baja.status, isNot(200));
        expect(baja.json?['error_code'], 'insufficient_aal');

        final despues = await pedir('/auth/v1/user', token: segunda['token']);
        expect(despues.esUsuario, isTrue);
        final sobrevivientes = despues.factores.where(
          (f) => f['id'] == factorId,
        );
        expect(sobrevivientes, hasLength(1));
        expect(sobrevivientes.single['status'], 'verified');
      },
    );
  });

  group('RECORRIDO POR LA APP (repositorio real, SDK real)', () {
    /// Arma el cableado real de la app, en el mismo orden que `bootstrap.dart`:
    ///
    ///   GoTrueClient → SessionScopedHttpClient → SecondFactorAttemptRecorder
    ///     → (compuertas del test) → red
    ///
    /// Las compuertas van **debajo** del recorder para poder perder una
    /// respuesta que el servidor ya procesó: así el recorder ve el pedido
    /// salir y no ve una respuesta que lo resuelva, que es exactamente la
    /// ventana de D1.
    ///
    /// [reintentos] inserta un `RetryClient` **por encima** del recorder, que
    /// es la composición que antes escondía los reintentos cuando la cuenta
    /// vivía en el repositorio.
    (_ClienteConCompuertas, GoTrueClient, SupabaseAuthRepository) cablear({
      int reintentos = 0,
    }) {
      final red = _ClienteConCompuertas(IOClient());
      final politica = SecondFactorCleanupPolicy();
      // ignore: invalid_use_of_visible_for_testing_member
      final recorder = SecondFactorAttemptRecorder.withInnerClient(
        politica,
        red,
      );
      final http.Client encimaDelRecorder = reintentos > 0
          ? RetryClient(
              recorder,
              retries: reintentos,
              when: (_) => false,
              whenError: (_, _) => true,
              delay: (_) => Duration.zero,
            )
          : recorder;
      late final GoTrueClient auth;
      final guard = SessionScopedHttpClient(
        encimaDelRecorder,
        currentAccessToken: () => auth.currentSession?.accessToken,
      );
      auth = GoTrueClient(
        url: '$baseUrl/auth/v1',
        headers: {'apikey': anonKey},
        httpClient: guard,
        autoRefreshToken: false,
      );
      addTearDown(red.close);
      return (red, auth, SupabaseAuthRepository(auth, politica));
    }

    test('RESPUESTA PERDIDA: el servidor aceptó el código, el cliente conserva '
        'el token aal1 de la MISMA sesión, y el descarte automático NO debe '
        'borrar el factor ya verificado', () async {
      await exigirStack();
      final email = await cuentaNueva('d1bis-app-descarte');
      final (red, auth, repositorio) = cablear();

      await auth.signInWithPassword(email: email, password: password);
      final tokenOriginal = auth.currentSession!.accessToken;
      final sesionOriginal = sessionIdentityOf(tokenOriginal);
      expect(decodeJwtClaims(tokenOriginal)?['aal'], 'aal1');

      final alta = await repositorio.enrollTotp(friendlyName: 'D1bis');
      final desafio = await repositorio.challengeSecondFactor(alta.factorId);

      // La respuesta de la verificación se PIERDE: el servidor la procesa y
      // el cliente recibe un error de transporte.
      red.compuertas.add(
        _Compuerta(
          (r) => r.method == 'POST' && r.url.path.endsWith('/verify'),
          efecto: _Efecto.perderRespuesta,
        ),
      );
      final paso = _totpStep();
      await expectLater(
        repositorio.verifySecondFactor(
          factorId: alta.factorId,
          challengeId: desafio.id,
          code: _totpCode(alta.secret, paso),
        ),
        throwsA(anything),
        reason: 'la respuesta se perdió: la operación tiene que fallar',
      );

      // Sigue siendo la MISMA sesión, sin logout ni login nuevo, y el token
      // que conserva el cliente sigue diciendo aal1.
      expect(
        auth.currentSession!.accessToken,
        tokenOriginal,
        reason: 'el SDK no llegó a guardar la sesión aal2',
      );
      expect(sessionIdentityOf(tokenOriginal), sesionOriginal);
      expect(decodeJwtClaims(tokenOriginal)?['aal'], 'aal1');

      // …pero el servidor SÍ aceptó el código: el factor está verificado.
      final antes = await pedir('/auth/v1/user', token: tokenOriginal);
      expect(antes.esUsuario, isTrue);
      expect(
        antes.factores.firstWhere((f) => f['id'] == alta.factorId)['status'],
        'verified',
        reason:
            'premisa del test: el servidor aceptó el código aunque el '
            'cliente no se haya enterado',
      );

      // El recorrido de la app: descarte automático del «pendiente».
      await repositorio.discardPendingSecondFactor(alta.factorId);

      final despues = await pedir('/auth/v1/user', token: tokenOriginal);
      expect(
        despues.esUsuario,
        isTrue,
        reason: 'la consulta posterior tiene que ser un 200 de usuario',
      );
      final sobrevivientes = despues.factores.where(
        (f) => f['id'] == alta.factorId,
      );
      expect(
        sobrevivientes,
        hasLength(1),
        reason:
            'CRITERIO DE ACEPTACIÓN: una limpieza automática no puede '
            'eliminar un factor que ya quedó verificado, aunque el cliente '
            'ignore ese resultado. Solicitudes: ${red.enviadas}',
      );
      expect(sobrevivientes.single['status'], 'verified');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test(
      'REINTENTO tras la respuesta perdida: el rechazo del segundo intento no '
      'desprotege al primero, que el servidor sí aceptó',
      () async {
        await exigirStack();
        final email = await cuentaNueva('d1bis-app-reintento');
        final (red, auth, repositorio) = cablear();

        await auth.signInWithPassword(email: email, password: password);
        final tokenOriginal = auth.currentSession!.accessToken;
        final alta = await repositorio.enrollTotp(friendlyName: 'D1bis');
        final desafio = await repositorio.challengeSecondFactor(alta.factorId);

        // Intento 1: el servidor acepta, la respuesta se pierde.
        red.compuertas.add(
          _Compuerta(
            (r) => r.method == 'POST' && r.url.path.endsWith('/verify'),
            efecto: _Efecto.perderRespuesta,
          ),
        );
        final paso = _totpStep();
        await expectLater(
          repositorio.verifySecondFactor(
            factorId: alta.factorId,
            challengeId: desafio.id,
            code: _totpCode(alta.secret, paso),
          ),
          throwsA(anything),
        );
        final intermedio = await pedir('/auth/v1/user', token: tokenOriginal);
        expect(
          intermedio.factores.firstWhere(
            (f) => f['id'] == alta.factorId,
          )['status'],
          'verified',
          reason: 'premisa: el servidor aceptó el código',
        );

        // Intento 2: la persona reintenta con un desafío nuevo y un código
        // incorrecto. El servidor responde `mfa_verification_failed`, que es
        // un rechazo legítimo DE ESE INTENTO.
        final desafio2 = await repositorio.challengeSecondFactor(alta.factorId);
        await expectLater(
          repositorio.verifySecondFactor(
            factorId: alta.factorId,
            challengeId: desafio2.id,
            code: '000000',
          ),
          throwsA(anything),
        );
        expect(
          auth.currentSession!.accessToken,
          tokenOriginal,
          reason: 'el cliente sigue con el token aal1 de la misma sesión',
        );

        // La persona sale de la pantalla: descarte automático.
        await repositorio.discardPendingSecondFactor(alta.factorId);

        final despues = await pedir('/auth/v1/user', token: tokenOriginal);
        expect(despues.esUsuario, isTrue);
        final sobrevivientes = despues.factores.where(
          (f) => f['id'] == alta.factorId,
        );
        expect(
          sobrevivientes,
          hasLength(1),
          reason:
              'CRITERIO DE ACEPTACIÓN: el rechazo del reintento no puede '
              'desproteger un factor ya verificado. '
              'Solicitudes: ${red.enviadas}',
        );
        expect(sobrevivientes.single['status'], 'verified');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('COMPOSICIÓN CON REINTENTOS: con un RetryClient por encima, el primer '
        'pedido lo acepta el servidor y su respuesta se pierde, el reintento se '
        'rechaza, y el factor sobrevive', () async {
      // Esta es la composición que antes escondía los reintentos: contando
      // invocaciones en el repositorio, acá se veía UNA verificación, el
      // servidor recibía DOS pedidos, y el rechazo del segundo «pagaba» por
      // el primero, que el servidor había aceptado. Contando en el
      // transporte —que es el punto más interno— se ven los dos.
      await exigirStack();
      final email = await cuentaNueva('d1bis-app-retry');
      final (red, auth, repositorio) = cablear(reintentos: 1);

      await auth.signInWithPassword(email: email, password: password);
      final tokenOriginal = auth.currentSession!.accessToken;
      final alta = await repositorio.enrollTotp(friendlyName: 'D1bis');
      final desafio = await repositorio.challengeSecondFactor(alta.factorId);

      // La compuerta se desarma después del primer pedido, así que el
      // reintento del RetryClient sí llega al servidor: ahí el desafío ya
      // fue consumido y GoTrue lo rechaza.
      red.compuertas.add(
        _Compuerta(
          (r) => r.method == 'POST' && r.url.path.endsWith('/verify'),
          efecto: _Efecto.perderRespuesta,
        ),
      );
      final paso = _totpStep();
      await expectLater(
        repositorio.verifySecondFactor(
          factorId: alta.factorId,
          challengeId: desafio.id,
          code: _totpCode(alta.secret, paso),
        ),
        throwsA(anything),
      );

      final verifies = red.enviadas.where((s) => s.contains('/verify')).length;
      expect(
        verifies,
        2,
        reason:
            'el RetryClient mandó DOS pedidos al servidor por una sola '
            'invocación: ${red.enviadas}',
      );
      expect(auth.currentSession!.accessToken, tokenOriginal);

      await repositorio.discardPendingSecondFactor(alta.factorId);

      final despues = await pedir('/auth/v1/user', token: tokenOriginal);
      expect(despues.esUsuario, isTrue);
      final sobrevivientes = despues.factores.where(
        (f) => f['id'] == alta.factorId,
      );
      expect(
        sobrevivientes,
        hasLength(1),
        reason:
            'CRITERIO DE ACEPTACIÓN: el pedido reintentado quedó anotado, '
            'así que el rechazo del segundo no resolvió al primero. '
            'Solicitudes: ${red.enviadas}',
      );
      expect(sobrevivientes.single['status'], 'verified');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test(
      'LECTURA DESACTUALIZADA: la verificación llega DESPUÉS de que enrollTotp '
      'leyó los factores y ANTES del borrado; la limpieza NO debe borrar el '
      'factor que quedó verificado',
      () async {
        await exigirStack();
        final email = await cuentaNueva('d1bis-app-alta');
        final (red, auth, repositorio) = cablear();

        await auth.signInWithPassword(email: email, password: password);
        final tokenOriginal = auth.currentSession!.accessToken;
        expect(decodeJwtClaims(tokenOriginal)?['aal'], 'aal1');

        // Un factor pendiente con su desafío, por el camino de la app: así el
        // transporte lo ve y lo anota, igual que en producción.
        final alta = await repositorio.enrollTotp(friendlyName: 'Interrumpida');
        final factorId = alta.factorId;
        final desafio = await repositorio.challengeSecondFactor(factorId);

        // La lectura de factores del alta SIGUIENTE se retiene: el servidor ya
        // respondió «pendiente», el cliente todavía no lo vio.
        final compuerta = _Compuerta(
          (r) => r.method == 'GET' && r.url.path.endsWith('/user'),
          efecto: _Efecto.retenerRespuesta,
        );
        red.compuertas.add(compuerta);

        final enAlta = repositorio.enrollTotp(friendlyName: 'Nueva');
        await compuerta.capturada.timeout(
          const Duration(seconds: 20),
          onTimeout: () => fail('enrollTotp nunca consultó GET /user'),
        );

        // Con la lectura retenida, el servidor acepta el código del factor
        // pendiente y la respuesta se pierde. A partir de acá F está
        // VERIFICADO en el servidor y la sesión está en aal2, pero el token
        // del cliente sigue en aal1 y la app no se enteró de nada.
        red.compuertas.add(
          _Compuerta(
            (r) => r.method == 'POST' && r.url.path.endsWith('/verify'),
            efecto: _Efecto.perderRespuesta,
          ),
        );
        final paso = _totpStep();
        await expectLater(
          repositorio.verifySecondFactor(
            factorId: factorId,
            challengeId: desafio.id,
            code: _totpCode(alta.secret, paso),
          ),
          throwsA(anything),
        );
        expect(auth.currentSession!.accessToken, tokenOriginal);
        expect(decodeJwtClaims(tokenOriginal)?['aal'], 'aal1');

        compuerta.liberar();
        // El alta puede terminar bien o cortarse: lo que se juzga es el
        // factor, no el desenlace del alta.
        await enAlta.then<void>((_) {}, onError: (_) {});

        final despues = await pedir('/auth/v1/user', token: tokenOriginal);
        expect(despues.esUsuario, isTrue);
        final sobrevivientes = despues.factores.where(
          (f) => f['id'] == factorId,
        );
        expect(
          sobrevivientes,
          hasLength(1),
          reason:
              'CRITERIO DE ACEPTACIÓN: la limpieza de pendientes no puede '
              'borrar un factor que el servidor verificó entre la lectura y '
              'el borrado. Solicitudes: ${red.enviadas}',
        );
        expect(sobrevivientes.single['status'], 'verified');
        await _esperarPasoNuevo(paso);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'OTRO CLIENTE de la misma cuenta verifica el factor con el secreto que '
      'se mostró en pantalla, SECUENCIALMENTE, y el factor sobrevive',
      () async {
        // ALCANCE DE ESTE TEST, para no leerlo de más:
        //
        // * Los pasos son **secuenciales**: el otro cliente termina de
        //   verificar ANTES de que la app pida la baja. Esto NO demuestra nada
        //   sobre solicitudes concurrentes, que es donde vive la carrera del
        //   `UnenrollFactor` de GoTrue.
        // * «Otro cliente» acá es otra SESIÓN, y se asevera que el
        //   `session_id` difiere. Otro cliente podría compartir la sesión —dos
        //   instalaciones con el mismo token, por ejemplo—, y ese caso no está
        //   cubierto.
        // * Hoy pasa por una razón más fuerte que la de antes: la app no manda
        //   ninguna baja automática. Antes pasaba porque GoTrue le borraba la
        //   sesión (R2), que además perdona a las sesiones ya `aal2`.
        //
        // Lo que sí documenta: el secreto NO es exclusivo —se muestra como QR y
        // como clave manual para que la persona lo copie—, así que un tercero
        // puede verificar un factor que dio de alta esta app.
        await exigirStack();
        final email = await cuentaNueva('d1bis-otro-cliente');
        final (red, auth, repositorio) = cablear();

        await auth.signInWithPassword(email: email, password: password);
        final tokenApp = auth.currentSession!.accessToken;
        final sesionApp = sessionIdentityOf(tokenApp);
        final alta = await repositorio.enrollTotp(friendlyName: 'Compartido');

        // Otro cliente autenticado de la MISMA cuenta: otro login, otra
        // sesión. Usa el secreto que la app mostró en pantalla.
        final otro = await ingresar(email);
        expect(
          sessionIdentityOf(otro['token']),
          isNot(sesionApp),
          reason: 'es otra sesión, no otro token de la misma',
        );
        final desafio = await pedir(
          '/auth/v1/factors/${alta.factorId}/challenge',
          token: otro['token'],
          metodo: 'POST',
        );
        expect(desafio.status, 200);
        final verificacion = await pedir(
          '/auth/v1/factors/${alta.factorId}/verify',
          token: otro['token'],
          metodo: 'POST',
          body: {
            'challenge_id': desafio.json!['id'],
            'code': _totpCode(alta.secret, _totpStep()),
          },
        );
        expect(
          verificacion.status,
          200,
          reason:
              'premisa: con el secreto mostrado, otro cliente SÍ puede '
              'verificar el factor',
        );

        // La app no se enteró y, por lo que ella sabe, el factor sigue
        // pendiente y es suyo: pide la baja sin dudarlo. Puede terminar de dos
        // maneras, y las dos son inofensivas: o el SDK ya se quedó sin sesión y
        // ni sale el pedido, o sale y el servidor lo rechaza. Lo que se juzga
        // es el estado del factor, no el desenlace de la llamada.
        await repositorio
            .discardPendingSecondFactor(alta.factorId)
            .then<void>((_) {}, onError: (Object _) {});

        final estado = await pedir('/auth/v1/user', token: otro['token']);
        expect(estado.esUsuario, isTrue);
        final sobrevivientes = estado.factores.where(
          (f) => f['id'] == alta.factorId,
        );
        expect(
          sobrevivientes,
          hasLength(1),
          reason:
              'el factor verificado sobrevive. Solicitudes de la app: '
              '${red.enviadas}',
        );
        expect(sobrevivientes.single['status'], 'verified');

        // Y el motivo, comprobado y no supuesto: la sesión de la app ya no
        // existe. Es el límite del modelo, escrito en SecondFactorCleanupPolicy.
        final propia = await pedir('/auth/v1/user', token: tokenApp);
        expect(
          propia.status,
          403,
          reason: 'la sesión de la app murió cuando el otro cliente verificó',
        );
        expect(propia.json?['error_code'], 'session_not_found');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
