import '../../onboarding/domain/candidate_onboarding_data.dart';
import 'candidate_profile.dart';
import 'weekly_availability.dart';

/// Proyección pública del candidato para empresas (T-024).
///
/// Espejo 1:1 de la whitelist de `get_candidate_public_profile`: si un campo
/// no está acá, no viaja. Sin contacto, sin nacimiento, sin salario esperado,
/// sin score. `displayName` es el nombre de pila (UX_FLOWS §6.2); el contacto
/// completo recién se desbloquea con el match (T-045, fuera de este bloque).
class CandidatePublicProfile {
  const CandidatePublicProfile({
    required this.candidateProfileId,
    required this.displayName,
    required this.headline,
    required this.bio,
    required this.provinceName,
    required this.localityName,
    required this.neighborhoodName,
    required this.sectorName,
    required this.availability,
    required this.workModes,
    required this.experienceLevel,
    required this.weeklyAvailability,
    required this.skills,
    required this.languages,
    required this.workHistory,
    required this.education,
    required this.presentationAvailable,
    required this.avatarPath,
    required this.avatarThumbPath,
  });

  final String candidateProfileId;
  final String displayName;
  final String? headline;
  final String? bio;
  final String? provinceName;
  final String? localityName;
  final String? neighborhoodName;
  final String? sectorName;
  final CandidateAvailability? availability;
  final Set<CandidateWorkMode> workModes;
  final ExperienceLevel? experienceLevel;
  final List<AvailabilitySlot> weeklyAvailability;
  final List<String> skills;
  final List<String> languages;
  final List<WorkExperience> workHistory;
  final List<EducationEntry> education;
  final bool presentationAvailable;
  final String? avatarPath;
  final String? avatarThumbPath;

  factory CandidatePublicProfile.fromJson(Map<String, dynamic> json) {
    return CandidatePublicProfile(
      candidateProfileId: json['candidate_profile_id'] as String,
      displayName: (json['display_name'] as String?) ?? '',
      headline: json['headline'] as String?,
      bio: json['bio'] as String?,
      provinceName: json['provincia'] as String?,
      localityName: json['localidad'] as String?,
      neighborhoodName: json['barrio'] as String?,
      sectorName: json['sector'] as String?,
      availability: CandidateAvailability.fromWire(json['availability']),
      workModes: _parseWorkModes(json['work_modes']),
      experienceLevel: ExperienceLevel.fromWire(json['experience']),
      weeklyAvailability: AvailabilitySlot.listFromJson(
        json['weekly_availability'],
      ),
      skills: _parseStringList(json['skills']),
      languages: _parseStringList(json['languages']),
      workHistory: _parseEntries(json['work_history'], WorkExperience.fromJson),
      education: _parseEntries(json['education'], EducationEntry.fromJson),
      presentationAvailable: json['presentation_available'] == true,
      avatarPath: json['avatar_path'] as String?,
      avatarThumbPath: json['avatar_thumb_path'] as String?,
    );
  }

  static Set<CandidateWorkMode> _parseWorkModes(Object? raw) {
    if (raw is! List) {
      return const {};
    }
    final modes = <CandidateWorkMode>{};
    for (final entry in raw) {
      final mode = CandidateWorkMode.fromWire(entry);
      if (mode != null) {
        modes.add(mode);
      }
    }
    return modes;
  }

  static List<String> _parseStringList(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return raw.whereType<String>().toList(growable: false);
  }

  static List<T> _parseEntries<T>(Object? raw, T? Function(Object?) parse) {
    if (raw is! List) {
      return const [];
    }
    final items = <T>[];
    for (final entry in raw) {
      final parsed = parse(entry);
      if (parsed != null) {
        items.add(parsed);
      }
    }
    return items;
  }
}
