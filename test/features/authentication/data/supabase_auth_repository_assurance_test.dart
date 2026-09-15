import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentflash_argentina/features/authentication/data/jwt_claims.dart';
import 'package:talentflash_argentina/features/authentication/data/second_factor_attempt_recorder.dart';
import 'package:talentflash_argentina/features/authentication/data/second_factor_cleanup_policy.dart';
import 'package:talentflash_argentina/features/authentication/data/session_scoped_http_client.dart';
import 'package:talentflash_argentina/features/authentication/data/supabase_auth_repository.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_failure.dart';
import 'package:talentflash_argentina/features/authentication/domain/session_assurance.dart';

import '../../../support/gotrue_fixtures.dart';

/// La limpieza automática de factores, contra un servidor simulado que
/// distingue **tres** cosas que antes se confundían en una:
///
/// 1. el nivel del **token que conserva el cliente** (el claim `aal`);
/// 2. el nivel de **esa misma sesión en el servidor**, que puede ir adelante
///    cuando una verificación se aceptó y la respuesta no llegó;
/// 3. el **estado del factor** en el servidor (`unverified` / `verified`).
///
/// Sin esa separación no se puede expresar la ventana que importa, y un doble
/// que devuelve siempre 200 al `DELETE` aprueba solo cualquier prueba. Acá el
/// `DELETE` se resuelve como en el GoTrue real: por el nivel de la **sesión**
/// contra el estado del factor, y **borra de verdad** del estado del doble.
/// Por eso lo que se asevera es si el factor sobrevive, no si salió un pedido.
///
/// Todo corre con el `GoTrueClient` instalado y el cableado real de
/// `bootstrap.dart` (el guard HTTP entre Supabase y la red). Las respuestas se
/// retienen con `Completer`, nunca con esperas de reloj.
void main() {
  group('la limpieza automática nunca destruye un factor verificado', () {
    test(
      'RESPUESTA PERDIDA, descarte ANTES de cualquier refresco: el cliente '
      'sigue viendo aal1 y el factor ya está verificado en el servidor',
      () async {
        final h = _Harness.build()..loseVerifyResponse = true;
        await h.signIn();
        final alta = await h.repository.enrollTotp(friendlyName: 'nuevo');

        await expectLater(
          h.repository.verifySecondFactor(
            factorId: alta.factorId,
            challengeId: 'challenge-1',
            code: '123456',
          ),
          throwsA(isA<AuthFailure>()),
          reason: 'el cliente ve un error de transporte',
        );

        // El cliente NO se enteró: su token sigue diciendo aal1 y no hubo
        // evento de verificación. Es la ventana que el nivel no puede cubrir.
        expect(h.repository.currentStatus.assurance, SessionAssurance.aal1);
        expect(h.serverAal, 'aal2', reason: 'pero el servidor sí lo sabe');
        expect(h.estado(alta.factorId), 'verified');

        await h.repository.discardPendingSecondFactor(alta.factorId);

        expect(
          h.estado(alta.factorId),
          'verified',
          reason:
              'CRITERIO DE ACEPTACIÓN: el factor verificado sobrevive aunque '
              'el cliente ignore que lo está',
        );
      },
    );

    test('RESPUESTA PERDIDA, descarte DESPUÉS de un refresco legítimo: el '
        'refresco revela el aal2 y el factor también sobrevive', () async {
      final h = _Harness.build()..loseVerifyResponse = true;
      await h.signIn();
      final alta = await h.repository.enrollTotp(friendlyName: 'nuevo');
      await expectLater(
        h.repository.verifySecondFactor(
          factorId: alta.factorId,
          challengeId: 'challenge-1',
          code: '123456',
        ),
        throwsA(isA<AuthFailure>()),
      );

      final antes = sessionIdentityOf(h.client.currentSession!.accessToken);
      await h.client.refreshSession();
      expect(
        sessionIdentityOf(h.client.currentSession!.accessToken),
        antes,
        reason: 'el refresco conserva el session_id: misma sesión',
      );
      expect(h.repository.currentStatus.assurance, SessionAssurance.aal2);

      await h.repository.discardPendingSecondFactor(alta.factorId);

      expect(h.estado(alta.factorId), 'verified');
    });

    test('LECTURA DESACTUALIZADA: la verificación se acepta mientras viaja la '
        'lectura de factores del alta; el cliente sigue en aal1 y aun así la '
        'limpieza no borra el factor', () async {
      final h = _Harness.build()..loseVerifyResponse = true;
      await h.signIn();
      final primera = await h.repository.enrollTotp(friendlyName: 'primera');

      // Segundo intento de alta: su lectura de `/user` queda retenida con el
      // factor todavía «pendiente».
      final alta = h.repository.enrollTotp(friendlyName: 'segunda');
      await h.holdReached('/user');

      // Entre la lectura y el borrado, el servidor acepta el código. La
      // respuesta se pierde: el cliente sigue creyendo que está en aal1, así
      // que la barrera del nivel NO lo protege. Solo la política.
      await expectLater(
        h.repository.verifySecondFactor(
          factorId: primera.factorId,
          challengeId: 'challenge-1',
          code: '123456',
        ),
        throwsA(isA<AuthFailure>()),
      );
      expect(h.repository.currentStatus.assurance, SessionAssurance.aal1);

      h.release('/user');
      await alta;

      expect(
        h.estado(primera.factorId),
        'verified',
        reason:
            'CRITERIO DE ACEPTACIÓN: releer no alcanza; lo que decide es '
            'que hay una verificación de desenlace desconocido',
      );
    });

    test('REINTENTO tras una respuesta perdida: el rechazo del SEGUNDO intento '
        'no desprotege al PRIMERO, que el servidor sí aceptó', () async {
      // Es la refutación que encontró la revisión independiente: con un
      // solo bit por factor, este rechazo legítimo del reintento borraba la
      // marca del intento anterior y habilitaba la baja de un factor ya
      // verificado. Contra el GoTrue local, ese reintento devuelve
      // `mfa_verification_failed` (desafío nuevo, código incorrecto) o
      // `mfa_ip_address_mismatch` (mismo desafío ya consumido): los dos
      // están en la lista blanca.
      final h = _Harness.build()..loseVerifyResponse = true;
      await h.signIn();
      final alta = await h.repository.enrollTotp(friendlyName: 'uno');

      // Intento 1: el servidor acepta y la respuesta se pierde.
      await expectLater(
        h.repository.verifySecondFactor(
          factorId: alta.factorId,
          challengeId: 'challenge-1',
          code: '123456',
        ),
        throwsA(isA<AuthFailure>()),
      );
      expect(h.estado(alta.factorId), 'verified');

      // Intento 2: la persona reintenta y el servidor rechaza ESE intento.
      h
        ..loseVerifyResponse = false
        ..rejectVerify = true;
      await expectLater(
        h.repository.verifySecondFactor(
          factorId: alta.factorId,
          challengeId: 'challenge-2',
          code: '000000',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthFailureCode.mfaInvalidCode,
          ),
        ),
      );

      // La persona se cansa y sale: descarte automático.
      await h.repository.discardPendingSecondFactor(alta.factorId);

      expect(
        h.estado(alta.factorId),
        'verified',
        reason:
            'CRITERIO DE ACEPTACIÓN: un rechazo tapa su propio intento, '
            'nunca el de otro',
      );
      expect(h.deletedFactorIds, isEmpty);
    });

    test(
      'COMPOSICIÓN CON REINTENTOS: con el recorder más adentro, los DOS '
      'pedidos quedan anotados y el rechazo del segundo no resuelve al primero',
      () async {
        final h = _Harness.build(reintentos: 1)
          ..loseFirstVerifyThenReject = true;
        await h.signIn();
        final alta = await h.repository.enrollTotp(friendlyName: 'uno');

        // UNA invocación del repositorio…
        await expectLater(
          h.repository.verifySecondFactor(
            factorId: alta.factorId,
            challengeId: 'challenge-1',
            code: '123456',
          ),
          throwsA(isA<AuthFailure>()),
        );
        // …que el servidor recibió DOS veces.
        expect(h.verifiesRecibidos, 2);
        expect(h.estado(alta.factorId), 'verified');

        await h.repository.discardPendingSecondFactor(alta.factorId);

        expect(
          h.estado(alta.factorId),
          'verified',
          reason:
              'CRITERIO DE ACEPTACIÓN: contar en el transporte hace que el '
              'reintento también quede anotado',
        );
        expect(h.deletedFactorIds, isEmpty);
      },
    );

    test('POR QUÉ EL ORDEN IMPORTA: con el reintento ESCONDIDO debajo del '
        'recorder, el segundo pedido no queda anotado', () async {
      // CONTROL NEGATIVO, identificado como tal: esta NO es la composición
      // de `bootstrap.dart`, la arma el test a mano. Fija por qué el
      // recorder tiene que ser el más interno.
      //
      // Hoy la app no manda bajas, así que el daño no llega a verse en el
      // factor; lo que se compara es el REGISTRO, que es lo que la
      // composición decide y la precondición que habría que cumplir si
      // alguna vez existe un endpoint de baja usable.
      final mal = _Harness.build(reintentos: 1, recorderMasInterno: false)
        ..loseFirstVerifyThenReject = true;
      await mal.signIn();
      final altaMal = await mal.repository.enrollTotp(friendlyName: 'uno');
      await expectLater(
        mal.repository.verifySecondFactor(
          factorId: altaMal.factorId,
          challengeId: 'challenge-1',
          code: '123456',
        ),
        throwsA(isA<AuthFailure>()),
      );

      expect(
        mal.verifiesRecibidos,
        2,
        reason: 'el servidor recibió dos pedidos por una sola invocación',
      );
      expect(
        mal.politica.unresolvedVerifications(altaMal.factorId),
        0,
        reason:
            'pero el recorder vio UNO solo, y el rechazo del segundo lo '
            'dio por resuelto: el factor queda sin protección aunque el '
            'servidor lo haya verificado',
      );
      expect(mal.estado(altaMal.factorId), 'verified');

      // Y con la composición real, el mismo escenario deja el intento
      // perdido sin resolver.
      final bien = _Harness.build(reintentos: 1)
        ..loseFirstVerifyThenReject = true;
      await bien.signIn();
      final altaBien = await bien.repository.enrollTotp(friendlyName: 'uno');
      await expectLater(
        bien.repository.verifySecondFactor(
          factorId: altaBien.factorId,
          challengeId: 'challenge-1',
          code: '123456',
        ),
        throwsA(isA<AuthFailure>()),
      );

      expect(bien.verifiesRecibidos, 2);
      expect(
        bien.politica.unresolvedVerifications(altaBien.factorId),
        1,
        reason: 'el recorder vio los dos pedidos y solo resolvió el segundo',
      );
    });

    test('un factor pendiente que esta instancia NO dio de alta no se toca: no '
        'se puede afirmar que nadie lo esté verificando', () async {
      final h = _Harness.build(pendingFactors: const ['de-otra-corrida']);
      await h.signIn();

      await h.repository.enrollTotp(friendlyName: 'nuevo');

      expect(
        h.estado('de-otra-corrida'),
        'unverified',
        reason: 'sigue existiendo: la app no lo borró',
      );
      expect(
        h.deletedFactorIds,
        isEmpty,
        reason: 'y ni siquiera se pidió la baja',
      );
    });

    test('con un nivel ilegible tampoco sale ninguna baja', () async {
      final h = _Harness.build(aal: null);
      await h.signIn();
      expect(h.repository.currentStatus.assurance, SessionAssurance.unknown);
      final alta = await h.repository.enrollTotp(friendlyName: 'nuevo');

      await h.repository.discardPendingSecondFactor(alta.factorId);

      expect(
        h.deletedFactorIds,
        isEmpty,
        reason: 'unknown nunca se interpreta como aal1',
      );
    });

    test(
      'con varios pendientes propios y todas las precondiciones cumplidas, el '
      'alta no borra ninguno',
      () async {
        final h = _Harness.build(
          ownedPendingFactors: const ['pendiente-1', 'pendiente-2'],
        );
        await h.signIn();

        await h.repository.enrollTotp(friendlyName: 'c');

        expect(h.deletedFactorIds, isEmpty);
        expect(h.estado('pendiente-1'), 'unverified');
        expect(
          h.estado('pendiente-2'),
          'unverified',
          reason:
              'son propios, sin intentos sin resolver y con la sesión en '
              'aal1: antes se habrían borrado los dos. Ya no',
        );
      },
    );
  });

  group('el registro de intentos sigue siendo correcto', () {
    // La app no manda bajas, pero el registro se mantiene: es la
    // precondición que habría que cumplir el día que exista un endpoint de
    // baja usable, y es lo que impide reintroducir D1 al encenderlo.
    test('un alta abandonada en esta corrida ya NO se limpia sola', () async {
      final h = _Harness.build();
      await h.signIn();
      final abandonada = await h.repository.enrollTotp(friendlyName: 'uno');

      final nueva = await h.repository.enrollTotp(friendlyName: 'dos');

      expect(h.deletedFactorIds, isEmpty);
      expect(
        h.estado(abandonada.factorId),
        'unverified',
        reason:
            'queda en el servidor. Como nunca se le pidió un desafío, lo "'
            'recolecta GoTrue en el próximo alta: ese es el reemplazo de la "'
            'limpieza que la app dejó de hacer',
      );
      expect(h.estado(nueva.factorId), 'unverified');
    });

    test('un rechazo definitivo resuelve el intento, aunque hoy eso no "'
        'habilite ninguna baja', () async {
      final h = _Harness.build()..rejectVerify = true;
      await h.signIn();
      final alta = await h.repository.enrollTotp(friendlyName: 'uno');
      await expectLater(
        h.repository.verifySecondFactor(
          factorId: alta.factorId,
          challengeId: 'challenge-1',
          code: '000000',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthFailureCode.mfaInvalidCode,
          ),
        ),
      );

      expect(h.politica.unresolvedVerifications(alta.factorId), 0);

      await h.repository.discardPendingSecondFactor(alta.factorId);

      expect(
        h.deletedFactorIds,
        isEmpty,
        reason:
            'la precondición se cumple y aun así no sale nada: lo que "'
            'corta es automaticUnenrollEnabled',
      );
      expect(h.estado(alta.factorId), 'unverified');
    });

    test('un error de transporte al verificar NO devuelve el factor a la lista '
        'de candidatos, ni siquiera más tarde', () async {
      final h = _Harness.build()..loseVerifyResponse = true;
      await h.signIn();
      final alta = await h.repository.enrollTotp(friendlyName: 'uno');
      await expectLater(
        h.repository.verifySecondFactor(
          factorId: alta.factorId,
          challengeId: 'challenge-1',
          code: '123456',
        ),
        throwsA(isA<AuthFailure>()),
      );

      await h.repository.discardPendingSecondFactor(alta.factorId);
      await h.repository.enrollTotp(friendlyName: 'dos');

      expect(
        h.deletedFactorIds,
        isEmpty,
        reason: 'ni el descarte directo ni la limpieza del alta lo tocan',
      );
    });
  });
}

