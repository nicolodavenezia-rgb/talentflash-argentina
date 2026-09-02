import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/onboarding/domain/candidate_onboarding_data.dart';
import 'package:talentflash_argentina/features/profiles/domain/candidate_profile.dart';
import 'package:talentflash_argentina/features/profiles/domain/candidate_profile_patch.dart';
import 'package:talentflash_argentina/features/profiles/domain/weekly_availability.dart';

/// Respuesta completa estilo `get_my_candidate_profile`, armada a mano.
Map<String, dynamic> fullProfileJson() {
  return <String, dynamic>{
    'candidate_profile_id': 'cand-1',
    'full_name': 'Ana María Prueba',
    'avatar_path': 'cand-1/avatar.jpg',
    'headline': 'Moza de salón con experiencia',
    'bio': 'Cinco años en gastronomía porteña.',
    'provincia': <String, dynamic>{'id': 'prov-caba', 'name': 'CABA'},
    'localidad': <String, dynamic>{'id': 'loc-caba', 'name': 'CABA'},
    'barrio': <String, dynamic>{'id': 'barrio-palermo', 'name': 'Palermo'},
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
    'expected_salary_max': 700000.5,
    'skills': <dynamic>['caja', 'salón', 'atención al cliente'],
    'languages': <dynamic>['español'],
    'work_history': <dynamic>[
      <String, dynamic>{
        'empresa': 'Parrilla de Prueba',
        'puesto': 'Moza',
        'desde': '2021-03',
        'hasta': '2023-11',
        'descripcion': 'Salón y caja.',
      },
    ],
    'education': <dynamic>[
      <String, dynamic>{
        'nivel': 'secundario',
        'institucion': 'Escuela Normal 1',
        'titulo': null,
        'desde': null,
        'hasta': null,
      },
    ],
    'presentation_status': 'ready',
    'is_published': true,
    'application_ready': true,
  };
}

