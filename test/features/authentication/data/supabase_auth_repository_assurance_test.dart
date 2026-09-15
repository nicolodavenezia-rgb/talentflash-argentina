import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentflash_argentina/features/authentication/data/jwt_claims.dart';
import 'package:talentflash_argentina/features/authentication/data/session_scoped_http_client.dart';
import 'package:talentflash_argentina/features/authentication/data/supabase_auth_repository.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_failure.dart';
import 'package:talentflash_argentina/features/authentication/domain/session_assurance.dart';

import '../../../support/gotrue_fixtures.dart';

/// El **nivel** de la sesión como condición para mandar una baja de factor.
///
/// La identidad de sesión (`session_id`) no puede cubrir este caso: una
/// verificación legítima sube de `aal1` a `aal2` **sin cambiar de sesión**, así
/// que `_ensureSameSession` y `SessionScopedHttpClient` la dejan pasar — y con
/// razón, porque no es un cambio de sesión. Lo que cambia es si la operación
/// destructiva todavía tiene sentido.
///
/// Todo corre con el `GoTrueClient` instalado y el cableado real de
/// `bootstrap.dart` (el guard HTTP entre Supabase y la red). Las respuestas se
/// retienen con `Completer`, nunca con esperas de reloj.
void main() {
  group('una baja de factor solo sale con la sesión en aal1', () {
    test(
      'el alta NO borra el factor cuya verificación el servidor acaba de '
      'aceptar: si el nivel subió a aal2, la limpieza no manda el DELETE',
      () async {
        final h = _Harness.build(
          pendingFactors: const ['factor-en-verificacion'],
        );
        await h.signIn();

        // El alta arranca y queda esperando la lectura de factores. Esa
        // respuesta la generó el servidor cuando el factor todavía estaba
        // pendiente.
        final alta = h.repository.enrollTotp(friendlyName: 'nuevo');
        await h.holdReached('/user');

        // Mientras tanto el servidor acepta el código: el SDK guarda la sesión
        // aal2. Misma sesión (mismo `session_id`), nivel nuevo.
        await h.repository.verifySecondFactor(
          factorId: 'factor-en-verificacion',
          challengeId: 'challenge-1',
          code: '123456',
        );
        expect(
          h.repository.currentStatus.assurance,
          SessionAssurance.aal2,
          reason: 'la verificación real subió el nivel de esta misma sesión',
        );

        // Recién ahora se entrega la lectura vieja, que sigue diciendo
        // «pendiente».
        h.release('/user');

        await expectLater(
          alta,
          throwsA(
            isA<AuthFailure>().having(
              (f) => f.code,
              'code',
              AuthFailureCode.mfaAlreadyVerified,
            ),
          ),
          reason:
              'se corta con un fallo propio, no con staleSession: '
              'la sesión es la misma',
        );
        expect(
          h.deletedFactorIds,
          isEmpty,
          reason: 'el factor recién verificado NO se borra',
        );
        expect(
          h.enrollCount,
          0,
          reason: 'tampoco queda un factor pendiente de más',
        );
      },
    );

    test('si el nivel sube mientras se espera un borrado anterior, el borrado '
        'siguiente ya no sale', () async {
      final h = _Harness.build(
        pendingFactors: const ['pendiente-1', 'pendiente-2'],
      );
      await h.signIn();

      final alta = h.repository.enrollTotp(friendlyName: 'nuevo');
      await h.holdReached('/factors/pendiente-1');

      await h.repository.verifySecondFactor(
        factorId: 'otro-factor',
        challengeId: 'challenge-1',
        code: '123456',
      );
      h.release('/factors/pendiente-1');

      await expectLater(alta, throwsA(isA<AuthFailure>()));
      expect(
        h.deletedFactorIds,
        ['pendiente-1'],
        reason:
            'el primero salió con aal1; el segundo ya no, porque entre '
            'medio la sesión subió de nivel',
      );
    });

    test('con un nivel ilegible no se manda ningún borrado, y el nivel '
        'desconocido nunca se toma por aal1', () async {
      final h = _Harness.build(
        pendingFactors: const ['pendiente-1'],
        aal: null, // token sin claim `aal`: SessionAssurance.unknown
      );
      await h.signIn();
      expect(h.repository.currentStatus.assurance, SessionAssurance.unknown);

      await h.repository.enrollTotp(friendlyName: 'nuevo');

      expect(
        h.deletedFactorIds,
        isEmpty,
        reason: 'unknown no habilita una operación destructiva',
      );
      expect(
        h.enrollCount,
        1,
        reason: 'pero tampoco es una verificación exitosa: el alta sigue',
      );
    });

    test('con aal1 estable la limpieza de pendientes sigue funcionando igual '
        'que antes', () async {
      final h = _Harness.build(
        pendingFactors: const ['pendiente-1', 'pendiente-2'],
      );
      await h.signIn();

      final enrollment = await h.repository.enrollTotp(friendlyName: 'nuevo');

      expect(h.deletedFactorIds, ['pendiente-1', 'pendiente-2']);
      expect(enrollment.factorId, 'factor-nuevo');
    });
  });

  group('descartar un factor pendiente', () {
    test('con aal1 manda el DELETE', () async {
      final h = _Harness.build();
      await h.signIn();

      await h.repository.discardPendingSecondFactor('pendiente-1');

      expect(h.deletedFactorIds, ['pendiente-1']);
    });

    test(
      'después de una verificación de desenlace desconocido que el servidor '
      'sí aceptó, un refresco deja la sesión en aal2 y el descarte ya no sale',
      () async {
        final h = _Harness.build();
        await h.signIn();
        // El servidor aceptó el código, pero la app nunca recibió la
        // respuesta; después, un refresco legítimo recalcula el nivel a partir
        // de los factores vigentes y devuelve aal2.
        await h.repository.verifySecondFactor(
          factorId: 'factor-en-verificacion',
          challengeId: 'challenge-1',
          code: '123456',
        );
        expect(h.repository.currentStatus.assurance, SessionAssurance.aal2);

        await h.repository.discardPendingSecondFactor('factor-en-verificacion');

        expect(
          h.deletedFactorIds,
          isEmpty,
          reason:
              'con aal2 el servidor aceptaría la baja de un factor '
              'verificado: el cliente no se la pide',
        );
      },
    );

    test('con un nivel ilegible tampoco sale', () async {
      final h = _Harness.build(aal: null);
      await h.signIn();

      await h.repository.discardPendingSecondFactor('pendiente-1');

      expect(h.deletedFactorIds, isEmpty);
    });

    test('RESPUESTA PERDIDA: el servidor aceptó el código pero el transporte '
        'falló; tras un refresco legítimo el descarte ya no sale', () async {
      final h = _Harness.build()..loseVerifyResponse = true;
      await h.signIn();
      final eventosAlEmpezar = h.events.length;

      // 1. El servidor acepta el código; la respuesta se pierde.
      await expectLater(
        h.repository.verifySecondFactor(
          factorId: 'factor-en-verificacion',
          challengeId: 'challenge-1',
          code: '123456',
        ),
        throwsA(isA<AuthFailure>()),
        reason: 'el cliente ve un error de transporte',
      );

      // 2. El cliente sigue creyendo que está en aal1 y NO recibió el
      //    evento de verificación: no sabe que el factor quedó verificado.
      expect(
        h.repository.currentStatus.assurance,
        SessionAssurance.aal1,
        reason: 'la respuesta nunca llegó: el nivel del cliente no cambió',
      );
      expect(
        h.events.sublist(eventosAlEmpezar),
        isNot(contains(AuthChangeEvent.mfaChallengeVerified)),
        reason: 'tampoco se emitió el evento de verificación',
      );

      // 3. Un refresco legítimo por el SDK: el servidor recalcula el nivel a
      //    partir de los factores vigentes y devuelve aal2, conservando la
      //    identidad de sesión.
      final antes = sessionIdentityOf(h.client.currentSession!.accessToken);
      await h.client.refreshSession();
      expect(
        sessionIdentityOf(h.client.currentSession!.accessToken),
        antes,
        reason: 'el refresco conserva el session_id: misma sesión',
      );
      expect(
        h.repository.currentStatus.assurance,
        SessionAssurance.aal2,
        reason: 'y ahora sí el cliente ve el nivel que el servidor ya tenía',
      );

      // 4. Recién acá se intenta descartar el «pendiente», que en realidad
      //    el servidor ya tiene como verificado.
      await h.repository.discardPendingSecondFactor('factor-en-verificacion');

      expect(
        h.deletedFactorIds,
        isEmpty,
        reason:
            'con aal2 el servidor aceptaría la baja y destruiría el '
            'factor: el cliente no se la pide',
      );
    });
  });
}

