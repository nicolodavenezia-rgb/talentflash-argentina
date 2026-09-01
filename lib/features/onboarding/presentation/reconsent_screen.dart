import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../authentication/providers/auth_controller.dart';
import '../../consents/domain/consent_type.dart';
import '../providers/reconsent_controller.dart';
import 'onboarding_copy.dart';
import 'widgets/wizard_scaffold.dart';

/// Reconsentimiento (T-018): un texto obligatorio subió de versión, así que
/// se vuelve a pedir la aceptación aunque el onboarding esté completo. El
/// guard 6 trae acá a la persona; al aceptar, el router la devuelve al shell.
class ReconsentScreen extends ConsumerStatefulWidget {
  const ReconsentScreen({super.key});

  @override
  ConsumerState<ReconsentScreen> createState() => _ReconsentScreenState();
}

class _ReconsentScreenState extends ConsumerState<ReconsentScreen> {
  final Set<ConsentType> _checked = {};
  bool _showErrors = false;

  String _labelFor(AppLocalizations l10n, ConsentType type) => switch (type) {
    ConsentType.termsAcceptance => l10n.consentTermsLabel,
    ConsentType.dataProcessing => l10n.authSignUpConsentDataProcessing,
    ConsentType.ageDeclaration => l10n.authSignUpConsentAge,
    ConsentType.videoProfilePublication => l10n.consentVideoLabel,
    ConsentType.aiFeatures => l10n.consentAiLabel,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(reconsentControllerProvider);
    final authLoading = ref.watch(authControllerProvider).isLoading;

    return async.when(
      skipLoadingOnReload: true,
      loading: () => WizardLoadingView(title: l10n.reconsentTitle),
      error: (error, stackTrace) => WizardErrorView(
        title: l10n.reconsentTitle,
        onRetry: () => ref.invalidate(reconsentControllerProvider),
      ),
      data: (state) {
        final pending = state.pending;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.reconsentTitle)),
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
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.reconsentTitle,
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.reconsentBody,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      if (state.failure != null)
                        MessageBanner.error(
                          title: l10n.onboardingErrorTitle,
                          message: OnboardingCopy.failure(l10n, state.failure!),
                        ),
                      for (final requirement in pending)
                        ConsentCheckTile(
                          value: _checked.contains(requirement.type),
                          label: _labelFor(l10n, requirement.type),
                          enabled: !state.submitting,
                          showError:
                              _showErrors &&
                              !_checked.contains(requirement.type),
                          errorText: l10n.authErrorConsentRequired,
                          onChanged: (value) => setState(() {
                            if (value) {
                              _checked.add(requirement.type);
                            } else {
                              _checked.remove(requirement.type);
                            }
                          }),
                        ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () =>
                            context.pushNamed(AppRoute.legalTerms.name),
                        child: Text(l10n.consentReadTerms),
                      ),
                      TextButton(
                        onPressed: () =>
                            context.pushNamed(AppRoute.legalPrivacy.name),
                        child: Text(l10n.consentReadPrivacy),
                      ),
                      const SizedBox(height: 16),
                      ProgressButton(
                        label: l10n.reconsentAccept,
                        isLoading: state.submitting,
                        onPressed: () {
                          final allChecked = pending.every(
                            (r) => _checked.contains(r.type),
                          );
                          setState(() => _showErrors = !allChecked);
                          if (allChecked) {
                            ref
                                .read(reconsentControllerProvider.notifier)
                                .acceptPending();
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: authLoading
                            ? null
                            : () => ref
                                  .read(authControllerProvider.notifier)
                                  .signOut(),
                        child: Text(l10n.authSignOut),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
