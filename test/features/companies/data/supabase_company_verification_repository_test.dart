import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentflash_argentina/features/companies/data/company_access_repository.dart';
import 'package:talentflash_argentina/features/companies/data/supabase_company_verification_repository.dart';
import 'package:talentflash_argentina/features/companies/domain/company_verification.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

import '../../../support/gotrue_fixtures.dart';

/// El repositorio de verificación contra un cliente HTTP falso con las formas
/// reales de PostgREST y Storage: ningún test toca un proyecto Supabase.
///
/// El nivel AAL de la sesión ya no se lee desde este repositorio: es parte del
/// estado de sesión y se prueba en `supabase_auth_repository_test.dart`.
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

  Map<String, dynamic> filaPropia() => <String, dynamic>{
    'company_id': 'c-1',
    'company_status': 'pending',
    'request_id': 'req-1',
    'request_status': 'pending',
    'cuit_submitted': '30-70000001-6',
    'document_path': 'c-1/constancia-arca.pdf',
    'rejection_reason': null,
    'submitted_at': '2026-09-01T10:00:00Z',
    'reviewed_at': null,
  };

  group('fetchMyVerification', () {
    test('pega al RPC y toma la primera fila de la tabla devuelta', () async {
      final client = await makeClient(
        (request) async => http.Response(
          jsonEncode(<dynamic>[filaPropia()]),
          200,
          headers: jsonHeaders,
        ),
      );

      final verification = await SupabaseCompanyVerificationRepository(client)
          .fetchMyVerification();

      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/rest/v1/rpc/my_company_verification');
      expect(verification.companyId, 'c-1');
      expect(verification.companyStatus, CompanyVerificationStatus.pending);
    });

    test(
      'una respuesta sin filas es un fallo tipado, no un null silencioso',
      () async {
        final client = await makeClient(
          (request) async =>
              http.Response(jsonEncode(<dynamic>[]), 200, headers: jsonHeaders),
        );

        await expectLater(
          SupabaseCompanyVerificationRepository(client).fetchMyVerification(),
          throwsA(
            isA<DataFailure>().having(
              (f) => f.code,
              'code',
              DataFailureCode.notAllowed,
            ),
          ),
        );
      },
    );

    test(
      '42501 se traduce a notAllowed y no filtra el detalle de Postgres',
      () async {
        final client = await makeClient((request) async => pgError('42501'));

        await expectLater(
          SupabaseCompanyVerificationRepository(client).fetchMyVerification(),
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
      },
    );
  });

  group('requestVerification', () {
    test('manda el CUIT y la extensión, nunca un path', () async {
      final client = await makeClient(
        (request) async =>
            http.Response(jsonEncode('req-9'), 200, headers: jsonHeaders),
      );

      final id = await SupabaseCompanyVerificationRepository(client)
          .requestVerification(
            cuit: '30-70000001-6',
            format: ConstanciaFormat.jpg,
          );

      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(id, 'req-9');
      expect(
        requests.single.url.path,
        '/rest/v1/rpc/request_company_verification',
      );
      expect(body['p_cuit'], '30-70000001-6');
      expect(body['p_document_extension'], 'jpg');
      expect(
        body.keys,
        isNot(contains('p_company_id')),
        reason: 'la empresa la resuelve el servidor desde auth.uid()',
      );
      expect(body.values.whereType<String>(), isNot(contains(contains('/'))));
    });

    test('sin constancia manda la extensión en null', () async {
      final client = await makeClient(
        (request) async =>
            http.Response(jsonEncode('req-9'), 200, headers: jsonHeaders),
      );

      await SupabaseCompanyVerificationRepository(client)
          .requestVerification(cuit: '30-70000001-6');

      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['p_document_extension'], isNull);
    });

    test('TFCUI llega como invalidCuit, no como error genérico', () async {
      final client = await makeClient((request) async => pgError('TFCUI'));

      await expectLater(
        SupabaseCompanyVerificationRepository(client)
            .requestVerification(cuit: '30-70000001-7'),
        throwsA(
          isA<DataFailure>().having(
            (f) => f.code,
            'code',
            DataFailureCode.invalidCuit,
          ),
        ),
      );
    });
  });

  group('uploadConstancia', () {
    test('pide el path al servidor y sube ahí, sin construirlo', () async {
      final client = await makeClient((request) async {
        if (request.url.path.contains('company_document_upload_path')) {
          return http.Response(
            jsonEncode('c-1/constancia-arca.pdf'),
            200,
            headers: jsonHeaders,
          );
        }
        return http.Response(
          jsonEncode({'Key': 'company-docs/c-1/constancia-arca.pdf'}),
          200,
          headers: jsonHeaders,
        );
      });

      final path = await SupabaseCompanyVerificationRepository(client)
          .uploadConstancia(
            PickedConstancia(
              bytes: Uint8List.fromList(<int>[1, 2, 3]),
              fileName: 'mi constancia.PDF',
            ),
          );

      expect(path, 'c-1/constancia-arca.pdf');
      final pedido = jsonDecode(requests.first.body) as Map<String, dynamic>;
      expect(pedido['p_extension'], 'pdf');
      expect(
        requests.last.url.path,
        contains('/storage/v1/object/company-docs/c-1/constancia-arca.pdf'),
        reason: 'sube exactamente al path que devolvió el servidor',
      );
    });

    test('una extensión no admitida se corta antes de pedir nada', () async {
      final client = await makeClient(
        (request) async => http.Response('{}', 200, headers: jsonHeaders),
      );

      await expectLater(
        SupabaseCompanyVerificationRepository(client).uploadConstancia(
          PickedConstancia(
            bytes: Uint8List.fromList(<int>[1]),
            fileName: 'virus.exe',
          ),
        ),
        throwsA(
          isA<DataFailure>().having(
            (f) => f.code,
            'code',
            DataFailureCode.invalidData,
          ),
        ),
      );
      expect(requests, isEmpty, reason: 'no debería haber salido a la red');
    });

    test('un archivo más grande que el límite no se sube', () async {
      final client = await makeClient(
        (request) async => http.Response('{}', 200, headers: jsonHeaders),
      );

      await expectLater(
        SupabaseCompanyVerificationRepository(client).uploadConstancia(
          PickedConstancia(
            bytes: Uint8List(constanciaMaxBytes + 1),
            fileName: 'grande.pdf',
          ),
        ),
        throwsA(isA<DataFailure>()),
      );
      expect(requests, isEmpty);
    });

    test('un 403 de la policy del bucket se traduce a notAllowed', () async {
      final client = await makeClient((request) async {
        if (request.url.path.contains('company_document_upload_path')) {
          return http.Response(
            jsonEncode('c-1/constancia-arca.pdf'),
            200,
            headers: jsonHeaders,
          );
        }
        return http.Response(
          jsonEncode({
            'statusCode': '403',
            'error': 'Unauthorized',
            'message': 'x',
          }),
          403,
          headers: jsonHeaders,
        );
      });

      await expectLater(
        SupabaseCompanyVerificationRepository(client).uploadConstancia(
          PickedConstancia(
            bytes: Uint8List.fromList(<int>[1]),
            fileName: 'c.pdf',
          ),
        ),
        throwsA(
          isA<DataFailure>().having(
            (f) => f.code,
            'code',
            DataFailureCode.notAllowed,
          ),
        ),
      );
    });
  });

  group('createConstanciaSignedUrl', () {
    test('pide una URL firmada de vida corta', () async {
      final client = await makeClient(
        (request) async => http.Response(
          jsonEncode({
            'signedURL': '/object/sign/company-docs/c-1/x.pdf?token=t',
          }),
          200,
          headers: jsonHeaders,
        ),
      );

      final url = await SupabaseCompanyVerificationRepository(client)
          .createConstanciaSignedUrl('c-1/constancia-arca.pdf');

      expect(url, contains('token='));
      expect(
        requests.single.url.path,
        contains('/storage/v1/object/sign/company-docs/'),
      );
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['expiresIn'], 300);
    });
  });

  group('cola administrativa', () {
    test('fetchVerificationQueue manda el estado y parsea la lista', () async {
      final client = await makeClient(
        (request) async => http.Response(
          jsonEncode(<dynamic>[
            <String, dynamic>{
              'request_id': 'req-1',
              'company_id': 'c-1',
              'company_name': 'Parrilla Dev',
              'company_status': 'pending',
              'request_status': 'pending',
              'cuit_submitted': '30-70000001-6',
              'document_path': 'c-1/constancia-arca.pdf',
              'rejection_reason': null,
              'submitted_at': '2026-09-01T10:00:00Z',
              'reviewed_at': null,
            },
          ]),
          200,
          headers: jsonHeaders,
        ),
      );

      final cola = await SupabaseCompanyVerificationRepository(client)
          .fetchVerificationQueue(CompanyVerificationStatus.pending);

      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['p_status'], 'pending');
      expect(cola.single.companyName, 'Parrilla Dev');
    });

    test(
      'TFMFA llega como secondFactorRequired, distinto de notAllowed',
      () async {
        final client = await makeClient((request) async => pgError('TFMFA'));

        await expectLater(
          SupabaseCompanyVerificationRepository(client)
              .fetchVerificationQueue(CompanyVerificationStatus.pending),
          throwsA(
            isA<DataFailure>().having(
              (f) => f.code,
              'code',
              DataFailureCode.secondFactorRequired,
            ),
          ),
        );
      },
    );

    test('aprobar manda decisión approved y motivo null', () async {
      final client = await makeClient(
        (request) async =>
            http.Response(jsonEncode('approved'), 200, headers: jsonHeaders),
      );

      await SupabaseCompanyVerificationRepository(client)
          .reviewVerification(requestId: 'req-1', approve: true);

      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['p_decision'], 'approved');
      expect(body['p_reason'], isNull);
    });

    test('rechazar manda el motivo de la lista cerrada', () async {
      final client = await makeClient(
        (request) async =>
            http.Response(jsonEncode('rejected'), 200, headers: jsonHeaders),
      );

      await SupabaseCompanyVerificationRepository(client).reviewVerification(
        requestId: 'req-1',
        approve: false,
        reason: VerificationRejectionReason.constanciaIlegible,
      );

      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['p_decision'], 'rejected');
      expect(body['p_reason'], 'constancia_ilegible');
    });

    test('aprobar nunca arrastra un motivo aunque se lo pasen', () async {
      final client = await makeClient(
        (request) async =>
            http.Response(jsonEncode('approved'), 200, headers: jsonHeaders),
      );

      await SupabaseCompanyVerificationRepository(client).reviewVerification(
        requestId: 'req-1',
        approve: true,
        reason: VerificationRejectionReason.otro,
      );

      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['p_reason'], isNull);
    });
  });
}
