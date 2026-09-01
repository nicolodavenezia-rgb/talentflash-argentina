import '../../consents/domain/consent_type.dart';

/// Estado de onboarding confiable, leído SIEMPRE de la base de datos
/// (`profiles.onboarding_completed` + estado vigente de `consents`): nunca de
/// estado local, query params ni `user_metadata`.
class OnboardingProgress {
  const OnboardingProgress({
    required this.completed,
    required this.pendingMandatoryConsents,
  });

  const OnboardingProgress.completedAndCurrent()
    : completed = true,
      pendingMandatoryConsents = const [];

  /// `profiles.onboarding_completed`. Solo lo escriben las RPC server-side.
  final bool completed;

  /// Consentimientos obligatorios sin otorgar en su versión vigente.
  final List<ConsentType> pendingMandatoryConsents;

  /// Onboarding sin terminar: el wizard del rol es la única pantalla del
  /// shell disponible.
  bool get needsWizard => !completed;

  /// Onboarding terminado pero con un texto obligatorio re-versionado: hay
  /// que volver a pedir la aceptación (T-018) antes de seguir.
  bool get needsReconsent => completed && pendingMandatoryConsents.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is OnboardingProgress &&
      other.completed == completed &&
      _sameTypes(other.pendingMandatoryConsents, pendingMandatoryConsents);

  @override
  int get hashCode =>
      Object.hash(completed, Object.hashAll(pendingMandatoryConsents));

  static bool _sameTypes(List<ConsentType> a, List<ConsentType> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}

/// Resolución del estado de onboarding para el router.
///
/// Igual que `AuthStatus`, es un tipo cerrado: la política de redirección
/// debe contemplar el caso "todavía no sé" y no puede mostrar contenido
/// privado mientras tanto (UX_FLOWS.md §1.5, guard 4).
sealed class OnboardingResolution {
  const OnboardingResolution();
}

/// No aplica onboarding: sin sesión, sesión inconsistente o rol admin.
final class OnboardingNotRequired extends OnboardingResolution {
  const OnboardingNotRequired();

  @override
  bool operator ==(Object other) => other is OnboardingNotRequired;

  @override
  int get hashCode => (OnboardingNotRequired).hashCode;
}

/// El estado se está cargando desde la base (o falló y espera reintento).
final class OnboardingResolving extends OnboardingResolution {
  const OnboardingResolving({this.failed = false});

  /// `true` si la última carga falló; la pantalla de carga ofrece reintentar.
  final bool failed;

  @override
  bool operator ==(Object other) =>
      other is OnboardingResolving && other.failed == failed;

  @override
  int get hashCode => Object.hash(OnboardingResolving, failed);
}

/// Estado conocido.
final class OnboardingReady extends OnboardingResolution {
  const OnboardingReady(this.progress);

  final OnboardingProgress progress;

  @override
  bool operator ==(Object other) =>
      other is OnboardingReady && other.progress == progress;

  @override
  int get hashCode => Object.hash(OnboardingReady, progress);
}
