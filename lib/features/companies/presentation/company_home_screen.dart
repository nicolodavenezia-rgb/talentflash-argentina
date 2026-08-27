import 'package:flutter/material.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../authentication/presentation/widgets/signed_in_scaffold.dart';

/// Shell de la empresa. Ruta privada: solo la alcanza una sesión con rol
/// `company` (el guard es UX; la autorización real es RLS).
/// El panel de ofertas y candidatos llega en el Bloque G del ROADMAP.
class CompanyHomeScreen extends StatelessWidget {
  const CompanyHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SignedInScaffold(
      title: l10n.companyHomeTitle,
      placeholder: l10n.companyHomePlaceholder,
    );
  }
}