/// Arma el tramo del transporte que va debajo del guard.
///
/// El orden es lo que se está probando: con [recorderMasInterno] en `true`
/// queda `RetryClient → recorder → red`, que es lo de `bootstrap.dart` y hace
/// que el recorder vea **cada** pedido; con `false` queda
/// `recorder → RetryClient → red`, donde el recorder ve una sola llamada
/// aunque salgan dos pedidos.
http.Client _componerTransporte({
  required SecondFactorCleanupPolicy policy,
  required http.Client red,
  required int reintentos,
  required bool recorderMasInterno,
}) {
  if (reintentos == 0) {
    return SecondFactorAttemptRecorder.withInnerClient(policy, red);
  }
  RetryClient reintentando(http.Client inner) => RetryClient(
    inner,
    retries: reintentos,
    when: (_) => false,
    whenError: (_, _) => true,
    delay: (_) => Duration.zero,
  );
  return recorderMasInterno
      ? reintentando(SecondFactorAttemptRecorder.withInnerClient(policy, red))
      : SecondFactorAttemptRecorder.withInnerClient(policy, reintentando(red));
}

/// `GoTrueClient` real detrás del guard de `bootstrap.dart`, contra un
/// servidor simulado con estado.
class _Harness {
  _Harness._({required this.factores, required this.aal});

