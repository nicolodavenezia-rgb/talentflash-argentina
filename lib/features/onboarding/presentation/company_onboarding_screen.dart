import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../domain/catalog.dart';
import '../domain/company_onboarding_data.dart';
import '../domain/onboarding_validation.dart';
import '../providers/company_onboarding_controller.dart';
import '../providers/onboarding_providers.dart';
import 'onboarding_copy.dart';
import 'widgets/mandatory_consents_step.dart';
import 'widgets/notification_prefs_step.dart';
import 'widgets/wizard_scaffold.dart';

/// Wizard de onboarding de empresa (T-017).
///
/// Los datos de la empresa viajan en memoria hasta el paso final: la empresa,
/// su owner y los datos del solicitante nacen juntos en la RPC atómica
/// `complete_company_onboarding`, siempre en estado `pending` (no verificada).
class CompanyOnboardingScreen extends ConsumerWidget {
  const CompanyOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(companyOnboardingControllerProvider);
    return async.when(
      skipLoadingOnReload: true,
      loading: () => WizardLoadingView(title: l10n.companyOnboardingTitle),
      error: (error, stackTrace) => WizardErrorView(
        title: l10n.companyOnboardingTitle,
        onRetry: () => ref.invalidate(companyOnboardingControllerProvider),
      ),
      data: (state) => _CompanyWizardView(state: state),
    );
  }
}

class _CompanyWizardView extends ConsumerWidget {
  const _CompanyWizardView({required this.state});

  final CompanyWizardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(companyOnboardingControllerProvider.notifier);

    final stepTitle = switch (state.step) {
      CompanyStep.consents => l10n.onboardingConsentsTitle,
      CompanyStep.company => l10n.companyStepDataTitle,
      CompanyStep.place => l10n.companyStepPlaceTitle,
      CompanyStep.applicant => l10n.companyStepApplicantTitle,
      CompanyStep.notifications => l10n.onboardingNotificationsTitle,
      CompanyStep.summary => l10n.onboardingSummaryTitle,
    };

    return WizardScaffold(
      title: l10n.companyOnboardingTitle,
      stepTitle: stepTitle,
      stepNumber: state.stepNumber,
      stepCount: state.stepCount,
      onBack: state.step == CompanyStep.consents ? null : controller.goBack,
      children: [
        if (state.failure != null)
          MessageBanner.error(
            title: l10n.onboardingErrorTitle,
            message: OnboardingCopy.failure(l10n, state.failure!),
          ),
        switch (state.step) {
          CompanyStep.consents => MandatoryConsentsStep(
            snapshot: state.consents,
            isLoading: state.submitting,
            onSubmit: controller.submitMandatoryConsents,
          ),
          CompanyStep.company => _CompanyDataStep(
            initialData: state.data,
            isLoading: state.submitting,
            onSubmit: controller.submitCompanyData,
          ),
          CompanyStep.place => _CompanyPlaceStep(
            initialData: state.data,
            isLoading: state.submitting,
            onSubmit: controller.submitPlace,
          ),
          CompanyStep.applicant => _ApplicantStep(
            initialData: state.data,
            isLoading: state.submitting,
            onSubmit: controller.submitApplicant,
          ),
          CompanyStep.notifications => NotificationPrefsStep(
            initialPrefs: state.prefs,
            isLoading: state.submitting,
            onSubmit: controller.submitNotificationPrefs,
          ),
          CompanyStep.summary => _CompanySummaryStep(state: state),
        },
      ],
    );
  }
}

class _CompanyDataStep extends ConsumerStatefulWidget {
  const _CompanyDataStep({
    required this.initialData,
    required this.isLoading,
    required this.onSubmit,
  });

  final CompanyOnboardingData initialData;
  final bool isLoading;
  final void Function({
    required String legalName,
    required String tradeName,
    required String cuit,
    required String sectorId,
    required CompanySizeRange sizeRange,
  })
  onSubmit;

