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
import '../../features/companies/presentation/company_verification_screen.dart';
import '../../features/legal/domain/legal_document.dart';
import '../../features/legal/presentation/legal_document_screen.dart';
import '../../features/moderation/presentation/admin_home_screen.dart';
import '../../features/moderation/presentation/admin_verifications_screen.dart';
import '../../features/onboarding/presentation/candidate_onboarding_screen.dart';
import '../../features/onboarding/presentation/company_onboarding_screen.dart';
import '../../features/onboarding/presentation/reconsent_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/onboarding/providers/onboarding_providers.dart';
import '../../features/profiles/presentation/candidate_home_screen.dart';
import '../../features/profiles/presentation/candidate_profile_edit_screen.dart';
import '../../features/profiles/presentation/candidate_profile_screen.dart';
import '../../features/profiles/presentation/company_candidate_screen.dart';
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
  // El estado de onboarding también mueve al router (guard 4/6): terminar el
  // wizard o aceptar un reconsentimiento reevalúa la política sin recrearlo.
  ref.listen(onboardingResolutionProvider, (_, _) => refresh.onAuthChanged());

  final router = GoRouter(
    initialLocation: entryPoint.initialLocation,
    refreshListenable: refresh,
    redirect: (context, state) => resolveAuthRedirect(
      status: ref.read(authStatusProvider),
      entryPoint: entryPoint,
      location: state.uri,
      onboarding: ref.read(onboardingResolutionProvider),
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
        path: AppRoute.candidateProfile.path,
        name: AppRoute.candidateProfile.name,
        builder: (context, state) => const CandidateProfileScreen(),
      ),
      GoRoute(
        path: AppRoute.candidateProfileEdit.path,
        name: AppRoute.candidateProfileEdit.name,
        builder: (context, state) => const CandidateProfileEditScreen(),
      ),
      GoRoute(
        path: AppRoute.companyCandidateDetail.path,
        name: AppRoute.companyCandidateDetail.name,
        builder: (context, state) => CompanyCandidateScreen(
          candidateProfileId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoute.companyHome.path,
        name: AppRoute.companyHome.name,
        builder: (context, state) => const CompanyHomeScreen(),
      ),
      GoRoute(
        path: AppRoute.companyVerification.path,
        name: AppRoute.companyVerification.name,
        builder: (context, state) => const CompanyVerificationScreen(),
      ),
      GoRoute(
        path: AppRoute.candidateOnboarding.path,
        name: AppRoute.candidateOnboarding.name,
        builder: (context, state) => const CandidateOnboardingScreen(),
      ),
      GoRoute(
        path: AppRoute.companyOnboarding.path,
        name: AppRoute.companyOnboarding.name,
        builder: (context, state) => const CompanyOnboardingScreen(),
      ),
      GoRoute(
        path: AppRoute.candidateReconsent.path,
        name: AppRoute.candidateReconsent.name,
        builder: (context, state) => const ReconsentScreen(),
      ),
      GoRoute(
        path: AppRoute.companyReconsent.path,
        name: AppRoute.companyReconsent.name,
        builder: (context, state) => const ReconsentScreen(),
      ),
      GoRoute(
        path: AppRoute.legalTerms.path,
        name: AppRoute.legalTerms.name,
        builder: (context, state) =>
            const LegalDocumentScreen(slug: LegalSlug.terms),
      ),
      GoRoute(
        path: AppRoute.legalPrivacy.path,
        name: AppRoute.legalPrivacy.name,
        builder: (context, state) =>
            const LegalDocumentScreen(slug: LegalSlug.privacy),
      ),
      GoRoute(
        path: AppRoute.adminHome.path,
        name: AppRoute.adminHome.name,
        builder: (context, state) => const AdminHomeScreen(),
      ),
      GoRoute(
        path: AppRoute.adminVerifications.path,
        name: AppRoute.adminVerifications.name,
        builder: (context, state) => const AdminVerificationsScreen(),
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
