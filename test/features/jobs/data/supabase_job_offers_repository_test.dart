import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentflash_argentina/features/companies/data/company_access_repository.dart';
import 'package:talentflash_argentina/features/jobs/data/supabase_job_offers_repository.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_feed_page.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_enums.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

import '../../../support/fake_job_offers_repository.dart';
import '../../../support/gotrue_fixtures.dart';

/// El repositorio de ofertas contra un cliente HTTP falso con las formas
/// reales de PostgREST: ningún test toca un proyecto Supabase.
void main() {
  const jsonHeaders = {'content-type': 'application/json'};
  const companyId = 'c0000000-0000-4000-8000-000000000001';
  final jobId = testJobId(7);
  final reloj = DateTime.utc(2026, 10, 10, 12);
  late List<http.Request> requests;

  Future<SupabaseClient> makeClient(
    Future<http.Response> Function(http.Request request) handler, {
    bool signIn = true,
  }) async {
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
        // PostgREST lee `response.request!`: la respuesta del mock tiene que
        // llevar el request adjunto o el parseo revienta.
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
    if (signIn) {
      await client.auth.signInWithPassword(
        email: 'empresa@dev.talentflash.test',
        password: 'password123',
      );
    }
    return client;
  }

  SupabaseJobOffersRepository repo(SupabaseClient client) =>
      SupabaseJobOffersRepository(client, clock: () => reloj);

  http.Response pgError(String code, {int status = 400}) => http.Response(
    jsonEncode({
      'code': code,
      'message': 'detalle interno que jamás se muestra',
      'details': null,
      'hint': null,
    }),
    status,
    headers: jsonHeaders,
  );

  Map<String, dynamic> fila({
    String? id,
    String status = 'draft',
    String? publishedAt,
    Map<String, dynamic>? company,
  }) => <String, dynamic>{
    'id': id ?? jobId,
    'company_id': companyId,
    'title': 'Mozo/a para salón',
    'description': 'Atención de mesas.',
    'sector_id': null,
    'salary_min': 900000,
    'salary_max': 1100000,
    'salary_currency': 'ARS',
    'salary_period': 'mensual',
    'contract_type': 'relacion_dependencia',
    'jornada': 'part_time',
    'schedule_days': <dynamic>['jue', 'vie'],
    'schedule_detail': '19 a 1 hs',
    'work_mode': 'presencial',
    'provincia_id': 'prov-1',
    'localidad_id': 'loc-1',
    'barrio_id': 'barrio-1',
    'experience': 'hasta_1_anio',
    'availability': 'inmediata',
    'benefits': <dynamic>['Propinas'],
    'expires_at': '2026-11-09T12:00:00+00:00',
    'vacancies': 1,
    'status': status,
    'published_at': publishedAt,
    'closed_at': null,
    'created_at': '2026-10-01T09:00:00+00:00',
    'updated_at': '2026-10-01T09:00:00+00:00',
    'company': ?company,
  };

  http.Response objeto(Map<String, dynamic> body) =>
      http.Response(jsonEncode(body), 200, headers: jsonHeaders);

  http.Response lista(List<Map<String, dynamic>> rows) =>
      http.Response(jsonEncode(rows), 200, headers: jsonHeaders);

  Matcher fallo(DataFailureCode code) => throwsA(
    isA<DataFailure>()
        .having((f) => f.code, 'code', code)
        .having(
          (f) => f.debugDetail,
          'debugDetail',
          isNot(contains('detalle interno')),
        ),
  );

  const protegidas = {
    'id',
    'published_at',
    'closed_at',
    'deleted_at',
    'created_at',
    'updated_at',
    'video_id',
  };

  group('fetchCompanyJobs', () {
    test('filtra por empresa y descarta las borradas, de la más nueva a la '
        'más vieja', () async {
      final client = await makeClient((request) async => lista([fila()]));

      final jobs = await repo(client).fetchCompanyJobs(companyId);

      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, '/rest/v1/jobs');
      final query = request.url.queryParameters;
      expect(query['company_id'], 'eq.$companyId');
      expect(query['deleted_at'], 'is.null');
      expect(query['order'], 'created_at.desc.nullslast,id.desc.nullslast');
      expect(jobs.single.id, jobId);
      expect(jobs.single.status, JobStatus.draft);
    });

    test('no pide created_by, video_id ni deleted_at', () async {
      final client = await makeClient((request) async => lista([]));

      await repo(client).fetchCompanyJobs(companyId);

      final columnas = requests.single.url.queryParameters['select']!.split(
        ',',
      );
      expect(columnas, contains('status'));
      expect(columnas, contains('published_at'));
      expect(
        columnas,
        isNot(anyOf(contains('created_by'), contains('video_id'))),
      );
      expect(columnas, isNot(contains('deleted_at')));
    });

    test('42501 llega como notAllowed sin filtrar el detalle', () async {
      final client = await makeClient(
        (request) async => pgError('42501', status: 403),
      );

      await expectLater(
        repo(client).fetchCompanyJobs(companyId),
        fallo(DataFailureCode.notAllowed),
      );
    });
  });

  group('fetchJob', () {
    test('embebe la empresa y excluye las descartadas', () async {
      final client = await makeClient(
        (request) async => lista([
          fila(
            status: 'active',
            publishedAt: '2026-10-01T12:00:00+00:00',
            company: <String, dynamic>{
              'name': 'Parrilla de Prueba',
              'verification_status': 'approved',
            },
          ),
        ]),
      );

      final job = await repo(client).fetchJob(jobId);

      final query = requests.single.url.queryParameters;
      expect(query['id'], 'eq.$jobId');
      expect(query['deleted_at'], 'is.null');
      expect(
        query['select'],
        endsWith('company:company_profiles(name,verification_status)'),
      );
      expect(job?.company?.name, 'Parrilla de Prueba');
      expect(
        job?.company?.verificationStatus,
        CompanyVerificationStatus.approved,
      );
    });

    test('sin filas devuelve null, igual que si no existiera', () async {
      final client = await makeClient((request) async => lista([]));

      expect(await repo(client).fetchJob(jobId), isNull);
    });

    test('un id malformado ni siquiera sale a la red', () async {
      final client = await makeClient((request) async => lista([]));

      expect(await repo(client).fetchJob('1 or 1=1'), isNull);
      expect(requests, isEmpty);
    });
  });

  group('createJob', () {
    test(
      'inserta como borrador con la empresa y el autor de la sesión',
      () async {
        final client = await makeClient((request) async => objeto(fila()));

        final job = await repo(client)
            .createJob(companyId, testJobOfferInput(), publish: false);

        final request = requests.single;
        expect(request.method, 'POST');
        expect(request.url.path, '/rest/v1/jobs');
        expect(request.headers['Prefer'], contains('return=representation'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['company_id'], companyId);
        expect(body['created_by'], GoTrueFixtures.userId);
        expect(body['status'], 'draft');
        expect(body['salary_currency'], 'ARS');
        expect(body.keys.toSet().intersection(protegidas), isEmpty);
        expect(job.id, jobId);
      },
    );

    test('publicar inserta directo como active, sin published_at', () async {
      final client = await makeClient(
        (request) async => objeto(
          fila(status: 'active', publishedAt: '2026-10-10T12:00:00+00:00'),
        ),
      );

      final job = await repo(client)
          .createJob(companyId, testJobOfferInput(), publish: true);

      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['status'], 'active');
      expect(
        body.keys,
        isNot(contains('published_at')),
        reason: 'published_at lo deriva el servidor (0032)',
      );
      expect(job.publishedAt, DateTime.utc(2026, 10, 10, 12));
    });

    test('sin sesión no sale a la red', () async {
      final client = await makeClient(
        (request) async => objeto(fila()),
        signIn: false,
      );

      await expectLater(
        repo(client).createJob(companyId, testJobOfferInput(), publish: false),
        fallo(DataFailureCode.notAllowed),
      );
      expect(requests, isEmpty);
    });

    test(
      'la policy que rechaza publicar sin verificación es notAllowed',
      () async {
        final client = await makeClient(
          (request) async => pgError('42501', status: 403),
        );

        await expectLater(
          repo(client).createJob(companyId, testJobOfferInput(), publish: true),
          fallo(DataFailureCode.notAllowed),
        );
      },
    );

    test(
      'TFDAT (regla de contenido o de publicación) es invalidData',
      () async {
        final client = await makeClient((request) async => pgError('TFDAT'));

        await expectLater(
          repo(client).createJob(companyId, testJobOfferInput(), publish: true),
          fallo(DataFailureCode.invalidData),
        );
      },
    );

    test('23502 (columna NOT NULL vacía) es invalidData', () async {
      final client = await makeClient((request) async => pgError('23502'));

      await expectLater(
        repo(client).createJob(companyId, testJobOfferInput(), publish: false),
        fallo(DataFailureCode.invalidData),
      );
    });
  });

  group('updateJob', () {
    test('reescribe el contenido de esa oferta sin tocar el estado', () async {
      final client = await makeClient((request) async => objeto(fila()));

      await repo(client).updateJob(jobId, testJobOfferInput());

      final request = requests.single;
      expect(request.method, 'PATCH');
      expect(request.url.path, '/rest/v1/jobs');
      expect(request.url.queryParameters['id'], 'eq.$jobId');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['title'], 'Mozo/a para salón');
      expect(body.keys, isNot(contains('status')));
      expect(body.keys, isNot(contains('company_id')));
      expect(body.keys, isNot(contains('created_by')));
      expect(body.keys.toSet().intersection(protegidas), isEmpty);
    });

    test(
      'publicar un borrador va en la MISMA escritura que los cambios',
      () async {
        final client = await makeClient(
          (request) async => objeto(fila(status: 'active')),
        );

        await repo(client).updateJob(jobId, testJobOfferInput(), publish: true);

        final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(requests, hasLength(1));
        expect(body['status'], 'active');
        expect(body['title'], 'Mozo/a para salón');
        expect(body.keys.toSet().intersection(protegidas), isEmpty);
      },
    );

    test('sin filas devueltas (RLS o inexistente) es notAllowed, no '
        'unknown', () async {
      final client = await makeClient(
        (request) async => http.Response(
          jsonEncode({
            'code': 'PGRST116',
            'details': 'The result contains 0 rows',
            'hint': null,
            'message': 'JSON object requested, multiple (or no) rows returned',
          }),
          406,
          headers: jsonHeaders,
        ),
      );

      await expectLater(
        repo(client).updateJob(jobId, testJobOfferInput()),
        throwsA(
          isA<DataFailure>()
              .having((f) => f.code, 'code', DataFailureCode.notAllowed)
              .having(
                (f) => f.debugDetail,
                'debugDetail',
                isNot(contains('JSON object requested')),
              ),
        ),
      );
    });

    test('TFJOB llega como jobStateConflict', () async {
      final client = await makeClient((request) async => pgError('TFJOB'));

      await expectLater(
        repo(client).updateJob(jobId, testJobOfferInput()),
        fallo(DataFailureCode.jobStateConflict),
      );
    });
  });

  group('changeStatus', () {
    test('manda SOLO el estado nuevo', () async {
      final client = await makeClient(
        (request) async => objeto(fila(status: 'paused')),
      );

      final job = await repo(client).changeStatus(jobId, JobStatus.paused);

      final request = requests.single;
      expect(request.method, 'PATCH');
      expect(request.url.queryParameters['id'], 'eq.$jobId');
      expect(jsonDecode(request.body), {'status': 'paused'});
      expect(job.status, JobStatus.paused);
    });

    test('una transición prohibida (TFJOB) es jobStateConflict', () async {
      final client = await makeClient((request) async => pgError('TFJOB'));

      await expectLater(
        repo(client).changeStatus(jobId, JobStatus.active),
        fallo(DataFailureCode.jobStateConflict),
      );
    });

    test(
      'la oferta de otra empresa no se toca: sin filas es notAllowed',
      () async {
        final client = await makeClient(
          (request) async => http.Response(
            jsonEncode({
              'code': 'PGRST116',
              'details': 'The result contains 0 rows',
              'hint': null,
              'message':
                  'JSON object requested, multiple (or no) rows returned',
            }),
            406,
            headers: jsonHeaders,
          ),
        );

        await expectLater(
          repo(client).changeStatus(jobId, JobStatus.closed),
          fallo(DataFailureCode.notAllowed),
        );
      },
    );
  });

  group('discardDraft', () {
    test('llama a la RPC con p_job_id', () async {
      final client = await makeClient(
        (request) async => http.Response('', 204),
      );

      await repo(client).discardDraft(jobId);

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/rpc/discard_job_draft');
      expect(jsonDecode(request.body), {'p_job_id': jobId});
    });

    test('descartar una publicada (TFJOB) es jobStateConflict', () async {
      final client = await makeClient((request) async => pgError('TFJOB'));

      await expectLater(
        repo(client).discardDraft(jobId),
        fallo(DataFailureCode.jobStateConflict),
      );
    });

    test('ajena o de un viewer (42501) es notAllowed', () async {
      final client = await makeClient(
        (request) async => pgError('42501', status: 403),
      );

      await expectLater(
        repo(client).discardDraft(jobId),
        fallo(DataFailureCode.notAllowed),
      );
    });
  });

  group('canWriteCompanyJobs', () {
    test('llama a la RPC con p_company_id y devuelve su booleano', () async {
      final client = await makeClient(
        (request) async =>
            http.Response(jsonEncode(true), 200, headers: jsonHeaders),
      );

      expect(await repo(client).canWriteCompanyJobs(companyId), isTrue);
      final request = requests.single;
      expect(request.url.path, '/rest/v1/rpc/can_write_company_jobs');
      expect(jsonDecode(request.body), {'p_company_id': companyId});
    });

    test('cualquier cosa que no sea true es false (fail-closed)', () async {
      for (final respuesta in <Object?>[false, null, 'true', 1]) {
        final client = await makeClient(
          (request) async =>
              http.Response(jsonEncode(respuesta), 200, headers: jsonHeaders),
        );
        expect(
          await repo(client).canWriteCompanyJobs(companyId),
          isFalse,
          reason: '$respuesta',
        );
      }
    });
  });

  group('fetchCompanySummary', () {
    test('lee nombre y verificación de esa empresa en company_profiles, y '
        'nada más', () async {
      final client = await makeClient(
        (request) async => lista([
          {'name': 'Parrilla de Prueba', 'verification_status': 'approved'},
        ]),
      );

      final summary = await repo(client).fetchCompanySummary(companyId);

      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, '/rest/v1/company_profiles');
      final query = request.url.queryParameters;
      expect(query['id'], 'eq.$companyId');
      expect(query['select'], 'name,verification_status');
      expect(summary?.name, 'Parrilla de Prueba');
      expect(summary?.verificationStatus, CompanyVerificationStatus.approved);
    });

    test('sin fila visible devuelve null', () async {
      final client = await makeClient((request) async => lista([]));

      expect(await repo(client).fetchCompanySummary(companyId), isNull);
    });

    test('un estado que este cliente no conoce no se muestra como '
        'verificada', () async {
      final client = await makeClient(
        (request) async => lista([
          {'name': 'Empresa SA', 'verification_status': 'estado_futuro'},
        ]),
      );

      final summary = await repo(client).fetchCompanySummary(companyId);

      expect(summary?.name, 'Empresa SA');
      expect(summary?.verificationStatus, isNull);
    });

    test('un rechazo del servidor llega como DataFailure, sin el detalle '
        'interno (la vista previa cae al nombre provisorio)', () async {
      final client = await makeClient(
        (request) async => pgError('42501', status: 403),
      );

      await expectLater(
        repo(client).fetchCompanySummary(companyId),
        throwsA(
          isA<DataFailure>().having(
            (f) => f.debugDetail,
            'debugDetail',
            isNot(contains('detalle interno')),
          ),
        ),
      );
    });
  });

  group('fetchActiveJobsPage', () {
    List<Map<String, dynamic>> filas(int cantidad) => [
      for (var i = 0; i < cantidad; i++)
        fila(
          id: testJobId(100 + i),
          status: 'active',
          publishedAt: '2026-10-0${1 + i % 9}T12:00:00.12345${i % 10}+00:00',
          company: <String, dynamic>{
            'name': 'Empresa $i',
            'verification_status': 'approved',
          },
        ),
    ];

    test('primera página: activas, no borradas, sin vencer y en orden '
        'keyset', () async {
      final client = await makeClient((request) async => lista(filas(3)));

      final page = await repo(client).fetchActiveJobsPage();

      final request = requests.single;
      expect(request.url.path, '/rest/v1/jobs');
      final query = request.url.queryParameters;
      expect(query['status'], 'eq.active');
      expect(query['deleted_at'], 'is.null');
      expect(query['expires_at'], 'gt.2026-10-10T12:00:00.000Z');
      expect(query['published_at'], 'not.is.null');
      expect(query['order'], 'published_at.desc.nullslast,id.desc.nullslast');
      expect(query['limit'], '20');
      expect(query.containsKey('or'), isFalse);
      expect(
        query['select'],
        endsWith('company:company_profiles(name,verification_status)'),
      );
      expect(page.items, hasLength(3));
      expect(page.items.first.company?.name, 'Empresa 0');
      expect(page.isLast, isTrue, reason: 'página incompleta = última');
    });

    test('página completa: el cursor es la última fila con su fecha '
        'cruda', () async {
      final rows = filas(jobFeedPageSize);
      final client = await makeClient((request) async => lista(rows));

      final page = await repo(client).fetchActiveJobsPage();

      expect(page.items, hasLength(jobFeedPageSize));
      expect(
        page.nextCursor,
        JobFeedCursor(
          publishedAt: rows.last['published_at'] as String,
          id: rows.last['id'] as String,
        ),
        reason: 'los microsegundos tienen que sobrevivir tal cual',
      );
    });

    test('con cursor pide lo anterior en (published_at, id)', () async {
      final client = await makeClient((request) async => lista([]));
      final cursor = JobFeedCursor(
        publishedAt: '2026-10-05T12:00:00.123456+00:00',
        id: testJobId(150),
      );

      final page = await repo(client).fetchActiveJobsPage(cursor: cursor);

      expect(
        requests.single.url.queryParameters['or'],
        '(published_at.lt."2026-10-05T12:00:00.123456+00:00",'
        'and(published_at.eq."2026-10-05T12:00:00.123456+00:00",'
        'id.lt.${testJobId(150)}))',
      );
      expect(page.items, isEmpty);
      expect(page.isLast, isTrue);
    });

    test('nunca pide más de 20 ni menos de 1', () async {
      final client = await makeClient((request) async => lista([]));

      await repo(client).fetchActiveJobsPage(limit: 500);
      await repo(client).fetchActiveJobsPage(limit: 0);

      expect(requests.map((r) => r.url.queryParameters['limit']), ['20', '1']);
    });

    test('un cursor con forma rara no se interpola en el filtro', () async {
      final client = await makeClient((request) async => lista([]));

      await expectLater(
        repo(client).fetchActiveJobsPage(
          cursor: const JobFeedCursor(
            publishedAt: '2026-10-05",id.gt.(0',
            id: 'x',
          ),
        ),
        fallo(DataFailureCode.invalidData),
      );
      expect(requests, isEmpty);
    });
  });

  test('un corte de red al escribir es network', () async {
    // Una escritura: los GET los reintenta el SDK con espera y el test
    // tardaría segundos en llegar al mismo resultado.
    final client = await makeClient(
      (request) async => throw http.ClientException('sin conexión'),
    );

    await expectLater(
      repo(client).changeStatus(jobId, JobStatus.paused),
      fallo(DataFailureCode.network),
    );
  });
}