void main() {
  group('CandidateProfile.fromJson', () {
    test('un mapa completo estilo RPC parsea todo', () {
      final profile = CandidateProfile.fromJson(fullProfileJson());

      expect(profile.candidateProfileId, 'cand-1');
      expect(profile.fullName, 'Ana María Prueba');
      expect(profile.province, const CatalogRef(id: 'prov-caba', name: 'CABA'));
      expect(profile.locality, const CatalogRef(id: 'loc-caba', name: 'CABA'));
      expect(
        profile.neighborhood,
        const CatalogRef(id: 'barrio-palermo', name: 'Palermo'),
      );
      expect(
        profile.sector,
        const SectorRef(
          id: 'sector-gastro',
          code: 'gastronomia_hoteleria',
          name: 'Gastronomía y hotelería',
        ),
      );
      expect(profile.availability, CandidateAvailability.inmediata);
      expect(profile.workModes, {
        CandidateWorkMode.presencial,
        CandidateWorkMode.hibrido,
      });
      expect(profile.experienceLevel, ExperienceLevel.de1A3Anios);
      expect(profile.weeklyAvailability.single.day, WeekDay.vie);
      expect(profile.weeklyAvailability.single.crossesMidnight, isTrue);
      expect(profile.expectedSalaryMin, 500000);
      expect(profile.expectedSalaryMax, 700000.5);
      expect(profile.skills, ['caja', 'salón', 'atención al cliente']);
      expect(profile.languages, ['español']);
      expect(profile.workHistory.single.company, 'Parrilla de Prueba');
      expect(profile.education.single.level, EducationLevel.secundario);
      expect(profile.presentationStatus, PresentationStatus.ready);
      expect(profile.isPublished, isTrue);
      expect(profile.applicationReady, isTrue);
    });

    test('claves ausentes o null caen en defaults seguros', () {
      final profile = CandidateProfile.fromJson(<String, dynamic>{
        'candidate_profile_id': 'solo-id',
        'headline': null,
      });

      expect(profile.candidateProfileId, 'solo-id');
      expect(profile.fullName, isNull);
      expect(profile.avatarPath, isNull);
      expect(profile.headline, isNull);
      expect(profile.province, isNull);
      expect(profile.sector, isNull);
      expect(profile.availability, isNull);
      expect(profile.workModes, isEmpty);
      expect(profile.experienceLevel, isNull);
      expect(profile.weeklyAvailability, isEmpty);
      expect(profile.expectedSalaryMin, isNull);
      expect(profile.skills, isEmpty);
      expect(profile.languages, isEmpty);
      expect(profile.workHistory, isEmpty);
      expect(profile.education, isEmpty);
      expect(profile.presentationStatus, PresentationStatus.none);
      expect(profile.isPublished, isFalse);
      expect(profile.applicationReady, isFalse);
    });

    test('enums desconocidos degradan sin romper', () {
      final json = fullProfileJson()
        ..['availability'] = 'cuando_pinte'
        ..['experience'] = 'veterana'
        ..['presentation_status'] = 'transcodificando'
        ..['work_modes'] = <dynamic>['presencial', 'teletransporte'];
      final profile = CandidateProfile.fromJson(json);

      expect(profile.availability, isNull);
      expect(profile.experienceLevel, isNull);
      expect(
        profile.presentationStatus,
        PresentationStatus.none,
        reason: 'estado desconocido se trata como ausencia (fail-closed)',
      );
      expect(profile.workModes, {CandidateWorkMode.presencial});
    });

    test('avatarThumbPath deriva el thumb del canónico', () {
      final conAvatar = CandidateProfile.fromJson(fullProfileJson());
      expect(conAvatar.avatarThumbPath, 'cand-1/thumb.jpg');

      final sinAvatar = CandidateProfile.fromJson(<String, dynamic>{
        'candidate_profile_id': 'cand-1',
      });
      expect(sinAvatar.avatarThumbPath, isNull);
    });
  });

  group('WorkExperience', () {
    test('roundtrip toJson/fromJson con hasta y descripción', () {
      const original = WorkExperience(
        company: 'Parrilla de Prueba',
        position: 'Moza',
        fromMonth: '2021-03',
        toMonth: '2023-11',
        description: 'Salón y caja.',
      );
      expect(WorkExperience.fromJson(original.toJson()), original);
      expect(original.isCurrent, isFalse);
    });

    test('roundtrip sin hasta ni descripción: trabajo actual', () {
      const actual = WorkExperience(
        company: 'Bar Prueba',
        position: 'Cajera',
        fromMonth: '2024-01',
      );
      final roundtrip = WorkExperience.fromJson(actual.toJson());
      expect(roundtrip, actual);
      expect(roundtrip!.isCurrent, isTrue);
    });
  });

  group('EducationEntry', () {
    test('un nivel fuera del catálogo invalida la entrada y se filtra', () {
      expect(
        EducationEntry.fromJson(<String, dynamic>{
          'nivel': 'doctorado_klingon',
          'institucion': 'X',
        }),
        isNull,
      );

      final json = fullProfileJson()
        ..['education'] = <dynamic>[
          <String, dynamic>{'nivel': 'universitario', 'institucion': 'UBA'},
          <String, dynamic>{'nivel': 'doctorado_klingon', 'institucion': 'X'},
        ];
      final profile = CandidateProfile.fromJson(json);
      expect(profile.education.single.institution, 'UBA');
    });
  });

  group('CandidateProfilePatch', () {
    test('clave ausente no viaja e isEmpty refleja el estado', () {
      final patch = CandidateProfilePatch();
      expect(patch.isEmpty, isTrue);
      expect(patch.toJson(), isEmpty);

      patch.setBio('Nueva bio.');
      expect(patch.isEmpty, isFalse);
      expect(patch.toJson().containsKey('headline'), isFalse);
      expect(patch.toJson()['bio'], 'Nueva bio.');
    });

    test(
      'setHeadline(null) es limpieza explícita: clave presente con null',
      () {
        final patch = CandidateProfilePatch()..setHeadline(null);
        final json = patch.toJson();
        expect(json.containsKey('headline'), isTrue);
        expect(json['headline'], isNull);
      },
    );

    test('setLocation mete la terna geográfica completa', () {
      final patch = CandidateProfilePatch()
        ..setLocation(
          provinceId: 'prov-1',
          localityId: 'loc-1',
          neighborhoodId: null,
        );
      final json = patch.toJson();
      expect(json['provincia_id'], 'prov-1');
      expect(json['localidad_id'], 'loc-1');
      expect(
        json.containsKey('barrio_id'),
        isTrue,
        reason: 'el barrio viaja aunque sea null: el servidor valida la terna',
      );
      expect(json['barrio_id'], isNull);
    });

    test('setWorkModes serializa los wireNames', () {
      final patch = CandidateProfilePatch()
        ..setWorkModes({
          CandidateWorkMode.presencial,
          CandidateWorkMode.remoto,
        });
      expect(patch.toJson()['work_mode_prefs'], ['presencial', 'remoto']);
    });

    test('setWeeklyAvailability serializa {day, start, end}', () {
      final patch = CandidateProfilePatch()
        ..setWeeklyAvailability(const [
          AvailabilitySlot(
            day: WeekDay.vie,
            startMinutes: 1320,
            endMinutes: 120,
          ),
        ]);
      expect(patch.toJson()['weekly_availability'], [
        {'day': 'vie', 'start': '22:00', 'end': '02:00'},
      ]);
    });
  });
}
