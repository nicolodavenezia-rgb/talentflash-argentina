import 'dart:async';

import 'package:talentflash_argentina/features/consents/data/consents_repository.dart';
import 'package:talentflash_argentina/features/consents/domain/consent_snapshot.dart';
import 'package:talentflash_argentina/features/consents/domain/consent_type.dart';
import 'package:talentflash_argentina/features/legal/data/legal_repository.dart';
import 'package:talentflash_argentina/features/legal/domain/legal_document.dart';
import 'package:talentflash_argentina/features/notifications/data/notification_prefs_repository.dart';
import 'package:talentflash_argentina/features/notifications/domain/notification_prefs.dart';
import 'package:talentflash_argentina/features/onboarding/data/catalog_repository.dart';
import 'package:talentflash_argentina/features/onboarding/data/onboarding_repository.dart';
import 'package:talentflash_argentina/features/onboarding/domain/candidate_onboarding_data.dart';
import 'package:talentflash_argentina/features/onboarding/domain/catalog.dart';
import 'package:talentflash_argentina/features/onboarding/domain/company_onboarding_data.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

/// Versión vigente que usan todos los fakes (espejo del seed de 0021).
const testConsentVersion = '2026-08-31';

List<ConsentRequirement> defaultConsentRequirements() => const [
  ConsentRequirement(
    type: ConsentType.termsAcceptance,
    version: testConsentVersion,
    documentSlug: 'terminos',
    isMandatory: true,
  ),
  ConsentRequirement(
    type: ConsentType.ageDeclaration,
    version: testConsentVersion,
    documentSlug: 'terminos',
    isMandatory: true,
  ),
  ConsentRequirement(
    type: ConsentType.dataProcessing,
    version: testConsentVersion,
    documentSlug: 'privacidad',
    isMandatory: true,
  ),
  ConsentRequirement(
    type: ConsentType.videoProfilePublication,
    version: testConsentVersion,
    documentSlug: 'privacidad',
    isMandatory: false,
  ),
  ConsentRequirement(
    type: ConsentType.aiFeatures,
    version: testConsentVersion,
    documentSlug: 'privacidad',
    isMandatory: false,
  ),
];

/// Doble del ledger de consentimientos: append-only en memoria.
class FakeConsentsRepository implements ConsentsRepository {
  FakeConsentsRepository({bool mandatoryGranted = true}) {
    if (mandatoryGranted) {
      grantAllMandatory();
    }
  }

  List<ConsentRequirement> requirements = defaultConsentRequirements();

  /// Eventos registrados en orden (la última fila por tipo es la vigente).
  final List<ConsentDecision> ledger = [];

  final List<String> calls = [];
  DataFailure? nextFailure;
  Completer<void>? pendingAction;

  void grantAllMandatory() {
    for (final requirement in requirements) {
      if (requirement.isMandatory) {
        ledger.add(
          ConsentDecision(
            type: requirement.type,
            granted: true,
            version: requirement.version,
          ),
        );
      }
    }
  }

  void grantLocally(ConsentType type, {String version = testConsentVersion}) {
    ledger.add(ConsentDecision(type: type, granted: true, version: version));
  }

  ConsentSnapshot buildSnapshot() {
    final latest = <ConsentType, ConsentDecision>{};
    for (final decision in ledger) {
      latest[decision.type] = decision;
    }
    return ConsentSnapshot(requirements: requirements, latestByType: latest);
  }

  @override
  Future<ConsentSnapshot> loadSnapshot() async {
    calls.add('loadSnapshot');
    await _awaitPending();
    _throwIfProgrammed();
    return buildSnapshot();
  }

  @override
  Future<void> grant(ConsentType type, {required String version}) async {
    calls.add('grant:${type.wireName}@$version');
    await _awaitPending();
    _throwIfProgrammed();
    ledger.add(ConsentDecision(type: type, granted: true, version: version));
  }

  @override
  Future<void> revoke(ConsentType type, {required String version}) async {
    calls.add('revoke:${type.wireName}@$version');
    await _awaitPending();
    _throwIfProgrammed();
    ledger.add(ConsentDecision(type: type, granted: false, version: version));
  }

  Future<void> _awaitPending() async {
    final pending = pendingAction;
    if (pending != null) {
      await pending.future;
    }
  }

  void _throwIfProgrammed() {
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
  }
}

/// Doble del repositorio de onboarding.
class FakeOnboardingRepository implements OnboardingRepository {
  FakeOnboardingRepository({this.onboardingCompleted = true});

  bool onboardingCompleted;
  CandidateOnboardingData draft = const CandidateOnboardingData();

  final List<String> calls = [];
  DataFailure? nextFailure;
  Completer<void>? pendingAction;

  CandidateOnboardingData? lastSavedData;
  CompanyOnboardingData? lastCompanyData;
  int completeCompanyCalls = 0;
  String companyId = 'empresa-de-prueba-id';

  @override
  Future<bool> fetchOnboardingCompleted() async {
    calls.add('fetchOnboardingCompleted');
    await _awaitPending();
    _throwIfProgrammed();
    return onboardingCompleted;
  }

  @override
  Future<CandidateOnboardingData> fetchCandidateDraft() async {
    calls.add('fetchCandidateDraft');
    await _awaitPending();
    _throwIfProgrammed();
    return draft;
  }

