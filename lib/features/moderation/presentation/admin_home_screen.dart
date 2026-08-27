import 'package:flutter/material.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../authentication/presentation/widgets/signed_in_scaffold.dart';

/// Destino de las cuentas con rol `admin`.
///
/// El panel real (verificaciones, moderación, denuncias, métricas) es el
/// Bloque P del ROADMAP. Existe desde ahora para que una cuenta de
/// administración **nunca** se degrade al shell de candidato o de empresa
/// cuando inicia sesión (`UX_FLOWS.md` §1.4).
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SignedInScaffold(
      title: l10n.adminHomeTitle,
      placeholder: l10n.adminHomePlaceholder,
    );
  }
}
