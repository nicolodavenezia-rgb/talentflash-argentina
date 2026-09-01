/// Valores del enum `availability_type` de Postgres que el wizard ofrece.
enum CandidateAvailability {
  inmediata('inmediata'),
  en1Semana('en_1_semana'),
  en2Semanas('en_2_semanas'),
  en1Mes('en_1_mes'),
  aConvenir('a_convenir');

  const CandidateAvailability(this.wireName);

  final String wireName;

  static CandidateAvailability? fromWire(Object? raw) {
    for (final value in CandidateAvailability.values) {
      if (raw == value.wireName) {
        return value;
      }
    }
    return null;
  }
}

/// Valores del enum `work_mode` de Postgres (modalidad preferida, T-016).
enum CandidateWorkMode {
  presencial('presencial'),
  hibrido('hibrido'),
  remoto('remoto');

  const CandidateWorkMode(this.wireName);

  final String wireName;

  static CandidateWorkMode? fromWire(Object? raw) {
    for (final value in CandidateWorkMode.values) {
      if (raw == value.wireName) {
        return value;
      }
    }
    return null;
  }
}

/// Instantánea del wizard de candidato (T-016). `null` = paso sin responder.
///
/// Cada avance de paso persiste la instantánea COMPLETA vía
/// `save_candidate_onboarding`, así el progreso sobrevive a cerrar la app y
/// el wizard retoma donde quedó.
class CandidateOnboardingData {
  const CandidateOnboardingData({
    this.fullName,
    this.birthDate,
    this.provinceId,
    this.localityId,
    this.neighborhoodId,
    this.sectorId,
    this.availability,
    this.workModes = const {},
  });

  final String? fullName;
  final DateTime? birthDate;
  final String? provinceId;
  final String? localityId;
  final String? neighborhoodId;
  final String? sectorId;
  final CandidateAvailability? availability;
  final Set<CandidateWorkMode> workModes;

  bool get hasIdentity =>
      (fullName ?? '').trim().isNotEmpty && birthDate != null;

  bool get hasPlace => provinceId != null && localityId != null;

  bool get hasPreferences =>
      sectorId != null && availability != null && workModes.isNotEmpty;

  CandidateOnboardingData copyWith({
    String? fullName,
    DateTime? birthDate,
    String? provinceId,
    String? localityId,
    String? Function()? neighborhoodId,
    String? sectorId,
    CandidateAvailability? availability,
    Set<CandidateWorkMode>? workModes,
  }) {
    return CandidateOnboardingData(
      fullName: fullName ?? this.fullName,
      birthDate: birthDate ?? this.birthDate,
      provinceId: provinceId ?? this.provinceId,
      localityId: localityId ?? this.localityId,
      // El barrio puede volver a `null` al cambiar de localidad, por eso el
      // parámetro es una función y no un valor.
      neighborhoodId: neighborhoodId == null
          ? this.neighborhoodId
          : neighborhoodId(),
      sectorId: sectorId ?? this.sectorId,
      availability: availability ?? this.availability,
      workModes: workModes ?? this.workModes,
    );
  }
}