  /// Estado del factor **en el servidor**: id → `unverified` / `verified`.
  /// Un factor borrado desaparece del mapa.
  final Map<String, String> factores;

  /// Claim `aal` de la sesión del login; `null` emite un token sin el claim.
  final String? aal;

  static const _sessionId = 'sesion-unica';

  late final GoTrueClient client;
  late final SecondFactorCleanupPolicy politica;
  late final SupabaseAuthRepository repository;

  final requests = <http.Request>[];
  final events = <AuthChangeEvent>[];
  final _holds = <String, Completer<void>>{};
  final _reached = <String, Completer<void>>{};
  int _altas = 0;

  /// Con `true`, el servidor **procesa** la verificación pero el transporte
  /// pierde la respuesta: el SDK recibe un error de red y nunca ve el `aal2`.
  bool loseVerifyResponse = false;

  /// Con `true`, el servidor **rechaza** el código sin ambigüedad.
  bool rejectVerify = false;

  /// Con `true`, el PRIMER pedido de verificación se acepta y su respuesta se
  /// pierde, y todos los siguientes se rechazan con `mfa_verification_failed`.
  /// Es lo que hace el servidor real cuando se reintenta un desafío que él ya
  /// consumió.
  bool loseFirstVerifyThenReject = false;

  /// Cuántos pedidos de verificación llegaron al servidor simulado. No es lo
  /// mismo que cuántas veces se llamó a `verifySecondFactor`.
  int verifiesRecibidos = 0;

