import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/gen/app_localizations.dart';
import '../../../companies/presentation/widgets/verified_company_badge.dart';
import '../../../onboarding/domain/catalog.dart';
import '../../../onboarding/presentation/onboarding_copy.dart';
import '../../../onboarding/providers/onboarding_providers.dart';
import '../../../profiles/presentation/profile_copy.dart';
import '../../domain/job_offer.dart';
import '../jobs_copy.dart';
import 'job_place.dart';
import 'job_section.dart';

/// Contenido completo de una oferta tal como lo ve un candidato.
///
/// Lo usan el detalle del candidato (`/candidato/ofertas/:id`) y la vista
/// previa del formulario de la empresa: así la vista previa es, literalmente,
/// lo que verá el candidato (UX_FLOWS §5.1). Se recorre por encabezados.
/// Solo datos públicos de la oferta: nunca quién la cargó (`created_by`).
class JobOfferDetailsView extends ConsumerWidget {
  const JobOfferDetailsView({required this.offer, super.key});

  final JobOffer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final company = offer.company;
    final place = watchJobPlace(
      ref,
      provinciaId: offer.provinciaId,
      localidadId: offer.localidadId,
      barrioId: offer.barrioId,
    );
    final sectorId = offer.sectorId;
    String? sectorName;
    if (sectorId != null) {
      for (final sector
          in ref.watch(sectorsProvider).value ?? const <Sector>[]) {
        if (sector.id == sectorId) {
          sectorName = sector.name;
        }
      }
    }
    final contractType = offer.contractType;
    final jornada = offer.jornada;
    final workMode = offer.workMode;
    final experience = offer.experience;
    final availability = offer.availability;
    final expiresAt = offer.expiresAt;
    final days = [...offer.scheduleDays]
      ..sort((a, b) => a.index.compareTo(b.index));
    final missing = l10n.jobValueMissing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(offer.title, style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              company?.name ?? l10n.jobCompanyUnknown,
              style: theme.textTheme.titleMedium,
            ),
            VerifiedCompanyBadge(status: company?.verificationStatus),
          ],
        ),
        const SizedBox(height: 24),
        JobSection(
          title: l10n.jobSectionSalary,
          children: [
            Text(
              JobsCopy.salary(l10n, offer),
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
        JobSection(
          title: l10n.jobSectionContract,
          children: [
            JobDetailRow(
              label: l10n.jobContractTypeLabel,
              value: contractType == null
                  ? null
                  : JobsCopy.contractType(l10n, contractType),
              emptyLabel: missing,
            ),
            JobDetailRow(
              label: l10n.jobJornadaLabel,
              value: jornada == null ? null : JobsCopy.jornada(l10n, jornada),
              emptyLabel: missing,
            ),
          ],
        ),
        JobSection(
          title: l10n.jobSectionSchedule,
          children: [
            JobDetailRow(
              label: l10n.jobScheduleDaysLabel,
              value: days.isEmpty
                  ? null
                  : days
                        .map((day) => ProfileCopy.weekDay(l10n, day))
                        .join(', '),
              emptyLabel: missing,
            ),
            JobDetailRow(
              label: l10n.jobScheduleDetailLabel,
              value: offer.scheduleDetail,
              emptyLabel: missing,
            ),
          ],
        ),
        JobSection(
          title: l10n.jobSectionWorkMode,
          children: [
            Text(
              workMode == null
                  ? missing
                  : OnboardingCopy.workMode(l10n, workMode),
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
        JobSection(
          title: l10n.jobSectionLocation,
          children: [
            Text(
              place ?? l10n.jobPlaceUnavailable,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
        JobSection(
          title: l10n.jobSectionDescription,
          children: [
            Text(offer.description, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            JobDetailRow(
              label: l10n.jobExperienceLabel,
              value: experience == null
                  ? null
                  : ProfileCopy.experienceLevel(l10n, experience),
              emptyLabel: missing,
            ),
            JobDetailRow(
              label: l10n.jobAvailabilityLabel,
              value: availability == null
                  ? null
                  : OnboardingCopy.availability(l10n, availability),
              emptyLabel: missing,
            ),
          ],
        ),
        JobSection(
          title: l10n.jobSectionBenefits,
          children: [
            if (offer.benefits.isEmpty)
              Text(l10n.jobBenefitsNone, style: theme.textTheme.bodyLarge)
            else
              // Un renglón por beneficio y no un chip: el texto de un chip va
              // en una sola línea y un beneficio de 60 caracteres se cortaba.
              for (final benefit in offer.benefits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.check,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(benefit, style: theme.textTheme.bodyLarge),
                      ),
                    ],
                  ),
                ),
          ],
        ),
        JobSection(
          title: l10n.jobSectionMore,
          children: [
            if (sectorId != null)
              JobDetailRow(
                label: l10n.sectorLabel,
                value: sectorName,
                emptyLabel: missing,
              ),
            JobDetailRow(
              label: l10n.jobVacanciesLabel,
              value: l10n.jobVacanciesValue(offer.vacancies),
              emptyLabel: missing,
            ),
            JobDetailRow(
              label: l10n.jobExpiryLabel,
              value: expiresAt == null
                  ? null
                  : JobsCopy.date(expiresAt, locale),
              emptyLabel: missing,
            ),
          ],
        ),
      ],
    );
  }
}
