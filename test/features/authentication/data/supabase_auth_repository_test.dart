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
}
