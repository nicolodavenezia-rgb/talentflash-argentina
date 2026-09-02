import '../../features/authentication/domain/business_role.dart';

/// Catálogo único de rutas: nombre (el propio `name` del enum) y path.
///
/// Se navega **siempre por nombre**; los paths siguen la nomenclatura en
/// español de `UX_FLOWS.md` §1.1. Las sub-rutas de cada shell (`/candidato/feed`,
/// `/empresa/ofertas`, …) llegan con sus bloques del ROADMAP.
enum AppRoute {
  /// Splash de restauración de sesión: se muestra mientras no se sabe si hay
  /// sesión, para no parpadear contenido privado ni el login equivocado.
  splash('/inicio', null),

  /// Landing pública con selección de recorrido.
  welcome('/', null),

  login('/auth/login', null),

  /// Selección de tipo de cuenta (UX_FLOWS.md §1.1: `/auth/registro`).
  signupChooser('/auth/registro', null),
  signupCandidate('/auth/registro/candidato', null),
  signupCompany('/auth/registro/empresa', null),

  passwordRecovery('/auth/recuperar', null),

  candidateHome('/candidato', BusinessRole.candidate),
  companyHome('/empresa', BusinessRole.company),

  /// Perfil profesional del candidato (Bloque D, T-021/T-023/T-025).
  candidateProfile('/candidato/perfil', BusinessRole.candidate),
  candidateProfileEdit('/candidato/perfil/editar', BusinessRole.candidate),

  /// Vista limitada de un candidato para la empresa (T-024). El `:id` es el
  /// candidate_profile_id; la autorización real la decide el servidor
  /// (proyección fail-closed), el rol acá es solo UX.
  companyCandidateDetail('/empresa/candidatos/:id', BusinessRole.company),

  /// Wizards de onboarding (Bloque C). Mientras el onboarding no está
  /// completo, el guard 4 (UX_FLOWS.md §1.5) convierte estas rutas en la
  /// única pantalla disponible del shell.
  candidateOnboarding('/candidato/onboarding', BusinessRole.candidate),
  companyOnboarding('/empresa/onboarding', BusinessRole.company),

  /// Reconsentimiento (T-018): un texto obligatorio subió de versión y hay
  /// que volver a aceptarlo aunque `onboarding_completed` sea true.
  candidateReconsent('/candidato/consentimientos', BusinessRole.candidate),
  companyReconsent('/empresa/consentimientos', BusinessRole.company),

  /// Documentos legales (T-020): públicos, accesibles también sin sesión y
  /// SIEMPRE alcanzables, incluso con onboarding a medio hacer.
  legalTerms('/legal/terminos', null),
  legalPrivacy('/legal/privacidad', null),

  /// Panel admin (UX_FLOWS.md §1.4). En este bloque es solo el marcador de
  /// posición: existe para que un `admin` nunca se degrade a otro shell.
  adminHome('/admin', BusinessRole.admin),

  /// Sesión inconsistente o acceso no permitido.
  sessionIssue('/sesion-invalida', null);

  const AppRoute(this.path, this.requiredRole);

  final String path;

  /// `null` = ruta pública. Este requisito es **UX**: la autorización real la
  /// aplica RLS en Postgres (`SECURITY.md` §3).
  final BusinessRole? requiredRole;

  static AppRoute? forPath(String path) {
    // Primero igualdad exacta: una ruta literal nunca puede quedar capturada
    // por el patrón de otra ('/candidato/perfil/editar' vs. ':id').
    for (final route in AppRoute.values) {
      if (route.path == path) {
        return route;
      }
    }
    for (final route in AppRoute.values) {
      if (_matchesPattern(route.path, path)) {
        return route;
      }
    }
    return null;
  }

  /// Matcheo por segmentos para paths con parámetros (`:id`): mismo largo,
  /// segmentos literales idénticos y parámetros no vacíos.
  static bool _matchesPattern(String pattern, String path) {
    if (!pattern.contains('/:')) {
      return false;
    }
    final patternSegments = pattern.split('/');
    final pathSegments = path.split('/');
    if (patternSegments.length != pathSegments.length) {
      return false;
    }
    for (var i = 0; i < patternSegments.length; i++) {
      if (patternSegments[i].startsWith(':')) {
        if (pathSegments[i].isEmpty) {
          return false;
        }
      } else if (patternSegments[i] != pathSegments[i]) {
        return false;
      }
    }
    return true;
  }

  /// Shell inicial de cada rol.
  static AppRoute homeFor(BusinessRole role) => switch (role) {
    BusinessRole.candidate => AppRoute.candidateHome,
    BusinessRole.company => AppRoute.companyHome,
    BusinessRole.admin => AppRoute.adminHome,
  };

  /// Wizard de onboarding de cada rol. Admin no pasa por onboarding: se le
  /// asigna su home para que ningún guard pueda mandarlo a un wizard.
  static AppRoute onboardingFor(BusinessRole role) => switch (role) {
    BusinessRole.candidate => AppRoute.candidateOnboarding,
    BusinessRole.company => AppRoute.companyOnboarding,
    BusinessRole.admin => AppRoute.adminHome,
  };

  /// Pantalla de reconsentimiento de cada rol (ídem admin).
  static AppRoute reconsentFor(BusinessRole role) => switch (role) {
    BusinessRole.candidate => AppRoute.candidateReconsent,
    BusinessRole.company => AppRoute.companyReconsent,
    BusinessRole.admin => AppRoute.adminHome,
  };
}

/// Motivo por el que se muestra [AppRoute.sessionIssue]; viaja como query
/// param `motivo` para que la pantalla sea enlazable y testeable.
enum SessionIssueReason {
  /// Hay sesión pero el claim `app_metadata.role` falta o no es válido.
  invalidClaim('claim'),

  /// El rol es válido pero no habilita la sección pedida.
  notAllowed('sin-permiso'),

  /// La ruta no existe (errorBuilder de go_router).
  notFound('no-encontrada');

  const SessionIssueReason(this.queryValue);

  final String queryValue;

  static SessionIssueReason fromQuery(String? raw) {
    for (final reason in SessionIssueReason.values) {
      if (reason.queryValue == raw) {
        return reason;
      }
    }
    return SessionIssueReason.invalidClaim;
  }
}

/// Query params compartidos por el flujo de autenticación.
abstract final class AuthQueryParams {
  /// Ruta a la que volver después de autenticarse.
  static const destination = 'destino';

  /// Pista de recorrido (candidato/empresa) para el login; solo afecta el copy
  /// y el enlace de registro, nunca los permisos.
  static const roleHint = 'rol';

  static const issueReason = 'motivo';

  static const candidateHint = 'candidato';
  static const companyHint = 'empresa';
}
