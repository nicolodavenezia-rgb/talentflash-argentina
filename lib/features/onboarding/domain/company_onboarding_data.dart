/// Tamaños de empresa que acepta `complete_company_onboarding` (0022).
enum CompanySizeRange {
  from1To10('1-10'),
  from11To50('11-50'),
  from51To200('51-200'),
  from201To500('201-500'),
  moreThan500('501+');

  const CompanySizeRange(this.wireName);

  final String wireName;
}

/// Relación del solicitante con la empresa (set cerrado validado server-side).
enum CompanyRelationship {
  owner('owner'),
  partner('partner'),
  manager('manager'),
  hr('hr'),
  other('other');

  const CompanyRelationship(this.wireName);

  final String wireName;
}

/// Datos del wizard de empresa (T-017).
///
/// A diferencia del candidato, NADA de esto se persiste hasta el paso final:
/// la empresa, su owner y los datos del solicitante nacen juntos en la RPC
/// atómica `complete_company_onboarding` — así jamás queda una empresa a
/// medio crear. El avance durable del wizard son los consentimientos y las
/// preferencias, que sí se guardan al confirmarse.
class CompanyOnboardingData {
  const CompanyOnboardingData({
    this.legalName,
    this.tradeName,
    this.cuit,
    this.sectorId,
    this.sizeRange,
    this.provinceId,
    this.localityId,
    this.website,
    this.applicantFullName,
    this.applicantPosition,
    this.applicantRelationship,
  });

  final String? legalName;
  final String? tradeName;
  final String? cuit;
  final String? sectorId;
  final CompanySizeRange? sizeRange;
  final String? provinceId;
  final String? localityId;
  final String? website;
  final String? applicantFullName;
  final String? applicantPosition;
  final CompanyRelationship? applicantRelationship;

  bool get hasCompanyData =>
      (legalName ?? '').trim().isNotEmpty &&
      (tradeName ?? '').trim().isNotEmpty &&
      (cuit ?? '').isNotEmpty &&
      sectorId != null &&
      sizeRange != null;

  bool get hasPlace => provinceId != null && localityId != null;

  bool get hasApplicant =>
      (applicantFullName ?? '').trim().isNotEmpty &&
      (applicantPosition ?? '').trim().isNotEmpty &&
      applicantRelationship != null;

  CompanyOnboardingData copyWith({
    String? legalName,
    String? tradeName,
    String? cuit,
    String? sectorId,
    CompanySizeRange? sizeRange,
    String? provinceId,
    String? localityId,
    String? Function()? website,
    String? applicantFullName,
    String? applicantPosition,
    CompanyRelationship? applicantRelationship,
  }) {
    return CompanyOnboardingData(
      legalName: legalName ?? this.legalName,
      tradeName: tradeName ?? this.tradeName,
      cuit: cuit ?? this.cuit,
      sectorId: sectorId ?? this.sectorId,
      sizeRange: sizeRange ?? this.sizeRange,
      provinceId: provinceId ?? this.provinceId,
      localityId: localityId ?? this.localityId,
      website: website == null ? this.website : website(),
      applicantFullName: applicantFullName ?? this.applicantFullName,
      applicantPosition: applicantPosition ?? this.applicantPosition,
      applicantRelationship:
          applicantRelationship ?? this.applicantRelationship,
    );
  }
}
