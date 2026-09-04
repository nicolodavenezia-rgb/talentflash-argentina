import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../shared/models/data_failure.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../companies/data/company_access_repository.dart';
import '../../companies/domain/company_verification.dart';
import '../../companies/providers/company_verification_providers.dart';

/// Cola de verificaciones de empresa (`/admin/verificaciones`).
///
/// AVANCE PARCIAL DE T-077: implementa solo la cola que T-028 necesita. Las
/// otras dos colas del panel (denuncias y moderación de videos), la asignación
/// de casos y el SLA siguen abiertas.
///
/// El guard de AAL2 que hay acá es VISUAL: evita ofrecer botones que el
/// servidor va a rechazar. La autorización real la aplican
/// `admin_list_company_verifications` y `admin_review_company_verification`
/// (migración 0028), que exigen rol admin leído de `profiles` y claim
/// `aal = aal2`, y fallan cerradas.
class AdminVerificationsScreen extends ConsumerWidget {
  const AdminVerificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final secondFactor = ref.watch(hasSecondFactorProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminVerificationsTitle)),
      body: SafeArea(
        child: switch (secondFactor) {
          AsyncData(value: false) => const _SecondFactorRequired(),
          AsyncData(value: true) => const _Queue(),
          AsyncError() => const _SecondFactorRequired(),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

/// Sesión sin segundo factor: se explica y no se muestra ni un dato de la cola.
/// Ante un error al leer el nivel se cae acá a propósito — no saber si hay
/// AAL2 es lo mismo que no tenerlo.
class _SecondFactorRequired extends StatelessWidget {
  const _SecondFactorRequired();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: MessageBanner.error(
            title: l10n.adminVerificationsMfaTitle,
            message: l10n.adminVerificationsMfaBody,
          ),
        ),
      ),
    );
  }
}

class _Queue extends ConsumerWidget {
  const _Queue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(verificationQueueFilterProvider);
    final queue = ref.watch(verificationQueueProvider);
    final review = ref.watch(verificationReviewControllerProvider);

