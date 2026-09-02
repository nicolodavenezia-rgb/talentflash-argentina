import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentflash_argentina/features/onboarding/domain/candidate_onboarding_data.dart';
import 'package:talentflash_argentina/features/profiles/data/supabase_profile_repository.dart';
import 'package:talentflash_argentina/features/profiles/domain/avatar.dart';
import 'package:talentflash_argentina/features/profiles/domain/candidate_profile.dart';
import 'package:talentflash_argentina/features/profiles/domain/candidate_profile_patch.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

import '../../../support/gotrue_fixtures.dart';

/// Respuesta completa estilo `get_my_candidate_profile` para el mock.
Map<String, dynamic> myProfileJson() {
  return <String, dynamic>{
    'candidate_profile_id': 'cand-1',
    'full_name': 'Ana María Prueba',
    'avatar_path': 'cand-1/avatar.jpg',
    'headline': 'Moza de salón con experiencia',
    'bio': 'Cinco años en gastronomía porteña.',
    'provincia': <String, dynamic>{'id': 'prov-caba', 'name': 'CABA'},
    'localidad': <String, dynamic>{'id': 'loc-caba', 'name': 'CABA'},
    'barrio': null,
    'sector': <String, dynamic>{
      'id': 'sector-gastro',
      'code': 'gastronomia_hoteleria',
      'name': 'Gastronomía y hotelería',
    },
    'availability': 'inmediata',
    'work_modes': <dynamic>['presencial', 'hibrido'],
    'experience': '1_a_3_anios',
    'weekly_availability': <dynamic>[
      <String, dynamic>{'day': 'vie', 'start': '22:00', 'end': '02:00'},
    ],
    'expected_salary_min': 500000,
    'expected_salary_max': 700000,
    'skills': <dynamic>['caja', 'salón'],
    'languages': <dynamic>['español'],
    'work_history': <dynamic>[
      <String, dynamic>{
        'empresa': 'Parrilla de Prueba',
        'puesto': 'Moza',
        'desde': '2021-03',
        'hasta': '2023-11',
      },
    ],
    'education': <dynamic>[
      <String, dynamic>{
        'nivel': 'secundario',
        'institucion': 'Escuela Normal 1',
      },
    ],
    'presentation_status': 'ready',
    'is_published': true,
    'application_ready': true,
  };
}

