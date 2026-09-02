import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/profiles/domain/candidate_profile.dart';
import 'package:talentflash_argentina/features/profiles/domain/profile_completeness.dart';
import 'package:talentflash_argentina/features/profiles/domain/weekly_availability.dart';

import '../../../support/fake_profile_repositories.dart';

/// Perfil con TODOS los ítems del score cumplidos.
CandidateProfile completeProfile({
  String? avatarPath = 'cand-prueba-id/avatar.jpg',
  PresentationStatus presentationStatus = PresentationStatus.ready,
}) {
  return testCandidateProfile(
    avatarPath: avatarPath,
    weeklyAvailability: const [
      AvailabilitySlot(day: WeekDay.lun, startMinutes: 540, endMinutes: 720),
    ],
    education: const [
      EducationEntry(
        level: EducationLevel.secundario,
        institution: 'Escuela Normal 1',
      ),
    ],
    presentationStatus: presentationStatus,
  );
}

/// Perfil con SOLO la base del onboarding (sin nada opcional cargado).
CandidateProfile baseOnlyProfile({String? headline}) {
  return testCandidateProfile(
    headline: headline,
    bio: null,
    workHistory: const [],
    skills: const [],
    languages: const [],
  );
}

void main() {
  group('ProfileCompleteness.of', () {
    test('el perfil completo llega exactamente a 100', () {
      final completeness = ProfileCompleteness.of(completeProfile());
      expect(completeness.score, 100);
      expect(completeness.pending, isEmpty);
    });

    test('la base mínima del onboarding vale 25', () {
      expect(ProfileCompleteness.of(baseOnlyProfile()).score, 25);
    });

    test('un headline de solo espacios no cuenta', () {
      expect(
        ProfileCompleteness.of(baseOnlyProfile(headline: '   ')).score,
        ProfileCompleteness.of(baseOnlyProfile()).score,
      );
    });

    test('tres skills iguales (aun con mayúsculas) no son "3 distintas"', () {
      final repetidas = ProfileCompleteness.of(
        testCandidateProfile(skills: const ['Caja', 'caja', ' CAJA ']),
      );
      final skillsItem = repetidas.items.singleWhere(
        (item) => item.labelKey == 'skills',
      );
      expect(skillsItem.achieved, isFalse);

      final distintas = ProfileCompleteness.of(
        testCandidateProfile(skills: const ['caja', 'salón', 'atención']),
      );
      expect(
        distintas.items
            .singleWhere((item) => item.labelKey == 'skills')
            .achieved,
        isTrue,
      );
    });

    test('barajar las listas no cambia el resultado', () {
      const experienciaA = WorkExperience(
        company: 'Parrilla de Prueba',
        position: 'Moza',
        fromMonth: '2021-03',
      );
      const experienciaB = WorkExperience(
        company: 'Bar Prueba',
        position: 'Cajera',
        fromMonth: '2024-01',
      );
      final ordenado = ProfileCompleteness.of(
        testCandidateProfile(
          skills: const ['caja', 'salón', 'atención'],
          languages: const ['español', 'portugués'],
          workHistory: const [experienciaA, experienciaB],
        ),
      );
      final barajado = ProfileCompleteness.of(
        testCandidateProfile(
          skills: const ['atención', 'caja', 'salón'],
          languages: const ['portugués', 'español'],
          workHistory: const [experienciaB, experienciaA],
        ),
      );
      expect(barajado.score, ordenado.score);
      expect(
        barajado.pending.map((item) => item.labelKey).toList(),
        ordenado.pending.map((item) => item.labelKey).toList(),
      );
    });

    test('el perfil vacío vale 0', () {
      final vacio = testCandidateProfile(
        fullName: null,
        headline: null,
        bio: null,
        province: null,
        locality: null,
        neighborhood: null,
        sector: null,
        availability: null,
        workModes: const {},
        experienceLevel: null,
        skills: const [],
        languages: const [],
        workHistory: const [],
      );
      final completeness = ProfileCompleteness.of(vacio);
      expect(completeness.score, 0);
      expect(completeness.pending, hasLength(completeness.items.length));
    });

    test('una presentación processing todavía no suma (solo ready)', () {
      final procesando = ProfileCompleteness.of(
        completeProfile(presentationStatus: PresentationStatus.processing),
      );
      expect(procesando.score, 95);
      expect(procesando.pending.map((item) => item.labelKey).toList(), [
        'presentation',
      ]);
    });

    test('el avatar suma 5 y su ausencia no afecta al resto', () {
      final sinAvatar = ProfileCompleteness.of(
        completeProfile(avatarPath: null),
      );
      expect(sinAvatar.score, 95);
      expect(sinAvatar.pending.map((item) => item.labelKey).toList(), [
        'avatar',
      ]);
    });

    test('pending lista exactamente los ítems no cumplidos', () {
      final completeness = ProfileCompleteness.of(baseOnlyProfile());
      expect(completeness.pending.map((item) => item.labelKey).toList(), [
        'headline',
        'bio',
        'experience',
        'skills',
        'languages',
        'schedule',
        'education',
        'avatar',
        'presentation',
      ]);
    });

    test('los pesos declarados suman 100', () {
      final items = ProfileCompleteness.of(testCandidateProfile()).items;
      final total = items.fold<int>(0, (sum, item) => sum + item.weight);
      expect(total, 100);
    });
  });
}
