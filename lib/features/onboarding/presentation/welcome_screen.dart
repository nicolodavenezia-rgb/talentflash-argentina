import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/routing/app_router.dart';

/// Pantalla de bienvenida con selección de rol (UX_FLOWS.md §1).
/// Punto de entrada de los dos recorridos: candidato y empresa.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.welcomeHeadline,
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.welcomeSubtitle,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.roleQuestion,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _RoleButton(
                    title: l10n.roleCandidateTitle,
                    subtitle: l10n.roleCandidateSubtitle,
                    semanticsLabel: l10n.roleCandidateSemantics,
                    icon: Icons.person_outline,
                    onPressed: () => context.goNamed(RouteNames.candidateHome),
                  ),
                  const SizedBox(height: 12),
                  _RoleButton(
                    title: l10n.roleCompanyTitle,
                    subtitle: l10n.roleCompanySubtitle,
                    semanticsLabel: l10n.roleCompanySemantics,
                    icon: Icons.storefront_outlined,
                    onPressed: () => context.goNamed(RouteNames.companyHome),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.title,
    required this.subtitle,
    required this.semanticsLabel,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String semanticsLabel;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Un solo nodo semántico por tarjeta (UX_FLOWS.md §20 — feeds/tarjetas).
    return Semantics(
      label: semanticsLabel,
      button: true,
      excludeSemantics: true,
      child: FilledButton.tonal(
        onPressed: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
