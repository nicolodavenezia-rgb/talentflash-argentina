import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/models/data_failure.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../domain/job_offer.dart';
import '../domain/job_offer_enums.dart';
import '../providers/job_offers_providers.dart';
import 'widgets/job_offer_details_view.dart';
import 'widgets/job_screen_states.dart';

/// Detalle de una oferta para el candidato (`/candidato/ofertas/:id`, T-030).
///
/// Lo que se puede leer lo decide RLS (activa, no descartada, de empresa
/// verificada). Además, una oferta que la pantalla no debería mostrar —no
/// activa, o activa con el vencimiento ya pasado mientras no exista el cron
/// de T-033— se trata igual que una inexistente: mismo mensaje, sin decir
/// cuál de los casos es. No hay "Postularme" (T-040) ni "Compartir" (T-034):
/// ningún botón que no funcione.
class JobOfferDetailScreen extends ConsumerWidget {
  const JobOfferDetailScreen({required this.jobId, super.key});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    final Widget body;
    if (!isWellFormedJobId(jobId)) {
      // Un id malformado ni siquiera viaja al servidor.
      body = const _NotAvailable();
    } else {
      final offer = ref.watch(jobOfferProvider(jobId));
      final now = ref.watch(jobClockProvider)();
      body = switch (offer) {
        AsyncData(:final value) when _isVisible(value, now) => _Detail(
          offer: value!,
        ),
        AsyncData() => const _NotAvailable(),
        AsyncError(:final error)
            when error is DataFailure &&
                error.code == DataFailureCode.network =>
          JobCenteredMessage(
            title: l10n.jobLoadError,
            actions: [
              FilledButton(
                onPressed: () => ref.invalidate(jobOfferProvider(jobId)),
                child: Text(l10n.retryLabel),
              ),
            ],
          ),
        AsyncError() => const _NotAvailable(),
        _ => const Center(child: CircularProgressIndicator()),
      };
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.goNamed(AppRoute.candidateFeed.name),
        ),
        title: Text(l10n.jobDetailTitle),
      ),
      body: SafeArea(child: body),
    );
  }

  static bool _isVisible(JobOffer? offer, DateTime now) =>
      offer != null &&
      offer.status == JobStatus.active &&
      !offer.hasPassedExpiry(now);
}

class _Detail extends StatelessWidget {
  const _Detail({required this.offer});

  final JobOffer offer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              JobOfferDetailsView(offer: offer),
              MessageBanner.info(message: l10n.jobApplyComingSoon),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotAvailable extends StatelessWidget {
  const _NotAvailable();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JobCenteredMessage(
      title: l10n.jobNotAvailableTitle,
      body: l10n.jobNotAvailableBody,
      actions: [
        OutlinedButton(
          onPressed: () => context.goNamed(AppRoute.candidateFeed.name),
          child: Text(l10n.jobBackToFeed),
        ),
      ],
    );
  }
}