/// `GoTrueClient` real detrás del guard de `bootstrap.dart`, con respuestas
/// retenibles por sufijo de ruta.
class _Harness {
  _Harness._({required this.pendingFactors, required this.aal});

  final List<String> pendingFactors;

  /// Claim `aal` de la sesión del login; `null` emite un token sin el claim.
  final String? aal;

  static const _sessionId = 'sesion-unica';

  late final GoTrueClient client;
  late final SupabaseAuthRepository repository;

  final requests = <http.Request>[];
  final events = <AuthChangeEvent>[];
  final _holds = <String, Completer<void>>{};
  final _reached = <String, Completer<void>>{};

  /// Con `true`, el servidor **procesa** la verificación pero el transporte
  /// pierde la respuesta: el SDK recibe un error de red y nunca ve el `aal2`.
  bool loseVerifyResponse = false;

  /// Nivel que el SERVIDOR le asigna a la sesión. Empieza igual que el del
  /// login y sube cuando el servidor acepta un código, aunque el cliente no se
  /// entere: es lo que devolverá un refresco posterior.
  late String? _serverAal = aal;

  List<String> get deletedFactorIds => requests
      .where((r) => r.method == 'DELETE')
      .map((r) => r.url.pathSegments.last)
      .toList();

  int get enrollCount => requests
      .where((r) => r.method == 'POST' && r.url.path.endsWith('/factors'))
      .length;

