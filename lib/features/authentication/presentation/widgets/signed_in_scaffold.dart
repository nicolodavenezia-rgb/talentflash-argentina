import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/gen/app_localizations.dart';
import '../../providers/auth_controller.dart';
import '../../providers/auth_providers.dart';

/// Andamiaje común de los shells autenticados de este bloque.
///
/// Muestra quién tiene la sesión y ofrece cerrarla. Cada shell reemplazará el
/// cuerpo por su navegación propia en los bloques siguientes del ROADMAP.
class SignedInScaffold extends ConsumerWidget {
  const SignedInScaffold({
    required this.title,
    required this.placeholder,
    this.children = const [],
    super.key,
  });

  final String title;
  final String placeholder;

  /// Accesos del shell debajo del texto (p. ej. "Mi perfil" en el home del
  /// candidato) hasta que llegue la navegación real de cada bloque.
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(currentAuthUserProvider);
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.authSignOut,
            onPressed: isLoading
                ? null
                : () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (user != null)
                    Text(
                      l10n.signedInAs(user.email),
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 16),
                  Text(
                    placeholder,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (children.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    ...children,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