  @override
  Future<void> saveCandidateData(CandidateOnboardingData data) async {
    calls.add('saveCandidateData');
    await _awaitPending();
    _throwIfProgrammed();
    lastSavedData = data;
    draft = data;
  }

  @override
  Future<void> completeCandidateOnboarding() async {
    calls.add('completeCandidateOnboarding');
    await _awaitPending();
    _throwIfProgrammed();
    onboardingCompleted = true;
  }

  @override
  Future<String> completeCompanyOnboarding(CompanyOnboardingData data) async {
    calls.add('completeCompanyOnboarding');
    completeCompanyCalls++;
    await _awaitPending();
    _throwIfProgrammed();
    lastCompanyData = data;
    onboardingCompleted = true;
    return companyId;
  }

  Future<void> _awaitPending() async {
    final pending = pendingAction;
    if (pending != null) {
      await pending.future;
    }
  }

  void _throwIfProgrammed() {
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
  }
}

/// Catálogos fijos para tests: dos provincias, localidades en cascada y
/// barrios solo en CABA (para probar la regla de barrio obligatorio).
class FakeCatalogRepository implements CatalogRepository {
  static const cabaProvinceId = 'prov-caba';
  static const baProvinceId = 'prov-ba';
  static const cabaLocalityId = 'loc-caba';
  static const laPlataLocalityId = 'loc-la-plata';
  static const palermoId = 'barrio-palermo';
  static const sanTelmoId = 'barrio-san-telmo';
  static const gastronomiaSectorId = 'sector-gastronomia';
  static const comercioSectorId = 'sector-comercio';

  final List<String> calls = [];
  DataFailure? nextFailure;

  @override
  Future<List<GeoProvince>> fetchProvinces() async {
    calls.add('fetchProvinces');
    _throwIfProgrammed();
    return const [
      GeoProvince(id: baProvinceId, name: 'Buenos Aires'),
      GeoProvince(id: cabaProvinceId, name: 'Ciudad Autónoma de Buenos Aires'),
    ];
  }

  @override
  Future<List<GeoLocality>> fetchLocalities(String provinceId) async {
    calls.add('fetchLocalities:$provinceId');
    _throwIfProgrammed();
    return switch (provinceId) {
      cabaProvinceId => const [
        GeoLocality(
          id: cabaLocalityId,
          name: 'Ciudad Autónoma de Buenos Aires',
        ),
      ],
      baProvinceId => const [
        GeoLocality(id: laPlataLocalityId, name: 'La Plata'),
      ],
      _ => const [],
    };
  }

  @override
  Future<List<GeoNeighborhood>> fetchNeighborhoods(String localityId) async {
    calls.add('fetchNeighborhoods:$localityId');
    _throwIfProgrammed();
    return switch (localityId) {
      cabaLocalityId => const [
        GeoNeighborhood(id: palermoId, name: 'Palermo'),
        GeoNeighborhood(id: sanTelmoId, name: 'San Telmo'),
      ],
      _ => const [],
    };
  }

  @override
  Future<List<Sector>> fetchSectors() async {
    calls.add('fetchSectors');
    _throwIfProgrammed();
    return const [
      Sector(
        id: gastronomiaSectorId,
        code: 'gastronomia_hoteleria',
        name: 'Gastronomía y hotelería',
      ),
      Sector(id: comercioSectorId, code: 'comercio', name: 'Comercio'),
    ];
  }

  void _throwIfProgrammed() {
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
  }
}

/// Doble de preferencias de notificaciones con upsert en memoria.
class FakeNotificationPrefsRepository implements NotificationPrefsRepository {
  final List<NotificationChannelPrefs> stored = [];
  final List<String> calls = [];
  DataFailure? nextFailure;

  @override
  Future<List<NotificationChannelPrefs>> fetchOwn() async {
    calls.add('fetchOwn');
    _throwIfProgrammed();
    return List.of(stored);
  }

  @override
  Future<void> save(List<NotificationChannelPrefs> prefs) async {
    calls.add('save');
    _throwIfProgrammed();
    for (final pref in prefs) {
      stored.removeWhere((row) => row.category == pref.category);
      stored.add(pref);
    }
  }

  void _throwIfProgrammed() {
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
  }
}

/// Documentos legales fijos.
class FakeLegalRepository implements LegalRepository {
  final List<String> calls = [];
  DataFailure? nextFailure;

  @override
  Future<LegalDocument> fetchCurrent(LegalSlug slug) async {
    calls.add('fetchCurrent:${slug.wireName}');
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
    return switch (slug) {
      LegalSlug.terms => const LegalDocument(
        slug: 'terminos',
        version: testConsentVersion,
        title: 'Términos y condiciones de TalentFlash',
        body:
            'AVISO: borrador de trabajo sin revisión legal.\n\n'
            '1. Qué es TalentFlash\n\nUna plataforma de empleo.',
      ),
      LegalSlug.privacy => const LegalDocument(
        slug: 'privacidad',
        version: testConsentVersion,
        title: 'Política de privacidad de TalentFlash',
        body:
            'AVISO: borrador de trabajo sin revisión legal.\n\n'
            '1. Quién trata tus datos\n\nTalentFlash Argentina.',
      ),
    };
  }
}
