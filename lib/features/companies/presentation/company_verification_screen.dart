import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../shared/models/data_failure.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../data/company_access_repository.dart';
import '../domain/company_verification.dart';
import '../domain/cuit.dart';
import '../providers/company_verification_providers.dart';
import 'widgets/verified_company_badge.dart';

/// Verificación de la empresa (T-028), lado empresa.
///
/// Muestra el estado actual y, cuando corresponde, deja adjuntar la constancia
/// de ARCA y enviar la solicitud. Los guards que hay acá son UX: quién puede
/// solicitar lo decide la RPC `request_company_verification` (0028), que exige
/// ser el owner y que el CUIT coincida con el de la empresa.
class CompanyVerificationScreen extends ConsumerStatefulWidget {
  const CompanyVerificationScreen({super.key});

  @override
  ConsumerState<CompanyVerificationScreen> createState() =>
      _CompanyVerificationScreenState();
}

class _CompanyVerificationScreenState
    extends ConsumerState<CompanyVerificationScreen> {
  final _cuitController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// Formato de la constancia recién adjuntada en esta pantalla. Null significa
  /// "no adjunté nada ahora", no "no hay constancia": puede haber una de un
  /// envío anterior, y el servidor no la borra si el reenvío llega sin archivo.
  ConstanciaFormat? _attached;

  @override
  void dispose() {
    _cuitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final verification = ref.watch(myCompanyVerificationProvider);
    final action = ref.watch(companyVerificationControllerProvider);

    ref.listen(companyVerificationControllerProvider, (_, next) {
      if (next.hasValue &&
          next.value == VerificationActionOutcome.submitted &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.companyVerificationSubmitted)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.companyVerificationTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: switch (verification) {
                AsyncData(:final value) => _Body(
                  verification: value,
                  formKey: _formKey,
                  cuitController: _cuitController,
                  attached: _attached,
                  action: action,
                  onAttach: _attach,
                  onSubmit: _submit,
                ),
                AsyncError(:final error) => _ErrorState(error: error),
                _ => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _attach() async {
    final format = await ref
        .read(companyVerificationControllerProvider.notifier)
        .attachConstancia();
    if (format != null && mounted) {
      setState(() => _attached = format);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await ref
        .read(companyVerificationControllerProvider.notifier)
        .submit(cuit: _cuitController.text, format: _attached);
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.verification,
    required this.formKey,
    required this.cuitController,
    required this.attached,
    required this.action,
    required this.onAttach,
    required this.onSubmit,
  });

  final CompanyVerification verification;
  final GlobalKey<FormState> formKey;
  final TextEditingController cuitController;
  final ConstanciaFormat? attached;
  final AsyncValue<VerificationActionOutcome?> action;
  final Future<void> Function() onAttach;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final busy = action.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusCard(verification: verification),
        const SizedBox(height: 16),
        if (action.hasError)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: MessageBanner.error(
              title: l10n.companyVerificationErrorTitle,
              message: _failureMessage(l10n, action.error),
            ),
          ),
        if (verification.canSubmit) ...[
          Text(
            l10n.companyVerificationFormTitle,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.companyVerificationFormHelp,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Form(
            key: formKey,
            child: TextFormField(
              controller: cuitController,
              enabled: !busy,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.cuitLabel,
                helperText: l10n.cuitHelp,
              ),
              validator: (value) => switch (Cuit.validate(value ?? '')) {
                null => null,
                CuitIssue.empty => l10n.cuitErrorRequired,
                CuitIssue.invalidCharacters => l10n.cuitErrorCharacters,
                CuitIssue.wrongLength => l10n.cuitErrorLength,
                CuitIssue.checkDigit => l10n.cuitErrorCheckDigit,
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onAttach,
                  icon: const Icon(Icons.attach_file),
                  label: Text(l10n.companyVerificationAttach),
                ),
              ),
            ],
          ),
          if (attached != null) ...[
            const SizedBox(height: 8),
            MessageBanner.info(
              message: l10n.companyVerificationAttached(attached!.wireName),
            ),
          ] else if (verification.documentPath != null) ...[
            const SizedBox(height: 8),
            MessageBanner.info(
              message: l10n.companyVerificationAttachedEarlier,
            ),
          ],
          const SizedBox(height: 24),
          ProgressButton(
            label: l10n.companyVerificationSubmit,
            isLoading: busy,
            onPressed: onSubmit,
          ),
        ],
      ],
    );
  }
}

