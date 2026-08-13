import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/routing/app_router.dart';

/// Punto de entrada del candidato. Placeholder del Bloque A: el feed de
/// ofertas llega en el Bloque G (ROADMAP.md).
class CandidateHomeScreen extends StatelessWidget {
  const CandidateHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.candidateHomeTitle),
        leading: BackButton(
          onPressed: () => context.goNamed(RouteNames.welcome),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.candidateHomePlaceholder,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