  static _Harness build({
    List<String> pendingFactors = const [],
    String? aal = 'aal1',
  }) {
    final h = _Harness._(pendingFactors: pendingFactors, aal: aal);
    h.client = GoTrueClient(
      url: 'http://127.0.0.1:54321/auth/v1',
      autoRefreshToken: false,
      flowType: AuthFlowType.implicit,
      httpClient: SessionScopedHttpClient(
        MockClient(h._route),
        currentAccessToken: () => h.client.currentSession?.accessToken,
      ),
    );
    h.repository = SupabaseAuthRepository(h.client);
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

  Future<void> signIn() => repository.signInWithEmail(
    email: 'admin@dev.talentflash.test',
    password: 'password123',
  );

  /// La próxima solicitud cuya ruta termine en [suffix] queda retenida.
  Future<void> holdReached(String suffix) {
    _holds[suffix] = Completer<void>();
    return (_reached[suffix] = Completer<void>()).future;
  }

  void release(String suffix) => _holds.remove(suffix)!.complete();

  Future<http.Response> _route(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    for (final suffix in _holds.keys.toList()) {
      if (path.endsWith(suffix)) {
        _reached[suffix]?.complete();
        await _holds[suffix]!.future;
        break;
      }
    }
    return _respond(request);
  }

  http.Response _respond(http.Request request) {
    final path = request.url.path;
    http.Response json(String body) =>
        http.Response(body, 200, headers: {'content-type': 'application/json'});

    if (path.endsWith('/token')) {
      // Vale para el login y para el refresco: el servidor devuelve el nivel
      // que él tiene, que puede ser más alto que el que conoce el cliente.
      return json(_sessionJson(_serverAal));
    }
    if (path.endsWith('/user') && request.method == 'GET') {
      return json(
        jsonEncode(
          GoTrueFixtures.user(
            appRole: 'admin',
            factors: [
              for (final id in pendingFactors)
                GoTrueFixtures.factor(id: id, status: 'unverified'),
            ],
          ),
        ),
      );
    }
    if (path.endsWith('/verify')) {
      // El servidor aceptó el código: el factor queda verificado y la sesión
      // sube de nivel DEL LADO DEL SERVIDOR.
      _serverAal = 'aal2';
      if (loseVerifyResponse) {
        // …pero la respuesta se pierde en el camino. El SDK ve un error de red
        // y sigue creyendo que la sesión es `aal1`.
        throw http.ClientException('conexión interrumpida', request.url);
      }
      return json(_sessionJson('aal2'));
    }
    if (request.method == 'DELETE' && path.contains('/factors/')) {
      return json(jsonEncode({'id': path.split('/').last}));
    }
    if (request.method == 'POST' && path.endsWith('/factors')) {
      return json(GoTrueFixtures.totpEnrollJson(id: 'factor-nuevo'));
    }
    if (path.endsWith('/challenge')) {
      return json(GoTrueFixtures.challengeJson());
    }
    return http.Response(
      '{}',
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  String _sessionJson(String? level) => GoTrueFixtures.sessionJson(
    appRole: 'admin',
    accessToken: GoTrueFixtures.accessTokenWithClaims(
      aal: level,
      sessionId: _sessionId,
      // Un claim propio para que dos tokens de la misma sesión sean strings
      // distintos, como pasa al verificar y al refrescar.
      amr: [
        {'method': 'password', 'level': level ?? 'sin-aal'},
      ],
    ),
  );
}
