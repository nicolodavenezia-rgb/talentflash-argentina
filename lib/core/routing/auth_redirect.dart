import '../../features/authentication/domain/auth_status.dart';
import '../../features/authentication/domain/business_role.dart';
import '../../features/onboarding/domain/onboarding_progress.dart';
import 'app_entry_point.dart';
import 'app_routes.dart';

/// Política de redirección del router, aislada como función pura para poder
/// probar cada regla sin levantar widgets ni Supabase.
///
/// **Los guards son UX, no seguridad.** Evitan que alguien vea una pantalla que
/// no le corresponde; lo que impide realmente leer o escribir datos ajenos son
/// las policies RLS (`SECURITY.md` §3, `ARCHITECTURE.md` §3.2). El estado de
/// onboarding que recibe viene de la base de datos, nunca de estado local.
///
/// Devuelve `null` cuando la ubicación actual es correcta (go_router entiende
/// `null` como "quedate donde estás"), o el destino al que hay que ir.
String? resolveAuthRedirect({
  required AuthStatus status,
  required AppEntryPoint entryPoint,
  required Uri location,
  required OnboardingResolution onboarding,
}) {
  final path = location.path;
  final destination = sanitizeDestination(
    location.queryParameters[AuthQueryParams.destination],
  );

  switch (status) {
    // 1. Todavía no se sabe si hay sesión: nadie se mueve de la pantalla de
    //    carga, y se recuerda a dónde quería ir.
    case AuthStatusUnknown():
      if (path == AppRoute.splash.path) {
        return null;
      }
      return _splashWith(sanitizeDestination(location.toString()));

    // 2. Sesión con rol ilegible: estado seguro, sin adivinar rol.
    case AuthStatusInconsistent():
      if (path == AppRoute.sessionIssue.path) {
        return null;
      }
      return _sessionIssue(SessionIssueReason.invalidClaim);

    // 3. Sin sesión: solo rutas públicas; el resto vuelve al login guardando
    //    el destino pretendido.
    case AuthStatusSignedOut():
      if (path == AppRoute.splash.path || path == AppRoute.sessionIssue.path) {
        return _startForSignedOut(entryPoint, destination);
      }
      final route = AppRoute.forPath(path);
      if (route == null || route.requiredRole == null) {
        return null;
      }
      return _loginWith(
        entryPoint: entryPoint,
        destination: _locationWithoutDestination(location),
      );

    // 4. Sesión válida.
    case AuthStatusSignedIn(:final authUser):
      final role = authUser.role;
      final home = AppRoute.homeFor(role).path;
      if (path == AppRoute.sessionIssue.path) {
        // Pantalla informativa: se llega acá a propósito y se sale con un
        // botón, nunca con un rebote automático que parezca un bug.
        return null;
      }
      // 4.a Gate de onboarding (guards 4 y 6 de UX_FLOWS.md §1.5). Admin no
      //     pasa por onboarding, y las rutas legales quedan alcanzables
      //     siempre: el wizard enlaza a los textos que se están aceptando.
      if (role != BusinessRole.admin && !_isLegalPath(path)) {
        switch (onboarding) {
          case OnboardingResolving():
            // Todavía no se sabe si falta onboarding: nada del shell se
            // dibuja mientras tanto (misma regla que la sesión sin resolver).
            if (path == AppRoute.splash.path) {
              return null;
            }
            return _splashWith(sanitizeDestination(location.toString()));
          case OnboardingReady(:final progress) when progress.needsWizard:
            final wizard = AppRoute.onboardingFor(role).path;
            return path == wizard ? null : wizard;
          case OnboardingReady(:final progress) when progress.needsReconsent:
            final reconsent = AppRoute.reconsentFor(role).path;
            return path == reconsent ? null : reconsent;
          case OnboardingReady():
            // Completo: el wizard y el reconsentimiento dejan de ser
            // destinos válidos (evita loops y pantallas sin propósito).
            if (path == AppRoute.onboardingFor(role).path ||
                path == AppRoute.reconsentFor(role).path) {
              return home;
            }
          case OnboardingNotRequired():
            break;
        }
      }
      if (path == AppRoute.splash.path ||
          path == AppRoute.welcome.path ||
          _isAuthPath(path)) {
        if (destination != null &&
            _isReachableWhileSignedIn(destination, role)) {
          return destination;
        }
        return home;
      }
      final route = AppRoute.forPath(path);
      final required = route?.requiredRole;
      if (required == null || required == role) {
        return null;
      }
      if (required == BusinessRole.admin) {
        // Intentar entrar al panel admin sin serlo se responde explícito, no
        // con un rebote silencioso.
        return _sessionIssue(SessionIssueReason.notAllowed);
      }
      // Cruce entre los dos shells pares: vuelve al propio (UX_FLOWS.md §1.5).
      return home;
  }
}

