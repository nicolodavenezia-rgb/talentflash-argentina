import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/supabase_client_provider.dart';
import '../../authentication/domain/auth_status.dart';
import '../../authentication/domain/business_role.dart';
import '../../authentication/providers/auth_providers.dart';
import '../../consents/providers/consents_providers.dart';
import '../data/catalog_repository.dart';
import '../data/onboarding_repository.dart';
import '../data/supabase_catalog_repository.dart';
import '../data/supabase_onboarding_repository.dart';
import '../domain/catalog.dart';
import '../domain/onboarding_progress.dart';

/// Repositorio de onboarding. En tests se sobreescribe con un fake.
final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return SupabaseOnboardingRepository(ref.watch(supabaseClientProvider));
});

/// Catálogos geo/sectores. En tests se sobreescribe con un fake.
final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return SupabaseCatalogRepository(ref.watch(supabaseClientProvider));
});

final provincesProvider = FutureProvider<List<GeoProvince>>((ref) {
  return ref.watch(catalogRepositoryProvider).fetchProvinces();
});

final localitiesProvider = FutureProvider.family<List<GeoLocality>, String>((
  ref,
  provinceId,
) {
  return ref.watch(catalogRepositoryProvider).fetchLocalities(provinceId);
});

final neighborhoodsProvider =
    FutureProvider.family<List<GeoNeighborhood>, String>((ref, localityId) {
      return ref
          .watch(catalogRepositoryProvider)
          .fetchNeighborhoods(localityId);
    });

final sectorsProvider = FutureProvider<List<Sector>>((ref) {
  return ref.watch(catalogRepositoryProvider).fetchSectors();
});

/// Resuelve el estado de onboarding para el router (guard 4 y 6 de
/// UX_FLOWS.md §1.5).
///
/// El estado se lee SIEMPRE de la base; mientras no se conoce, la política de
/// redirección deja a la persona en la pantalla de carga (nada privado se
/// dibuja). El notifier mantiene el valor anterior durante los `reload`
/// posteriores para no parpadear la pantalla de carga en cada refresco.
class OnboardingResolutionNotifier extends Notifier<OnboardingResolution> {
  int _loadId = 0;

  @override
  OnboardingResolution build() {
    // Un rebuild o dispose invalida cualquier carga en vuelo: su resultado ya
    // no corresponde a esta sesión.
    ref.onDispose(() => _loadId++);
    final status = ref.watch(authStatusProvider);
    switch (status) {
      case AuthStatusSignedIn(:final authUser)
          when authUser.role != BusinessRole.admin:
        _startLoad();
        return const OnboardingResolving();
      // Admin no pasa por onboarding; sin sesión (o inconsistente) tampoco.
      case AuthStatusSignedIn():
      case AuthStatusUnknown():
      case AuthStatusSignedOut():
      case AuthStatusInconsistent():
        _loadId++; // invalida cargas en vuelo de una sesión anterior
        return const OnboardingNotRequired();
    }
  }

  void _startLoad() {
    final id = ++_loadId;
    Future(() async {
      try {
        final progress = await _fetch();
        if (id == _loadId) {
          state = OnboardingReady(progress);
        }
      } catch (_) {
        if (id == _loadId) {
          state = const OnboardingResolving(failed: true);
        }
      }
    });
  }

  Future<OnboardingProgress> _fetch() async {
    final completed = await ref
        .read(onboardingRepositoryProvider)
        .fetchOnboardingCompleted();
    final snapshot = await ref.read(consentsRepositoryProvider).loadSnapshot();
    return OnboardingProgress(
      completed: completed,
      pendingMandatoryConsents: [
        for (final requirement in snapshot.pendingMandatory) requirement.type,
      ],
    );
  }

  /// Reintento manual desde la pantalla de carga.
  void retry() {
    if (state case OnboardingResolving(failed: true)) {
      state = const OnboardingResolving();
      _startLoad();
    }
  }

  /// Refresco en segundo plano (tras terminar un wizard o aceptar un
  /// reconsentimiento): conserva el estado actual hasta tener el nuevo, así
  /// no se vuelve a la pantalla de carga.
  Future<void> reload() async {
    final id = ++_loadId;
    try {
      final progress = await _fetch();
      if (id == _loadId) {
        state = OnboardingReady(progress);
      }
    } catch (_) {
      // Se conserva el estado anterior; el guard sigue siendo conservador.
    }
  }
}

final onboardingResolutionProvider =
    NotifierProvider<OnboardingResolutionNotifier, OnboardingResolution>(
      OnboardingResolutionNotifier.new,
    );
