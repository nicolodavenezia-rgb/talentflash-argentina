import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_failure.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/authenticated_user.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/authentication/domain/second_factor.dart';
import 'package:talentflash_argentina/features/authentication/domain/session_assurance.dart';
import 'package:talentflash_argentina/features/authentication/providers/auth_providers.dart';
import 'package:talentflash_argentina/features/authentication/providers/second_factor_controller.dart';

import '../../../support/fake_auth_repository.dart';

/// Máquina de estados del segundo factor, sin widgets ni Supabase.
void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;
  late DateTime now;

  const admin = AuthenticatedUser(
    id: 'admin-1',
    email: 'admin@dev.talentflash.test',
    role: BusinessRole.admin,
  );
  const otherAdmin = AuthenticatedUser(
    id: 'admin-2',
    email: 'otra@dev.talentflash.test',
    role: BusinessRole.admin,
  );
  const friendlyName = 'TalentFlash · 08/09/2026 14:32';

  Future<void> settle() async {
    // Dos vueltas del event loop: una para el stream de sesión y otra para
    // las continuaciones del controller.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  SecondFactorController controller() =>
      container.read(secondFactorControllerProvider.notifier);
  SecondFactorFlow state() => container.read(secondFactorControllerProvider);

  /// Arma el contenedor con la sesión ya resuelta y el controller vivo.
  Future<void> arrange({
    AuthStatus initial = const AuthStatusSignedIn(
      admin,
      assurance: SessionAssurance.aal1,
    ),
  }) async {
    repository = FakeAuthRepository(initialStatus: initial);
    addTearDown(repository.dispose);
    now = DateTime(2026, 9, 8, 14, 32);
    container = ProviderContainer.test(
      retry: (retryCount, error) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    container.listen(authStatusProvider, (_, _) {});
    await settle();
    final subscription = container.listen(
      secondFactorControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
  }

  group('arranque', () {
    test('sin factor verificado inicia el alta y muestra el secreto', () async {
      await arrange();

      await controller().start(friendlyName: friendlyName);

      expect(repository.calls, <String>[
        'listVerifiedSecondFactors',
        'enrollTotp',
      ], reason: 'el desafío NO se pide en el alta: lo pide el envío');
      expect(repository.lastFriendlyName, friendlyName);
      final flow = state();
      expect(flow, isA<SecondFactorEnrolling>());
      flow as SecondFactorEnrolling;
      expect(flow.enrollment.secret, repository.nextEnrollment.secret);
      expect(
        flow.challenge,
        isNull,
        reason:
            'el desafío se pide recién al mandar el código. Así un alta '
            'abandonada queda SIN desafío, que es la única forma en que el '
            'servidor la recolecta: lo hace dentro del handler del alta '
            'siguiente, no con un temporizador',
      );
      expect(flow.isSubmitting, isFalse);
    });

    test(
      'start es idempotente: una reconstrucción no duplica el alta',
      () async {
        await arrange();

        await controller().start(friendlyName: friendlyName);
        await controller().start(friendlyName: friendlyName);
        await controller().start(friendlyName: 'otro nombre');

        expect(repository.calls.where((c) => c == 'enrollTotp').length, 1);
      },
    );

    test('dos start simultáneos tampoco duplican', () async {
      await arrange();

      final primero = controller().start(friendlyName: friendlyName);
      final segundo = controller().start(friendlyName: friendlyName);
      await Future.wait<void>([primero, segundo]);

      expect(repository.calls.where((c) => c == 'enrollTotp').length, 1);
    });

    test('con un factor verificado desafía ESE y no crea otro', () async {
      await arrange();
      repository.verifiedFactors = const [
        SecondFactor(id: 'factor-ok', friendlyName: 'Mi celular'),
      ];

      await controller().start(friendlyName: friendlyName);

      expect(repository.calls, <String>['listVerifiedSecondFactors']);
      final flow = state();
      expect(flow, isA<SecondFactorChallenging>());
      flow as SecondFactorChallenging;
      expect(flow.factor.id, 'factor-ok');
      expect(flow.canChooseAnother, isFalse);
    });

    test(
      'con varios factores pide elegir, y se puede volver a elegir',
      () async {
        await arrange();
        repository.verifiedFactors = const [
          SecondFactor(id: 'factor-a', friendlyName: 'Celular'),
          SecondFactor(id: 'factor-b', friendlyName: 'Tablet'),
        ];

        await controller().start(friendlyName: friendlyName);
        expect(state(), isA<SecondFactorChoosing>());
        expect(repository.calls, isNot(contains('enrollTotp')));

        controller().chooseFactor('factor-b');
        final elegido = state();
        expect(elegido, isA<SecondFactorChallenging>());
        elegido as SecondFactorChallenging;
        expect(elegido.factor.id, 'factor-b');
        expect(elegido.canChooseAnother, isTrue);

        controller().chooseAnother();
        expect(state(), isA<SecondFactorChoosing>());

        controller().chooseFactor('factor-inexistente');
        expect(state(), isA<SecondFactorChoosing>());
      },
    );

    test(
      'una sesión que ya es aal2 no entra en un bucle de desafíos',
      () async {
        await arrange(
          initial: const AuthStatusSignedIn(
            admin,
            assurance: SessionAssurance.aal2,
          ),
        );

        await controller().start(friendlyName: friendlyName);

        expect(state(), isA<SecondFactorAlreadyVerified>());
        expect(repository.calls, isEmpty);
      },
    );

    test('sin sesión no se pide nada', () async {
      await arrange(initial: const AuthStatusSignedOut());

      await controller().start(friendlyName: friendlyName);

      final flow = state();
      expect(flow, isA<SecondFactorUnavailable>());
      expect(
        (flow as SecondFactorUnavailable).failure.code,
        AuthFailureCode.sessionMissing,
      );
      expect(repository.calls, isEmpty);
    });

    test('un error de red al leer los factores se puede reintentar', () async {
      await arrange();
      repository.nextListFactorsFailure = const AuthFailure(
        AuthFailureCode.network,
      );

      await controller().start(friendlyName: friendlyName);
      final flow = state();
      expect(flow, isA<SecondFactorUnavailable>());
      expect(
        (flow as SecondFactorUnavailable).failure.code,
        AuthFailureCode.network,
      );

      await controller().start(friendlyName: friendlyName);
      expect(state(), isA<SecondFactorEnrolling>());
    });

    test(
      'un alta rechazada por nombre repetido se explica y se reintenta',
      () async {
        await arrange();
        repository.nextEnrollFailure = const AuthFailure(
          AuthFailureCode.mfaFactorNameConflict,
        );

        await controller().start(friendlyName: friendlyName);
        expect(
          (state() as SecondFactorUnavailable).failure.code,
          AuthFailureCode.mfaFactorNameConflict,
        );

        await controller().start(
          friendlyName: 'TalentFlash · 08/09/2026 14:33',
        );
        expect(state(), isA<SecondFactorEnrolling>());
        expect(repository.lastFriendlyName, 'TalentFlash · 08/09/2026 14:33');
      },
    );
  });

  group('envío del código', () {
    test('pide un desafío, verifica y termina en verificado', () async {
      await arrange();
      await controller().start(friendlyName: friendlyName);

      await controller().submitCode('123456');
      await settle();

      expect(repository.lastChallengedFactorId, 'factor-pendiente');
      expect(repository.lastVerifiedFactorId, 'factor-pendiente');
      expect(repository.lastVerifiedChallengeId, 'challenge-1');
      expect(repository.lastVerifiedCode, '123456');
      expect(state(), isA<SecondFactorVerified>());
      // Mismo usuario y rol, ahora con aal2 (llega por el stream de sesión).
      final status = container.read(authStatusProvider);
      expect(status.user, admin);
      expect(status.hasSecondFactorVerified, isTrue);
    });

    test('un formato inválido no llega al servidor', () async {
      await arrange();
      await controller().start(friendlyName: friendlyName);

      await controller().submitCode('12ab');

      final flow = state() as SecondFactorEnrolling;
      expect(flow.failure?.code, AuthFailureCode.mfaInvalidCode);
      expect(repository.calls, isNot(contains(startsWith('verify'))));
      expect(
        repository.calls.where((c) => c.startsWith('challenge')),
        isEmpty,
        reason: 'el formato se rechaza en local: no se pide ni el desafío',
      );
    });

    test('el envío pide el desafío y sigue con la verificación', () async {
      await arrange();

      await controller().start(friendlyName: friendlyName);
      final flow = state();
      expect(flow, isA<SecondFactorEnrolling>());
      expect((flow as SecondFactorEnrolling).challenge, isNull);
      expect(flow.failure, isNull, reason: 'el alta se muestra igual');

      await controller().submitCode('123456');

      expect(repository.lastVerifiedChallengeId, 'challenge-1');
      expect(state(), isA<SecondFactorVerified>());
    });

    test(
      'si el factor se recolectó mientras la persona se tomaba su tiempo, se '
      'rehace el alta UNA vez y se avisa que el QR cambió',
      () async {
        await arrange();
        // El alta rehecha tiene que traer un secreto propio: es lo que hace
        // que el QR cambie de verdad.
        repository.queuedEnrollments.add(repository.nextEnrollment);
        // Secreto inventado y **de baja entropía a propósito**: el scan de
        // secretos de la CI (gitleaks, `generic-api-key`) marca cualquier
        // literal cerca de la palabra `secret` que pase de 3.5 bits por
        // carácter, así que el fixture repite caracteres en vez de usar 16
        // distintos.
        repository.queuedEnrollments.add(
          const TotpEnrollment(
            factorId: 'factor-rehecho',
            friendlyName: 'TalentFlash · 08/09/2026 14:40',
            secret: 'KRSXG5CTKRSXG5CT',
            uri:
                'otpauth://totp/TalentFlash%20Argentina:persona'
                '?secret=KRSXG5CTKRSXG5CT',
          ),
        );
        await controller().start(friendlyName: friendlyName);
        final primero = (state() as SecondFactorEnrolling).enrollment;
        repository.nextChallengeFailure = const AuthFailure(
          AuthFailureCode.mfaFactorNotFound,
        );

        await controller().submitCode('123456');

        final flow = state();
        expect(flow, isA<SecondFactorEnrolling>());
        flow as SecondFactorEnrolling;
        expect(
          flow.restarted,
          isTrue,
          reason: 'la pantalla tiene que decir que el QR cambió',
        );
        expect(
          flow.enrollment.secret,
          isNot(primero.secret),
          reason: 'NO se reutiliza el secreto anterior',
        );
        expect(flow.challenge, isNull);
        expect(
          repository.calls.where((c) => c.startsWith('verify')),
          isEmpty,
          reason:
              'tampoco se reintenta el código: la persona tiene que escanear '
              'el QR nuevo y mandar otro',
        );
        expect(
          repository.calls.where((c) => c.startsWith('enrollTotp')).length,
          2,
          reason: 'exactamente un alta nueva, sin bucle',
        );
      },
    );

    test('un código incorrecto conserva el alta y el desafío', () async {
      await arrange();
      await controller().start(friendlyName: friendlyName);
      repository.nextVerifyFailure = const AuthFailure(
        AuthFailureCode.mfaInvalidCode,
      );

      await controller().submitCode('000000');
      final rechazado = state();
      expect(rechazado, isA<SecondFactorEnrolling>());
      rechazado as SecondFactorEnrolling;
      expect(rechazado.failure?.code, AuthFailureCode.mfaInvalidCode);
      expect(rechazado.isSubmitting, isFalse);
      expect(rechazado.challenge?.id, 'challenge-1');
      expect(
        container.read(authStatusProvider).hasSecondFactorVerified,
        isFalse,
      );

      await controller().submitCode('654321');
      expect(state(), isA<SecondFactorVerified>());
      expect(
        repository.calls.where((c) => c.startsWith('challenge')).length,
        1,
        reason: 'el desafío vigente se reutiliza; no se pide otro',
      );
      expect(repository.calls.where((c) => c == 'enrollTotp').length, 1);
    });

    test(
      'un desafío vencido en el servidor se repone en el próximo envío',
      () async {
        await arrange();
        await controller().start(friendlyName: friendlyName);
        repository.nextVerifyFailure = const AuthFailure(
          AuthFailureCode.mfaChallengeExpired,
        );

        await controller().submitCode('111111');
        final vencido = state() as SecondFactorEnrolling;
        expect(vencido.failure?.code, AuthFailureCode.mfaChallengeExpired);
        expect(vencido.challenge, isNull);

        await controller().submitCode('222222');
        expect(repository.lastVerifiedChallengeId, 'challenge-2');
        expect(state(), isA<SecondFactorVerified>());
      },
    );

    test(
      'un desafío rechazado por el servidor (otra red) también se repone',
      () async {
        await arrange();
        await controller().start(friendlyName: friendlyName);
        repository.nextVerifyFailure = const AuthFailure(
          AuthFailureCode.mfaRejected,
        );

        await controller().submitCode('111111');
        final rechazado = state() as SecondFactorEnrolling;
        expect(rechazado.failure?.code, AuthFailureCode.mfaRejected);
        expect(
          rechazado.challenge,
          isNull,
          reason: 'GoTrue ata el desafío a la IP: reusarlo fallaría siempre',
        );

        await controller().submitCode('222222');
        expect(repository.lastVerifiedChallengeId, 'challenge-2');
      },
    );

    test(
      'un desafío vencido según el reloj se repone antes de enviar',
      () async {
        await arrange();
        repository.nextChallengeExpiresAt = now.add(const Duration(minutes: 5));
        await controller().start(friendlyName: friendlyName);
        repository.nextVerifyFailure = const AuthFailure(
          AuthFailureCode.mfaInvalidCode,
        );
        await controller().submitCode('111111');
        expect((state() as SecondFactorEnrolling).challenge?.id, 'challenge-1');

        // Pasan seis minutos entre el rechazo y el siguiente intento.
        now = now.add(const Duration(minutes: 6));
        await controller().submitCode('222222');

        expect(repository.lastVerifiedChallengeId, 'challenge-2');
      },
    );

    test('un doble toque no manda dos verificaciones', () async {
      await arrange();
      await controller().start(friendlyName: friendlyName);
      final gate = Completer<void>();
      repository.pendingSecondFactorAction = gate;

      final primero = controller().submitCode('123456');
      final segundo = controller().submitCode('123456');
      expect((state() as SecondFactorEnrolling).isSubmitting, isTrue);
      gate.complete();
      await Future.wait<void>([primero, segundo]);

      expect(repository.calls.where((c) => c.startsWith('verify')).length, 1);
    });

    test('el límite de intentos del servidor se muestra como tal', () async {
      await arrange();
      await controller().start(friendlyName: friendlyName);
      repository.nextVerifyFailure = const AuthFailure(
        AuthFailureCode.rateLimited,
      );

      await controller().submitCode('123456');

      expect(
        (state() as SecondFactorEnrolling).failure?.code,
        AuthFailureCode.rateLimited,
      );
    });

    test('sobre un factor existente se verifica ese factor', () async {
      await arrange();
      repository.verifiedFactors = const [SecondFactor(id: 'factor-ok')];
      await controller().start(friendlyName: friendlyName);

      await controller().submitCode('123456');

      expect(repository.lastChallengedFactorId, 'factor-ok');
      expect(repository.lastVerifiedFactorId, 'factor-ok');
      expect(state(), isA<SecondFactorVerified>());
    });

    test(
      'si la sesión llega a aal2 por otra vía, el flujo se da por verificado',
      () async {
        await arrange();
        await controller().start(friendlyName: friendlyName);

        // Otra pestaña verificó: el SDK emite el mismo usuario con aal2.
        repository.emit(
          const AuthStatusSignedIn(admin, assurance: SessionAssurance.aal2),
        );
        await settle();

        expect(state(), isA<SecondFactorVerified>());
      },
    );

    test('un refresco de token del mismo nivel no toca el flujo', () async {
      await arrange();
      await controller().start(friendlyName: friendlyName);

      repository.emit(
        const AuthStatusSignedIn(admin, assurance: SessionAssurance.aal1),
      );
      await settle();

      expect(state(), isA<SecondFactorEnrolling>());
    });
  });

  group('cancelación y estado sensible', () {
    test('cancelar descarta el factor pendiente y vuelve al inicio', () async {
      await arrange();
      await controller().start(friendlyName: friendlyName);

      controller().cancel();
      await settle();

      expect(state(), isA<SecondFactorIdle>());
      expect(repository.discardedFactorIds, <String>['factor-pendiente']);
    });

    test('cancelar un desafío sobre un factor verificado no lo toca', () async {
      await arrange();
      repository.verifiedFactors = const [SecondFactor(id: 'factor-ok')];
      await controller().start(friendlyName: friendlyName);

      controller().cancel();
      await settle();

      expect(repository.discardedFactorIds, isEmpty);
    });

    test('salir de la pantalla descarta el factor pendiente', () async {
      await arrange();
      await controller().start(friendlyName: friendlyName);

      container.dispose();
      await settle();

      expect(repository.discardedFactorIds, <String>['factor-pendiente']);
    });

    test('tras verificar, salir de la pantalla no borra nada', () async {
      await arrange();
      await controller().start(friendlyName: friendlyName);
      await controller().submitCode('123456');
      expect(state(), isA<SecondFactorVerified>());

      container.dispose();
      await settle();

      expect(repository.discardedFactorIds, isEmpty);
    });

    test('un fallo al descartar no rompe nada', () async {
      await arrange();
      await controller().start(friendlyName: friendlyName);
      repository.nextDiscardFailure = const AuthFailure(
        AuthFailureCode.network,
      );

      controller().cancel();
      await settle();

      expect(state(), isA<SecondFactorIdle>());
    });
  });

  group('cierre de sesión y cambio de cuenta', () {
    test('cerrar sesión descarta el alta sin llamar al servidor', () async {
      await arrange();
      await controller().start(friendlyName: friendlyName);
      expect(state(), isA<SecondFactorEnrolling>());

      repository.emit(const AuthStatusSignedOut());
      await settle();

      expect(state(), isA<SecondFactorIdle>());
      expect(
        repository.discardedFactorIds,
        isEmpty,
        reason: 'sin sesión no hay con qué descartar; el servidor lo vence',
      );
    });

    test(
      'una respuesta tardía del alta de una cuenta no se aplica a la siguiente',
      () async {
        await arrange();
        final gate = Completer<void>();
        repository.pendingSecondFactorAction = gate;
        final arranque = controller().start(friendlyName: friendlyName);
        await settle();
        expect(state(), isA<SecondFactorPreparing>());

        // La cuenta cambia mientras la lista de factores está en vuelo.
        repository.emit(const AuthStatusSignedOut());
        await settle();
        repository.emit(
          const AuthStatusSignedIn(
            otherAdmin,
            assurance: SessionAssurance.aal1,
          ),
        );
        await settle();
        expect(state(), isA<SecondFactorIdle>());

        gate.complete();
        await arranque;
        await settle();

        expect(state(), isA<SecondFactorIdle>());
        expect(
          repository.calls,
          isNot(contains('enrollTotp')),
          reason:
              'la continuación del flujo viejo no crea un factor para la '
              'cuenta nueva',
        );
      },
    );

    test(
      'una verificación en vuelo de la cuenta anterior no marca verificada a '
      'la siguiente',
      () async {
        await arrange();
        repository.verifiedFactors = const [SecondFactor(id: 'factor-a')];
        await controller().start(friendlyName: friendlyName);
        final gate = Completer<void>();
        repository.pendingSecondFactorAction = gate;
        // Lo que responde GoTrue cuando la verificación llega después del
        // cierre de sesión que la precedió: la sesión ya no existe.
        repository.nextVerifyFailure = const AuthFailure(
          AuthFailureCode.sessionMissing,
        );
        final envio = controller().submitCode('123456');
        await settle();

        repository.emit(const AuthStatusSignedOut());
        await settle();
        repository.emit(
          const AuthStatusSignedIn(
            otherAdmin,
            assurance: SessionAssurance.aal1,
          ),
        );
        await settle();

        gate.complete();
        await envio;
        await settle();

        expect(
          state(),
          isA<SecondFactorIdle>(),
          reason: 'ni el error tardío ni nada del flujo viejo se muestra',
        );
        expect(
          container.read(authStatusProvider).hasSecondFactorVerified,
          isFalse,
        );
      },
    );

    test(
      'la misma cuenta en una sesión nueva es otro flujo, aunque no pase por '
      'SignedOut',
      () async {
        await arrange(
          initial: const AuthStatusSignedIn(
            admin,
            assurance: SessionAssurance.aal1,
            sessionId: 'sesion-1',
          ),
        );
        await controller().start(friendlyName: friendlyName);
        expect(state(), isA<SecondFactorEnrolling>());

        // Reingreso de la misma cuenta: otro `session_id`.
        repository.emit(
          const AuthStatusSignedIn(
            admin,
            assurance: SessionAssurance.aal1,
            sessionId: 'sesion-2',
          ),
        );
        await settle();

        // No queda en `Idle`: la pantalla dibuja `Idle` igual que «preparando»
        // y nadie vuelve a llamar a `start()`, así que anunciaría para siempre
        // un trabajo inexistente. Con una sesión nueva todavía utilizable se
        // informa el corte y se ofrece reintentar.
        final flow = state();
        expect(flow, isA<SecondFactorUnavailable>());
        expect(
          (flow as SecondFactorUnavailable).failure.code,
          AuthFailureCode.staleSession,
        );
        expect(
          repository.discardedFactorIds,
          isEmpty,
          reason: 'la sesión que creó el pendiente ya no está',
        );
        expect(
          repository.calls,
          isNot(contains('discardPendingSecondFactor:factor-pendiente')),
        );
      },
    );

    test(
      'sin sesión el flujo vuelve a Idle: el router se lleva la pantalla y no '
      'hay nada que reintentar',
      () async {
        await arrange(
          initial: const AuthStatusSignedIn(
            admin,
            assurance: SessionAssurance.aal1,
            sessionId: 'sesion-1',
          ),
        );
        await controller().start(friendlyName: friendlyName);
        expect(state(), isA<SecondFactorEnrolling>());

        repository.emit(const AuthStatusSignedOut());
        await settle();

        expect(state(), isA<SecondFactorIdle>());
        expect(repository.discardedFactorIds, isEmpty);
      },
    );

    test(
      'verificar conserva la sesión: mismo session_id, nivel nuevo',
      () async {
        await arrange(
          initial: const AuthStatusSignedIn(
            admin,
            assurance: SessionAssurance.aal1,
            sessionId: 'sesion-1',
          ),
        );
        await controller().start(friendlyName: friendlyName);

        await controller().submitCode('123456');
        await settle();

        expect(state(), isA<SecondFactorVerified>());
        expect(container.read(authStatusProvider).sessionId, 'sesion-1');
      },
    );

    test('con la cuenta nueva el flujo arranca de cero', () async {
      await arrange();
      await controller().start(friendlyName: friendlyName);
      repository.emit(const AuthStatusSignedOut());
      await settle();
      repository.emit(
        const AuthStatusSignedIn(otherAdmin, assurance: SessionAssurance.aal1),
      );
      await settle();
      repository.verifiedFactors = const [SecondFactor(id: 'factor-otra')];

      await controller().start(friendlyName: friendlyName);

      final flow = state();
      expect(flow, isA<SecondFactorChallenging>());
      expect((flow as SecondFactorChallenging).factor.id, 'factor-otra');
    });

    test(
      'salir tras un cambio de cuenta no descarta con el token ajeno',
      () async {
        await arrange();
        await controller().start(friendlyName: friendlyName);
        repository.emit(
          const AuthStatusSignedIn(
            otherAdmin,
            assurance: SessionAssurance.aal1,
          ),
        );
        await settle();

        container.dispose();
        await settle();

        expect(repository.discardedFactorIds, isEmpty);
      },
    );

    test('un alta que resuelve DESPUÉS del dispose relee la sesión del '
        'repositorio y no descarta con el bearer ajeno', () async {
      await arrange(
        initial: const AuthStatusSignedIn(
          admin,
          assurance: SessionAssurance.aal1,
          sessionId: 'sesion-1',
        ),
      );
      // El alta queda en vuelo y la pantalla se va: a partir de acá el
      // `ref.listen` del controller está cerrado, así que una copia guardada
      // de la sesión quedaría congelada en `sesion-1` para siempre.
      final alta = Completer<void>();
      repository.pendingByCall['enrollTotp'] = alta;
      final arranque = controller().start(friendlyName: friendlyName);
      await settle();
      container.dispose();

      // Recién ahora cambia la sesión, y recién después contesta el alta:
      // la continuación de `start` es la que decide si descartar.
      repository.emit(
        const AuthStatusSignedIn(
          otherAdmin,
          assurance: SessionAssurance.aal1,
          sessionId: 'sesion-2',
        ),
      );
      await settle();
      alta.complete();
      await arranque;
      await settle();

      expect(
        repository.discardedFactorIds,
        isEmpty,
        reason:
            'el unenroll del SDK viaja con el bearer de la sesión VIGENTE: '
            'con otra sesión no debe salir ninguna solicitud del flujo viejo',
      );
    });
  });

  group('verificación en vuelo al salir de la pantalla', () {
    test(
      'salir mientras el código viaja NO pide el descarte del factor que el '
      'servidor está aceptando, que es la barrera que hay que conservar',
      () async {
        await arrange();
        await controller().start(friendlyName: friendlyName);
        expect(state(), isA<SecondFactorEnrolling>());

        // El código ya salió y el servidor todavía no contestó.
        final verificando = Completer<void>();
        repository.pendingByCall['verifySecondFactor'] = verificando;
        final envio = controller().submitCode('123456');
        await settle();
        expect(
          repository.calls,
          contains('verifySecondFactor:factor-pendiente'),
          reason: 'la verificación está en vuelo',
        );

        // Atrás del navegador / del sistema: la ruta se va aunque «Cancelar»
        // esté deshabilitado por el envío en curso.
        container.dispose();
        await settle();

        expect(
          repository.discardedFactorIds,
          isEmpty,
          reason:
              'esto se fija en la capa del controller: hoy el repositorio no '
              'borra nada, pero la barrera tiene que estar igual. Si alguna '
              'vez existe una baja usable, pedirla acá correría contra la '
              'verificación y podría dejar la cuenta en aal2 sin '
              'autenticador, sin baja ni recuperación posibles',
        );

        verificando.complete();
        await envio;
        await settle();
        expect(repository.discardedFactorIds, isEmpty);
      },
    );

    test(
      'un alta sin código enviado sí PIDE el descarte al salir (el repositorio '
      'hoy no borra, pero el controller tiene que seguir pidiéndolo)',
      () async {
        await arrange();
        await controller().start(friendlyName: friendlyName);
        expect(state(), isA<SecondFactorEnrolling>());

        container.dispose();
        await settle();

        expect(repository.discardedFactorIds, <String>['factor-pendiente']);
      },
    );

    test('cancelar con el alta todavía en vuelo descarta el pendiente reción '
        'creado con la MISMA sesión', () async {
      await arrange();
      final alta = Completer<void>();
      repository.pendingByCall['enrollTotp'] = alta;
      final arranque = controller().start(friendlyName: friendlyName);
      await settle();
      expect(state(), isA<SecondFactorPreparing>());

      controller().cancel();
      await settle();
      alta.complete();
      await arranque;
      await settle();

      expect(state(), isA<SecondFactorIdle>());
      expect(repository.discardedFactorIds, <String>[
        'factor-pendiente',
      ], reason: 'el factor que el servidor creó tras el cancel no queda vivo');
    });

    test('si la sesión cambió mientras el alta viajaba, el pendiente NO se '
        'descarta (iría con el token de la sesión nueva)', () async {
      await arrange(
        initial: const AuthStatusSignedIn(
          admin,
          assurance: SessionAssurance.aal1,
          sessionId: 'sesion-1',
        ),
      );
      final alta = Completer<void>();
      repository.pendingByCall['enrollTotp'] = alta;
      final arranque = controller().start(friendlyName: friendlyName);
      await settle();
      expect(state(), isA<SecondFactorPreparing>());

      repository.emit(
        const AuthStatusSignedIn(
          otherAdmin,
          assurance: SessionAssurance.aal1,
          sessionId: 'sesion-2',
        ),
      );
      await settle();
      alta.complete();
      await arranque;
      await settle();

      expect(repository.discardedFactorIds, isEmpty);
      expect(
        repository.calls,
        isNot(contains('discardPendingSecondFactor:factor-pendiente')),
      );
    });
  });
}