    ref.listen(verificationReviewControllerProvider, (_, next) {
      if (next.hasValue &&
          next.value == VerificationActionOutcome.reviewed &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminVerificationsResolved)),
        );
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Wrap(
            spacing: 8,
            children: [
              for (final status in const [
                CompanyVerificationStatus.pending,
                CompanyVerificationStatus.approved,
                CompanyVerificationStatus.rejected,
              ])
                ChoiceChip(
                  label: Text(_statusLabel(l10n, status)),
                  selected: filter == status,
                  onSelected: (_) => ref
                      .read(verificationQueueFilterProvider.notifier)
                      .select(status),
                ),
            ],
          ),
        ),
        if (review.hasError)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: MessageBanner.error(
              title: l10n.adminVerificationsErrorTitle,
              message: _failureMessage(l10n, review.error),
            ),
          ),
        Expanded(
          child: switch (queue) {
            AsyncData(:final value) when value.isEmpty => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.adminVerificationsEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            AsyncData(:final value) => ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: value.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _RequestCard(request: value[index], busy: review.isLoading),
            ),
            AsyncError(:final error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: MessageBanner.error(
                  title: l10n.adminVerificationsErrorTitle,
                  message: _failureMessage(l10n, error),
                ),
              ),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ],
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request, required this.busy});

  final CompanyVerificationRequest request;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final resoluble =
        request.requestStatus == CompanyVerificationStatus.pending;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(request.companyName, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.adminVerificationsCuit(request.cuitSubmitted),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              request.documentPath == null
                  ? l10n.adminVerificationsNoDocument
                  : l10n.adminVerificationsWithDocument,
              style: theme.textTheme.bodySmall,
            ),
            if (request.documentPath != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    _mostrarConstancia(context, ref, request.documentPath!),
                icon: const Icon(Icons.description_outlined),
                label: Text(l10n.adminVerificationsOpenDocument),
              ),
            ],
            if (request.rejectionReason != null) ...[
              const SizedBox(height: 4),
              Text(
                l10n.adminVerificationsReason(
                  _reasonLabel(l10n, request.rejectionReason!),
                ),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (resoluble) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => ref
                              .read(
                                verificationReviewControllerProvider.notifier,
                              )
                              .approve(request.requestId),
                    child: Text(l10n.adminVerificationsApprove),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : () => _askReason(context, ref),
                    child: Text(l10n.adminVerificationsReject),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Pide una URL firmada de vida corta para la constancia y la muestra para
  /// copiar. Sin esto la revisión sería a ciegas: el panel decía que había un
  /// documento adjunto pero no había forma de mirarlo.
  ///
  /// No se abre el navegador desde la app a propósito: `url_launcher` no está
  /// declarado como dependencia directa (hoy llega solo como transitiva) y
  /// sumar una es una decisión de proyecto, no de esta pantalla. El enlace vive
  /// cinco minutos, así que copiarlo y pegarlo es equivalente y no deja un
  /// enlace vivo dando vueltas por la UI.
  Future<void> _mostrarConstancia(
    BuildContext context,
    WidgetRef ref,
    String path,
  ) {
    final l10n = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.adminVerificationsDocumentTitle),
        content: Consumer(
          builder: (context, ref, _) {
            final url = ref.watch(constanciaSignedUrlProvider(path));
            return switch (url) {
              AsyncData(:final value) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.adminVerificationsDocumentHelp),
                  const SizedBox(height: 12),
                  SelectableText(value),
                ],
              ),
              AsyncError() => Text(l10n.adminVerificationsDocumentError),
              _ => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            };
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.adminVerificationsDocumentClose),
          ),
        ],
      ),
    );
  }

  /// El rechazo pide siempre un motivo de la lista cerrada: no hay botón que
  /// pueda mandar un rechazo sin motivo, porque la RPC lo rechazaría.
  Future<void> _askReason(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final reason = await showDialog<VerificationRejectionReason>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.adminVerificationsReasonTitle),
        children: [
          for (final reason in VerificationRejectionReason.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(reason),
              child: Text(_reasonLabel(l10n, reason)),
            ),
        ],
      ),
    );
    if (reason == null) {
      return;
    }
    await ref
        .read(verificationReviewControllerProvider.notifier)
        .reject(request.requestId, reason);
  }
}

String _statusLabel(AppLocalizations l10n, CompanyVerificationStatus status) {
  return switch (status) {
    CompanyVerificationStatus.pending => l10n.verificationStatusPending,
    CompanyVerificationStatus.inReview => l10n.verificationStatusInReview,
    CompanyVerificationStatus.approved => l10n.verificationStatusApproved,
    CompanyVerificationStatus.rejected => l10n.verificationStatusRejected,
  };
}

String _reasonLabel(AppLocalizations l10n, VerificationRejectionReason reason) {
  return switch (reason) {
    VerificationRejectionReason.cuitNoCoincide => l10n.rejectionCuitMismatch,
    VerificationRejectionReason.constanciaIlegible =>
      l10n.rejectionUnreadableDocument,
    VerificationRejectionReason.constanciaVencida =>
      l10n.rejectionExpiredDocument,
    VerificationRejectionReason.datosIncompletos => l10n.rejectionMissingData,
    VerificationRejectionReason.empresaNoOperativa =>
      l10n.rejectionCompanyNotOperating,
    VerificationRejectionReason.otro => l10n.rejectionOther,
  };
}

String _failureMessage(AppLocalizations l10n, Object? error) {
  final failure = error is DataFailure
      ? error
      : DataFailure(DataFailureCode.unknown, debugDetail: '$error');
  return switch (failure.code) {
    DataFailureCode.secondFactorRequired => l10n.dataFailureSecondFactor,
    DataFailureCode.notAllowed => l10n.dataFailureNotAllowed,
    DataFailureCode.invalidCuit => l10n.dataFailureInvalidCuit,
    DataFailureCode.invalidData ||
    DataFailureCode.underage => l10n.dataFailureInvalidData,
    DataFailureCode.staleConsent => l10n.dataFailureStaleConsent,
    DataFailureCode.duplicate => l10n.dataFailureDuplicate,
    DataFailureCode.network => l10n.dataFailureNetwork,
    DataFailureCode.unknown => l10n.dataFailureUnknown,
  };
}
