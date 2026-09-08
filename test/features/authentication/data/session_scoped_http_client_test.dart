import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:talentflash_argentina/features/authentication/data/jwt_claims.dart';
import 'package:talentflash_argentina/features/authentication/data/session_scoped_http_client.dart';

import '../../../support/gotrue_fixtures.dart';

/// El guard HTTP que ata cada solicitud de segundo factor a la sesión que la
/// emitió. Se prueba solo, con un cliente falso: qué deja pasar, qué no envía
/// y qué descarta al recibir.
void main() {
  late List<http.Request> sent;
  late Completer<http.Response>? hold;
  late String? currentToken;

  String token(String sessionId, {int rev = 0}) =>
      GoTrueFixtures.accessTokenWithClaims(
        sessionId: sessionId,
        amr: [
          {'method': 'password', 'timestamp': 1757353800 + rev},
        ],
      );

  SessionScopedHttpClient buildGuard() {
    sent = <http.Request>[];
    hold = null;
    final inner = MockClient((request) async {
      sent.add(request);
      final pending = hold;
      if (pending != null) {
        return pending.future;
      }
      return http.Response(
        jsonEncode({'ok': true, 'path': request.url.path}),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });
    return SessionScopedHttpClient(
      inner,
      currentAccessToken: () => currentToken,
    );
  }

  Future<http.Response> call(
    http.Client client,
    String path, {
    String? bearer,
    String method = 'POST',
  }) {
    final url = Uri.parse('http://127.0.0.1:54321$path');
    final headers = <String, String>{
      'apikey': 'sb_publishable_de_prueba',
      if (bearer != null) 'Authorization': 'Bearer $bearer',
    };
    return switch (method) {
      'GET' => client.get(url, headers: headers),
      'DELETE' => client.delete(url, headers: headers),
      _ => client.post(url, headers: headers, body: '{}'),
    };
  }

  Map<String, dynamic> body(http.Response response) =>
      jsonDecode(response.body) as Map<String, dynamic>;

  setUp(() {
    currentToken = null;
  });

  group('identidad de sesión', () {
    test('es el claim session_id cuando el token lo trae', () {
      expect(sessionIdentityOf(token('s-1')), 's-1');
      expect(sessionIdentityOf(token('s-1', rev: 1)), 's-1');
    });

    test('sin claim o sin forma de JWT, es el token entero', () {
      expect(
        sessionIdentityOf(GoTrueFixtures.accessTokenWithClaims(aal: 'aal1')),
        GoTrueFixtures.accessTokenWithClaims(aal: 'aal1'),
      );
      expect(
        sessionIdentityOf(GoTrueFixtures.accessToken),
        GoTrueFixtures.accessToken,
      );
      expect(sessionIdentityOf(null), isNull);
      expect(sessionIdentityOf(''), isNull);
    });
  });

  group('qué rutas cubre', () {
    test('solo las rutas de segundo factor', () {
      Uri auth(String path) => Uri.parse('http://x/auth/v1$path');
      expect(SessionScopedHttpClient.isGuarded(auth('/factors')), isTrue);
      expect(
        SessionScopedHttpClient.isGuarded(auth('/factors/f-1/verify')),
        isTrue,
      );
      expect(SessionScopedHttpClient.isGuarded(auth('/factors/f-1')), isTrue);
      // `/user` no muta la sesión, y el SDK lo consulta con un token que
      // todavía no es el vigente al instalar una sesión (setSession,
      // enlaces con flujo implícito): guardarlo rompería esos flujos.
      expect(SessionScopedHttpClient.isGuarded(auth('/user')), isFalse);
      expect(
        SessionScopedHttpClient.isGuarded(
          Uri.parse('http://x/auth/v1/token?grant_type=password'),
        ),
        isFalse,
      );
      expect(SessionScopedHttpClient.isGuarded(auth('/logout')), isFalse);
      expect(
        SessionScopedHttpClient.isGuarded(Uri.parse('http://x/rest/v1/rpc/f')),
        isFalse,
      );
    });

    test('una ruta no cubierta pasa tal cual, aun con otro bearer', () async {
      final guard = buildGuard();
      currentToken = token('s-1');

      final response = await call(
        guard,
        '/auth/v1/token?grant_type=refresh_token',
        bearer: token('s-otra'),
      );

      expect(response.statusCode, 200);
      expect(sent, hasLength(1));
    });
  });

  group('antes de enviar', () {
    test(
      'con la sesión vigente, la solicitud sale y la respuesta llega',
      () async {
        final guard = buildGuard();
        currentToken = token('s-1');

        final response = await call(
          guard,
          '/auth/v1/factors/f-1/verify',
          bearer: token('s-1'),
        );

        expect(response.statusCode, 200);
        expect(body(response)['ok'], isTrue);
        expect(sent.single.url.path, endsWith('/factors/f-1/verify'));
      },
    );

    test('con el token de otra sesión, no sale nada', () async {
      final guard = buildGuard();
      currentToken = token('s-2');

      final response = await call(
        guard,
        '/auth/v1/factors',
        bearer: token('s-1'),
      );

      expect(sent, isEmpty, reason: 'el servidor nunca ve la solicitud');
      expect(response.statusCode, 401);
      expect(
        body(response)['error_code'],
        SessionScopedHttpClient.staleSessionCode,
      );
    });

    test('sin sesión vigente, tampoco', () async {
      final guard = buildGuard();
      currentToken = null;

      final response = await call(
        guard,
        '/auth/v1/factors/f-1',
        bearer: token('s-1'),
        method: 'DELETE',
      );

      expect(sent, isEmpty);
      expect(response.statusCode, 401);
    });

    test('/user con un token que no es el vigente pasa (lo usa el SDK al '
        'instalar una sesión)', () async {
      final guard = buildGuard();
      currentToken = null;

      final response = await call(
        guard,
        '/auth/v1/user',
        bearer: token('s-nueva'),
        method: 'GET',
      );

      expect(sent, hasLength(1));
      expect(response.statusCode, 200);
    });

    test('sin bearer (clave anónima), no hay sesión que atar', () async {
      final guard = buildGuard();
      currentToken = token('s-1');

      final response = await call(guard, '/auth/v1/factors');

      expect(sent, isEmpty);
      expect(response.statusCode, 401);
    });
  });

  group('al recibir', () {
    test(
      'decide con el cuerpo completo: un cambio de sesión durante la descarga '
      'del cuerpo también descarta',
      () async {
        // Con un cliente real `send` resuelve al llegar las cabeceras; el
        // cuerpo llega después y recién entonces el SDK guardaría la sesión.
        final bodyController = StreamController<List<int>>();
        final requests = <http.BaseRequest>[];
        final inner = MockClient.streaming((request, bodyStream) async {
          requests.add(request);
          return http.StreamedResponse(
            bodyController.stream,
            200,
            headers: const {'content-type': 'application/json'},
          );
        });
        currentToken = token('s-1');
        final guard = SessionScopedHttpClient(
          inner,
          currentAccessToken: () => currentToken,
        );

        final pending = call(
          guard,
          '/auth/v1/factors/f-1/verify',
          bearer: token('s-1'),
        );
        await Future<void>.delayed(Duration.zero);
        expect(requests, hasLength(1), reason: 'cabeceras recibidas');

        // Cierre de sesión con el cuerpo todavía en tránsito.
        currentToken = null;
        bodyController.add(utf8.encode('{"access_token":"no-debe-'));
        bodyController.add(utf8.encode('aplicarse"}'));
        await bodyController.close();

        final response = await pending;
        expect(response.statusCode, 401);
        expect(
          body(response)['error_code'],
          SessionScopedHttpClient.staleSessionCode,
        );
        expect(response.body, isNot(contains('no-debe-aplicarse')));
      },
    );

    test(
      'si la sesión cambió mientras viajaba, la respuesta se descarta',
      () async {
        final guard = buildGuard();
        currentToken = token('s-1');
        hold = Completer<http.Response>();
        final pending = call(
          guard,
          '/auth/v1/factors/f-1/verify',
          bearer: token('s-1'),
        );
        await Future<void>.delayed(Duration.zero);
        expect(sent, hasLength(1), reason: 'salió con la sesión vigente');

        // Cierre de sesión y otra cuenta antes de que la red responda.
        currentToken = token('s-2');
        hold!.complete(
          http.Response(
            jsonEncode({'access_token': 'sesion-que-no-debe-aplicarse'}),
            200,
            headers: const {'content-type': 'application/json'},
          ),
        );

        final response = await pending;
        expect(response.statusCode, 401);
        expect(
          body(response)['error_code'],
          SessionScopedHttpClient.staleSessionCode,
        );
        expect(response.body, isNot(contains('sesion-que-no-debe-aplicarse')));
      },
    );

    test('si la sesión se cerró mientras viajaba, también', () async {
      final guard = buildGuard();
      currentToken = token('s-1');
      hold = Completer<http.Response>();
      final pending = call(
        guard,
        '/auth/v1/factors/f-1/verify',
        bearer: token('s-1'),
      );
      await Future<void>.delayed(Duration.zero);

      currentToken = null;
      hold!.complete(http.Response('{"access_token":"x"}', 200));

      expect((await pending).statusCode, 401);
    });

    test('un refresco (misma sesión, token nuevo) no la descarta', () async {
      final guard = buildGuard();
      currentToken = token('s-1');
      hold = Completer<http.Response>();
      final pending = call(
        guard,
        '/auth/v1/factors/f-1/verify',
        bearer: token('s-1'),
      );
      await Future<void>.delayed(Duration.zero);

      currentToken = token('s-1', rev: 1);
      hold!.complete(
        http.Response(
          '{"ok":true}',
          200,
          headers: const {'content-type': 'application/json'},
        ),
      );

      final response = await pending;
      expect(response.statusCode, 200);
      expect(body(response)['ok'], isTrue);
    });

    test(
      'con tokens sin forma de JWT, la identidad es el token entero',
      () async {
        final guard = buildGuard();
        currentToken = 'token-plano-1';
        hold = Completer<http.Response>();
        final pending = call(
          guard,
          '/auth/v1/factors',
          bearer: 'token-plano-1',
        );
        await Future<void>.delayed(Duration.zero);
        expect(sent, hasLength(1));

        currentToken = 'token-plano-2';
        hold!.complete(http.Response('{"ok":true}', 200));

        expect((await pending).statusCode, 401);
      },
    );
  });
}
