import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentflash_argentina/features/authentication/data/jwt_claims.dart';
import 'package:talentflash_argentina/features/authentication/data/second_factor_attempt_recorder.dart';
import 'package:talentflash_argentina/features/authentication/data/second_factor_cleanup_policy.dart';
import 'package:talentflash_argentina/features/authentication/data/session_scoped_http_client.dart';
import 'package:talentflash_argentina/features/authentication/data/supabase_auth_repository.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_failure.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/session_assurance.dart';

import '../../../support/gotrue_fixtures.dart';

/// Con `--dart-define=MFA_SESSION_GUARD=false` las reproducciones corren con
/// el cableado ANTERIOR (GoTrue sobre el cliente HTTP a secas), que es como
/// se demostró el defecto. Por defecto corren con el cableado real de
/// `bootstrap.dart`: [SessionScopedHttpClient] entre Supabase y la red.
const _guardedByDefault = bool.fromEnvironment(
  'MFA_SESSION_GUARD',
  defaultValue: true,
);

/// Operaciones de segundo factor **en vuelo** frente a un cambio de sesión,
/// con el `GoTrueClient` instalado y respuestas HTTP retenidas por un
/// `Completer`: la respuesta existe (el servidor la generó antes del cierre
/// de sesión) y la red la entrega después.
///
/// Lo que se comprueba no es el estado visual sino los efectos: la sesión del
/// SDK, los eventos que emite y las solicitudes que salen con qué credencial.
void main() {
  group('sesión cerrada o reemplazada durante una operación MFA', () {
    test('una verificación exitosa tardía tras cerrar sesión no restaura la '
        'sesión anterior', () async {
      final h = _Harness.build();
      await h.signIn(_Account.a);
      final verifying = h.repository.verifySecondFactor(
        factorId: 'factor-a',
        challengeId: 'challenge-a',
        code: '123456',
      );
      await h.holdReached('/verify');

      await h.repository.signOut();
      expect(h.client.currentSession, isNull);
      final eventsAtLogout = h.events.length;

      // La red entrega la sesión A/aal2 que el servidor emitió antes del
      // cierre de sesión.
      h.release('/verify', _Account.a.session(aal: 'aal2'));

      await expectLater(verifying, throwsA(_stale()));
      await h.settle();
      expect(h.client.currentSession, isNull, reason: 'A no vuelve');
      expect(h.repository.currentStatus, isA<AuthStatusSignedOut>());
      expect(
        h.events.sublist(eventsAtLogout),
        isNot(contains(AuthChangeEvent.mfaChallengeVerified)),
        reason: 'no se publica un evento de un flujo que ya no existe',
      );
    });

    test(
      'una verificación exitosa tardía de A no reemplaza la sesión de B',
      () async {
        final h = _Harness.build();
        await h.signIn(_Account.a);
        final verifying = h.repository.verifySecondFactor(
          factorId: 'factor-a',
          challengeId: 'challenge-a',
          code: '123456',
        );
        await h.holdReached('/verify');

        await h.repository.signOut();
        await h.signIn(_Account.b);
        final eventsAtB = h.events.length;

        h.release('/verify', _Account.a.session(aal: 'aal2'));

        await expectLater(verifying, throwsA(_stale()));
        await h.settle();
        final session = h.client.currentSession;
        expect(session?.user.id, _Account.b.id, reason: 'B sigue siendo B');
        expect(h.repository.currentStatus.user?.id, _Account.b.id);
        expect(
          h.repository.currentStatus.assurance,
          SessionAssurance.aal1,
          reason: 'B no hereda el aal2 de A',
        );
        expect(
          h.events.sublist(eventsAtB),
          isNot(contains(AuthChangeEvent.mfaChallengeVerified)),
        );
      },
    );

    test('la misma cuenta que cierra sesión y vuelve a entrar es OTRA sesión: '
        'la verificación vieja tampoco se aplica', () async {
      final h = _Harness.build();
      await h.signIn(_Account.a);
      final firstSession = h.client.currentSession!.accessToken;
      final verifying = h.repository.verifySecondFactor(
        factorId: 'factor-a',
        challengeId: 'challenge-a',
        code: '123456',
      );
      await h.holdReached('/verify');

      await h.repository.signOut();
      await h.signIn(_Account.a);
      final secondSession = h.client.currentSession!.accessToken;
      expect(secondSession, isNot(firstSession));
      final eventsAtRelogin = h.events.length;

      h.release('/verify', _Account.a.session(aal: 'aal2', login: 1));

      await expectLater(verifying, throwsA(_stale()));
      await h.settle();
      expect(h.client.currentSession?.accessToken, secondSession);
      expect(h.repository.currentStatus.assurance, SessionAssurance.aal1);
      expect(
        h.events.sublist(eventsAtRelogin),
        isNot(contains(AuthChangeEvent.mfaChallengeVerified)),
      );
    });

    test('un alta de A no continúa con la sesión de B', () async {
      final h = _Harness.build();
      await h.signIn(_Account.a, pendingFactor: 'pendiente-a');
      final enrolling = h.repository.enrollTotp(friendlyName: 'nuevo');
      // La espera del alta ahora es la LECTURA de factores: desde que la app
      // dejó de mandar bajas automáticas, el `DELETE` ya no existe y no hay
      // dónde retener. El punto que importa es el mismo: después de una
      // espera, el alta no puede seguir con otra sesión.
      await h.holdReached('/user');

      await h.repository.signOut();
      await h.signIn(_Account.b);

      h.release(
        '/user',
        http.Response(
          jsonEncode(
            GoTrueFixtures.user(
              appRole: 'admin',
              id: _Account.a.id,
              email: _Account.a.email,
              factors: [
                GoTrueFixtures.factor(id: 'pendiente-a', status: 'unverified'),
              ],
            ),
          ),
          200,
          headers: const {'content-type': 'application/json'},
        ),
      );

      await expectLater(enrolling, throwsA(_stale()));
      final enrollRequests = h.requests.where(
        (r) => r.method == 'POST' && r.url.path.endsWith('/factors'),
      );
      expect(
        enrollRequests,
        isEmpty,
        reason: 'el POST de alta no sale con el token de B',
      );
      expect(
        h.requests
            .where((r) => r.url.path.contains('/factors'))
            .map(h.subjectOf)
            .toSet(),
        isNot(contains(_Account.b.id)),
        reason: 'ninguna solicitud del flujo de A viaja con credenciales de B',
      );
      expect(
        h.requests
            .where((r) => r.url.path.endsWith('/user'))
            .map(h.subjectOf)
            .toSet(),
        {_Account.a.id},
        reason: 'la única solicitud del flujo salió con el token de A',
      );
    });
  });

  group('lo que sigue funcionando', () {
    test(
      'una renovación legítima del token durante la verificación no la rompe',
      () async {
        final h = _Harness.build();
        await h.signIn(_Account.a);
        final firstToken = h.client.currentSession?.accessToken;
        final verifying = h.repository.verifySecondFactor(
          factorId: 'factor-a',
          challengeId: 'challenge-a',
          code: '123456',
        );
        await h.holdReached('/verify');

        // Misma sesión, token nuevo: exactamente lo que hace el refresco.
        await h.client.refreshSession();
        final refreshed = h.client.currentSession?.accessToken;
        expect(refreshed, isNot(firstToken), reason: 'token nuevo');
        expect(
          sessionIdentityOf(refreshed),
          sessionIdentityOf(firstToken),
          reason: 'misma sesión',
        );

        h.release('/verify', _Account.a.session(aal: 'aal2', rev: 2));

        await verifying;
        await h.settle();
        expect(h.repository.currentStatus.user?.id, _Account.a.id);
        expect(h.repository.currentStatus.assurance, SessionAssurance.aal2);
        expect(h.events, contains(AuthChangeEvent.mfaChallengeVerified));
      },
    );

    test('alta, desafío y verificación sin cambio de sesión', () async {
      final h = _Harness.build();
      await h.signIn(_Account.a, pendingFactor: 'pendiente-a');

      final enrollment = await h.repository.enrollTotp(friendlyName: 'nuevo');
      expect(enrollment.factorId, 'factor-a');
      expect(
        h.requests.where((r) => r.method == 'DELETE'),
        isEmpty,
        reason:
            'la app ya no manda bajas automáticas: el pendiente viejo queda, '
            'y el alta sigue igual',
      );
      final challenge = await h.repository.challengeSecondFactor('factor-a');
      expect(challenge.id, 'challenge-a');
      await h.repository.verifySecondFactor(
        factorId: 'factor-a',
        challengeId: challenge.id,
        code: '123456',
      );
      expect(h.repository.currentStatus.assurance, SessionAssurance.aal2);
      expect(h.requests.map(h.subjectOf).where((sub) => sub != null).toSet(), {
        _Account.a.id,
      }, reason: 'todo viajó con credenciales de A');
    });

    test('listar factores consulta al servidor sin tocar la sesión', () async {
      final h = _Harness.build();
      await h.signIn(_Account.a, pendingFactor: 'pendiente-a');
      final before = h.client.currentSession?.accessToken;

      final factors = await h.repository.listVerifiedSecondFactors();

      expect(factors.map((f) => f.id), ['factor-a']);
      expect(h.client.currentSession?.accessToken, before);
      expect(
        h.requests.where(
          (r) => r.url.queryParameters['grant_type'] == 'refresh_token',
        ),
        isEmpty,
        reason: 'sin refresco: no rota el refresh token de otras pestañas',
      );
      expect(
        h.requests.last.method == 'GET' &&
            h.requests.last.url.path.endsWith('/user'),
        isTrue,
      );
    });
  });

  group('el repositorio por su cuenta', () {
    test('sin el guard HTTP, igual corta un alta cuya sesión cambió durante la '
        'limpieza de pendientes', () async {
      final h = _Harness.build(guarded: false);
      await h.signIn(_Account.a, pendingFactor: 'pendiente-a');
      final enrolling = h.repository.enrollTotp(friendlyName: 'nuevo');
      await h.holdReached('/user');

      await h.repository.signOut();
      await h.signIn(_Account.b);
      h.release(
        '/user',
        http.Response(
          jsonEncode(
            GoTrueFixtures.user(
              appRole: 'admin',
              id: _Account.a.id,
              email: _Account.a.email,
              factors: [
                GoTrueFixtures.factor(id: 'pendiente-a', status: 'unverified'),
              ],
            ),
          ),
          200,
          headers: const {'content-type': 'application/json'},
        ),
      );

      await expectLater(enrolling, throwsA(_stale()));
      expect(
        h.requests.where(
          (r) => r.method == 'POST' && r.url.path.endsWith('/factors'),
        ),
        isEmpty,
      );
    });

    test(
      'el alta lee los factores del SERVIDOR, no la copia de la sesión',
      () async {
        final h = _Harness.build();
        await h.signIn(
          _Account.a,
          pendingFactor: 'pendiente-a',
          pendingOnlyOnServer: true,
        );
        expect(
          h.client.currentUser?.factors?.where((f) => f.id == 'pendiente-a'),
          isEmpty,
          reason: 'la sesión guardada no lo conoce',
        );

        await h.repository.enrollTotp(friendlyName: 'nuevo');

        // Antes esto se comprobaba por el DELETE que salía. Ya no sale
        // ninguno, así que lo que se fija es la lectura: el alta consulta
        // `GET /user` y no se conforma con la copia del usuario que viaja en
        // la sesión, que es la foto del último login o refresco.
        expect(
          h.requests.where(
            (r) => r.method == 'GET' && r.url.path.endsWith('/user'),
          ),
          isNotEmpty,
          reason: 'el estado de los factores se le pregunta al servidor',
        );
        expect(
          h.requests.where((r) => r.method == 'DELETE'),
          isEmpty,
          reason: 'y no se manda ninguna baja automática',
        );
      },
    );

    test('con el token vencido refresca antes de leer los factores', () async {
      final h = _Harness.build();
      await h.signIn(_Account.a, expired: true);
      expect(h.client.currentSession?.isExpired, isTrue);

      final factors = await h.repository.listVerifiedSecondFactors();
      await h.settle();

      expect(factors.map((f) => f.id), ['factor-a']);
      expect(
        h.requests.where(
          (r) => r.url.queryParameters['grant_type'] == 'refresh_token',
        ),
        hasLength(1),
      );
      expect(h.client.currentSession?.isExpired, isFalse);
      expect(h.events, contains(AuthChangeEvent.tokenRefreshed));
    });
  });

  group('por qué existe el guard', () {
    test('sin el guard, el SDK instalado aplica la respuesta tardía y restaura '
        'la sesión cerrada', () async {
      // Documenta la conducta del SDK que motiva `SessionScopedHttpClient`.
      // Si un SDK futuro deja de hacerlo, este test avisa que el guard puede
      // revisarse.
      final h = _Harness.build(guarded: false);
      await h.signIn(_Account.a);
      final verifying = h.repository.verifySecondFactor(
        factorId: 'factor-a',
        challengeId: 'challenge-a',
        code: '123456',
      );
      await h.holdReached('/verify');
      await h.repository.signOut();
      final eventsAtLogout = h.events.length;

      h.release('/verify', _Account.a.session(aal: 'aal2'));
      await verifying;
      await h.settle();

      expect(h.client.currentSession?.user.id, _Account.a.id);
      expect(h.repository.currentStatus.assurance, SessionAssurance.aal2);
      expect(
        h.events.sublist(eventsAtLogout),
        contains(AuthChangeEvent.mfaChallengeVerified),
      );
    });
  });
}

