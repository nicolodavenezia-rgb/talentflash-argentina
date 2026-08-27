import 'package:flutter/material.dart';

import '../../../core/localization/gen/app_localizations.dart';

/// Pantalla del arranque: se muestra mientras la sesión todavía no se resolvió.
///
/// No contiene nada privado y no decide nada: existe para que el primer frame
/// no muestre ni contenido de una sesión que quizá no exista ni el login de
/// alguien que sí la tiene (UX_FLOWS.md §1.5).
class SessionLoadingScreen extends StatelessWidget {
  const SessionLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
          ],
        ),
      ),
    );
  }
}
