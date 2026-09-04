import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../authentication/presentation/widgets/signed_in_scaffold.dart';
import '../../profiles/providers/profile_providers.dart';
import 'widgets/verified_company_badge.dart';

/// Shell de la empresa. Ruta privada: solo la alcanza una sesion con rol
/// `company` (el guard es UX; la autorizacion real es RLS).
/// El panel de ofertas y candidatos llega en el Bloque G del ROADMAP.
class CompanyHomeScreen extends ConsumerWidget {
  const CompanyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Estado propio de la empresa (T-024). Mientras carga o si falla, el badge
    // recibe null y no se dibuja: nunca se muestra "verificada" por defecto.
    final status = ref.watch(ownCompanyVerificationProvider).value;

    return SignedInScaffold(
      title: l10n.companyHomeTitle,
      placeholder: l10n.companyHomePlaceholder,
      children: [VerifiedCompanyBadge(status: status)],
    );
  }
}
