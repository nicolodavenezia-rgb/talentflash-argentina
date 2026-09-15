// Regresión de D1 contra el GoTrue REAL del stack local.
//
// **No corre con `flutter test`.** Vive fuera de `test/` a propósito: necesita
// el stack levantado y no puede exigirlo en CI ni en la suite habitual.
// Ejecución explícita:
//
//     npm run db:start          # si el stack no está levantado
//     npm run mfa:test:flutter  # == flutter test test_integration
//
// Si el stack no responde, el test **falla** con un mensaje de bloqueo: una
// integración que no se pudo correr nunca se informa como aprobada.
//
// Qué fija. El defecto D1 era que la limpieza de pendientes del alta borraba el
// factor cuya verificación el servidor acababa de aceptar, porque para entonces
// el token ya había subido a `aal2` —el nivel que el servidor exige para dar de
// baja un factor verificado—. Acá se reproduce ese orden exacto y se comprueba
// el comportamiento CORRECTO: no sale el DELETE, el factor sigue verificado
// según una consulta nueva, y no queda un pendiente de más.
//
// Nada se fabrica: los tokens, el `aal2`, el cuerpo de `/user` y el estado
// final son del servidor. Lo único que controla el test es el MOMENTO en que
// viajan dos mensajes.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

// `crypto` llega como dependencia transitiva del SDK y se usa solo acá, para
// calcular un código TOTP de verdad. No se agrega a `pubspec.yaml` porque esta
// tarea no toca dependencias; si alguna vez dejara de resolverse, este archivo
// falla al compilar, que es la señal correcta para un test de integración.
// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentflash_argentina/features/authentication/data/jwt_claims.dart';
import 'package:talentflash_argentina/features/authentication/data/second_factor_attempt_recorder.dart';
import 'package:talentflash_argentina/features/authentication/data/second_factor_cleanup_policy.dart';
import 'package:talentflash_argentina/features/authentication/data/session_scoped_http_client.dart';
import 'package:talentflash_argentina/features/authentication/data/supabase_auth_repository.dart';
import 'package:talentflash_argentina/features/authentication/providers/auth_providers.dart';
import 'package:talentflash_argentina/features/authentication/providers/second_factor_controller.dart';

/// Compuerta sobre una solicitud concreta, salteando [skip] coincidencias.
///
/// Con [beforeSend] retiene la solicitud **antes de salir** (el servidor
/// todavía no la vio); si no, retiene la **respuesta ya recibida**. La
/// distinción importa: para que la lectura de factores vea F como pendiente de
/// verdad, el servidor no puede haber procesado el código todavía.
class _Gate {
  _Gate(this.matches, {this.skip = 0, this.beforeSend = false});

  final bool Function(http.BaseRequest request) matches;
  final bool beforeSend;
  int skip;

  final _captured = Completer<void>();
  final _open = Completer<void>();
  bool _armed = true;

  Future<void> get captured => _captured.future;
  void release() {
    if (!_open.isCompleted) _open.complete();
  }
}

/// Cliente de red real que solo demora mensajes. No altera bytes, estado ni
/// cabeceras.
class _GatedClient extends http.BaseClient {
  _GatedClient(this._inner);

  final http.Client _inner;
  final List<_Gate> gates = [];

  /// `MÉTODO ruta | aal del bearer`. Nunca el token.
  final List<String> sent = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bearer = request.headers.entries
        .firstWhere(
          (e) => e.key.toLowerCase() == 'authorization',
          orElse: () => const MapEntry('', ''),
        )
        .value;
    final token = bearer.startsWith('Bearer ') ? bearer.substring(7) : null;
    sent.add(
      '${request.method} ${request.url.path} '
      '| aal=${decodeJwtClaims(token)?['aal'] ?? '(sin aal)'}',
    );

    for (final gate in gates) {
      if (!gate._armed || !gate.beforeSend || !gate.matches(request)) continue;
      if (gate.skip > 0) {
        gate.skip--;
        continue;
      }
      gate._armed = false;
      if (!gate._captured.isCompleted) gate._captured.complete();
      await gate._open.future;
      break;
    }

    final response = await _inner.send(request);

