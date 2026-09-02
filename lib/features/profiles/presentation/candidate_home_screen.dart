import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../authentication/presentation/widgets/signed_in_scaffold.dart';

/// Shell del candidato. Ruta privada: solo la alcanza una sesión con rol
/// `candidate` (el guard es UX; la autorización real es RLS).
/// El feed de ofertas llega en el Bloque G del ROADMAP.
class CandidateHomeScreen extends StatelessWidget {
  const CandidateHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SignedInScaffold(
      title: l10n.candidateHomeTitle,
      placeholder: l10n.candidateHomePlaceholder,
      children: [
        // Entrada accesible al perfil (Bloque D, T-021).
        FilledButton.icon(
          onPressed: () => context.goNamed(AppRoute.candidateProfile.name),
          icon: const Icon(Icons.person_outline),
          label: Text(l10n.profileTitle),
        ),
      ],
    );
  }
}
