import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/supabase_client_provider.dart';
import '../../companies/data/company_access_repository.dart';
import '../../companies/data/supabase_company_access_repository.dart';
import '../data/file_selector_avatar_picker.dart';
import '../data/profile_repository.dart';
import '../data/supabase_profile_repository.dart';
import '../domain/avatar.dart';
import '../domain/candidate_profile.dart';
import '../domain/candidate_public_profile.dart';

/// Repositorio de perfiles. En tests se sobreescribe con un fake.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return SupabaseProfileRepository(ref.watch(supabaseClientProvider));
});

/// Selector de imagen del avatar, inyectable para tests de widgets.
final avatarImagePickerProvider = Provider<AvatarImagePicker>(
  (ref) => const FileSelectorAvatarPicker(),
);

/// Acceso de la empresa a su propio estado de verificación.
final companyAccessRepositoryProvider = Provider<CompanyAccessRepository>((
  ref,
) {
  return SupabaseCompanyAccessRepository(ref.watch(supabaseClientProvider));
});

/// Perfil propio del candidato. Se refresca tras cada guardado.
class MyProfileController extends AsyncNotifier<CandidateProfile> {
  @override
  Future<CandidateProfile> build() {
    return ref.watch(profileRepositoryProvider).fetchMyProfile();
  }

  /// Recarga sin descartar el valor anterior (evita parpadeos de pantalla).
  Future<void> refresh() async {
    final previous = state;
    final next = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).fetchMyProfile(),
    );
    // Si la recarga falla se conserva lo último conocido: la pantalla propia
    // nunca "pierde" el perfil por un corte puntual de red.
    state = next.hasError && previous.hasValue ? previous : next;
  }
}

final myProfileProvider =
    AsyncNotifierProvider<MyProfileController, CandidateProfile>(
      MyProfileController.new,
    );

/// URL firmada de corta vida para un path del bucket de avatares.
/// autoDispose: al salir de la pantalla se descarta y se renueva al volver.
final avatarSignedUrlProvider = FutureProvider.autoDispose
    .family<String, String>((ref, path) {
      return ref.watch(profileRepositoryProvider).createAvatarSignedUrl(path);
    });

/// Proyección pública de un candidato (vista empresa, T-024).
final candidatePublicProfileProvider = FutureProvider.autoDispose
    .family<CandidatePublicProfile?, String>((ref, candidateProfileId) {
      return ref
          .watch(profileRepositoryProvider)
          .fetchCandidatePublicProfile(candidateProfileId);
    });

/// Estado de verificación de la empresa del caller (para explicar el estado
/// "pendiente" con datos PROPIOS, nunca del candidato).
final ownCompanyVerificationProvider =
    FutureProvider.autoDispose<CompanyVerificationStatus?>((ref) {
      return ref
          .watch(companyAccessRepositoryProvider)
          .fetchOwnVerificationStatus();
    });