Matcher _stale() => isA<AuthFailure>().having(
  (f) => f.code,
  'code',
  AuthFailureCode.staleSession,
);

/// Dos cuentas sintéticas con tokens JWT armados en tiempo de ejecución.
/// [login] distingue sesiones (una por inicio de sesión) y [rev] tokens de la
/// misma sesión (refresco, verificación).
enum _Account {
  a('11111111-1111-4111-8111-111111111111', 'a@dev.talentflash.test'),
  b('22222222-2222-4222-8222-222222222222', 'b@dev.talentflash.test');

  const _Account(this.id, this.email);

  final String id;
  final String email;

  String sessionId(int login) => 'session-$name-$login';

  String token({
    String aal = 'aal1',
    int login = 0,
    int rev = 0,
    bool expired = false,
  }) => GoTrueFixtures.accessTokenWithClaims(
    aal: aal,
    sub: id,
    sessionId: sessionId(login),
    exp: expired
        ? DateTime.now()
                  .subtract(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000
        : null,
    // Un claim propio para que dos tokens de la misma sesión sean
    // strings distintos, como pasa al refrescar.
    amr: [
      {'method': 'password', 'timestamp': 1757353800 + rev},
    ],
  );

  http.Response session({
    String aal = 'aal1',
    int login = 0,
    int rev = 0,
    String? pendingFactor,
    bool expired = false,
  }) {
    return http.Response(
      GoTrueFixtures.sessionJson(
        appRole: 'admin',
        id: id,
        email: email,
        accessToken: token(aal: aal, login: login, rev: rev, expired: expired),
        refreshToken: 'refresh-$name-$login-$rev',
        factors: [
          GoTrueFixtures.factor(id: 'factor-$name'),
          if (pendingFactor != null)
            GoTrueFixtures.factor(id: pendingFactor, status: 'unverified'),
        ],
      ),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _Harness {
  _Harness._();

  late final GoTrueClient client;
  late final SupabaseAuthRepository repository;
  final requests = <http.Request>[];
  final events = <AuthChangeEvent>[];

  /// Respuestas retenidas por sufijo de path; la red "las entrega" cuando el
  /// test las libera.
  final _holds = <String, Completer<http.Response>>{};
  final _reached = <String, Completer<void>>{};
  final _logins = <_Account, int>{};

  /// Política de limpieza del repositorio. Los pendientes que sembran los
  /// tests son altas interrumpidas de ESTA misma app, así que se registran
  /// como propias: es lo que haría el alta real.
  final cleanup = SecondFactorCleanupPolicy();

  String? _pendingFactor;
  bool _pendingInSession = true;
  bool _expired = false;

  static _Harness build({bool guarded = _guardedByDefault}) {
    final h = _Harness._();
    // El recorder va SIEMPRE, con guard o sin él: es el punto más interno y
    // es lo que anota cada pedido de verificación que sale.
    final inner = SecondFactorAttemptRecorder.withInnerClient(
      h.cleanup,
      MockClient(h._route),
    );
    final httpClient = guarded
        ? SessionScopedHttpClient(
            inner,
            currentAccessToken: () => h.client.currentSession?.accessToken,
          )
        : inner;
    h.client = GoTrueClient(
      url: 'http://127.0.0.1:54321/auth/v1',
      autoRefreshToken: false,
      flowType: AuthFlowType.implicit,
      httpClient: httpClient,
    );
    h.repository = SupabaseAuthRepository(h.client, h.cleanup);
    final subscription = h.client.onAuthStateChange.listen(
      (state) => h.events.add(state.event),
      onError: (Object _) {},
    );
    addTearDown(() async {
      await subscription.cancel();
      h.client.dispose();
    });
    return h;
  }

  /// [pendingFactor] existe en el servidor (`/user`); con
  /// [pendingOnlyOnServer] la copia del usuario que viaja en la sesión del
  /// login no lo trae, como pasa con un alta interrumpida en otra pestaña.
  /// Con [expired] el access token del login ya venció.
  Future<void> signIn(
    _Account account, {
    String? pendingFactor,
    bool pendingOnlyOnServer = false,
    bool expired = false,
  }) async {
    _pendingFactor = pendingFactor;
    if (pendingFactor != null) cleanup.recordEnrolled(pendingFactor);
    _pendingInSession = !pendingOnlyOnServer;
    _expired = expired;
    await repository.signInWithEmail(
      email: account.email,
      password: 'password123',
    );
  }

  /// La próxima solicitud cuyo path termine en [suffix] queda retenida.
  Future<void> holdReached(String suffix) {
    _holds[suffix] = Completer<http.Response>();
    return (_reached[suffix] = Completer<void>()).future;
  }

  void release(String suffix, http.Response response) {
    _holds.remove(suffix)!.complete(response);
  }

  String? bearerOf(http.Request request) {
    final value =
        request.headers['Authorization'] ?? request.headers['authorization'];
    if (value == null || !value.startsWith('Bearer ')) {
      return null;
    }
    return value.substring('Bearer '.length);
  }

  /// `sub` del bearer de la solicitud, decodificado del JWT de utilería.
  String? subjectOf(http.Request request) {
    final bearer = bearerOf(request);
    final parts = bearer?.split('.');
    if (parts == null || parts.length != 3) {
      return null;
    }
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    return (jsonDecode(payload) as Map<String, dynamic>)['sub'] as String?;
  }

  bool isTokenOf(http.Request request, _Account account) =>
      subjectOf(request) == account.id;

  /// Deja que el stream de eventos del SDK entregue lo que ya publicó.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<http.Response> _route(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    for (final suffix in _holds.keys) {
      if (path.endsWith(suffix)) {
        _reached[suffix]?.complete();
        return _holds[suffix]!.future;
      }
    }
    return _respond(request);
  }

  http.Response _respond(http.Request request) {
    final path = request.url.path;
    final grant = request.url.queryParameters['grant_type'];
    if (path.endsWith('/token') && grant == 'password') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final account = _Account.values.firstWhere(
        (a) => a.email == body['email'],
      );
      final login = _logins[account] ?? 0;
      _logins[account] = login + 1;
      return account.session(
        login: login,
        pendingFactor: _pendingInSession ? _pendingFactor : null,
        expired: _expired,
      );
    }
    if (path.endsWith('/token') && grant == 'refresh_token') {
      // Misma sesión de A, token nuevo.
      return _Account.a.session(rev: 1, pendingFactor: _pendingFactor);
    }
    if (path.endsWith('/logout')) {
      return http.Response('', 204);
    }
    if (path.endsWith('/user')) {
      return http.Response(
        jsonEncode(
          GoTrueFixtures.user(
            appRole: 'admin',
            id: _Account.a.id,
            email: _Account.a.email,
            factors: [
              GoTrueFixtures.factor(id: 'factor-a'),
              if (_pendingFactor != null)
                GoTrueFixtures.factor(
                  id: _pendingFactor!,
                  status: 'unverified',
                ),
            ],
          ),
        ),
        200,
        headers: const {'content-type': 'application/json'},
      );
    }
    if (request.method == 'DELETE' && path.contains('/factors/')) {
      return http.Response(
        jsonEncode({'id': request.url.pathSegments.last}),
        200,
        headers: const {'content-type': 'application/json'},
      );
    }
    if (request.method == 'POST' && path.endsWith('/factors')) {
      return http.Response(
        GoTrueFixtures.totpEnrollJson(id: 'factor-a'),
        200,
        headers: const {'content-type': 'application/json'},
      );
    }
    if (path.endsWith('/challenge')) {
      return http.Response(
        GoTrueFixtures.challengeJson(id: 'challenge-a'),
        200,
        headers: const {'content-type': 'application/json'},
      );
    }
    if (path.endsWith('/verify')) {
      return _Account.a.session(aal: 'aal2', rev: 2);
    }
    return http.Response(
      GoTrueFixtures.errorJson(
        code: 404,
        errorCode: 'not_found',
        message: 'ruta no simulada: $path',
      ),
      404,
      headers: const {'content-type': 'application/json'},
    );
  }
}
