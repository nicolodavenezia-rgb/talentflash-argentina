import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import 'widgets/auth_form_widgets.dart';

/// Selección de tipo de cuenta (`UX_FLOWS.md` §1.1 — `/auth/registro`).
///
/// Bifurca al alta de candidato o de empresa. Es la única forma de elegir rol:
/// no existe un campo libre donde pedir otro valor.
class AccountTypeScreen extends StatelessWidget {
  const AccountTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthScreenLayout(
      title: l10n.authAccountTypeTitle,
      subtitle: l10n.authAccountTypeSubtitle,
      children: [
        _AccountTypeButton(
          title: l10n.roleCandidateTitle,
          subtitle: l10n.roleCandidateSubtitle,
          semanticsLabel: l10n.roleCandidateSemantics,
          icon: Icons.person_outline,
          onPressed: () => context.goNamed(AppRoute.signupCandidate.name),
        ),
        const SizedBox(height: 12),
        _AccountTypeButton(
          title: l10n.roleCompanyTitle,
          subtitle: l10n.roleCompanySubtitle,
          semanticsLabel: l10n.roleCompanySemantics,
          icon: Icons.storefront_outlined,
          onPressed: () => context.goNamed(AppRoute.signupCompany.name),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => context.goNamed(AppRoute.login.name),
          child: Text(l10n.authGoToLogin),
        ),
      ],
    );
  }
}

class _AccountTypeButton extends StatelessWidget {
  const _AccountTypeButton({
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
    // Un solo nodo semántico por tarjeta (UX_FLOWS.md §20).
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
