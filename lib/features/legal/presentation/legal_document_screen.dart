import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../domain/legal_document.dart';
import '../providers/legal_providers.dart';

/// Documento legal público (T-020): accesible también sin sesión, muestra la
/// versión vigente — la misma que se registra en `consents` al aceptar.
class LegalDocumentScreen extends ConsumerWidget {
  const LegalDocumentScreen({required this.slug, super.key});

  final LegalSlug slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(legalDocumentProvider(slug));
    final fallbackTitle = switch (slug) {
      LegalSlug.terms => l10n.legalTermsFallbackTitle,
      LegalSlug.privacy => l10n.legalPrivacyFallbackTitle,
    };

    return Scaffold(
      appBar: AppBar(title: Text(async.value?.title ?? fallbackTitle)),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MessageBanner.info(message: l10n.legalLoadError),
                    FilledButton(
                      onPressed: () =>
                          ref.invalidate(legalDocumentProvider(slug)),
                      child: Text(l10n.retryLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
          data: (document) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        document.title,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.legalVersionLabel(document.version),
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 16),
                    for (final paragraph in document.paragraphs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SelectableText(
                          paragraph,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
