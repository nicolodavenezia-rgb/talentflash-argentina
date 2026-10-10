import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/gen/app_localizations.dart';
import '../../../companies/presentation/widgets/verified_company_badge.dart';
import '../../../onboarding/presentation/onboarding_copy.dart';
import '../../domain/job_offer.dart';
import '../jobs_copy.dart';
import 'job_place.dart';

/// Tarjeta de oferta del feed de candidatos (UX_FLOWS §6.1): puesto, empresa
/// con su distintivo de verificada, lugar, sueldo SIEMPRE visible, jornada y
/// modalidad.
///
/// Es UN solo nodo semántico (UX_FLOWS §20, "tarjetas como un solo nodo"):
/// el lector la anuncia con una etiqueta armada en orden de importancia y la
/// abre con un toque. Por eso los hijos quedan excluidos de la semántica y
/// la mención de "empresa verificada" entra en esa etiqueta con la MISMA
/// regla que dibuja el chip ([VerifiedCompanyBadge.appliesTo]). Todavía no
/// hay acciones internas: guardar y postularse llegan con T-083 y T-040, y
/// esta tarjeta no muestra botones que no funcionan.
class JobOfferCard extends ConsumerWidget {
  const JobOfferCard({required this.offer, required this.onTap, super.key});

  final JobOffer offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final company = offer.company;
    final companyName = company?.name ?? l10n.jobCompanyUnknown;
    final verificationStatus = company?.verificationStatus;
    final place = watchJobPlace(
      ref,
      provinciaId: offer.provinciaId,
      localidadId: offer.localidadId,
      barrioId: offer.barrioId,
    );
    final salary = JobsCopy.salary(l10n, offer);
    final jornada = offer.jornada;
    final workMode = offer.workMode;
    final conditions = [
      if (jornada != null) JobsCopy.jornada(l10n, jornada),
      if (workMode != null) OnboardingCopy.workMode(l10n, workMode),
    ];

    final semanticsLabel = _sentences([
      offer.title,
      companyName,
      if (VerifiedCompanyBadge.appliesTo(verificationStatus))
        l10n.companyVerifiedBadgeSemantics,
      ?place,
      salary,
      ...conditions,
    ]);

    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: semanticsLabel,
      onTap: onTap,
      onTapHint: l10n.jobCardOpenHint,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(offer.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(companyName, style: theme.textTheme.bodyMedium),
                    VerifiedCompanyBadge(
                      status: verificationStatus,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (place != null)
                  _IconLine(icon: Icons.place_outlined, text: place),
                _IconLine(
                  icon: Icons.payments_outlined,
                  text: salary,
                  style: theme.textTheme.titleSmall,
                ),
                if (conditions.isNotEmpty)
                  _IconLine(
                    icon: Icons.schedule_outlined,
                    text: conditions.join(' · '),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Une los datos como oraciones para que el lector haga una pausa entre
  /// cada uno, sin duplicar el punto de los textos que ya lo traen.
  static String _sentences(List<String> parts) => parts
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .map((part) => part.endsWith('.') ? part : '$part.')
      .join(' ');
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text, this.style});

  final IconData icon;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: style ?? theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
