import 'dart:async';
import 'dart:typed_data';

import 'package:talentflash_argentina/features/companies/data/company_access_repository.dart';
import 'package:talentflash_argentina/features/onboarding/domain/candidate_onboarding_data.dart';
import 'package:talentflash_argentina/features/profiles/data/profile_repository.dart';
import 'package:talentflash_argentina/features/profiles/domain/avatar.dart';
import 'package:talentflash_argentina/features/profiles/domain/candidate_profile.dart';
import 'package:talentflash_argentina/features/profiles/domain/candidate_profile_patch.dart';
import 'package:talentflash_argentina/features/profiles/domain/candidate_public_profile.dart';
import 'package:talentflash_argentina/features/profiles/domain/weekly_availability.dart';

/// Perfil propio de utilería con datos completos y editables por parámetro.
CandidateProfile testCandidateProfile({
  String candidateProfileId = 'cand-prueba-id',
  String? fullName = 'Ana María Prueba',
  String? avatarPath,
  String? headline = 'Moza de salón con experiencia',
  String? bio = 'Cinco años en gastronomía porteña.',
  CatalogRef? province = const CatalogRef(id: 'prov-caba', name: 'CABA'),
  CatalogRef? locality = const CatalogRef(id: 'loc-caba', name: 'CABA'),
  CatalogRef? neighborhood = const CatalogRef(
    id: 'barrio-palermo',
    name: 'Palermo',
  ),
  SectorRef? sector = const SectorRef(
    id: 'sector-gastronomia',
    code: 'gastronomia_hoteleria',
    name: 'Gastronomía y hotelería',
  ),
  CandidateAvailability? availability = CandidateAvailability.inmediata,
  Set<CandidateWorkMode> workModes = const {CandidateWorkMode.presencial},
  ExperienceLevel? experienceLevel = ExperienceLevel.de1A3Anios,
  List<AvailabilitySlot> weeklyAvailability = const [],
  num? expectedSalaryMin,
  num? expectedSalaryMax,
  List<String> skills = const ['atención al cliente', 'caja', 'salón'],
  List<String> languages = const ['español'],
  List<WorkExperience> workHistory = const [
    WorkExperience(
      company: 'Parrilla de Prueba',
      position: 'Moza',
      fromMonth: '2021-03',
      toMonth: '2023-11',
    ),
  ],
  List<EducationEntry> education = const [],
  PresentationStatus presentationStatus = PresentationStatus.none,
  bool isPublished = true,
  bool applicationReady = true,
}) {
  return CandidateProfile(
    candidateProfileId: candidateProfileId,
    fullName: fullName,
    avatarPath: avatarPath,
    headline: headline,
    bio: bio,
    province: province,
    locality: locality,
    neighborhood: neighborhood,
    sector: sector,
    availability: availability,
    workModes: workModes,
    experienceLevel: experienceLevel,
    weeklyAvailability: weeklyAvailability,
    expectedSalaryMin: expectedSalaryMin,
    expectedSalaryMax: expectedSalaryMax,
    skills: skills,
    languages: languages,
    workHistory: workHistory,
    education: education,
    presentationStatus: presentationStatus,
    isPublished: isPublished,
    applicationReady: applicationReady,
  );
}

/// Proyección pública de utilería (whitelist de T-024).
CandidatePublicProfile testPublicProfile({
  String candidateProfileId = 'cand-prueba-id',
  String displayName = 'Ana',
  String? headline = 'Moza de salón con experiencia',
  String? bio = 'Cinco años en gastronomía porteña.',
  bool presentationAvailable = false,
  String? avatarPath,
  String? avatarThumbPath,
}) {
  return CandidatePublicProfile(
    candidateProfileId: candidateProfileId,
    displayName: displayName,
    headline: headline,
    bio: bio,
    provinceName: 'CABA',
    localityName: 'CABA',
    neighborhoodName: 'Palermo',
    sectorName: 'Gastronomía y hotelería',
    availability: CandidateAvailability.inmediata,
    workModes: const {CandidateWorkMode.presencial},
    experienceLevel: ExperienceLevel.de1A3Anios,
    weeklyAvailability: const [],
    skills: const ['atención al cliente'],
    languages: const ['español'],
    workHistory: const [
      WorkExperience(
        company: 'Parrilla de Prueba',
        position: 'Moza',
        fromMonth: '2021-03',
      ),
    ],
    education: const [],
    presentationAvailable: presentationAvailable,
    avatarPath: avatarPath,
    avatarThumbPath: avatarThumbPath,
  );
}

