import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../authentication/providers/auth_controller.dart';
import '../../consents/domain/consent_type.dart';
import '../domain/candidate_onboarding_data.dart';
import '../domain/catalog.dart';
import '../domain/onboarding_validation.dart';
import '../providers/candidate_onboarding_controller.dart';
import '../providers/onboarding_providers.dart';
import 'onboarding_copy.dart';
import 'widgets/mandatory_consents_step.dart';
import 'widgets/notification_prefs_step.dart';
import 'widgets/wizard_scaffold.dart';

/// Wizard de onboarding de candidato (T-016).
///
/// El avance se persiste paso a paso (`save_candidate_onboarding`), así que
/// cerrar la app y volver retoma donde quedó. La finalización la valida el
/// servidor; una persona menor de 18 queda bloqueada sin persistir datos.
class CandidateOnboardingScreen extends ConsumerWidget {
  const CandidateOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(candidateOnboardingControllerProvider);
    return async.when(
      skipLoadingOnReload: true,
      loading: () => WizardLoadingView(title: l10n.candidateOnboardingTitle),
      error: (error, stackTrace) => WizardErrorView(
        title: l10n.candidateOnboardingTitle,
        onRetry: () => ref.invalidate(candidateOnboardingControllerProvider),
      ),
      data: (state) {
        if (state.underage) {
          return const _UnderageView();
        }
        return _CandidateWizardView(state: state);
      },
    );
  }
}

class _CandidateWizardView extends ConsumerWidget {
  const _CandidateWizardView({required this.state});

  final CandidateWizardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(candidateOnboardingControllerProvider.notifier);

    final stepTitle = switch (state.step) {
      CandidateStep.consents => l10n.onboardingConsentsTitle,
      CandidateStep.identity => l10n.candidateStepIdentityTitle,
      CandidateStep.place => l10n.candidateStepPlaceTitle,
      CandidateStep.preferences => l10n.candidateStepPreferencesTitle,
      CandidateStep.privacy => l10n.candidateStepPrivacyTitle,
      CandidateStep.notifications => l10n.onboardingNotificationsTitle,
      CandidateStep.summary => l10n.onboardingSummaryTitle,
    };

    return WizardScaffold(
      title: l10n.candidateOnboardingTitle,
      stepTitle: stepTitle,
      stepNumber: state.stepNumber,
      stepCount: state.stepCount,
      onBack: state.step == CandidateStep.consents ? null : controller.goBack,
      children: [
        if (state.failure != null)
          MessageBanner.error(
            title: l10n.onboardingErrorTitle,
            message: OnboardingCopy.failure(l10n, state.failure!),
          ),
        switch (state.step) {
          CandidateStep.consents => MandatoryConsentsStep(
            snapshot: state.consents,
            isLoading: state.submitting,
            onSubmit: controller.submitMandatoryConsents,
          ),
          CandidateStep.identity => _IdentityStep(
            initialData: state.data,
            isLoading: state.submitting,
            onSubmit: (fullName, birthDate) => controller.submitIdentity(
              fullName: fullName,
              birthDate: birthDate,
            ),
          ),
          CandidateStep.place => _PlaceStep(
            initialData: state.data,
            isLoading: state.submitting,
            onSubmit: (province, locality, neighborhood) =>
                controller.submitPlace(
                  provinceId: province,
                  localityId: locality,
                  neighborhoodId: neighborhood,
                ),
          ),
          CandidateStep.preferences => _PreferencesStep(
            initialData: state.data,
            isLoading: state.submitting,
            onSubmit: (sector, availability, workModes) =>
                controller.submitPreferences(
                  sectorId: sector,
                  availability: availability,
                  workModes: workModes,
                ),
          ),
          CandidateStep.privacy => _PrivacyStep(
            initiallyPublishing: state.consents.isCurrentlyGranted(
              ConsentType.videoProfilePublication,
            ),
            initiallyAi: state.consents.isCurrentlyGranted(
              ConsentType.aiFeatures,
            ),
            isLoading: state.submitting,
            onSubmit: (publish, ai) => controller.submitPrivacy(
              publishProfile: publish,
              aiFeatures: ai,
            ),
          ),
          CandidateStep.notifications => NotificationPrefsStep(
            initialPrefs: state.prefs,
            isLoading: state.submitting,
            onSubmit: controller.submitNotificationPrefs,
          ),
          CandidateStep.summary => _SummaryStep(state: state),
        },
      ],
    );
  }
}

/// Paso 2: nombre y fecha de nacimiento (verificación de mayoría de 18 por
/// fecha calendario, también aplicada server-side).
class _IdentityStep extends StatefulWidget {
  const _IdentityStep({
    required this.initialData,
    required this.isLoading,
    required this.onSubmit,
  });

