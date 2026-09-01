import 'package:flutter/material.dart';

import '../../../../core/localization/gen/app_localizations.dart';
import '../../../../shared/widgets/feedback_widgets.dart';

/// Estructura común de los pasos del wizard: ancho de lectura acotado, scroll
/// propio, título de pantalla + título de paso como encabezados semánticos y
/// progreso "Paso X de Y" anunciado por el lector (UX_FLOWS.md §20).
class WizardScaffold extends StatelessWidget {
  const WizardScaffold({
    required this.title,
    required this.stepTitle,
    required this.stepNumber,
    required this.stepCount,
    required this.children,
    this.onBack,
    super.key,
  });

  final String title;
  final String stepTitle;
  final int stepNumber;
  final int stepCount;
  final List<Widget> children;

  /// Volver al paso anterior; `null` en el primero.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stepLabel = l10n.onboardingStepLabel(stepNumber, stepCount);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: onBack == null ? null : BackButton(onPressed: onBack),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(stepLabel, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Semantics(
                    header: true,
                    child: Text(
                      stepTitle,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Carga inicial del wizard: nunca se dibuja contenido del shell mientras el
/// avance guardado no llegó de la base.
class WizardLoadingView extends StatelessWidget {
  const WizardLoadingView({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const SafeArea(child: Center(child: CircularProgressIndicator())),
    );
  }
}

/// Error al cargar el avance del wizard, con reintento accesible.
class WizardErrorView extends StatelessWidget {
  const WizardErrorView({
    required this.title,
    required this.onRetry,
    super.key,
  });

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MessageBanner.info(message: l10n.sessionLoadFailedBody),
                  FilledButton(
                    onPressed: onRetry,
                    child: Text(l10n.retryLabel),
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
