import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../domain/auth_status.dart';
import '../providers/auth_controller.dart';
import '../providers/auth_providers.dart';

/// Pantalla de salida segura: sesión con rol ilegible, sección no permitida o
/// ruta inexistente.
///
/// Nunca "arregla" el problema eligiendo un rol: ofrece cerrar sesión o volver
/// al inicio propio. La autorización real siempre la aplica RLS
/// (`SECURITY.md` §3).
class SessionIssueScreen extends ConsumerWidget {
  const SessionIssueScreen({required this.reason, super.key});

  final SessionIssueReason reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = ref.watch(authStatusProvider);
    final role = status.role;
    // A esta pantalla también se llega por una ruta inexistente sin sesión: en
    // ese caso ofrecer "cerrar sesión" no tendría sentido.
    final hasSession =
        status is AuthStatusSignedIn || status is AuthStatusInconsistent;
    final isLoading = ref.watch(authControllerProvider).isLoading;

    final (title, body) = switch (reason) {
      SessionIssueReason.invalidClaim => (
        l10n.authSessionIssueClaimTitle,
        l10n.authSessionIssueClaimBody,
      ),
      SessionIssueReason.notAllowed => (
        l10n.authSessionIssueNotAllowedTitle,
        l10n.authSessionIssueNotAllowedBody,
      ),
      SessionIssueReason.notFound => (
        l10n.authSessionIssueNotFoundTitle,
        l10n.authSessionIssueNotFoundBody,
      ),
    };

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
                  Semantics(
                    header: true,
                    child: Text(title, style: theme.textTheme.headlineSmall),
                  ),
                  const SizedBox(height: 12),
                  Text(body, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 32),
                  // Con rol válido se puede volver al shell propio; sin rol
                  // confiable la única salida es cerrar sesión.
                  if (role != null)
                    FilledButton(
                      onPressed: isLoading
                          ? null
                          : () => context.goNamed(AppRoute.homeFor(role).name),
                      child: Text(l10n.authGoHome),
                    ),
                  if (role != null) const SizedBox(height: 12),
                  if (hasSession)
                    OutlinedButton(
                      onPressed: isLoading
                          ? null
                          : () => ref
                                .read(authControllerProvider.notifier)
                                .signOut(),
                      child: Text(l10n.authSignOut),
                    )
                  else
                    OutlinedButton(
                      // `/inicio` reevalúa la política y manda a la pantalla
                      // de arranque que corresponde a este binario.
                      onPressed: () => context.goNamed(AppRoute.splash.name),
                      child: Text(l10n.authGoToStart),
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
