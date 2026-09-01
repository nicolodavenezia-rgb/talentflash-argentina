import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../onboarding/domain/onboarding_progress.dart';
import '../../onboarding/providers/onboarding_providers.dart';

/// Pantalla del arranque: se muestra mientras la sesión —o el estado de
/// onboarding— todavía no se resolvió.
///
/// No contiene nada privado y no decide nada: existe para que el primer frame
/// no muestre ni contenido de una sesión que quizá no exista ni el login de
/// alguien que sí la tiene (UX_FLOWS.md §1.5). Si la carga del estado de
/// onboarding falla (p. ej. sin red), ofrece reintentar en vez de colgarse.
class SessionLoadingScreen extends ConsumerWidget {
  const SessionLoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final onboarding = ref.watch(onboardingResolutionProvider);
    final loadFailed = switch (onboarding) {
      OnboardingResolving(failed: true) => true,
      _ => false,
    };
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!loadFailed) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.authLoadingSession,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ] else ...[
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    l10n.sessionLoadFailedBody,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () =>
                    ref.read(onboardingResolutionProvider.notifier).retry(),
                child: Text(l10n.retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
