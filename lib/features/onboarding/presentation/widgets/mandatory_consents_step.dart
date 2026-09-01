import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/gen/app_localizations.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../consents/domain/consent_snapshot.dart';
import '../../../consents/domain/consent_type.dart';

/// Paso de consentimientos obligatorios de ambos wizards (T-018).
///
/// El registro del Bloque B mostraba estas aceptaciones antes de existir una
/// sesión durable, así que acá se piden DE NUEVO y recién entonces se
/// persisten en `consents` con versión, fecha y canal: nunca se inventa una
/// aceptación que no se pueda probar. Lo ya registrado en su versión vigente
/// se muestra como hecho y no se vuelve a pedir.
class MandatoryConsentsStep extends StatefulWidget {
  const MandatoryConsentsStep({
    required this.snapshot,
    required this.isLoading,
    required this.onSubmit,
    super.key,
  });

  final ConsentSnapshot snapshot;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  State<MandatoryConsentsStep> createState() => _MandatoryConsentsStepState();
}

class _MandatoryConsentsStepState extends State<MandatoryConsentsStep> {
  final Set<ConsentType> _checked = {};
  bool _showErrors = false;

  List<ConsentRequirement> get _mandatory => [
    for (final requirement in widget.snapshot.requirements)
      if (requirement.isMandatory) requirement,
  ];

  bool _isPending(ConsentRequirement requirement) =>
      !widget.snapshot.isCurrentlyGranted(requirement.type);

  void _submit() {
    final pending = _mandatory.where(_isPending);
    final allChecked = pending.every((r) => _checked.contains(r.type));
    setState(() => _showErrors = !allChecked);
    if (allChecked) {
      widget.onSubmit();
    }
  }

  String _labelFor(AppLocalizations l10n, ConsentType type) => switch (type) {
    ConsentType.termsAcceptance => l10n.consentTermsLabel,
    ConsentType.dataProcessing => l10n.authSignUpConsentDataProcessing,
    ConsentType.ageDeclaration => l10n.authSignUpConsentAge,
    // Los opcionales jamás aparecen en este paso; si el catálogo trae algo
    // inesperado se muestra su descripción genérica de datos.
    ConsentType.videoProfilePublication => l10n.consentVideoLabel,
    ConsentType.aiFeatures => l10n.consentAiLabel,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.onboardingConsentsIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        for (final requirement in _mandatory)
          if (_isPending(requirement))
            ConsentCheckTile(
              value: _checked.contains(requirement.type),
              label: _labelFor(l10n, requirement.type),
              enabled: !widget.isLoading,
              showError: _showErrors && !_checked.contains(requirement.type),
              errorText: l10n.authErrorConsentRequired,
              onChanged: (value) => setState(() {
                if (value) {
                  _checked.add(requirement.type);
                } else {
                  _checked.remove(requirement.type);
                }
              }),
            )
          else
            CheckboxListTile(
              value: true,
              onChanged: null,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(
                _labelFor(l10n, requirement.type),
                style: theme.textTheme.bodyMedium,
              ),
              subtitle: Text(
                l10n.consentAlreadyAccepted,
                style: theme.textTheme.bodySmall,
              ),
            ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.pushNamed(AppRoute.legalTerms.name),
          child: Text(l10n.consentReadTerms),
        ),
        TextButton(
          onPressed: () => context.pushNamed(AppRoute.legalPrivacy.name),
          child: Text(l10n.consentReadPrivacy),
        ),
        const SizedBox(height: 16),
        ProgressButton(
          label: l10n.onboardingContinue,
          isLoading: widget.isLoading,
          onPressed: _submit,
        ),
      ],
    );
  }
}
