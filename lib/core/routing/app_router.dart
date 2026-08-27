import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/data/auth_repository.dart';
import '../../features/authentication/presentation/account_type_screen.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/authentication/presentation/password_recovery_screen.dart';
import '../../features/authentication/presentation/session_issue_screen.dart';
import '../../features/authentication/presentation/session_loading_screen.dart';
import '../../features/authentication/presentation/sign_up_screen.dart';
import '../../features/authentication/providers/auth_providers.dart';
import '../../features/companies/presentation/company_home_screen.dart';
import '../../features/moderation/presentation/admin_home_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/profiles/presentation/candidate_home_screen.dart';
import 'app_entry_point.dart';
import 'app_routes.dart';
import 'auth_redirect.dart';

/// Puente entre Riverpod y `GoRouter.refreshListenable`.
///
/// Permite que el router se **refresque** ante un cambio de sesión sin
/// recrearse: con `ref.watch` se construiría un GoRouter nuevo por cada evento
/// de auth y se perdería la pila de navegación.
class _AuthRefreshNotifier extends ChangeNotifier {
  void onAuthChanged() => notifyListeners();
}

/// Router único de la app (una sola instancia por `ProviderScope`).
final appRouterProvider = Provider<GoRouter>((ref) {
  final entryPoint = ref.watch(appEntryPointProvider);
  final refresh = _AuthRefreshNotifier();
  ref.listen(authStatusProvider, (_, _) => refresh.onAuthChanged());

  final router = GoRouter(
    initialLocation: entryPoint.initialLocation,
    refreshListenable: refresh,
    redirect: (context, state) => resolveAuthRedirect(
      status: ref.read(authStatusProvider),
      entryPoint: entryPoint,
      location: state.uri,
    ),
    routes: [
      GoRoute(
        path: AppRoute.splash.path,
        name: AppRoute.splash.name,
        builder: (context, state) => const SessionLoadingScreen(),
      ),
      GoRoute(
        path: AppRoute.welcome.path,
        name: AppRoute.welcome.name,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoute.login.path,
        name: AppRoute.login.name,
        builder: (context, state) => LoginScreen(
          roleHint: state.uri.queryParameters[AuthQueryParams.roleHint],
        ),
      ),
      GoRoute(
        path: AppRoute.signupChooser.path,
        name: AppRoute.signupChooser.name,
        builder: (context, state) => const AccountTypeScreen(),
      ),
      GoRoute(
        path: AppRoute.signupCandidate.path,
        name: AppRoute.signupCandidate.name,
        builder: (context, state) =>
            const SignUpScreen(role: SignUpRole.candidate),
      ),
      GoRoute(
        path: AppRoute.signupCompany.path,
        name: AppRoute.signupCompany.name,
        builder: (context, state) =>
            const SignUpScreen(role: SignUpRole.company),
      ),
      GoRoute(
        path: AppRoute.passwordRecovery.path,
        name: AppRoute.passwordRecovery.name,
        builder: (context, state) => const PasswordRecoveryScreen(),
      ),
      GoRoute(
        path: AppRoute.candidateHome.path,
        name: AppRoute.candidateHome.name,
        builder: (context, state) => const CandidateHomeScreen(),
      ),
      GoRoute(
        path: AppRoute.companyHome.path,
        name: AppRoute.companyHome.name,
        builder: (context, state) => const CompanyHomeScreen(),
      ),
      GoRoute(
        path: AppRoute.adminHome.path,
        name: AppRoute.adminHome.name,
        builder: (context, state) => const AdminHomeScreen(),
      ),
      GoRoute(
        path: AppRoute.sessionIssue.path,
        name: AppRoute.sessionIssue.name,
        builder: (context, state) => SessionIssueScreen(
          reason: SessionIssueReason.fromQuery(
            state.uri.queryParameters[AuthQueryParams.issueReason],
          ),
        ),
      ),
    ],
    errorBuilder: (context, state) =>
        const SessionIssueScreen(reason: SessionIssueReason.notFound),
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