/// El repositorio de perfiles contra un cliente HTTP falso con las formas
/// reales de PostgREST/Storage/Functions: ningún test toca un proyecto
/// Supabase (mismo patrón que los tests de onboarding).
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

  group('fetchMyProfile', () {
    test(
      'pega al RPC get_my_candidate_profile y parsea la respuesta',
      () async {
        final client = await makeClient(
          (request) async => http.Response(
            jsonEncode(myProfileJson()),
            200,
            headers: jsonHeaders,
          ),
        );
        final repository = SupabaseProfileRepository(client);

        final profile = await repository.fetchMyProfile();

        final request = restRequests.single;
        expect(request.method, 'POST');
        expect(request.url.path, '/rest/v1/rpc/get_my_candidate_profile');
        expect(profile.candidateProfileId, 'cand-1');
        expect(
          profile.province,
          const CatalogRef(id: 'prov-caba', name: 'CABA'),
        );
        expect(profile.neighborhood, isNull);
        expect(profile.sector?.code, 'gastronomia_hoteleria');
        expect(profile.availability, CandidateAvailability.inmediata);
        expect(profile.workModes, {
          CandidateWorkMode.presencial,
          CandidateWorkMode.hibrido,
        });
        expect(profile.weeklyAvailability.single.crossesMidnight, isTrue);
        expect(profile.workHistory.single.company, 'Parrilla de Prueba');
        expect(profile.education.single.level, EducationLevel.secundario);
        expect(profile.presentationStatus, PresentationStatus.ready);
        expect(profile.isPublished, isTrue);
      },
    );
  });

  group('updateMyProfile', () {
    test(
      'el body lleva p_patch con las claves seteadas, null incluido',
      () async {
        final client = await makeClient(
          (request) async => http.Response('', 204),
        );
        final repository = SupabaseProfileRepository(client);

        final patch = CandidateProfilePatch()
          ..setHeadline(null)
          ..setBio('Nueva bio de prueba.')
          ..setWorkModes({CandidateWorkMode.remoto});
        await repository.updateMyProfile(patch);

        final request = restRequests.single;
        expect(request.url.path, '/rest/v1/rpc/update_my_candidate_profile');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final patchJson = body['p_patch'] as Map<String, dynamic>;
        expect(
          patchJson.containsKey('headline'),
          isTrue,
          reason: 'null explícito = limpiar el campo',
        );
        expect(patchJson['headline'], isNull);
        expect(patchJson['bio'], 'Nueva bio de prueba.');
        expect(patchJson['work_mode_prefs'], ['remoto']);
        expect(
          patchJson.containsKey('full_name'),
          isFalse,
          reason: 'clave no seteada no viaja',
        );
      },
    );

    test('con un parche vacío no se hace ningún request', () async {
      final client = await makeClient(
        (request) async => http.Response('', 204),
      );
      final repository = SupabaseProfileRepository(client);

      await repository.updateMyProfile(CandidateProfilePatch());

      expect(restRequests, isEmpty);
    });
  });

  group('fetchCandidatePublicProfile', () {
    test(
      'un null literal del RPC se devuelve como null (fail-closed)',
      () async {
        final client = await makeClient(
          (request) async => http.Response('null', 200, headers: jsonHeaders),
        );
        final repository = SupabaseProfileRepository(client);

        final result = await repository.fetchCandidatePublicProfile('cand-9');

        expect(result, isNull);
        final request = restRequests.single;
        expect(request.url.path, '/rest/v1/rpc/get_candidate_public_profile');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['p_candidate_profile_id'], 'cand-9');
      },
    );

    test('una respuesta objeto parsea la proyección pública', () async {
      final client = await makeClient(
        (request) async => http.Response(
          jsonEncode(<String, dynamic>{
            'candidate_profile_id': 'cand-9',
            'display_name': 'Ana',
            'headline': 'Moza de salón',
            'provincia': 'CABA',
            'sector': 'Gastronomía y hotelería',
            'availability': 'inmediata',
            'work_modes': <dynamic>['presencial'],
            'skills': <dynamic>['caja'],
            'presentation_available': true,
            'avatar_path': 'cand-9/avatar.jpg',
            'avatar_thumb_path': 'cand-9/thumb.jpg',
          }),
          200,
          headers: jsonHeaders,
        ),
      );
      final repository = SupabaseProfileRepository(client);

      final result = await repository.fetchCandidatePublicProfile('cand-9');

      expect(result, isNotNull);
      expect(result!.displayName, 'Ana');
      expect(result.provinceName, 'CABA');
      expect(result.sectorName, 'Gastronomía y hotelería');
      expect(result.availability, CandidateAvailability.inmediata);
      expect(result.presentationAvailable, isTrue);
      expect(result.avatarThumbPath, 'cand-9/thumb.jpg');
    });
  });

  group('errores PostgREST tipados', () {
    test('TFDAT llega como DataFailure invalidData', () async {
      final client = await makeClient((request) async => pgError('TFDAT'));
      final repository = SupabaseProfileRepository(client);

      await expectLater(
        repository.fetchMyProfile(),
        throwsA(
          isA<DataFailure>().having(
            (f) => f.code,
            'code',
            DataFailureCode.invalidData,
          ),
        ),
      );
    });

    test('42501 llega como DataFailure notAllowed', () async {
      final client = await makeClient((request) async => pgError('42501'));
      final repository = SupabaseProfileRepository(client);

      final patch = CandidateProfilePatch()..setBio('lo que sea');
      await expectLater(
        repository.updateMyProfile(patch),
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

  group('createAvatarSignedUrl', () {
    test('firma contra el bucket avatars y devuelve la URL completa', () async {
      final client = await makeClient(
        (request) async => http.Response(
          jsonEncode({
            'signedURL':
                '/object/sign/avatars/cand-1/avatar.jpg?token=token-firmado',
          }),
          200,
          headers: jsonHeaders,
        ),
      );
      final repository = SupabaseProfileRepository(client);

      final url = await repository.createAvatarSignedUrl(
        'cand-1/avatar.jpg',
        expiresInSeconds: 120,
      );

      final request = restRequests.single;
      expect(request.method, 'POST');
      expect(
        request.url.path,
        '/storage/v1/object/sign/avatars/cand-1/avatar.jpg',
      );
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['expiresIn'], 120);
      // El SDK antepone la base de storage al path firmado del body.
      expect(url, startsWith('http://127.0.0.1:54321/storage/v1'));
      expect(url, contains('avatars/cand-1/avatar.jpg'));
      expect(url, contains('token=token-firmado'));
    });
  });

  group('uploadAvatar', () {
    test('manda base64 y content_type a la Edge Function avatar', () async {
      final bytes = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);
      final client = await makeClient(
        (request) async => http.Response(
          jsonEncode({
            'avatar_path': 'cand-1/avatar.jpg',
            'thumb_path': 'cand-1/thumb.jpg',
          }),
          200,
          headers: jsonHeaders,
        ),
      );
      final repository = SupabaseProfileRepository(client);

      final paths = await repository.uploadAvatar(
        bytes: bytes,
        contentType: 'image/jpeg',
      );

      final request = restRequests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/functions/v1/avatar');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['data'], base64Encode(bytes));
      expect(body['content_type'], 'image/jpeg');
      expect(paths.avatarPath, 'cand-1/avatar.jpg');
      expect(paths.thumbPath, 'cand-1/thumb.jpg');
    });

    test(
      'un 415 {code: invalid_image} llega como AvatarFailure tipado',
      () async {
        final client = await makeClient(
          (request) async => http.Response(
            jsonEncode({'code': 'invalid_image'}),
            415,
            headers: jsonHeaders,
          ),
        );
        final repository = SupabaseProfileRepository(client);

        await expectLater(
          repository.uploadAvatar(
            bytes: Uint8List.fromList([1, 2, 3]),
            contentType: 'image/png',
          ),
          throwsA(
            isA<AvatarFailure>().having(
              (f) => f.code,
              'code',
              AvatarFailureCode.invalidImage,
            ),
          ),
        );
      },
    );
  });

  group('deleteAvatar', () {
    test('manda un DELETE a la Edge Function avatar', () async {
      final client = await makeClient(
        (request) async => http.Response('', 200),
      );
      final repository = SupabaseProfileRepository(client);

      await repository.deleteAvatar();

      final request = restRequests.single;
      expect(request.method, 'DELETE');
      expect(request.url.path, '/functions/v1/avatar');
    });
  });
}