  @override
  ConsumerState<_CompanyDataStep> createState() => _CompanyDataStepState();
}

class _CompanyDataStepState extends ConsumerState<_CompanyDataStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _legalNameController;
  late final TextEditingController _tradeNameController;
  late final TextEditingController _cuitController;
  String? _sectorId;
  CompanySizeRange? _sizeRange;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _legalNameController = TextEditingController(
      text: widget.initialData.legalName ?? '',
    );
    _tradeNameController = TextEditingController(
      text: widget.initialData.tradeName ?? '',
    );
    _cuitController = TextEditingController(
      text: widget.initialData.cuit ?? '',
    );
    _sectorId = widget.initialData.sectorId;
    _sizeRange = widget.initialData.sizeRange;
  }

  @override
  void dispose() {
    _legalNameController.dispose();
    _tradeNameController.dispose();
    _cuitController.dispose();
    super.dispose();
  }

  void _submit() {
    final formValid = _formKey.currentState?.validate() ?? false;
    final selectionsValid = _sectorId != null && _sizeRange != null;
    setState(() => _showErrors = !selectionsValid);
    if (!formValid || !selectionsValid) {
      return;
    }
    widget.onSubmit(
      legalName: _legalNameController.text,
      tradeName: _tradeNameController.text,
      cuit: OnboardingValidation.normalizeCuit(_cuitController.text),
      sectorId: _sectorId!,
      sizeRange: _sizeRange!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sectors = ref.watch(sectorsProvider);
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _legalNameController,
            enabled: !widget.isLoading,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.legalNameLabel,
              border: const OutlineInputBorder(),
            ),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? l10n.legalNameError : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _tradeNameController,
            enabled: !widget.isLoading,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.tradeNameLabel,
              border: const OutlineInputBorder(),
            ),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? l10n.tradeNameError : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cuitController,
            enabled: !widget.isLoading,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.cuitLabel,
              hintText: l10n.cuitHint,
              helperText: l10n.cuitHelp,
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              final issue = OnboardingValidation.validateCuit(value ?? '');
              return issue == null
                  ? null
                  : OnboardingCopy.cuitIssue(l10n, issue);
            },
            // El CUIT se muestra normalizado apenas el campo pierde el foco.
            onEditingComplete: () {
              _cuitController.text = OnboardingValidation.normalizeCuit(
                _cuitController.text,
              );
              FocusScope.of(context).nextFocus();
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _sectorId,
            decoration: InputDecoration(
              labelText: l10n.sectorLabel,
              border: const OutlineInputBorder(),
              errorText: _showErrors && _sectorId == null
                  ? l10n.selectOptionError
                  : null,
            ),
            items: [
              for (final sector in sectors.value ?? const <Sector>[])
                DropdownMenuItem(value: sector.id, child: Text(sector.name)),
            ],
            onChanged: widget.isLoading
                ? null
                : (value) => setState(() => _sectorId = value),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<CompanySizeRange>(
            isExpanded: true,
            initialValue: _sizeRange,
            decoration: InputDecoration(
              labelText: l10n.companySizeLabel,
              border: const OutlineInputBorder(),
              errorText: _showErrors && _sizeRange == null
                  ? l10n.selectOptionError
                  : null,
            ),
            items: [
              for (final size in CompanySizeRange.values)
                DropdownMenuItem(
                  value: size,
                  child: Text(OnboardingCopy.companySize(l10n, size)),
                ),
            ],
            onChanged: widget.isLoading
                ? null
                : (value) => setState(() => _sizeRange = value),
          ),
          const SizedBox(height: 24),
          ProgressButton(
            label: l10n.onboardingContinue,
            isLoading: widget.isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _CompanyPlaceStep extends ConsumerStatefulWidget {
  const _CompanyPlaceStep({
    required this.initialData,
    required this.isLoading,
    required this.onSubmit,
  });

  final CompanyOnboardingData initialData;
  final bool isLoading;
  final void Function({
    required String provinceId,
    required String localityId,
    String? website,
  })
  onSubmit;

  @override
  ConsumerState<_CompanyPlaceStep> createState() => _CompanyPlaceStepState();
}

class _CompanyPlaceStepState extends ConsumerState<_CompanyPlaceStep> {
  late final TextEditingController _websiteController;
  String? _provinceId;
  String? _localityId;
  bool _showErrors = false;
  String? _websiteError;

  @override
  void initState() {
    super.initState();
    _websiteController = TextEditingController(
      text: widget.initialData.website ?? '',
    );
    _provinceId = widget.initialData.provinceId;
    _localityId = widget.initialData.localityId;
  }

  @override
  void dispose() {
    _websiteController.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final websiteIssue = OnboardingValidation.validateWebsite(
      _websiteController.text,
    );
    final valid =
        _provinceId != null && _localityId != null && websiteIssue == null;
    setState(() {
      _showErrors = _provinceId == null || _localityId == null;
      _websiteError = websiteIssue == null ? null : l10n.websiteError;
    });
    if (valid) {
      widget.onSubmit(
        provinceId: _provinceId!,
        localityId: _localityId!,
        website: OnboardingValidation.normalizeWebsite(_websiteController.text),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provinces = ref.watch(provincesProvider);
    final localities = _provinceId == null
        ? null
        : ref.watch(localitiesProvider(_provinceId!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _provinceId,
          decoration: InputDecoration(
            labelText: l10n.provinceLabel,
            border: const OutlineInputBorder(),
            errorText: _showErrors && _provinceId == null
                ? l10n.selectOptionError
                : null,
          ),
          items: [
            for (final province in provinces.value ?? const <GeoProvince>[])
              DropdownMenuItem(value: province.id, child: Text(province.name)),
          ],
          onChanged: widget.isLoading
              ? null
              : (value) => setState(() {
                  _provinceId = value;
                  _localityId = null;
                }),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          isExpanded: true,
          key: ValueKey('localidades-de-${_provinceId ?? 'nada'}'),
          initialValue: _localityId,
          decoration: InputDecoration(
            labelText: l10n.localityLabel,
            border: const OutlineInputBorder(),
            errorText: _showErrors && _localityId == null
                ? l10n.selectOptionError
                : null,
          ),
          items: [
            for (final locality in localities?.value ?? const <GeoLocality>[])
              DropdownMenuItem(value: locality.id, child: Text(locality.name)),
          ],
          onChanged: widget.isLoading || _provinceId == null
              ? null
              : (value) => setState(() => _localityId = value),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _websiteController,
          enabled: !widget.isLoading,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: l10n.websiteLabel,
            errorText: _websiteError,
            border: const OutlineInputBorder(),
          ),
          onFieldSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 24),
        ProgressButton(
          label: l10n.onboardingContinue,
          isLoading: widget.isLoading,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _ApplicantStep extends StatefulWidget {
  const _ApplicantStep({
    required this.initialData,
    required this.isLoading,
    required this.onSubmit,
  });

  final CompanyOnboardingData initialData;
  final bool isLoading;
  final void Function({
    required String fullName,
    required String position,
    required CompanyRelationship relationship,
  })
  onSubmit;

  @override
  State<_ApplicantStep> createState() => _ApplicantStepState();
}

class _ApplicantStepState extends State<_ApplicantStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _positionController;
  CompanyRelationship? _relationship;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialData.applicantFullName ?? '',
    );
    _positionController = TextEditingController(
      text: widget.initialData.applicantPosition ?? '',
    );
    _relationship = widget.initialData.applicantRelationship;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  void _submit() {
    final formValid = _formKey.currentState?.validate() ?? false;
    setState(() => _showErrors = _relationship == null);
    if (!formValid || _relationship == null) {
      return;
    }
    widget.onSubmit(
      fullName: _nameController.text,
      position: _positionController.text,
      relationship: _relationship!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            enabled: !widget.isLoading,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: InputDecoration(
              labelText: l10n.fullNameLabel,
              border: const OutlineInputBorder(),
            ),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? l10n.fullNameError : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _positionController,
            enabled: !widget.isLoading,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.positionLabel,
              border: const OutlineInputBorder(),
            ),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? l10n.positionError : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<CompanyRelationship>(
            isExpanded: true,
            initialValue: _relationship,
            decoration: InputDecoration(
              labelText: l10n.relationshipLabel,
              border: const OutlineInputBorder(),
              errorText: _showErrors && _relationship == null
                  ? l10n.selectOptionError
                  : null,
            ),
            items: [
              for (final value in CompanyRelationship.values)
                DropdownMenuItem(
                  value: value,
                  child: Text(OnboardingCopy.relationship(l10n, value)),
                ),
            ],
            onChanged: widget.isLoading
                ? null
                : (value) => setState(() => _relationship = value),
          ),
          const SizedBox(height: 24),
          ProgressButton(
            label: l10n.onboardingContinue,
            isLoading: widget.isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _CompanySummaryStep extends ConsumerWidget {
  const _CompanySummaryStep({required this.state});

  final CompanyWizardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(companyOnboardingControllerProvider.notifier);
    final data = state.data;

    String sectorName() {
      final sectors = ref.watch(sectorsProvider).value;
      if (sectors == null || data.sectorId == null) {
        return l10n.summaryMissingValue;
      }
      for (final sector in sectors) {
        if (sector.id == data.sectorId) {
          return sector.name;
        }
      }
      return l10n.summaryMissingValue;
    }

    String provinceName() {
      final provinces = ref.watch(provincesProvider).value;
      if (provinces == null || data.provinceId == null) {
        return l10n.summaryMissingValue;
      }
      for (final province in provinces) {
        if (province.id == data.provinceId) {
          return province.name;
        }
      }
      return l10n.summaryMissingValue;
    }

    String localityName() {
      if (data.provinceId == null || data.localityId == null) {
        return l10n.summaryMissingValue;
      }
      final localities = ref.watch(localitiesProvider(data.provinceId!)).value;
      if (localities == null) {
        return l10n.summaryMissingValue;
      }
      for (final locality in localities) {
        if (locality.id == data.localityId) {
          return locality.name;
        }
      }
      return l10n.summaryMissingValue;
    }

    final rows = <(String, String)>[
      (l10n.legalNameLabel, data.legalName ?? l10n.summaryMissingValue),
      (l10n.tradeNameLabel, data.tradeName ?? l10n.summaryMissingValue),
      (l10n.cuitLabel, data.cuit ?? l10n.summaryMissingValue),
      (l10n.sectorLabel, sectorName()),
      (
        l10n.companySizeLabel,
        switch (data.sizeRange) {
          null => l10n.summaryMissingValue,
          final size => OnboardingCopy.companySize(l10n, size),
        },
      ),
      (l10n.provinceLabel, provinceName()),
      (l10n.localityLabel, localityName()),
      if ((data.website ?? '').isNotEmpty) (l10n.websiteLabel, data.website!),
      (l10n.fullNameLabel, data.applicantFullName ?? l10n.summaryMissingValue),
      (l10n.positionLabel, data.applicantPosition ?? l10n.summaryMissingValue),
      (
        l10n.relationshipLabel,
        switch (data.applicantRelationship) {
          null => l10n.summaryMissingValue,
          final value => OnboardingCopy.relationship(l10n, value),
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.summaryIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: value, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        MessageBanner.info(message: l10n.companyPendingNote),
        ProgressButton(
          label: l10n.onboardingFinish,
          isLoading: state.submitting,
          onPressed: controller.finish,
        ),
      ],
    );
  }
}