/// Estado actual, con su propio copy por cada valor posible. Un estado
/// desconocido (null) se trata como "todavía no verificada": nunca como buena
/// noticia.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.verification});

  final CompanyVerification verification;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = verification.companyStatus;

    final (String title, String body) = switch (status) {
      CompanyVerificationStatus.approved => (
        l10n.companyVerificationApprovedTitle,
        l10n.companyVerificationApprovedBody,
      ),
      CompanyVerificationStatus.rejected => (
        l10n.companyVerificationRejectedTitle,
        _rejectionBody(l10n, verification.rejectionReason),
      ),
      CompanyVerificationStatus.inReview || CompanyVerificationStatus.pending =>
        verification.hasOpenRequest
            ? (
                l10n.companyVerificationInReviewTitle,
                l10n.companyVerificationInReviewBody,
              )
            : (
                l10n.companyVerificationPendingTitle,
                l10n.companyVerificationPendingBody,
              ),
      null => (
        l10n.companyVerificationPendingTitle,
        l10n.companyVerificationPendingBody,
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                VerifiedCompanyBadge(status: status, compact: true),
              ],
            ),
            const SizedBox(height: 8),
            Text(body, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MessageBanner.error(
      title: l10n.companyVerificationErrorTitle,
      message: _failureMessage(l10n, error),
    );
  }
}

String _rejectionBody(
  AppLocalizations l10n,
  VerificationRejectionReason? reason,
) {
  final motivo = switch (reason) {
    VerificationRejectionReason.cuitNoCoincide => l10n.rejectionCuitMismatch,
    VerificationRejectionReason.constanciaIlegible =>
      l10n.rejectionUnreadableDocument,
    VerificationRejectionReason.constanciaVencida =>
      l10n.rejectionExpiredDocument,
    VerificationRejectionReason.datosIncompletos => l10n.rejectionMissingData,
    VerificationRejectionReason.empresaNoOperativa =>
      l10n.rejectionCompanyNotOperating,
    VerificationRejectionReason.otro || null => l10n.rejectionOther,
  };
  return l10n.companyVerificationRejectedBody(motivo);
}

String _failureMessage(AppLocalizations l10n, Object? error) {
  final failure = error is DataFailure
      ? error
      : DataFailure(DataFailureCode.unknown, debugDetail: '$error');
  return switch (failure.code) {
    DataFailureCode.notAllowed => l10n.companyVerificationNotOwner,
    DataFailureCode.invalidCuit => l10n.dataFailureInvalidCuit,
    DataFailureCode.secondFactorRequired => l10n.dataFailureSecondFactor,
    DataFailureCode.ambiguousCompany => l10n.dataFailureAmbiguousCompany,
    DataFailureCode.invalidData ||
    DataFailureCode.underage => l10n.dataFailureInvalidData,
    DataFailureCode.staleConsent => l10n.dataFailureStaleConsent,
    DataFailureCode.duplicate => l10n.dataFailureDuplicate,
    DataFailureCode.network => l10n.dataFailureNetwork,
    // TFJOB solo sale de escrituras de ofertas: acá no puede llegar y, si
    // llegara, el texto de ofertas ("ya te mostramos cómo quedó") mentiría.
    DataFailureCode.jobStateConflict ||
    DataFailureCode.unknown => l10n.dataFailureUnknown,
  };
}