/// Doble de prueba del repositorio de perfiles.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({CandidateProfile? profile})
    : profile = profile ?? testCandidateProfile();

  CandidateProfile profile;

  /// Proyección devuelta a la empresa; null = no disponible (fail-closed).
  CandidatePublicProfile? publicProfile;

  final List<String> calls = <String>[];
  CandidateProfilePatch? lastPatch;
  Uint8List? lastUploadedBytes;
  String? lastUploadedContentType;

  /// Error a lanzar en la próxima acción (se consume al usarse).
  Object? nextFailure;

  /// Retiene la próxima acción hasta que el test la complete.
  Completer<void>? pendingAction;

  @override
  Future<CandidateProfile> fetchMyProfile() async {
    calls.add('fetchMyProfile');
    await _awaitPending();
    _throwIfProgrammed();
    return profile;
  }

  @override
  Future<void> updateMyProfile(CandidateProfilePatch patch) async {
    calls.add('updateMyProfile');
    lastPatch = patch;
    await _awaitPending();
    _throwIfProgrammed();
  }

  @override
  Future<CandidatePublicProfile?> fetchCandidatePublicProfile(
    String candidateProfileId,
  ) async {
    calls.add('fetchPublic:$candidateProfileId');
    await _awaitPending();
    _throwIfProgrammed();
    return publicProfile;
  }

  @override
  Future<String> createAvatarSignedUrl(
    String path, {
    int expiresInSeconds = 300,
  }) async {
    calls.add('signedUrl:$path@$expiresInSeconds');
    _throwIfProgrammed();
    return 'https://firmada.local/$path?vence=$expiresInSeconds';
  }

  @override
  Future<AvatarPaths> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async {
    calls.add('uploadAvatar');
    lastUploadedBytes = bytes;
    lastUploadedContentType = contentType;
    await _awaitPending();
    _throwIfProgrammed();
    return const AvatarPaths(
      avatarPath: 'cand-prueba-id/avatar.jpg',
      thumbPath: 'cand-prueba-id/thumb.jpg',
    );
  }

  @override
  Future<void> deleteAvatar() async {
    calls.add('deleteAvatar');
    await _awaitPending();
    _throwIfProgrammed();
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
      // ignore: only_throw_errors -- los fakes relanzan los failures tipados.
      throw failure;
    }
  }
}

/// Doble del acceso de la empresa a su propio estado de verificación.
class FakeCompanyAccessRepository implements CompanyAccessRepository {
  FakeCompanyAccessRepository({
    this.status = CompanyVerificationStatus.approved,
  });

  CompanyVerificationStatus? status;
  Object? nextFailure;
  final List<String> calls = <String>[];

  @override
  Future<CompanyVerificationStatus?> fetchOwnVerificationStatus() async {
    calls.add('fetchOwnVerificationStatus');
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      // ignore: only_throw_errors -- los fakes relanzan los failures tipados.
      throw failure;
    }
    return status;
  }
}

/// Selector de imagen falso: nunca abre UI nativa.
class FakeAvatarImagePicker implements AvatarImagePicker {
  PickedAvatarImage? next;
  int pickCount = 0;

  @override
  Future<PickedAvatarImage?> pickImage() async {
    pickCount++;
    return next;
  }
}
