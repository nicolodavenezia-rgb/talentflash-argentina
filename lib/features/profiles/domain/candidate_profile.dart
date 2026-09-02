import '../../onboarding/domain/candidate_onboarding_data.dart';
import 'weekly_availability.dart';

/// Nivel de experiencia declarado (enum `experience_level` de la base).
enum ExperienceLevel {
  sinExperiencia('sin_experiencia'),
  hasta1Anio('hasta_1_anio'),
  de1A3Anios('1_a_3_anios'),
  de3A5Anios('3_a_5_anios'),
  masDe5Anios('mas_de_5_anios');

  const ExperienceLevel(this.wireName);

  final String wireName;

  static ExperienceLevel? fromWire(Object? raw) {
    for (final value in ExperienceLevel.values) {
      if (value.wireName == raw) {
        return value;
      }
    }
    return null;
  }
}

/// Nivel educativo del catálogo cerrado que valida el servidor.
enum EducationLevel {
  primario('primario'),
  secundario('secundario'),
  terciario('terciario'),
  universitario('universitario'),
  posgrado('posgrado'),
  curso('curso');

  const EducationLevel(this.wireName);

  final String wireName;

  static EducationLevel? fromWire(Object? raw) {
    for (final value in EducationLevel.values) {
      if (value.wireName == raw) {
        return value;
      }
    }
    return null;
  }
}

/// Estado de la presentación del candidato (T-023), derivado del video
/// vinculado. `none` = todavía no hay presentación; el video real llega en el
/// Bloque K y audio/texto con T-084 — la UI nunca simula esos flujos.
enum PresentationStatus {
  none('none'),
  uploading('uploading'),
  processing('processing'),
  ready('ready'),
  failed('failed'),
  expired('expired'),
  removed('removed');

  const PresentationStatus(this.wireName);

  final String wireName;

  static PresentationStatus fromWire(Object? raw) {
    for (final value in PresentationStatus.values) {
      if (value.wireName == raw) {
        return value;
      }
    }
    // Estado desconocido de la base: se trata como ausencia (fail-closed).
    return PresentationStatus.none;
  }
}

/// Referencia de catálogo con nombre resuelto server-side.
class CatalogRef {
  const CatalogRef({required this.id, required this.name});

  final String id;
  final String name;

  static CatalogRef? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || name is! String) {
      return null;
    }
    return CatalogRef(id: id, name: name);
  }

  @override
  bool operator ==(Object other) =>
      other is CatalogRef && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(CatalogRef, id, name);
}

/// Sector con código estable y nombre es-AR.
class SectorRef {
  const SectorRef({required this.id, required this.code, required this.name});

  final String id;
  final String code;
  final String name;

  static SectorRef? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final id = raw['id'];
    final code = raw['code'];
    final name = raw['name'];
    if (id is! String || code is! String || name is! String) {
      return null;
    }
    return SectorRef(id: id, code: code, name: name);
  }

  @override
  bool operator ==(Object other) =>
      other is SectorRef &&
      other.id == id &&
      other.code == code &&
      other.name == name;

  @override
  int get hashCode => Object.hash(SectorRef, id, code, name);
}

/// Una experiencia laboral del historial (`work_history` jsonb).
///
/// Las fechas viajan como 'YYYY-MM'; `hasta == null` significa "actualmente".
class WorkExperience {
  const WorkExperience({
    required this.company,
    required this.position,
    required this.fromMonth,
    this.toMonth,
    this.description,
  });

  final String company;
  final String position;
  final String fromMonth;
  final String? toMonth;
  final String? description;

  bool get isCurrent => toMonth == null;

  static WorkExperience? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final company = raw['empresa'];
    final position = raw['puesto'];
    final fromMonth = raw['desde'];
    if (company is! String || position is! String || fromMonth is! String) {
      return null;
    }
    return WorkExperience(
      company: company,
      position: position,
      fromMonth: fromMonth,
      toMonth: raw['hasta'] as String?,
      description: raw['descripcion'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'empresa': company,
    'puesto': position,
    'desde': fromMonth,
    'hasta': toMonth,
    'descripcion': description,
  };

  @override
  bool operator ==(Object other) =>
      other is WorkExperience &&
      other.company == company &&
      other.position == position &&
      other.fromMonth == fromMonth &&
      other.toMonth == toMonth &&
      other.description == description;

  @override
  int get hashCode => Object.hash(
    WorkExperience,
    company,
    position,
    fromMonth,
    toMonth,
    description,
  );
}

/// Una entrada de educación (`education` jsonb). Todo salvo nivel e
/// institución es opcional: la educación nunca es requisito.
class EducationEntry {
  const EducationEntry({
    required this.level,
    required this.institution,
    this.degree,
    this.fromMonth,
    this.toMonth,
  });