/// Acepta solo rutas internas de la app que valga la pena recuperar.
///
/// Rechaza URLs absolutas y protocol-relative (`//host`) para que el parámetro
/// `destino` no sirva de redirección abierta, y descarta las pantallas que no
/// son un destino útil: la de carga, la de sesión inválida y el landing.
String? sanitizeDestination(String? raw) {
  if (raw == null ||
      raw.isEmpty ||
      !raw.startsWith('/') ||
      raw.startsWith('//')) {
    return null;
  }
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.hasScheme || uri.hasAuthority) {
    return null;
  }
  if (uri.path == AppRoute.splash.path ||
      uri.path == AppRoute.sessionIssue.path ||
      uri.path == AppRoute.welcome.path) {
    return null;
  }
  return raw;
}

/// Una vez autenticado, no tiene sentido "volver" al login ni al landing.
bool _isReachableWhileSignedIn(String destination, BusinessRole role) {
  final path = Uri.parse(destination).path;
  if (_isAuthPath(path) || path == AppRoute.welcome.path) {
    return false;
  }
  final required = AppRoute.forPath(path)?.requiredRole;
  return required == null || required == role;
}

bool _isAuthPath(String path) => path.startsWith('/auth');

/// Los documentos legales (T-020) se pueden leer siempre: sin sesión, con el
/// onboarding a medio hacer o durante un reconsentimiento.
bool _isLegalPath(String path) => path.startsWith('/legal');

String _splashWith(String? destination) {
  if (destination == null) {
    return AppRoute.splash.path;
  }
  return Uri(
    path: AppRoute.splash.path,
    queryParameters: {AuthQueryParams.destination: destination},
  ).toString();
}

String _sessionIssue(SessionIssueReason reason) => Uri(
  path: AppRoute.sessionIssue.path,
  queryParameters: {AuthQueryParams.issueReason: reason.queryValue},
).toString();

/// A dónde mandar a alguien sin sesión que cae en el splash o sale de la
/// pantalla de sesión inconsistente.
String _startForSignedOut(AppEntryPoint entryPoint, String? destination) {
  if (destination != null) {
    final destinationPath = Uri.parse(destination).path;
    final route = AppRoute.forPath(destinationPath);
    final isPublic = route == null || route.requiredRole == null;
    if (isPublic) {
      return destination;
    }
    return _loginWith(entryPoint: entryPoint, destination: destination);
  }
  return switch (entryPoint) {
    // Los binarios de candidato y empresa abren directo su flujo de
    // autenticación; el binario general muestra la bienvenida.
    AppEntryPoint.chooser => AppRoute.welcome.path,
    AppEntryPoint.candidate ||
    AppEntryPoint.company => _loginWith(entryPoint: entryPoint),
  };
}

String _loginWith({required AppEntryPoint entryPoint, String? destination}) {
  final hint = roleHintFor(entryPoint);
  final query = <String, String>{
    AuthQueryParams.roleHint: ?hint,
    AuthQueryParams.destination: ?destination,
  };
  if (query.isEmpty) {
    return AppRoute.login.path;
  }
  return Uri(path: AppRoute.login.path, queryParameters: query).toString();
}

/// Pista de recorrido según el binario. Solo cambia el copy y el enlace de
/// registro del login.
String? roleHintFor(AppEntryPoint entryPoint) => switch (entryPoint) {
  AppEntryPoint.chooser => null,
  AppEntryPoint.candidate => AuthQueryParams.candidateHint,
  AppEntryPoint.company => AuthQueryParams.companyHint,
};

String _locationWithoutDestination(Uri location) {
  final query = Map<String, String>.from(location.queryParameters)
    ..remove(AuthQueryParams.destination);
  if (query.isEmpty) {
    return location.path;
  }
  return Uri(path: location.path, queryParameters: query).toString();
}