  final CandidateOnboardingData initialData;
  final bool isLoading;
  final void Function(String fullName, DateTime birthDate) onSubmit;

  @override
  State<_IdentityStep> createState() => _IdentityStepState();
}

class _IdentityStepState extends State<_IdentityStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _birthController;
  final _nameFocus = FocusNode();
  final _birthFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialData.fullName ?? '',
    );
    _birthController = TextEditingController(
      text: switch (widget.initialData.birthDate) {
        null => '',
        final date => OnboardingCopy.birthDateText(date),
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthController.dispose();
    _nameFocus.dispose();
    _birthFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      if (OnboardingValidation.validateFullName(_nameController.text) != null) {
        _nameFocus.requestFocus();
      } else {
        _birthFocus.requestFocus();
      }
      return;
    }
    final birthDate = OnboardingValidation.parseBirthDate(
      _birthController.text,
    );
    if (birthDate == null) {
      _birthFocus.requestFocus();
      return;
    }
    widget.onSubmit(_nameController.text, birthDate);
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
            focusNode: _nameFocus,
            enabled: !widget.isLoading,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: InputDecoration(
              labelText: l10n.fullNameLabel,
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              final issue = OnboardingValidation.validateFullName(value ?? '');
              return issue == null
                  ? null
                  : OnboardingCopy.fullNameIssue(l10n, issue);
            },
            onFieldSubmitted: (_) => _birthFocus.requestFocus(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _birthController,
            focusNode: _birthFocus,
            enabled: !widget.isLoading,
            keyboardType: TextInputType.datetime,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.birthday],
            decoration: InputDecoration(
              labelText: l10n.birthDateLabel,
              hintText: l10n.birthDateHint,
              helperText: l10n.birthDateHelp,
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              final issue = OnboardingValidation.validateBirthDate(value ?? '');
              // La minoría de edad no es un error de campo: se deja pasar la
              // validación y el controller bloquea el wizard sin persistir.
              if (issue == null || issue == BirthDateIssue.underage) {
                return null;
              }
              return OnboardingCopy.birthDateIssue(l10n, issue);
            },
            onFieldSubmitted: (_) => _submit(),
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

/// Paso 3: cascada provincia → localidad → barrio, con datos SIEMPRE de la
/// base. El barrio es obligatorio solo cuando la localidad tiene barrios.
class _PlaceStep extends ConsumerStatefulWidget {
  const _PlaceStep({
    required this.initialData,
    required this.isLoading,
    required this.onSubmit,
  });

  final CandidateOnboardingData initialData;
  final bool isLoading;
  final void Function(String province, String locality, String? neighborhood)
  onSubmit;

  @override
  ConsumerState<_PlaceStep> createState() => _PlaceStepState();
}

class _PlaceStepState extends ConsumerState<_PlaceStep> {
  String? _provinceId;
  String? _localityId;
  String? _neighborhoodId;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _provinceId = widget.initialData.provinceId;
    _localityId = widget.initialData.localityId;
    _neighborhoodId = widget.initialData.neighborhoodId;
  }

  void _submit(List<GeoNeighborhood> neighborhoods) {
    final neighborhoodRequired = neighborhoods.isNotEmpty;
    final valid =
        _provinceId != null &&
        _localityId != null &&
        (!neighborhoodRequired || _neighborhoodId != null);
    setState(() => _showErrors = !valid);
    if (valid) {
      widget.onSubmit(_provinceId!, _localityId!, _neighborhoodId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provinces = ref.watch(provincesProvider);
    final localities = _provinceId == null
        ? const AsyncValue<List<GeoLocality>>.data([])
        : ref.watch(localitiesProvider(_provinceId!));
    final neighborhoods = _localityId == null
        ? const AsyncValue<List<GeoNeighborhood>>.data([])
        : ref.watch(neighborhoodsProvider(_localityId!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CatalogDropdown(
          label: l10n.provinceLabel,
          value: _provinceId,
          enabled: !widget.isLoading,
          asyncItems: provinces.whenData(
            (items) => [
              for (final item in items) (id: item.id, name: item.name),
            ],
          ),
          errorText: _showErrors && _provinceId == null
              ? l10n.selectOptionError
              : null,
          onChanged: (value) => setState(() {
            _provinceId = value;
            _localityId = null;
            _neighborhoodId = null;
          }),
        ),
        const SizedBox(height: 16),
        _CatalogDropdown(
          label: l10n.localityLabel,
          value: _localityId,
          enabled: !widget.isLoading && _provinceId != null,
          asyncItems: localities.whenData(
            (items) => [
              for (final item in items) (id: item.id, name: item.name),
            ],
          ),
          errorText: _showErrors && _localityId == null
              ? l10n.selectOptionError
              : null,
          onChanged: (value) => setState(() {
            _localityId = value;
            _neighborhoodId = null;
          }),
        ),
        const SizedBox(height: 16),
        if (neighborhoods.value?.isNotEmpty ?? false) ...[
          _CatalogDropdown(
            label: l10n.neighborhoodLabel,
            value: _neighborhoodId,
            enabled: !widget.isLoading,
            asyncItems: neighborhoods.whenData(
              (items) => [
                for (final item in items) (id: item.id, name: item.name),
              ],
            ),
            errorText: _showErrors && _neighborhoodId == null
                ? l10n.selectOptionError
                : null,
            onChanged: (value) => setState(() => _neighborhoodId = value),
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 8),
        ProgressButton(
          label: l10n.onboardingContinue,
          isLoading: widget.isLoading,
          onPressed: () => _submit(neighborhoods.value ?? const []),
        ),
      ],
    );
  }
}

/// Paso 4: sector desde el catálogo, disponibilidad y modalidades.
class _PreferencesStep extends ConsumerStatefulWidget {
  const _PreferencesStep({
    required this.initialData,
    required this.isLoading,
    required this.onSubmit,
  });

  final CandidateOnboardingData initialData;
  final bool isLoading;
  final void Function(
    String sector,
    CandidateAvailability availability,
    Set<CandidateWorkMode> workModes,
  )
  onSubmit;

  @override
  ConsumerState<_PreferencesStep> createState() => _PreferencesStepState();
}

class _PreferencesStepState extends ConsumerState<_PreferencesStep> {
  String? _sectorId;
  CandidateAvailability? _availability;
  late Set<CandidateWorkMode> _workModes;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _sectorId = widget.initialData.sectorId;
    _availability = widget.initialData.availability;
    _workModes = Set.of(widget.initialData.workModes);
  }

  void _submit() {
    final valid =
        _sectorId != null && _availability != null && _workModes.isNotEmpty;
    setState(() => _showErrors = !valid);
    if (valid) {
      widget.onSubmit(_sectorId!, _availability!, _workModes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sectors = ref.watch(sectorsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CatalogDropdown(
          label: l10n.sectorLabel,
          value: _sectorId,
          enabled: !widget.isLoading,
          asyncItems: sectors.whenData(
            (items) => [
              for (final item in items) (id: item.id, name: item.name),
            ],
          ),
          errorText: _showErrors && _sectorId == null
              ? l10n.selectOptionError
              : null,
          onChanged: (value) => setState(() => _sectorId = value),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<CandidateAvailability>(
          isExpanded: true,
          initialValue: _availability,
          decoration: InputDecoration(
            labelText: l10n.availabilityLabel,
            border: const OutlineInputBorder(),
            errorText: _showErrors && _availability == null
                ? l10n.selectOptionError
                : null,
          ),
          items: [
            for (final value in CandidateAvailability.values)
              DropdownMenuItem(
                value: value,
                child: Text(OnboardingCopy.availability(l10n, value)),
              ),
          ],
          onChanged: widget.isLoading
              ? null
              : (value) => setState(() => _availability = value),
        ),
        const SizedBox(height: 16),
        Text(l10n.workModesLabel, style: theme.textTheme.titleMedium),
        for (final mode in CandidateWorkMode.values)
          CheckboxListTile(
            value: _workModes.contains(mode),
            onChanged: widget.isLoading
                ? null
                : (checked) => setState(() {
                    if (checked ?? false) {
                      _workModes.add(mode);
                    } else {
                      _workModes.remove(mode);
                    }
                  }),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(OnboardingCopy.workMode(l10n, mode)),
          ),
        if (_showErrors && _workModes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              l10n.workModesError,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: 16),
        ProgressButton(
          label: l10n.onboardingContinue,
          isLoading: widget.isLoading,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// Paso 5: consentimientos opcionales B y C (UX_FLOWS.md §2.3), nunca
/// premarcados salvo que ya estuvieran otorgados. `ai_training` no existe.
class _PrivacyStep extends StatefulWidget {
  const _PrivacyStep({
    required this.initiallyPublishing,
    required this.initiallyAi,
    required this.isLoading,
    required this.onSubmit,
  });

  final bool initiallyPublishing;
  final bool initiallyAi;
  final bool isLoading;
  final void Function(bool publish, bool ai) onSubmit;

  @override
  State<_PrivacyStep> createState() => _PrivacyStepState();
}

class _PrivacyStepState extends State<_PrivacyStep> {
  late bool _publish;
  late bool _ai;

  @override
  void initState() {
    super.initState();
    _publish = widget.initiallyPublishing;
    _ai = widget.initiallyAi;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.privacyIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        SwitchListTile(
          value: _publish,
          onChanged: widget.isLoading
              ? null
              : (value) => setState(() => _publish = value),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.consentVideoLabel),
          subtitle: Text(l10n.consentVideoHelp),
        ),
        SwitchListTile(
          value: _ai,
          onChanged: widget.isLoading
              ? null
              : (value) => setState(() => _ai = value),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.consentAiLabel),
          subtitle: Text(l10n.consentAiHelp),
        ),
        const SizedBox(height: 24),
        ProgressButton(
          label: l10n.onboardingContinue,
          isLoading: widget.isLoading,
          onPressed: () => widget.onSubmit(_publish, _ai),
        ),
      ],
    );
  }
}

/// Paso final: resumen legible + finalización server-side.
class _SummaryStep extends ConsumerWidget {
  const _SummaryStep({required this.state});

  final CandidateWizardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(candidateOnboardingControllerProvider.notifier);
    final data = state.data;

    String nameOf(
      AsyncValue<List<({String id, String name})>> items,
      String? id,
    ) {
      if (id == null) {
        return l10n.summaryMissingValue;
      }
      final list = items.value;
      if (list == null) {
        return l10n.summaryMissingValue;
      }
      for (final item in list) {
        if (item.id == id) {
          return item.name;
        }
      }
      return l10n.summaryMissingValue;
    }

    final provinces = ref
        .watch(provincesProvider)
        .whenData((items) => [for (final i in items) (id: i.id, name: i.name)]);
    final localities = data.provinceId == null
        ? const AsyncValue<List<({String id, String name})>>.data([])
        : ref
              .watch(localitiesProvider(data.provinceId!))
              .whenData(
                (items) => [for (final i in items) (id: i.id, name: i.name)],
              );
    final neighborhoods = data.localityId == null
        ? const AsyncValue<List<({String id, String name})>>.data([])
        : ref
              .watch(neighborhoodsProvider(data.localityId!))
              .whenData(
                (items) => [for (final i in items) (id: i.id, name: i.name)],
              );
    final sectors = ref
        .watch(sectorsProvider)
        .whenData((items) => [for (final i in items) (id: i.id, name: i.name)]);

    final willBeVisible = state.consents.isCurrentlyGranted(
      ConsentType.videoProfilePublication,
    );

    final rows = <(String, String)>[
      (l10n.fullNameLabel, data.fullName ?? l10n.summaryMissingValue),
      (
        l10n.birthDateLabel,
        switch (data.birthDate) {
          null => l10n.summaryMissingValue,
          final date => OnboardingCopy.birthDateText(date),
        },
      ),
      (l10n.provinceLabel, nameOf(provinces, data.provinceId)),
      (l10n.localityLabel, nameOf(localities, data.localityId)),
      if (data.neighborhoodId != null)
        (l10n.neighborhoodLabel, nameOf(neighborhoods, data.neighborhoodId)),
      (l10n.sectorLabel, nameOf(sectors, data.sectorId)),
      (
        l10n.availabilityLabel,
        switch (data.availability) {
          null => l10n.summaryMissingValue,
          final value => OnboardingCopy.availability(l10n, value),
        },
      ),
      (
        l10n.workModesLabel,
        data.workModes.isEmpty
            ? l10n.summaryMissingValue
            : [
                for (final mode in data.workModes)
                  OnboardingCopy.workMode(l10n, mode),
              ].join(', '),
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
        MessageBanner.info(
          message: willBeVisible
              ? l10n.summaryVisibleYes
              : l10n.summaryVisibleNo,
        ),
        ProgressButton(
          label: l10n.onboardingFinish,
          isLoading: state.submitting,
          onPressed: controller.finish,
        ),
      ],
    );
  }
}

/// Bloqueo por minoría de edad (PRIVACY.md §3): explicación clara, sin
/// persistir ningún dato adicional; la única salida es cerrar sesión.
class _UnderageView extends ConsumerWidget {
  const _UnderageView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isLoading = ref.watch(authControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.underageTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.underageTitle,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.underageBody, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 32),
                  OutlinedButton(
                    onPressed: isLoading
                        ? null
                        : () => ref
                              .read(authControllerProvider.notifier)
                              .signOut(),
                    child: Text(l10n.authSignOut),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dropdown de catálogo con estados de carga/error del propio dataset.
class _CatalogDropdown extends StatelessWidget {
  const _CatalogDropdown({
    required this.label,
    required this.value,
    required this.enabled,
    required this.asyncItems,
    required this.onChanged,
    this.errorText,
  });

  final String label;
  final String? value;
  final bool enabled;
  final AsyncValue<List<({String id, String name})>> asyncItems;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = asyncItems.value ?? const <({String id, String name})>[];
    final hasError = asyncItems.hasError;
    final containsValue = items.any((item) => item.id == value);
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: containsValue ? value : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        errorText: hasError ? l10n.dataFailureNetwork : errorText,
        suffixIcon: asyncItems.isLoading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      items: [
        for (final item in items)
          DropdownMenuItem(value: item.id, child: Text(item.name)),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}
