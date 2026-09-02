import 'dart:typed_data';

import '../domain/candidate_profile.dart';
import '../domain/candidate_profile_patch.dart';
import '../domain/candidate_public_profile.dart';

/// Paths canónicos del avatar recién subido.
class AvatarPaths {
  const AvatarPaths({required this.avatarPath, required this.thumbPath});

  final String avatarPath;
  final String thumbPath;
}

/// Frontera de la feature de perfiles (T-021…T-024): ninguna pantalla ni
/// notifier toca el SDK de Supabase; todo pasa por acá (ARCHITECTURE.md §2).
abstract interface class ProfileRepository {
  /// Perfil propio completo (`get_my_candidate_profile`).
  Future<CandidateProfile> fetchMyProfile();

  /// Aplica un parche al perfil propio (`update_my_candidate_profile`).
  Future<void> updateMyProfile(CandidateProfilePatch patch);

  /// Proyección pública de un candidato para la empresa (T-024).
  /// Devuelve null (indistinguible de "no existe") si el caller no puede
  /// verlo: fail-closed, la decisión es 100% server-side.
  Future<CandidatePublicProfile?> fetchCandidatePublicProfile(
    String candidateProfileId,
  );

  /// URL firmada de corta duración para un path del bucket `avatars`.
  /// La URL vence sola (T-022): nunca se persiste, se renueva al mostrar.
  Future<String> createAvatarSignedUrl(String path, {int expiresInSeconds});

  /// Sube (o reemplaza) el avatar vía la Edge Function `avatar`, que valida
  /// magic bytes, re-encodea sin metadata y genera el thumbnail.
  Future<AvatarPaths> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
  });

  /// Elimina avatar y thumbnail (idempotente).
  Future<void> deleteAvatar();
}