  final EducationLevel level;
  final String institution;
  final String? degree;
  final String? fromMonth;
  final String? toMonth;

  static EducationEntry? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final level = EducationLevel.fromWire(raw['nivel']);
    final institution = raw['institucion'];
    if (level == null || institution is! String) {
      return null;
    }
    return EducationEntry(
      level: level,
      institution: institution,
      degree: raw['titulo'] as String?,
      fromMonth: raw['desde'] as String?,
      toMonth: raw['hasta'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'nivel': level.wireName,
    'institucion': institution,
    'titulo': degree,
    'desde': fromMonth,
    'hasta': toMonth,
  };

  @override
  bool operator ==(Object other) =>
      other is EducationEntry &&
      other.level == level &&
      other.institution == institution &&
      other.degree == degree &&
      other.fromMonth == fromMonth &&
      other.toMonth == toMonth;

  @override
  int get hashCode => Object.hash(
    EducationEntry,
    level,
    institution,
    degree,
    fromMonth,
    toMonth,
  );
}

/// Perfil profesional propio del candidato (respuesta de
/// `get_my_candidate_profile`). Inmutable; el estado editable vive en el
/// controller de edición.
class CandidateProfile {
  const CandidateProfile({
    required this.candidateProfileId,
    required this.fullName,
    required this.avatarPath,
    required this.headline,
    required this.bio,
    required this.province,
    required this.locality,
    required this.neighborhood,
    required this.sector,
    required this.availability,
    required this.workModes,
    required this.experienceLevel,
    required this.weeklyAvailability,
    required this.expectedSalaryMin,
    required this.expectedSalaryMax,
    required this.skills,
    required this.languages,
    required this.workHistory,
    required this.education,
    required this.presentationStatus,
    required this.isPublished,
    required this.applicationReady,
  });

  final String candidateProfileId;
  final String? fullName;
  final String? avatarPath;
  final String? headline;
  final String? bio;
  final CatalogRef? province;
  final CatalogRef? locality;
  final CatalogRef? neighborhood;
  final SectorRef? sector;
  final CandidateAvailability? availability;
  final Set<CandidateWorkMode> workModes;
  final ExperienceLevel? experienceLevel;
  final List<AvailabilitySlot> weeklyAvailability;
  final num? expectedSalaryMin;
  final num? expectedSalaryMax;
  final List<String> skills;
  final List<String> languages;
  final List<WorkExperience> workHistory;
  final List<EducationEntry> education;
  final PresentationStatus presentationStatus;
  final bool isPublished;
  final bool applicationReady;

  /// Path del thumbnail derivado del canónico (misma regla que el servidor).
  String? get avatarThumbPath =>
      avatarPath?.replaceFirst(RegExp(r'avatar\.jpg$'), 'thumb.jpg');

  factory CandidateProfile.fromJson(Map<String, dynamic> json) {
    return CandidateProfile(
      candidateProfileId: json['candidate_profile_id'] as String,
      fullName: json['full_name'] as String?,
      avatarPath: json['avatar_path'] as String?,
      headline: json['headline'] as String?,
      bio: json['bio'] as String?,
      province: CatalogRef.fromJson(json['provincia']),
      locality: CatalogRef.fromJson(json['localidad']),
      neighborhood: CatalogRef.fromJson(json['barrio']),
      sector: SectorRef.fromJson(json['sector']),
      availability: CandidateAvailability.fromWire(json['availability']),
      workModes: _parseWorkModes(json['work_modes']),
      experienceLevel: ExperienceLevel.fromWire(json['experience']),
      weeklyAvailability: AvailabilitySlot.listFromJson(
        json['weekly_availability'],
      ),
      expectedSalaryMin: json['expected_salary_min'] as num?,
      expectedSalaryMax: json['expected_salary_max'] as num?,
      skills: _parseStringList(json['skills']),
      languages: _parseStringList(json['languages']),
      workHistory: _parseList(json['work_history'], WorkExperience.fromJson),
      education: _parseList(json['education'], EducationEntry.fromJson),
      presentationStatus: PresentationStatus.fromWire(
        json['presentation_status'],
      ),
      isPublished: json['is_published'] == true,
      applicationReady: json['application_ready'] == true,
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

  static List<T> _parseList<T>(Object? raw, T? Function(Object?) parse) {
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
