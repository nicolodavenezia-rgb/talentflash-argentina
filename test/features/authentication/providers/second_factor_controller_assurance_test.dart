import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentflash_argentina/features/authentication/data/session_scoped_http_client.dart';
import 'package:talentflash_argentina/features/authentication/data/supabase_auth_repository.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_failure.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/authenticated_user.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/authentication/domain/session_assurance.dart';
import 'package:talentflash_argentina/features/authentication/providers/auth_providers.dart';
import 'package:talentflash_argentina/features/authentication/providers/second_factor_controller.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/gotrue_fixtures.dart';

/// El recorrido que la protección del controller **no puede** cubrir: la
/// pantalla se destruye y se vuelve a crear mientras el código viaja.
///
/// `_verifyingFactorId` vive en un notifier `autoDispose` y muere con la
/// pantalla, así que el flujo siguiente no sabe que hay una verificación en
/// vuelo. Lo que sostiene el caso es el repositorio.
///
/// Ciclo completo del controller sobre el repositorio real y el
/// `GoTrueClient` instalado; las respuestas se sueltan con `Completer`.
void main() {
  test(
    'destruir y recrear la pantalla con la verificación en vuelo no borra el '
    'factor ni abre un alta nueva',
    () async {
      final h = _Harness.build();
      await h.signIn();

      // --- Pantalla 1: alta de F y envío del código ------------------------
      final pantalla1 = h.nuevaPantalla();
      await pantalla1.esperarSesion();
      await pantalla1.controller.start(friendlyName: 'primera');
      expect(pantalla1.estado, isA<SecondFactorEnrolling>());
      final factorF =
          (pantalla1.estado as SecondFactorEnrolling).enrollment.factorId;

      unawaited(pantalla1.controller.submitCode('123456'));
      await h.holdReached('/verify');

      // --- La pantalla se destruye con el código todavía viajando ----------
      pantalla1.dispose();
      expect(
        h.deletedFactorIds,
        isEmpty,
        reason: 'el dispose respeta el factor cuyo código ya salió',
      );

      // --- Pantalla 2: se vuelve a entrar ---------------------------------
      // El servidor todavía reporta F como pendiente: su lectura se retiene.
      final pantalla2 = h.nuevaPantalla();
      await pantalla2.esperarSesion();
      final consultasAntes = h.getUserCount;
      // `start()` consulta `/user` dos veces: la lista de verificados y, dentro
      // de `enrollTotp`, la que alimenta la limpieza. Se retiene la SEGUNDA.
      final alcanzoLaLimpieza = h.holdReached('/user', skip: 1);
      final segundoStart = pantalla2.controller.start(friendlyName: 'segunda');
      await alcanzoLaLimpieza;

      // Prueba de que la ejecución llegó de verdad a la consulta de la
      // limpieza, y no se cortó antes por la comprobación de época.
      expect(
        h.getUserCount - consultasAntes,
        2,
        reason: 'la retención es la segunda consulta: la de enrollTotp',
      );

      // El servidor acepta el código: la sesión sube a aal2, misma sesión.
      h.release('/verify');
      await pumpEventQueue();

      // Recién ahora se entrega la lectura vieja, que dice «pendiente».
      h.release('/user');
      await segundoStart;
      await pumpEventQueue();

      expect(
        h.deletedFactorIds,
        isEmpty,
        reason: 'D1: el factor recién verificado no se borra por este camino',
      );
      expect(
        h.deletedFactorIds,
        isNot(contains(factorF)),
        reason:
            'y en particular no se borra F, que es el que el servidor '
            'acaba de aceptar',
      );
      expect(
        h.enrollCount,
        1,
        reason: 'no se crea una segunda alta pendiente por la carrera',
      );
      expect(
        pantalla2.estado,
        isA<SecondFactorVerified>(),
        reason:
            'la persona termina en el estado que la lleva a la cola, '
            'no en un error de sesión ni en un QR nuevo',
      );
      pantalla2.dispose();
    },
  );

  group('conversión de mfaAlreadyVerified', () {
    test('sin evento del stream, el flujo termina en AlreadyVerified y no en '
        'un error de sesión', () async {
      // Doble de repositorio: devuelve el fallo nuevo **sin** que el estado de
      // sesión cambie, que es el caso que el `ref.listen` no puede cubrir
      // (cuando el evento del SDK todavía no llegó).
      final fake =
          FakeAuthRepository(
              initialStatus: const AuthStatusSignedIn(
                AuthenticatedUser(
                  id: 'admin-1',
                  email: 'admin@dev.talentflash.test',
                  role: BusinessRole.admin,
                ),
                assurance: SessionAssurance.aal1,
                sessionId: 'sesion-1',
              ),
            )
            ..nextEnrollFailure = const AuthFailure(
              AuthFailureCode.mfaAlreadyVerified,
            );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      container.listen(authStatusProvider, (_, _) {}, fireImmediately: true);
      container.listen(
        secondFactorControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      await pumpEventQueue();

      await container
          .read(secondFactorControllerProvider.notifier)
          .start(friendlyName: 'nuevo');

      expect(
        container.read(secondFactorControllerProvider),
        isA<SecondFactorAlreadyVerified>(),
        reason:
            'la sesión vigente ya está autorizada: va a la cola, no a un '
            'error que diga que la sesión cambió',
      );
      expect(
        fake.discardedFactorIds,
        isEmpty,
        reason: 'y no se descarta nada por el camino',
      );
    });

    test('un Verified que ya llegó por el stream NO se sobrescribe', () async {
      final fake = FakeAuthRepository(
        initialStatus: const AuthStatusSignedIn(
          AuthenticatedUser(
            id: 'admin-1',
            email: 'admin@dev.talentflash.test',
            role: BusinessRole.admin,
          ),
          assurance: SessionAssurance.aal1,
          sessionId: 'sesion-1',
        ),
      );
      // El alta queda retenida: mientras tanto llega el `aal2` por el stream.
      final gate = Completer<void>();
      fake.pendingByCall['enrollTotp'] = gate;
      fake.nextEnrollFailure = const AuthFailure(
        AuthFailureCode.mfaAlreadyVerified,
      );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      container.listen(authStatusProvider, (_, _) {}, fireImmediately: true);
      container.listen(
        secondFactorControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      await pumpEventQueue();

      final arranque = container
          .read(secondFactorControllerProvider.notifier)
          .start(friendlyName: 'nuevo');
      await pumpEventQueue();

      // Misma cuenta y misma sesión, ahora verificada: el stream lo propaga.
      fake.emit(
        const AuthStatusSignedIn(
          AuthenticatedUser(
            id: 'admin-1',
            email: 'admin@dev.talentflash.test',
            role: BusinessRole.admin,
          ),
          assurance: SessionAssurance.aal2,
          sessionId: 'sesion-1',
        ),
      );
      await pumpEventQueue();
      expect(
        container.read(secondFactorControllerProvider),
        isA<SecondFactorVerified>(),
        reason: 'el stream ya dejó el flujo verificado',
      );

      // Recién ahora vuelve el alta con el fallo: no tiene que pisar nada.
      gate.complete();
      await arranque;
      await pumpEventQueue();

      expect(
        container.read(secondFactorControllerProvider),
        isA<SecondFactorVerified>(),
        reason:
            'el Verified que ya vio la persona sobrevive a la respuesta '
            'tardía del repositorio',
      );
    });
  });
}

class _Pantalla {
  _Pantalla(this._container);

  final ProviderContainer _container;

  SecondFactorController get controller =>
      _container.read(secondFactorControllerProvider.notifier);

  SecondFactorFlow get estado =>
      _container.read(secondFactorControllerProvider);

  /// El estado de sesión llega por el stream del SDK; hay que dejar que se
  /// resuelva antes de arrancar el flujo.
  Future<void> esperarSesion() async {
    for (
      var i = 0;
      i < 50 && _container.read(authStatusProvider).user == null;
      i++
    ) {
      await pumpEventQueue();
    }
  }

  void dispose() => _container.dispose();
}

class _Harness {
  _Harness._();

  static const _sessionId = 'sesion-unica';

  late final GoTrueClient client;
  late final SupabaseAuthRepository repository;

  final requests = <http.Request>[];
  final _holds = <String, Completer<void>>{};
  final _reached = <String, Completer<void>>{};
  final _skips = <String, int>{};

  /// Factores que el servidor reporta en `/user`; el alta agrega el suyo como
  /// pendiente, igual que GoTrue.
  final _serverFactors = <String>[];
  var _aal = 'aal1';

  List<String> get deletedFactorIds => requests
      .where((r) => r.method == 'DELETE')
      .map((r) => r.url.pathSegments.last)
      .toList();

  int get enrollCount => requests
      .where((r) => r.method == 'POST' && r.url.path.endsWith('/factors'))
      .length;

  static _Harness build() {
    final h = _Harness._();
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
    addTearDown(h.client.dispose);
    return h;
  }

  Future<void> signIn() => repository.signInWithEmail(
    email: 'admin@dev.talentflash.test',
    password: 'password123',
  );

  _Pantalla nuevaPantalla() {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    // El provider es `autoDispose`: sin oyente se descarta entre lecturas. La
    // pantalla real lo mantiene vivo mientras está montada.
    container.listen(authStatusProvider, (_, _) {}, fireImmediately: true);
    container.listen(
      secondFactorControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    return _Pantalla(container);
  }

  /// Retiene la solicitud cuya ruta termine en [suffix], **después de saltear
  /// [skip] coincidencias**. Hace falta para `start()`, que lee `/user` dos
  /// veces: la primera es la lista de factores verificados y la segunda, la que
  /// alimenta la limpieza de `enrollTotp`. Retener la primera cortaría el flujo
  /// por época antes de llegar a la limpieza, que es justamente lo que hay que
  /// ejercitar.
  Future<void> holdReached(String suffix, {int skip = 0}) {
    _skips[suffix] = skip;
    _holds[suffix] = Completer<void>();
    return (_reached[suffix] = Completer<void>()).future;
  }

  /// Cuántas veces se consultó `/user` hasta ahora.
  int get getUserCount => requests
      .where((r) => r.method == 'GET' && r.url.path.endsWith('/user'))
      .length;

  void release(String suffix) => _holds.remove(suffix)!.complete();

  Future<http.Response> _route(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    for (final suffix in _holds.keys.toList()) {
      if (!path.endsWith(suffix)) continue;
      if ((_skips[suffix] ?? 0) > 0) {
        _skips[suffix] = _skips[suffix]! - 1;
        continue;
      }
      _reached[suffix]?.complete();
      await _holds[suffix]!.future;
      break;
    }
    return _respond(request);
  }

  http.Response _respond(http.Request request) {
    final path = request.url.path;
    http.Response json(String body) =>
        http.Response(body, 200, headers: {'content-type': 'application/json'});

    if (path.endsWith('/token')) {
      return json(_sessionJson(_aal));
    }
    if (path.endsWith('/user') && request.method == 'GET') {
      return json(
        jsonEncode(
          GoTrueFixtures.user(
            appRole: 'admin',
            factors: [
              for (final id in _serverFactors)
                GoTrueFixtures.factor(id: id, status: 'unverified'),
            ],
          ),
        ),
      );
    }
    if (path.endsWith('/verify')) {
      // El servidor aceptó el código: sube el nivel de ESTA misma sesión.
      _aal = 'aal2';
      return json(_sessionJson('aal2'));
    }
    if (request.method == 'DELETE' && path.contains('/factors/')) {
      _serverFactors.remove(path.split('/').last);
      return json(jsonEncode({'id': path.split('/').last}));
    }
    if (request.method == 'POST' && path.endsWith('/factors')) {
      const id = 'factor-nuevo';
      _serverFactors.add(id);
      return json(GoTrueFixtures.totpEnrollJson(id: id));
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

  String _sessionJson(String level) => GoTrueFixtures.sessionJson(
    appRole: 'admin',
    accessToken: GoTrueFixtures.accessTokenWithClaims(
      aal: level,
      sessionId: _sessionId,
      amr: [
        {'method': 'password', 'level': level},
      ],
    ),
  );
}