    for (final gate in gates) {
      if (!gate._armed || gate.beforeSend || !gate.matches(request)) continue;
      if (gate.skip > 0) {
        gate.skip--;
        continue;
      }
      gate._armed = false;
      final body = await response.stream.toBytes();
      if (!gate._captured.isCompleted) gate._captured.complete();
      await gate._open.future;
      return http.StreamedResponse(
        Stream<List<int>>.value(body),
        response.statusCode,
        contentLength: body.length,
        request: request,
        headers: response.headers,
        reasonPhrase: response.reasonPhrase,
      );
    }
    return response;
  }

  @override
  void close() => _inner.close();
}

// --- TOTP real (RFC 6238), igual que `scripts/mfa-integration-test.mjs` -----
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

/// Espera a que se cumpla [cumplida], con un tope explícito. Reemplaza a las
/// esperas fijas: lo que decide es la condición, no el reloj de la máquina.
Future<void> _esperarCondicion(
  bool Function() cumplida, {
  required String descripcion,
  Duration timeout = const Duration(seconds: 10),
  Duration intervalo = const Duration(milliseconds: 20),
}) async {
  final limite = DateTime.now().add(timeout);
  while (!cumplida()) {
    if (DateTime.now().isAfter(limite)) {
      fail(
        'se agotó el tiempo (${timeout.inSeconds} s) esperando a que '
        '$descripcion',
      );
    }
    await Future<void>.delayed(intervalo);
  }
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

  // Este test crea y borra datos: solo contra un stack local.
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

  final runId = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final email = 'd1-reg-$runId@tests.local';
  const password = 'password123';

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

  /// Borra **solo** la cuenta sintética de esta corrida y **comprueba** que la
  /// limpieza terminó bien: ignorar el `exitCode` dejaría datos sin que nadie
  /// se entere. No toca ninguna otra cuenta.
  void cleanupYVerificar() {
    final borrado = psql("delete from auth.users where email = '$email';");
    expect(
      borrado.exitCode,
      0,
      reason: 'la limpieza de la cuenta sintética falló: ${borrado.stderr}',
    );
    final quedan = psql(
      "select count(*) from auth.users where email = '$email';",
    );
    expect(quedan.exitCode, 0, reason: 'no se pudo verificar la limpieza');
    expect(
      quedan.stdout.toString().trim(),
      '0',
      reason: 'quedaron datos de la cuenta sintética de esta corrida',
    );
  }

  test(
    'D1 · destruir y recrear la pantalla con la verificación en vuelo NO borra '
    'el factor que el servidor acaba de aceptar',
    () async {
      http.Response probe;
      try {
        probe = await http
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
          'BLOQUEO: el stack local respondió ${probe.statusCode} en '
          '$baseUrl/auth/v1/health. La integración NO se ejecutó.',
        );
      }

      // Composición REAL, la misma que arma `bootstrap.dart`: el recorder es
      // el más interno y la política es una sola, compartida entre él y el
      // repositorio. Este test dice reproducir producción, así que tiene que
      // usar el cableado de producción; con el guard suelto sobre la red
      // estaría probando otra cosa.
      final net = _GatedClient(IOClient());
      final politica = SecondFactorCleanupPolicy();
      // ignore: invalid_use_of_visible_for_testing_member
      final recorder = SecondFactorAttemptRecorder.withInnerClient(
        politica,
        net,
      );
      late final GoTrueClient auth;
      final guard = SessionScopedHttpClient(
        recorder,
        currentAccessToken: () => auth.currentSession?.accessToken,
      );
      auth = GoTrueClient(
        url: '$baseUrl/auth/v1',
        headers: {'apikey': anonKey},
        httpClient: guard,
        autoRefreshToken: false,
      );
      final repository = SupabaseAuthRepository(auth, politica);

      ProviderContainer pantalla() {
        final container = ProviderContainer(
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
        );
        // `autoDispose`: sin oyente el provider se descarta entre lecturas.
        container.listen(authStatusProvider, (_, _) {}, fireImmediately: true);
        container.listen(
          secondFactorControllerProvider,
          (_, _) {},
          fireImmediately: true,
        );
        return container;
      }

      // `onAuthStateChange` de gotrue es un `ReplaySubject` sin límite: a cada
      // suscriptor nuevo le reproduce todo el historial. Hay que esperar a que
      // drene, o un evento viejo sin sesión reinicia el flujo.
      Future<void> esperarSesion(ProviderContainer c) async {
        var estables = 0;
        for (var i = 0; i < 400; i++) {
          if (c.read(authStatusProvider).user != null) {
            estables++;
            if (estables >= 15) return;
          } else {
            estables = 0;
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        fail('el estado de sesión nunca se estabilizó');
      }

      try {
        final alta = await http.post(
          Uri.parse('$baseUrl/auth/v1/signup'),
          headers: {'apikey': anonKey, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
            'data': {'role': 'candidate'},
          }),
        );
        expect(alta.statusCode, 200, reason: 'alta de la cuenta sintética');
        await auth.signInWithPassword(email: email, password: password);

        // --- Pantalla 1: alta de F y envío del código ---------------------
        final pantalla1 = pantalla();
        await esperarSesion(pantalla1);
        final ctrl1 = pantalla1.read(secondFactorControllerProvider.notifier);
        await ctrl1.start(friendlyName: 'd1-reg-$runId');
        final estado1 = pantalla1.read(secondFactorControllerProvider);
        expect(estado1, isA<SecondFactorEnrolling>());
        final enrolling = estado1 as SecondFactorEnrolling;
        final factorF = enrolling.enrollment.factorId;

        // El verify se retiene ANTES de salir: el servidor todavía no lo vio,
        // así que la lectura de factores del flujo siguiente ve F pendiente
        // de verdad.
        final compuertaVerify = _Gate(
          (r) => r.method == 'POST' && r.url.path.endsWith('/$factorF/verify'),
          beforeSend: true,
        );
        net.gates.add(compuertaVerify);
        unawaited(
          ctrl1.submitCode(_totpCode(enrolling.enrollment.secret, _totpStep())),
        );
        await compuertaVerify.captured;

        // --- La pantalla se destruye con el código en vuelo ----------------
        pantalla1.dispose();

        // --- Pantalla 2 ----------------------------------------------------
        // `start()` lee `/user` dos veces (lista de verificados y alta); hay
        // que retener la SEGUNDA, que es la que alimenta la limpieza.
        final compuertaUser = _Gate(
          (r) => r.method == 'GET' && r.url.path.endsWith('/user'),
          skip: 1,
        );
        net.gates.add(compuertaUser);

        final pantalla2 = pantalla();
        await esperarSesion(pantalla2);
        final segundoStart = pantalla2
            .read(secondFactorControllerProvider.notifier)
            .start(friendlyName: 'd1-reg-b-$runId');
        await compuertaUser.captured;

        // El servidor acepta el código: la sesión sube a aal2. Se espera la
        // CONDICIÓN (que el SDK haya instalado la sesión aal2), no un tiempo
        // fijo: una máquina lenta no puede cambiar el resultado.
        compuertaVerify.release();
        await _esperarCondicion(
          () =>
              auth.currentSession != null &&
              SupabaseAuthRepository.assuranceFromAccessToken(
                    auth.currentSession!.accessToken,
                  ).claim ==
                  'aal2',
          descripcion: 'el SDK instale la sesión aal2 devuelta por el servidor',
        );

        // Se entrega la lectura vieja y corre la limpieza.
        compuertaUser.release();
        await segundoStart;

        // ignore: avoid_print
        print('[solicitudes reales]\n  ${net.sent.join('\n  ')}');

        // --- Comportamiento correcto --------------------------------------
        expect(
          net.sent.where((l) => l.startsWith('DELETE') && l.contains(factorF)),
          isEmpty,
          reason: 'no sale el DELETE de F',
        );

        final estadoServidor = await auth.getUser();
        final factores = estadoServidor.user?.factors ?? const <Factor>[];
        final f = factores.where((x) => x.id == factorF).toList();
        expect(
          f.length,
          1,
          reason: 'una consulta NUEVA al servidor: F sigue existiendo',
        );
        expect(
          f.single.status,
          FactorStatus.verified,
          reason: 'y sigue verificado',
        );
        expect(
          factores.where((x) => x.status == FactorStatus.unverified),
          isEmpty,
          reason: 'no quedó un factor pendiente adicional por la carrera',
        );

        // Estado final afirmado en positivo: la propagación del `aal2` por el
        // stream deja el flujo verificado, que es lo que la pantalla convierte
        // en «ya podés revisar la cola» y navega. No se afirma solo «no es un
        // error»: eso dejaría pasar cualquier otro estado raro.
        expect(
          pantalla2.read(secondFactorControllerProvider),
          isA<SecondFactorVerified>(),
          reason:
              'la persona termina en la cola: ni «tu sesión cambió», ni un '
              'spinner, ni un QR nuevo',
        );
        pantalla2.dispose();
      } finally {
        cleanupYVerificar();
        guard.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
