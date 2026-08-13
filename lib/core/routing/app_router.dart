import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/companies/presentation/company_home_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/profiles/presentation/candidate_home_screen.dart';

/// Nombres de ruta centralizados: navegar siempre por nombre, nunca por string.
abstract final class RouteNames {
  static const welcome = 'welcome';
  static const candidateHome = 'candidateHome';
  static const companyHome = 'companyHome';
}

/// Router del Bloque A: bienvenida + puntos de entrada candidato/empresa.
/// Los guards de sesión y rol llegan con la autenticación (Bloque B, T-011+).
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: RouteNames.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/candidato',
        name: RouteNames.candidateHome,
        builder: (context, state) => const CandidateHomeScreen(),
      ),
      GoRoute(
        path: '/empresa',
        name: RouteNames.companyHome,
        builder: (context, state) => const CompanyHomeScreen(),
      ),
    ],
  );
});