  /// Nivel que el SERVIDOR le asigna a la sesión. Empieza igual que el del
  /// login y sube cuando el servidor acepta un código, aunque el cliente no se
  /// entere: es lo que devolverá un refresco posterior, y —lo que importa— es
  /// lo que el servidor usa para resolver el `DELETE`.
  late String? serverAal = aal;

  /// Estado del factor según el servidor, o `null` si ya no existe.
  String? estado(String factorId) => factores[factorId];

  List<String> get deletedFactorIds => requests
      .where((r) => r.method == 'DELETE')
      .map((r) => r.url.pathSegments.last)
      .toList();

  /// [pendingFactors] son pendientes que la app **no** dio de alta (los dejó
  /// otra corrida). [ownedPendingFactors] son pendientes que sí: se siembran
  /// en la política, que es justo lo que hace el alta real. Sirve para armar
  /// escenarios con varios pendientes propios, que encadenando altas no se
  /// pueden montar porque cada alta limpia la anterior.
  /// Cuántos reintentos hace el `RetryClient` del transporte. Con 0 no hay.
  /// [recorderMasInterno] elige la composición: `true` es la de
  /// `bootstrap.dart` (el recorder abajo de todo, ve cada pedido); `false` es
  /// la incorrecta, con el reintento escondido debajo del recorder.
  static _Harness build({
    List<String> pendingFactors = const [],
    List<String> ownedPendingFactors = const [],
    String? aal = 'aal1',
    int reintentos = 0,
    bool recorderMasInterno = true,
  }) {
    final policy = SecondFactorCleanupPolicy();
    for (final id in ownedPendingFactors) {
      policy.recordEnrolled(id);
    }
    final h = _Harness._(
      factores: {
        for (final id in [...pendingFactors, ...ownedPendingFactors])
          id: 'unverified',
      },
      aal: aal,
    );
    h.client = GoTrueClient(
      url: 'http://127.0.0.1:54321/auth/v1',
      autoRefreshToken: false,
      flowType: AuthFlowType.implicit,
      // Misma composición que `bootstrap.dart`, y el orden importa: el
      // recorder es el más interno, así ve cada pedido de verificación.
      httpClient: SessionScopedHttpClient(
        _componerTransporte(
          policy: policy,
          red: MockClient(h._route),
          reintentos: reintentos,
          recorderMasInterno: recorderMasInterno,
        ),
        currentAccessToken: () => h.client.currentSession?.accessToken,
      ),
    );
    h.politica = policy;
    h.repository = SupabaseAuthRepository(h.client, policy);
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
    http.Response json(String body, [int status = 200]) => http.Response(
      body,
      status,
      headers: {'content-type': 'application/json'},
    );

    if (path.endsWith('/token')) {
      // Vale para el login y para el refresco: el servidor devuelve el nivel
      // que ÉL tiene, que puede ir adelante del que conoce el cliente.
      return json(_sessionJson(serverAal));
    }
    if (path.endsWith('/user') && request.method == 'GET') {
      return json(
        jsonEncode(
          GoTrueFixtures.user(
            appRole: 'admin',
            factors: [
              for (final entry in factores.entries)
                GoTrueFixtures.factor(id: entry.key, status: entry.value),
            ],
          ),
        ),
      );
    }
    if (path.endsWith('/verify')) {
      final factorId =
          request.url.pathSegments[request.url.pathSegments.length - 2];
      verifiesRecibidos++;
      if (loseFirstVerifyThenReject) {
        if (verifiesRecibidos == 1) {
          // Aceptado, y la respuesta se pierde.
          if (factores.containsKey(factorId)) factores[factorId] = 'verified';
          serverAal = 'aal2';
          throw http.ClientException('conexión interrumpida', request.url);
        }
        // El desafío ya fue consumido: el servidor rechaza ESTE pedido.
        return json(
          jsonEncode({
            'code': 422,
            'error_code': 'mfa_verification_failed',
            'msg': 'Invalid TOTP code entered',
          }),
          422,
        );
      }
      if (rejectVerify) {
        return json(
          jsonEncode({
            'code': 422,
            'error_code': 'mfa_verification_failed',
            'msg': 'Invalid TOTP code entered',
          }),
          422,
        );
      }
      // El servidor aceptó el código: el factor queda verificado y la sesión
      // sube de nivel DEL LADO DEL SERVIDOR.
      if (factores.containsKey(factorId)) factores[factorId] = 'verified';
      serverAal = 'aal2';
      if (loseVerifyResponse) {
        // …pero la respuesta se pierde en el camino. El SDK ve un error de red
        // y sigue creyendo que la sesión es `aal1`.
        throw http.ClientException('conexión interrumpida', request.url);
      }
      return json(_sessionJson('aal2'));
    }
    if (request.method == 'DELETE' && path.contains('/factors/')) {
      final factorId = request.url.pathSegments.last;
      // Como el servidor real: decide por el nivel de la SESIÓN, no por el
      // claim del token que mandó el cliente. Un factor verificado solo se
      // puede borrar con la sesión en aal2 — y entonces se borra de verdad.
      if (factores[factorId] == 'verified' && serverAal != 'aal2') {
        return json(
          jsonEncode({
            'code': 422,
            'error_code': 'insufficient_aal',
            'msg': 'AAL2 required to unenroll a verified factor',
          }),
          422,
        );
      }
      factores.remove(factorId);
      return json(jsonEncode({'id': factorId}));
    }
    if (request.method == 'POST' && path.endsWith('/factors')) {
      final id = 'factor-nuevo-${++_altas}';
      factores[id] = 'unverified';
      return json(GoTrueFixtures.totpEnrollJson(id: id));
    }
    if (path.endsWith('/challenge')) {
      return json(GoTrueFixtures.challengeJson());
    }
    return json('{}');
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
