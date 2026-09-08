import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentflash_argentina/features/authentication/data/auth_repository.dart';
import 'package:talentflash_argentina/features/authentication/data/supabase_auth_repository.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_failure.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/authentication/domain/session_assurance.dart';

import '../../../support/gotrue_fixtures.dart';

/// Ejercita el repositorio real contra un cliente HTTP falso que devuelve las
/// mismas respuestas que el GoTrue del stack local. No hay ningún proyecto
/// Supabase remoto ni red involucrada.
void main() {
  late List<http.Request> requests;

  /// Construye el repositorio con un GoTrue apuntado al cliente falso.
  SupabaseAuthRepository buildRepository(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    final client = GoTrueClient(
      url: 'http://127.0.0.1:54321/auth/v1',
      autoRefreshToken: false,
      // El flujo PKCE necesita almacenamiento asíncrono; para estos tests
      // alcanza con el implícito.
      flowType: AuthFlowType.implicit,
      httpClient: MockClient((request) {
        requests.add(request);
        return handler(request);
      }),
    );
    addTearDown(client.dispose);
    return SupabaseAuthRepository(client);
  }

  http.Response json(String body, {int status = 200}) => http.Response(
    body,
    status,
    headers: const {'content-type': 'application/json'},
  );

  setUp(() {
    requests = <http.Request>[];
  });

  group('alta de cuenta', () {
    test(
      'manda solo el rol pedido en metadata y normaliza el correo',
      () async {
        final repository = buildRepository(
          (_) async => json(GoTrueFixtures.sessionJson(appRole: 'company')),
        );

        final outcome = await repository.signUpWithEmail(
          email: '  Empresa1@Dev.TalentFlash.Test ',
          password: 'password12345',
          role: SignUpRole.company,
        );

        expect(outcome, SignUpOutcome.signedIn);
        expect(requests.single.url.path, endsWith('/signup'));
        final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(body['email'], 'empresa1@dev.talentflash.test');
        expect(body['data'], <String, dynamic>{'role': 'company'});
      },
    );

    test('el alta de candidato pide el rol candidate', () async {
      final repository = buildRepository(
        (_) async => json(GoTrueFixtures.sessionJson()),
      );

      await repository.signUpWithEmail(
        email: 'candidato@dev.talentflash.test',
        password: 'password12345',
        role: SignUpRole.candidate,
      );

      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['data'], <String, dynamic>{'role': 'candidate'});
    });

    test('la UI no puede pedir admin: el tipo solo tiene dos variantes', () {
      expect(SignUpRole.values, <SignUpRole>[
        SignUpRole.candidate,
        SignUpRole.company,
      ]);
      expect(
        SignUpRole.values.map((role) => role.claim),
        isNot(contains(BusinessRole.admin.claim)),
      );
    });

    test('sin sesión en la respuesta hay que confirmar el correo', () async {
      final repository = buildRepository(
        (_) async => json(GoTrueFixtures.userWithoutSessionJson()),
      );

      final outcome = await repository.signUpWithEmail(
        email: 'nueva@dev.talentflash.test',
        password: 'password12345',
        role: SignUpRole.candidate,
      );

      expect(outcome, SignUpOutcome.emailConfirmationRequired);
      expect(repository.currentStatus, isA<AuthStatusSignedOut>());
    });

    test('un correo ya registrado llega como error tipado', () async {
      final repository = buildRepository(
        (_) async => json(
          GoTrueFixtures.errorJson(
            code: 422,
            errorCode: 'user_already_exists',
            message: 'User already registered',
          ),
          status: 422,
        ),
      );

      await expectLater(
        repository.signUpWithEmail(
          email: 'candidato1@dev.talentflash.test',
          password: 'password12345',
          role: SignUpRole.candidate,
        ),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.code,
            'code',
            AuthFailureCode.emailAlreadyRegistered,
          ),
        ),
      );
    });

    test('una contraseña débil llega como error tipado', () async {
      final repository = buildRepository(
        (_) async => json(
          GoTrueFixtures.errorJson(
            code: 422,
            errorCode: 'weak_password',
            message: 'Password should be at least 10 characters.',
          ),
          status: 422,
        ),
      );

      await expectLater(
        repository.signUpWithEmail(
          email: 'nueva@dev.talentflash.test',
          password: '123456789',
          role: SignUpRole.candidate,
        ),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.code,
            'code',
            AuthFailureCode.weakPassword,
          ),
        ),
      );
    });
  });

  group('inicio de sesión', () {
    test(
      'el rol confiable sale de app_metadata, no de user_metadata',
      () async {
        final repository = buildRepository(
          (_) async => json(
            GoTrueFixtures.sessionJson(
              appRole: 'company',
              // Lo que el cliente pidió al registrarse: no debe influir.
              requestedRole: 'admin',
              email: 'empresa1@dev.talentflash.test',
            ),
          ),
        );

        await repository.signInWithEmail(
          email: 'empresa1@dev.talentflash.test',
          password: 'password123',
        );

        final status = repository.currentStatus;
        expect(status, isA<AuthStatusSignedIn>());
        expect(status.role, BusinessRole.company);
        expect(status.user?.email, 'empresa1@dev.talentflash.test');
      },
    );

    test('sin claim de rol la sesión queda en estado inconsistente', () async {
      final repository = buildRepository(
        (_) async => json(GoTrueFixtures.sessionJson(includeAppRole: false)),
      );

      await repository.signInWithEmail(
        email: 'persona@dev.talentflash.test',
        password: 'password123',
      );

      expect(repository.currentStatus, isA<AuthStatusInconsistent>());
      expect(repository.currentStatus.role, isNull);
    });

    test('un claim desconocido tampoco habilita nada', () async {
      final repository = buildRepository(
        (_) async => json(GoTrueFixtures.sessionJson(appRole: 'moderator')),
      );

      await repository.signInWithEmail(
        email: 'persona@dev.talentflash.test',
        password: 'password123',
      );

      final status = repository.currentStatus;
      expect(status, isA<AuthStatusInconsistent>());
      expect((status as AuthStatusInconsistent).rawClaim, 'moderator');
    });

    test('credenciales incorrectas llegan como error tipado', () async {
      final repository = buildRepository(
        (_) async => json(
          GoTrueFixtures.errorJson(
            code: 400,
            errorCode: 'invalid_credentials',
            message: 'Invalid login credentials',
          ),
          status: 400,
        ),
      );

      await expectLater(
        repository.signInWithEmail(
          email: 'candidato1@dev.talentflash.test',
          password: 'incorrecta1',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.code,
            'code',
            AuthFailureCode.invalidCredentials,
          ),
        ),
      );
      expect(repository.currentStatus, isA<AuthStatusSignedOut>());
    });

    test('el stream publica el cambio de sesión', () async {
      final repository = buildRepository(
        (_) async => json(GoTrueFixtures.sessionJson(appRole: 'candidate')),
      );
      final emitted = <AuthStatus>[];
      final subscription = repository.statusChanges().listen(emitted.add);
      addTearDown(subscription.cancel);

      await repository.signInWithEmail(
        email: 'candidato1@dev.talentflash.test',
        password: 'password123',
      );
      await Future<void>.delayed(Duration.zero);

      expect(emitted.last, isA<AuthStatusSignedIn>());
      expect(emitted.last.role, BusinessRole.candidate);
    });
  });

  group('recuperación de contraseña', () {
    test(
      'pide el correo de restablecimiento con el correo normalizado',
      () async {
        final repository = buildRepository((_) async => json('{}'));

        await repository.sendPasswordRecoveryEmail(
          ' Candidato1@Dev.TalentFlash.Test ',
        );

        expect(requests.single.url.path, endsWith('/recover'));
        final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(body['email'], 'candidato1@dev.talentflash.test');
      },
    );

    test('el límite de envíos llega como error tipado', () async {
      final repository = buildRepository(
        (_) async => json(
          GoTrueFixtures.errorJson(
            code: 429,
            errorCode: 'over_email_send_rate_limit',
            message: 'Email rate limit exceeded',
          ),
          status: 429,
        ),
      );

      await expectLater(
        repository.sendPasswordRecoveryEmail('candidato1@dev.talentflash.test'),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.code,
            'code',
            AuthFailureCode.rateLimited,
          ),
        ),
      );
    });
  });

  group('cierre de sesión', () {
    test('deja el estado sin sesión', () async {
      final repository = buildRepository((request) async {
        if (request.url.path.endsWith('/logout')) {
          return http.Response('', 204);
        }
        return json(GoTrueFixtures.sessionJson(appRole: 'candidate'));
      });

      await repository.signInWithEmail(
        email: 'candidato1@dev.talentflash.test',
        password: 'password123',
      );
      expect(repository.currentStatus, isA<AuthStatusSignedIn>());

      await repository.signOut();

      expect(repository.currentStatus, isA<AuthStatusSignedOut>());
      expect(repository.currentStatus.user, isNull);
    });
  });

  group('nivel de la sesión (claim aal)', () {
    test('un token sin forma de JWT vale desconocido, no explota', () {
      expect(
        SupabaseAuthRepository.assuranceFromAccessToken(
          GoTrueFixtures.accessToken,
        ),
        SessionAssurance.unknown,
      );
      expect(
        SupabaseAuthRepository.assuranceFromAccessToken('a.b.c'),
        SessionAssurance.unknown,
      );
      expect(
        SupabaseAuthRepository.assuranceFromAccessToken(''),
        SessionAssurance.unknown,
      );
    });

    test('lee aal1 y aal2 exactos del payload', () {
      expect(
        SupabaseAuthRepository.assuranceFromAccessToken(
          GoTrueFixtures.accessTokenWithClaims(aal: 'aal1'),
        ),
        SessionAssurance.aal1,
      );
      expect(
        SupabaseAuthRepository.assuranceFromAccessToken(
          GoTrueFixtures.accessTokenWithClaims(aal: 'aal2'),
        ),
        SessionAssurance.aal2,
      );
    });

    test('claim ausente, caja equivocada o nivel inventado: desconocido', () {
      for (final aal in <String?>[null, 'AAL2', 'aal3', 'aal2 ']) {
        expect(
          SupabaseAuthRepository.assuranceFromAccessToken(
            GoTrueFixtures.accessTokenWithClaims(aal: aal),
          ),
          SessionAssurance.unknown,
          reason: 'para $aal',
        );
      }
    });

    test('la sesión traduce el nivel junto con el rol', () async {
      final repository = buildRepository(
        (_) async => json(
          GoTrueFixtures.sessionJson(
            appRole: 'admin',
            accessToken: GoTrueFixtures.accessTokenWithClaims(aal: 'aal1'),
          ),
        ),
      );

      await repository.signInWithEmail(
        email: 'admin@dev.talentflash.test',
        password: 'password123',
      );

      final status = repository.currentStatus;
      expect(status.role, BusinessRole.admin);
      expect(status.assurance, SessionAssurance.aal1);
      expect(status.hasSecondFactorVerified, isFalse);
    });
  });

  group('segundo factor TOTP', () {
    /// Sesión aal1 de una admin, más los endpoints de MFA con las formas
    /// reales del stack local (`npm run mfa:test`).
    Future<SupabaseAuthRepository> signedInAdmin({
      List<Map<String, dynamic>>? factors,
      http.Response Function(http.Request request)? mfa,
    }) async {
      final repository = buildRepository((request) async {
        final path = request.url.path;
        if (path.endsWith('/token')) {
          return json(
            GoTrueFixtures.sessionJson(
              appRole: 'admin',
              accessToken: GoTrueFixtures.accessTokenWithClaims(aal: 'aal1'),
              factors: factors,
            ),
          );
        }
        final custom = mfa?.call(request);
        if (custom != null) {
          return custom;
        }
        return json(
          GoTrueFixtures.errorJson(
            code: 404,
            errorCode: 'not_found',
            message: 'ruta no simulada: $path',
          ),
          status: 404,
        );
      });
      await repository.signInWithEmail(
        email: 'admin@dev.talentflash.test',
        password: 'password123',
      );
      requests.clear();
      return repository;
    }

    test('lista solo los factores TOTP verificados, tras refrescar', () async {
      final repository = await signedInAdmin(
        factors: [
          GoTrueFixtures.factor(id: 'ok', friendlyName: 'Celular'),
          GoTrueFixtures.factor(id: 'pendiente', status: 'unverified'),
          GoTrueFixtures.factor(id: 'sms', factorType: 'phone'),
          GoTrueFixtures.factor(id: 'sin-nombre', friendlyName: ''),
        ],
      );

      final factors = await repository.listVerifiedSecondFactors();

      expect(
        requests.single.url.queryParameters['grant_type'],
        'refresh_token',
        reason: 'la lista sale del servidor, no del token guardado',
      );
      expect(factors.map((f) => f.id), <String>['ok', 'sin-nombre']);
      expect(factors.first.friendlyName, 'Celular');
      expect(factors.last.friendlyName, isNull);
      expect(factors.first.createdAt, isNotNull);
    });

    test('sin factores la lista es vacía', () async {
      final repository = await signedInAdmin();
      expect(await repository.listVerifiedSecondFactors(), isEmpty);
    });

    test(
      'el alta manda tipo, emisor y nombre, y guarda solo lo necesario',
      () async {
        final repository = await signedInAdmin(
          mfa: (request) => request.url.path.endsWith('/factors')
              ? json(GoTrueFixtures.totpEnrollJson())
              : http.Response('', 404),
        );

        final enrollment = await repository.enrollTotp(
          friendlyName: 'TalentFlash · 08/09/2026 14:32',
        );

        final request = requests.single;
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/factors'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['factor_type'], 'totp');
        expect(body['issuer'], 'TalentFlash Argentina');
        expect(body['friendly_name'], 'TalentFlash · 08/09/2026 14:32');
        expect(enrollment.factorId, 'factor-1');
        expect(enrollment.secret, 'JBSWY3DPEHPK3PXP');
        expect(enrollment.uri, startsWith('otpauth://totp/'));
        expect(enrollment.toString(), isNot(contains('JBSWY3DPEHPK3PXP')));
        // Crear el factor pendiente no cambia el nivel de la sesión.
        expect(repository.currentStatus.assurance, SessionAssurance.aal1);
      },
    );

    test(
      'antes de un alta nueva descarta los factores pendientes viejos',
      () async {
        final repository = await signedInAdmin(
          factors: [
            GoTrueFixtures.factor(id: 'huerfano-1', status: 'unverified'),
            GoTrueFixtures.factor(id: 'verificado', status: 'verified'),
            GoTrueFixtures.factor(
              id: 'huerfano-2',
              status: 'unverified',
              friendlyName: null,
            ),
            GoTrueFixtures.factor(
              id: 'sms-pendiente',
              status: 'unverified',
              factorType: 'phone',
            ),
          ],
          mfa: (request) {
            if (request.method == 'DELETE') {
              return json(jsonEncode({'id': request.url.pathSegments.last}));
            }
            if (request.url.path.endsWith('/factors')) {
              return json(GoTrueFixtures.totpEnrollJson());
            }
            return http.Response('', 404);
          },
        );

        await repository.enrollTotp(friendlyName: 'x');

        final deletes = requests
            .where((r) => r.method == 'DELETE')
            .map((r) => r.url.pathSegments.last)
            .toList();
        expect(deletes, <String>['huerfano-1', 'huerfano-2']);
        expect(requests.last.method, 'POST');
        expect(requests.last.url.path, endsWith('/factors'));
      },
    );

    test(
      'si un pendiente viejo no se puede borrar, el alta sigue igual',
      () async {
        final repository = await signedInAdmin(
          factors: [
            GoTrueFixtures.factor(id: 'huerfano', status: 'unverified'),
          ],
          mfa: (request) {
            if (request.method == 'DELETE') {
              return json(
                GoTrueFixtures.errorJson(
                  code: 404,
                  errorCode: 'mfa_factor_not_found',
                  message: 'Factor not found',
                ),
                status: 404,
              );
            }
            return json(GoTrueFixtures.totpEnrollJson());
          },
        );

        final enrollment = await repository.enrollTotp(friendlyName: 'x');

        expect(enrollment.factorId, 'factor-1');
      },
    );

    test(
      'con un factor verificado y aal1 el servidor rechaza otra alta',
      () async {
        final repository = await signedInAdmin(
          mfa: (_) => json(
            GoTrueFixtures.errorJson(
              code: 403,
              errorCode: 'insufficient_aal',
              message: 'AAL2 required to enroll a new factor',
            ),
            status: 403,
          ),
        );

        await expectLater(
          repository.enrollTotp(friendlyName: 'x'),
          throwsA(
            isA<AuthFailure>().having(
              (f) => f.code,
              'code',
              AuthFailureCode.mfaInsufficientAssurance,
            ),
          ),
        );
      },
    );

    test('el desafío devuelve id y vencimiento', () async {
      final expiresAt = DateTime.utc(2026, 9, 8, 17, 40);
      final repository = await signedInAdmin(
        mfa: (request) => request.url.path.endsWith('/challenge')
            ? json(GoTrueFixtures.challengeJson(expiresAt: expiresAt))
            : http.Response('', 404),
      );

      final challenge = await repository.challengeSecondFactor('factor-1');

      expect(requests.single.url.path, endsWith('/factors/factor-1/challenge'));
      expect(challenge.id, 'challenge-1');
      expect(challenge.factorId, 'factor-1');
      expect(challenge.expiresAt.toUtc(), expiresAt);
    });

    test(
      'verificar sube la sesión a aal2 con el MISMO usuario y lo publica por '
      'el stream',
      () async {
        final repository = await signedInAdmin(
          mfa: (request) {
            if (!request.url.path.endsWith('/verify')) {
              return http.Response('', 404);
            }
            return json(
              GoTrueFixtures.sessionJson(
                appRole: 'admin',
                accessToken: GoTrueFixtures.accessTokenWithClaims(
                  aal: 'aal2',
                  amr: [
                    {'method': 'totp', 'timestamp': 1757353920},
                    {'method': 'password', 'timestamp': 1757353800},
                  ],
                ),
                factors: [GoTrueFixtures.factor()],
              ),
            );
          },
        );
        final before = repository.currentStatus;
        final emitted = <AuthStatus>[];
        final subscription = repository.statusChanges().listen(emitted.add);
        addTearDown(subscription.cancel);

        await repository.verifySecondFactor(
          factorId: 'factor-1',
          challengeId: 'challenge-1',
          code: '123456',
        );
        await Future<void>.delayed(Duration.zero);

        final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(requests.single.url.path, endsWith('/factors/factor-1/verify'));
        expect(body['challenge_id'], 'challenge-1');
        expect(body['code'], '123456');

        final after = repository.currentStatus;
        expect(after.assurance, SessionAssurance.aal2);
        expect(after.hasSecondFactorVerified, isTrue);
        expect(after.user, before.user, reason: 'misma identidad');
        expect(after.role, BusinessRole.admin);
        expect(before.assurance, SessionAssurance.aal1);
        expect(before == after, isFalse, reason: 'el estado SÍ cambió');
        expect(
          emitted.last,
          isA<AuthStatusSignedIn>().having(
            (s) => s.assurance,
            'assurance',
            SessionAssurance.aal2,
          ),
        );
      },
    );

    test(
      'un código incorrecto llega tipado y la sesión sigue en aal1',
      () async {
        final repository = await signedInAdmin(
          mfa: (_) => json(
            GoTrueFixtures.errorJson(
              code: 422,
              errorCode: 'mfa_verification_failed',
              message: 'Invalid TOTP code entered',
            ),
            status: 422,
          ),
        );

        await expectLater(
          repository.verifySecondFactor(
            factorId: 'factor-1',
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
        expect(repository.currentStatus.assurance, SessionAssurance.aal1);
      },
    );

    test('un desafío vencido llega tipado', () async {
      final repository = await signedInAdmin(
        mfa: (_) => json(
          GoTrueFixtures.errorJson(
            code: 422,
            errorCode: 'mfa_challenge_expired',
            message: 'MFA challenge has expired',
          ),
          status: 422,
        ),
      );

      await expectLater(
        repository.verifySecondFactor(
          factorId: 'factor-1',
          challengeId: 'challenge-1',
          code: '123456',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthFailureCode.mfaChallengeExpired,
          ),
        ),
      );
    });

    test('descartar un factor pendiente pega DELETE al factor', () async {
      final repository = await signedInAdmin(
        mfa: (request) => request.method == 'DELETE'
            ? json(jsonEncode({'id': 'factor-1'}))
            : http.Response('', 404),
      );

      await repository.discardPendingSecondFactor('factor-1');

      expect(requests.single.method, 'DELETE');
      expect(requests.single.url.path, endsWith('/factors/factor-1'));
    });

    test('descartar un factor que ya no existe no es un error', () async {
      final repository = await signedInAdmin(
        mfa: (_) => json(
          GoTrueFixtures.errorJson(
            code: 404,
            errorCode: 'mfa_factor_not_found',
            message: 'Factor not found',
          ),
          status: 404,
        ),
      );

      await expectLater(
        repository.discardPendingSecondFactor('factor-1'),
        completes,
      );
    });

    test('otros fallos al descartar sí se propagan tipados', () async {
      final repository = await signedInAdmin(
        mfa: (_) => json(
          GoTrueFixtures.errorJson(
            code: 403,
            errorCode: 'insufficient_aal',
            message: 'AAL2 required to unenroll a verified factor',
          ),
          status: 403,
        ),
      );

      await expectLater(
        repository.discardPendingSecondFactor('factor-1'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthFailureCode.mfaInsufficientAssurance,
          ),
        ),
      );
    });
  });
}
