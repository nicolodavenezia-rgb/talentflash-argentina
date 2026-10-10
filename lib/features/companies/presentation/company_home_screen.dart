import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../authentication/presentation/widgets/signed_in_scaffold.dart';
import '../../profiles/providers/profile_providers.dart';
import 'widgets/verified_company_badge.dart';

/// Shell de la empresa. Ruta privada: solo la alcanza una sesión con rol
/// `company` (el guard es UX; la autorización real es RLS).
/// Los candidatos llegan en el Bloque G y las postulaciones en el Bloque H del
/// ROADMAP.
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
      children: [
        VerifiedCompanyBadge(status: status),
        const SizedBox(height: 16),
        // Ofertas de la empresa (T-030).
        FilledButton.icon(
          onPressed: () => context.goNamed(AppRoute.companyJobs.name),
          icon: const Icon(Icons.work_outline),
          label: Text(l10n.jobsCompanyTitle),
        ),
        const SizedBox(height: 12),
        // Entrada al circuito de verificación (T-028).
        FilledButton.icon(
          onPressed: () => context.goNamed(AppRoute.companyVerification.name),
          icon: const Icon(Icons.verified_user_outlined),
          label: Text(l10n.companyVerificationTitle),
        ),
      ],
    );
  }
}
