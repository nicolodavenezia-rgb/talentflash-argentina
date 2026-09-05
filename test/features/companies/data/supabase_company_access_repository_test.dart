import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentflash_argentina/features/companies/data/company_access_repository.dart';
import 'package:talentflash_argentina/features/companies/data/supabase_company_access_repository.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

import '../../../support/gotrue_fixtures.dart';

/// Lectura del estado de verificación propio contra un cliente HTTP falso.
///
/// El caso que motiva este archivo es el de DOS membresías: la versión anterior
/// del repositorio resolvía la empresa con
/// `.eq('profile_id', uid).limit(1).maybeSingle()` y elegía una en silencio.
/// Acá se comprueba que ese camino ya no existe y que el estado partido falla
/// cerrado.
void main() {
  const jsonHeaders = {'content-type': 'application/json'};
  late List<http.Request> requests;

  Future<SupabaseClient> makeClient(
    Future<http.Response> Function(http.Request request) handler,
  ) async {
    requests = [];
    final client = SupabaseClient(
      'http://127.0.0.1:54321',
      'sb_publishable_de_prueba',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/auth/v1/token')) {
          return http.Response(
            GoTrueFixtures.sessionJson(appRole: 'company'),
            200,
            headers: jsonHeaders,
          );
        }
        requests.add(request);
        final response = await handler(request);
        return http.Response(
          response.body,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }),
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: false,
      ),
    );
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(
      email: 'empresa@dev.talentflash.test',
      password: 'password123',
    );
    return client;
  }

  http.Response pgError(String code, {int status = 403}) => http.Response(
    jsonEncode({
      'code': code,
      'message': 'detalle interno que jamás se muestra',
      'details': null,
      'hint': null,
    }),
    status,
    headers: jsonHeaders,
  );

  Map<String, dynamic> fila(String companyStatus) => <String, dynamic>{
    'company_id': 'c-1',
    'company_status': companyStatus,
    'request_id': null,
    'request_status': null,
    'cuit_submitted': null,
    'document_path': null,
    'rejection_reason': null,
    'submitted_at': null,
    'reviewed_at': null,
  };

  group('fetchOwnVerificationStatus', () {
    test('UNA empresa: devuelve su estado exacto, leído por la RPC', () async {
      final client = await makeClient(
        (request) async => http.Response(
          jsonEncode(<dynamic>[fila('approved')]),
          200,
          headers: jsonHeaders,
        ),
      );

      final status = await SupabaseCompanyAccessRepository(client)
          .fetchOwnVerificationStatus();

      // La consulta directa a `company_members` con `limit(1)` ya no existe.
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/rest/v1/rpc/my_company_verification');
      expect(status, CompanyVerificationStatus.approved);
    });

    test('CERO empresas: TFEMP se traduce a null, no a un error', () async {
      final client = await makeClient((request) async => pgError('TFEMP'));

      final status = await SupabaseCompanyAccessRepository(client)
          .fetchOwnVerificationStatus();

      expect(status, isNull);
    });

    test(
      'DOS empresas: TFMUL es un fallo tipado y NUNCA elige la primera',
      () async {
        final client = await makeClient((request) async => pgError('TFMUL'));

        await expectLater(
          SupabaseCompanyAccessRepository(client).fetchOwnVerificationStatus(),
          throwsA(
            isA<DataFailure>().having(
              (f) => f.code,
              'code',
              DataFailureCode.ambiguousCompany,
            ),
          ),
        );
      },
    );

    test('una respuesta sin filas no inventa ningún estado', () async {
      final client = await makeClient(
        (request) async =>
            http.Response(jsonEncode(<dynamic>[]), 200, headers: jsonHeaders),
      );

      expect(
        await SupabaseCompanyAccessRepository(client)
            .fetchOwnVerificationStatus(),
        isNull,
      );
    });

    test(
      'un estado desconocido no se muestra como verificado por accidente',
      () async {
        final client = await makeClient(
          (request) async => http.Response(
            jsonEncode(<dynamic>[fila('flamante_estado_nuevo')]),
            200,
            headers: jsonHeaders,
          ),
        );

        expect(
          await SupabaseCompanyAccessRepository(client)
              .fetchOwnVerificationStatus(),
          isNull,
        );
      },
    );

    test('42501 sigue siendo notAllowed y no filtra el detalle', () async {
      final client = await makeClient((request) async => pgError('42501'));

      await expectLater(
        SupabaseCompanyAccessRepository(client).fetchOwnVerificationStatus(),
        throwsA(
          isA<DataFailure>()
              .having((f) => f.code, 'code', DataFailureCode.notAllowed)
              .having(
                (f) => f.debugDetail,
                'debugDetail',
                isNot(contains('detalle interno')),
              ),
        ),
      );
    });
  });
}
