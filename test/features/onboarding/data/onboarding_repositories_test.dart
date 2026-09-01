import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentflash_argentina/features/consents/data/supabase_consents_repository.dart';
import 'package:talentflash_argentina/features/consents/domain/consent_type.dart';
import 'package:talentflash_argentina/features/legal/data/supabase_legal_repository.dart';
import 'package:talentflash_argentina/features/legal/domain/legal_document.dart';
import 'package:talentflash_argentina/features/notifications/data/supabase_notification_prefs_repository.dart';
import 'package:talentflash_argentina/features/notifications/domain/notification_prefs.dart';
import 'package:talentflash_argentina/features/onboarding/data/supabase_onboarding_repository.dart';
import 'package:talentflash_argentina/features/onboarding/domain/candidate_onboarding_data.dart';
import 'package:talentflash_argentina/features/onboarding/domain/company_onboarding_data.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

import '../../../support/gotrue_fixtures.dart';

/// Los repositorios del Bloque C contra un cliente HTTP falso con las formas
/// reales de PostgREST: ningún test toca un proyecto Supabase.
void main() {
  const jsonHeaders = {'content-type': 'application/json'};
  late List<http.Request> restRequests;

  Future<SupabaseClient> makeClient(
    Future<http.Response> Function(http.Request request) restHandler,
  ) async {
    restRequests = [];
    final client = SupabaseClient(
      'http://127.0.0.1:54321',
      'sb_publishable_de_prueba',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/auth/v1/token')) {
          return http.Response(
            GoTrueFixtures.sessionJson(),
            200,
            headers: jsonHeaders,
          );
        }
        restRequests.add(request);
        final response = await restHandler(request);
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
    await client.auth.signInWithPassword(
      email: 'persona@dev.talentflash.test',
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

  group('SupabaseOnboardingRepository', () {
    test('el guardado llama a la RPC con la instantánea completa', () async {
      final client = await makeClient(
        (request) async => http.Response('', 204),
      );
      final repository = SupabaseOnboardingRepository(client);

      await repository.saveCandidateData(
        CandidateOnboardingData(
          fullName: 'Ana Pérez',
          birthDate: DateTime(1995, 4, 10),
          provinceId: 'prov-1',
          localityId: 'loc-1',
          sectorId: 'sector-1',
          availability: CandidateAvailability.en1Semana,
          workModes: const {
            CandidateWorkMode.presencial,
            CandidateWorkMode.hibrido,
          },
        ),
      );

      final request = restRequests.single;
      expect(request.url.path, '/rest/v1/rpc/save_candidate_onboarding');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['p_full_name'], 'Ana Pérez');
      expect(body['p_birth_date'], '1995-04-10');
      expect(body['p_barrio_id'], isNull);
      expect(body['p_availability'], 'en_1_semana');
      expect(body['p_work_modes'], ['presencial', 'hibrido']);
    });

    test(
      'la finalización de empresa normaliza el CUIT y devuelve el id',
      () async {
        final client = await makeClient(
          (request) async => http.Response(
            '"c0000000-0000-4000-8000-000000000099"',
            200,
            headers: jsonHeaders,
          ),
        );
        final repository = SupabaseOnboardingRepository(client);

        final companyId = await repository.completeCompanyOnboarding(
          const CompanyOnboardingData(
            legalName: 'Gastro SA',
            tradeName: 'La Fantasía',
            cuit: '30 71234567 8',
            sectorId: 'sector-1',
            sizeRange: CompanySizeRange.from11To50,
            provinceId: 'prov-1',
            localityId: 'loc-1',
            website: 'lafantasia.com.ar',
            applicantFullName: 'Dueña Prueba',
            applicantPosition: 'Dueña',
            applicantRelationship: CompanyRelationship.owner,
          ),
        );

        expect(companyId, 'c0000000-0000-4000-8000-000000000099');
        final body =
            jsonDecode(restRequests.single.body) as Map<String, dynamic>;
        expect(body['p_cuit'], '30-71234567-8');
        expect(body['p_size_range'], '11-50');
        expect(body['p_website'], 'https://lafantasia.com.ar');
        expect(body['p_applicant_relationship'], 'owner');
      },
    );

    test('la minoría de edad server-side llega como fallo tipado', () async {
      final client = await makeClient((request) async => pgError('TF018'));
      final repository = SupabaseOnboardingRepository(client);

      await expectLater(
        repository.completeCandidateOnboarding(),
        throwsA(
          isA<DataFailure>().having(
            (f) => f.code,
            'code',
            DataFailureCode.underage,
          ),
        ),
      );
    });
  });

  group('SupabaseConsentsRepository', () {
    test(
      'otorgar inserta la fila con versión y canal, sin tocar nada más',
      () async {
        final client = await makeClient(
          (request) async => http.Response('', 201),
        );
        final repository = SupabaseConsentsRepository(client);

        await repository.grant(
          ConsentType.dataProcessing,
          version: '2026-08-31',
        );

        final request = restRequests.single;
        expect(request.method, 'POST');
        expect(request.url.path, '/rest/v1/consents');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['profile_id'], GoTrueFixtures.userId);
        expect(body['consent_type'], 'data_processing');
        expect(body['granted'], isTrue);
        expect(body['version'], '2026-08-31');
        expect(body['user_agent'], startsWith('app_'));
      },
    );

    test('la instantánea junta versiones vigentes y última decisión', () async {
      final client = await makeClient((request) async {
        if (request.url.path.endsWith('/consent_versions')) {
          return http.Response(
            jsonEncode([
              {
                'consent_type': 'data_processing',
                'version': '2026-08-31',
                'document_slug': 'privacidad',
                'is_mandatory': true,
              },
              {
                'consent_type': 'video_profile_publication',
                'version': '2026-08-31',
                'document_slug': 'privacidad',
                'is_mandatory': false,
              },
            ]),
            200,
            headers: jsonHeaders,
          );
        }
        return http.Response(
          jsonEncode([
            // seq desc: lo último que pasó es la revocación.
            {
              'consent_type': 'video_profile_publication',
              'granted': false,
              'version': '2026-08-31',
              'seq': 9,
            },
            {
              'consent_type': 'video_profile_publication',
              'granted': true,
              'version': '2026-08-31',
              'seq': 5,
            },
            {
              'consent_type': 'data_processing',
              'granted': true,
              'version': '2026-08-31',
              'seq': 4,
            },
          ]),
          200,
          headers: jsonHeaders,
        );
      });
      final repository = SupabaseConsentsRepository(client);

      final snapshot = await repository.loadSnapshot();

      expect(snapshot.isCurrentlyGranted(ConsentType.dataProcessing), isTrue);
      expect(
        snapshot.isCurrentlyGranted(ConsentType.videoProfilePublication),
        isFalse,
        reason: 'la última fila (revocación) es la que vale',
      );
      expect(snapshot.pendingMandatory, isEmpty);
    });

    test('una versión pisada llega como fallo de consentimiento', () async {
      final client = await makeClient((request) async => pgError('TFCNS'));
      final repository = SupabaseConsentsRepository(client);

      await expectLater(
        repository.grant(ConsentType.dataProcessing, version: 'vieja'),
        throwsA(
          isA<DataFailure>().having(
            (f) => f.code,
            'code',
            DataFailureCode.staleConsent,
          ),
        ),
      );
    });
  });

  group('SupabaseNotificationPrefsRepository', () {
    test('guardar es un upsert por (profile_id, category)', () async {
      final client = await makeClient(
        (request) async => http.Response('', 201),
      );
      final repository = SupabaseNotificationPrefsRepository(client);

      await repository.save(const [
        NotificationChannelPrefs(
          category: NotificationCategory.message,
          pushEnabled: true,
        ),
        NotificationChannelPrefs(
          category: NotificationCategory.system,
          emailEnabled: true,
        ),
      ]);

      final request = restRequests.single;
      expect(request.url.path, '/rest/v1/notification_prefs');
      expect(request.url.queryParameters['on_conflict'], 'profile_id,category');
      expect(request.headers['Prefer'], contains('resolution=merge'));
      final rows = jsonDecode(request.body) as List<dynamic>;
      expect(rows, hasLength(2));
      expect(
        (rows.first as Map<String, dynamic>)['profile_id'],
        GoTrueFixtures.userId,
      );
      expect((rows.first as Map<String, dynamic>)['push_enabled'], isTrue);
      expect((rows.first as Map<String, dynamic>)['email_enabled'], isFalse);
    });
  });

  group('SupabaseLegalRepository', () {
    test('trae la versión vigente del documento pedido', () async {
      final client = await makeClient(
        (request) async => http.Response(
          jsonEncode({
            'slug': 'terminos',
            'version': '2026-08-31',
            'title': 'Términos y condiciones de TalentFlash',
            'body': 'AVISO\n\nCuerpo.',
          }),
          200,
          headers: jsonHeaders,
        ),
      );
      final repository = SupabaseLegalRepository(client);

      final document = await repository.fetchCurrent(LegalSlug.terms);

      expect(document.version, '2026-08-31');
      expect(document.paragraphs, ['AVISO', 'Cuerpo.']);
      final request = restRequests.single;
      expect(request.url.path, '/rest/v1/legal_documents');
      expect(request.url.queryParameters['slug'], 'eq.terminos');
      expect(request.url.queryParameters['order'], contains('published_at'));
    });
  });
}
