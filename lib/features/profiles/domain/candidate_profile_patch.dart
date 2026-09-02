import '../../onboarding/domain/candidate_onboarding_data.dart';
import 'candidate_profile.dart';
import 'weekly_availability.dart';

/// Parche del perfil con la semántica exacta de `update_my_candidate_profile`:
/// clave PRESENTE se escribe (null = limpiar explícitamente), clave AUSENTE
/// queda intacta. Solo existe un setter por campo editable: role, email,
/// is_published, onboarding, video y columnas administrativas no tienen forma
/// de viajar en este tipo.
class CandidateProfilePatch {
  final Map<String, Object?> _fields = {};

  bool get isEmpty => _fields.isEmpty;

  Map<String, Object?> toJson() => Map.unmodifiable(_fields);

  void setFullName(String value) => _fields['full_name'] = value;

  void setHeadline(String? value) => _fields['headline'] = value;

  void setBio(String? value) => _fields['bio'] = value;

  void setLocation({
    required String provinceId,
    required String localityId,
    required String? neighborhoodId,
  }) {
    // La geografía viaja siempre como terna: el servidor valida coherencia
    // provincia→localidad→barrio sobre el estado final.
    _fields['provincia_id'] = provinceId;
    _fields['localidad_id'] = localityId;
    _fields['barrio_id'] = neighborhoodId;
  }

  void setSector(String sectorId) => _fields['sector_id'] = sectorId;

  void setAvailability(CandidateAvailability value) =>
      _fields['availability'] = value.wireName;

  void setWorkModes(Set<CandidateWorkMode> modes) =>
      _fields['work_mode_prefs'] = modes
          .map((mode) => mode.wireName)
          .toList(growable: false);

  void setExperienceLevel(ExperienceLevel? value) =>
      _fields['experience'] = value?.wireName;

  void setWeeklyAvailability(List<AvailabilitySlot> slots) =>
      _fields['weekly_availability'] = slots
          .map((slot) => slot.toJson())
          .toList(growable: false);

  void setExpectedSalary({required num? min, required num? max}) {
    _fields['expected_salary_min'] = min;
    _fields['expected_salary_max'] = max;
  }

  void setSkills(List<String> skills) =>
      _fields['skills'] = List<String>.unmodifiable(skills);

  void setLanguages(List<String> languages) =>
      _fields['languages'] = List<String>.unmodifiable(languages);

  void setWorkHistory(List<WorkExperience> entries) => _fields['work_history'] =
      entries.map((entry) => entry.toJson()).toList(growable: false);

  void setEducation(List<EducationEntry> entries) => _fields['education'] =
      entries.map((entry) => entry.toJson()).toList(growable: false);
}
