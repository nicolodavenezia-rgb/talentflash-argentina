import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/models/data_failure.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../onboarding/domain/candidate_onboarding_data.dart';
import '../../onboarding/domain/catalog.dart';
import '../../onboarding/presentation/onboarding_copy.dart';
import '../../onboarding/providers/onboarding_providers.dart';
import '../domain/avatar.dart';
import '../domain/candidate_profile.dart';
import '../domain/candidate_profile_patch.dart';
import '../domain/weekly_availability.dart';
import '../providers/profile_edit_controller.dart';
import '../providers/profile_providers.dart';
import 'profile_copy.dart';
import 'widgets/profile_widgets.dart';

/// Edición del perfil profesional (T-021) + avatar (T-022).
///
/// Todo el estado del formulario vive acá; guardar arma UN parche completo y
/// lo aplica `update_my_candidate_profile` (idempotente). El servidor re-valida
/// todo: esta pantalla solo evita round-trips obvios.
class CandidateProfileEditScreen extends ConsumerStatefulWidget {
  const CandidateProfileEditScreen({super.key});

  @override
  ConsumerState<CandidateProfileEditScreen> createState() =>
      _CandidateProfileEditScreenState();
}

class _CandidateProfileEditScreenState
    extends ConsumerState<CandidateProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _headlineController = TextEditingController();
  final _bioController = TextEditingController();
  final _salaryMinController = TextEditingController();
  final _salaryMaxController = TextEditingController();

  bool _initialized = false;
  CandidateProfile? _base;

  String? _provinceId;
  String? _localityId;
  String? _neighborhoodId;
  String? _sectorId;
  CandidateAvailability? _availability;
  Set<CandidateWorkMode> _workModes = {};
  ExperienceLevel? _experienceLevel;
  List<String> _skills = [];
  List<String> _languages = [];
  List<WorkExperience> _workHistory = [];
  List<EducationEntry> _education = [];
  List<AvailabilitySlot> _slots = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(profileEditControllerProvider.notifier).reset();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _headlineController.dispose();
    _bioController.dispose();
    _salaryMinController.dispose();
    _salaryMaxController.dispose();
    super.dispose();
  }

  void _initFrom(CandidateProfile profile) {
    _base = profile;
    _nameController.text = profile.fullName ?? '';
    _headlineController.text = profile.headline ?? '';
    _bioController.text = profile.bio ?? '';
    _salaryMinController.text =
        profile.expectedSalaryMin?.toInt().toString() ?? '';
    _salaryMaxController.text =
        profile.expectedSalaryMax?.toInt().toString() ?? '';
    _provinceId = profile.province?.id;
    _localityId = profile.locality?.id;
    _neighborhoodId = profile.neighborhood?.id;
    _sectorId = profile.sector?.id;
    _availability = profile.availability;
    _workModes = {...profile.workModes};
    _experienceLevel = profile.experienceLevel;
    _skills = [...profile.skills];
    _languages = [...profile.languages];
    _workHistory = [...profile.workHistory];
    _education = [...profile.education];
    _slots = [...profile.weeklyAvailability];
    _initialized = true;
  }

  bool get _isDirty {
    final base = _base;
    if (base == null) {
      return false;
    }
    List<String> normalizedSalary(String raw) => [raw.trim()];
    return _nameController.text.trim() != (base.fullName ?? '') ||
        _headlineController.text.trim() != (base.headline ?? '') ||
        _bioController.text.trim() != (base.bio ?? '') ||
        normalizedSalary(_salaryMinController.text).first !=
            (base.expectedSalaryMin?.toInt().toString() ?? '') ||
        normalizedSalary(_salaryMaxController.text).first !=
            (base.expectedSalaryMax?.toInt().toString() ?? '') ||
        _provinceId != base.province?.id ||
        _localityId != base.locality?.id ||
        _neighborhoodId != base.neighborhood?.id ||
        _sectorId != base.sector?.id ||
        _availability != base.availability ||
        !_setEquals(_workModes, base.workModes) ||
        _experienceLevel != base.experienceLevel ||
        !_listEquals(_skills, base.skills) ||
        !_listEquals(_languages, base.languages) ||
        !_listEquals(_workHistory, base.workHistory) ||
        !_listEquals(_education, base.education) ||
        !_listEquals(_slots, base.weeklyAvailability);
  }

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  static bool _setEquals<T>(Set<T> a, Set<T> b) =>
      a.length == b.length && a.containsAll(b);

  Future<void> _handleClose() async {
    if (!_isDirty) {
      context.goNamed(AppRoute.candidateProfile.name);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileDiscardTitle),
        content: Text(l10n.profileDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.profileDiscardCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.profileDiscardConfirm),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      context.goNamed(AppRoute.candidateProfile.name);
    }
  }

  void _save() {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final min = _parseSalary(_salaryMinController.text);
    final max = _parseSalary(_salaryMaxController.text);
    if (min != null && max != null && min > max) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileErrorSalaryInvalid)));
      return;
    }

    // Parche completo: guardar dos veces el mismo estado es idempotente.
    final patch = CandidateProfilePatch()
      ..setFullName(_nameController.text.trim())
      ..setHeadline(_emptyToNull(_headlineController.text))
      ..setBio(_emptyToNull(_bioController.text))
      ..setExperienceLevel(_experienceLevel)
      ..setExpectedSalary(min: min, max: max)
      ..setSkills(_skills)
      ..setLanguages(_languages)
      ..setWorkHistory(_workHistory)
      ..setEducation(_education)
      ..setWeeklyAvailability(_slots);
    if (_provinceId != null && _localityId != null) {
      patch.setLocation(
        provinceId: _provinceId!,
        localityId: _localityId!,
        neighborhoodId: _neighborhoodId,
      );
    }
    if (_sectorId != null) {
      patch.setSector(_sectorId!);
    }
    if (_availability != null) {
      patch.setAvailability(_availability!);
    }
    if (_workModes.isNotEmpty) {
      patch.setWorkModes(_workModes);
    }
    FocusScope.of(context).unfocus();
    ref.read(profileEditControllerProvider.notifier).save(patch);
  }

  static String? _emptyToNull(String raw) {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static num? _parseSalary(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return int.tryParse(trimmed);
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ref.read(avatarImagePickerProvider);
    final image = await picker.pickImage();
    if (image == null || !mounted) {
      return;
    }
    await ref.read(profileEditControllerProvider.notifier).uploadAvatar(image);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(myProfileProvider);
    final actionState = ref.watch(profileEditControllerProvider);
    final isLoading = actionState.isLoading;

    ref.listen(profileEditControllerProvider, (previous, next) {
      final outcome = next.value;
      if (previous?.value != outcome && outcome != null) {
        final message = switch (outcome) {
          ProfileActionOutcome.saved => l10n.profileSavedMessage,
          ProfileActionOutcome.avatarUploaded => l10n.profileAvatarUploaded,
          ProfileActionOutcome.avatarDeleted => l10n.profileAvatarDeleted,
        };
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        if (outcome == ProfileActionOutcome.saved) {
          // El guardado quedó aplicado: la base pasa a ser lo recién salvado.
          final refreshed = ref.read(myProfileProvider).value;
          if (refreshed != null) {
            setState(() => _initFrom(refreshed));
          }
        }
      }
    });

    if (profileAsync.hasValue && !_initialized) {
      _initFrom(profileAsync.value!);
    }

    final error = actionState.error;
    final errorMessage = switch (error) {
      final AvatarFailure failure => ProfileCopy.avatarFailure(l10n, failure),
      final DataFailure failure => ProfileCopy.dataFailure(l10n, failure),
      _ => null,
    };

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleClose();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _handleClose),
          title: Text(l10n.profileEditTitle),
        ),
        body: SafeArea(
          child: !profileAsync.hasValue
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (errorMessage != null)
                              MessageBanner.error(
                                title: l10n.authErrorTitle,
                                message: errorMessage,
                              ),
                            _buildAvatarSection(l10n, isLoading),
                            const SizedBox(height: 24),
                            _buildIdentitySection(l10n, isLoading),
                            const SizedBox(height: 24),
                            _buildLocationSection(l10n, isLoading),
                            const SizedBox(height: 24),
                            _buildPreferencesSection(l10n, isLoading),
                            const SizedBox(height: 24),
                            _buildScheduleSection(l10n, isLoading),
                            const SizedBox(height: 24),
                            _buildSalarySection(l10n, isLoading),
                            const SizedBox(height: 24),
                            _ChipsEditor(
                              title: l10n.profileSectionSkills,
                              addLabel: l10n.skillsAddLabel,
                              values: _skills,
                              maxItems: 20,
                              maxLength: 40,
                              enabled: !isLoading,
                              onChanged: (values) =>
                                  setState(() => _skills = values),
                            ),
                            const SizedBox(height: 24),
                            _ChipsEditor(
                              title: l10n.profileSectionLanguages,
                              addLabel: l10n.languagesAddLabel,
                              values: _languages,
                              maxItems: 10,
                              maxLength: 30,
                              enabled: !isLoading,
                              onChanged: (values) =>
                                  setState(() => _languages = values),
                            ),
                            const SizedBox(height: 24),
                            _buildExperienceSection(l10n, isLoading),
                            const SizedBox(height: 24),
                            _buildEducationSection(l10n, isLoading),
                            const SizedBox(height: 32),
                            ProgressButton(
                              label: l10n.profileSaveAction,
                              isLoading: isLoading,
                              onPressed: _save,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(AppLocalizations l10n, bool isLoading) {
    final profile = ref.watch(myProfileProvider).value;
    final hasAvatar = profile?.avatarPath != null;
    return ProfileSection(
      title: l10n.profileAvatarLabel,
      children: [
        Row(
          children: [
            ProfileAvatar(
              avatarPath: profile?.avatarPath,
              semanticLabel: l10n.profileAvatarLabel,
              radius: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : _pickAndUploadAvatar,
                    icon: const Icon(Icons.photo_outlined),
                    label: Text(
                      hasAvatar
                          ? l10n.profileAvatarReplace
                          : l10n.profileAvatarAdd,
                    ),
                  ),
                  if (hasAvatar)
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => ref
                                .read(profileEditControllerProvider.notifier)
                                .deleteAvatar(),
                      child: Text(l10n.profileAvatarDelete),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.profileAvatarOptionalNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildIdentitySection(AppLocalizations l10n, bool isLoading) {
    return ProfileSection(
      title: l10n.profileSectionIdentity,
      children: [
        TextFormField(
          controller: _nameController,
          enabled: !isLoading,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.fullNameLabel,
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            final trimmed = (value ?? '').trim();
            if (trimmed.length < 2 || trimmed.length > 80) {
              return l10n.profileErrorNameRequired;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _headlineController,
          enabled: !isLoading,
          maxLength: 120,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.headlineLabel,
            helperText: l10n.headlineHelp,
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
          validator: (value) => (value ?? '').length > 120
              ? l10n.profileErrorHeadlineTooLong
              : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _bioController,
          enabled: !isLoading,
          maxLength: 2000,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: l10n.bioLabel,
            helperText: l10n.bioHelp,
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          validator: (value) =>
              (value ?? '').length > 2000 ? l10n.profileErrorBioTooLong : null,
        ),
      ],
    );
  }

  Widget _buildLocationSection(AppLocalizations l10n, bool isLoading) {
    final provinces = ref.watch(provincesProvider);
    final localities = _provinceId == null
        ? const AsyncValue<List<GeoLocality>>.data([])
        : ref.watch(localitiesProvider(_provinceId!));
    final neighborhoods = _localityId == null
        ? const AsyncValue<List<GeoNeighborhood>>.data([])
        : ref.watch(neighborhoodsProvider(_localityId!));
    return ProfileSection(
      title: l10n.profileSectionLocation,
      children: [
        _CatalogDropdown(
          label: l10n.provinceLabel,
          value: _provinceId,
          enabled: !isLoading,
          asyncItems: provinces.whenData(
            (items) => [
              for (final item in items) (id: item.id, name: item.name),
            ],
          ),
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
          enabled: !isLoading && _provinceId != null,
          asyncItems: localities.whenData(
            (items) => [
              for (final item in items) (id: item.id, name: item.name),
            ],
          ),
          onChanged: (value) => setState(() {
            _localityId = value;
            _neighborhoodId = null;
          }),
        ),
        const SizedBox(height: 16),
        _CatalogDropdown(
          label: l10n.neighborhoodLabel,
          value: _neighborhoodId,
          enabled: !isLoading && _localityId != null,
          asyncItems: neighborhoods.whenData(
            (items) => [
              for (final item in items) (id: item.id, name: item.name),
            ],
          ),
          onChanged: (value) => setState(() => _neighborhoodId = value),
        ),
      ],
    );
  }

  Widget _buildPreferencesSection(AppLocalizations l10n, bool isLoading) {
    final sectors = ref.watch(sectorsProvider);
    return ProfileSection(
      title: l10n.profileSectionPreferences,
      children: [
        _CatalogDropdown(
          label: l10n.sectorLabel,
          value: _sectorId,
          enabled: !isLoading,
          asyncItems: sectors.whenData(
            (items) => [
              for (final item in items) (id: item.id, name: item.name),
            ],
          ),
          onChanged: (value) => setState(() => _sectorId = value),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<CandidateAvailability>(
          initialValue: _availability,
          decoration: InputDecoration(
            labelText: l10n.availabilityLabel,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final value in CandidateAvailability.values)
              DropdownMenuItem(
                value: value,
                child: Text(OnboardingCopy.availability(l10n, value)),
              ),
          ],
          onChanged: isLoading
              ? null
              : (value) => setState(() => _availability = value),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<ExperienceLevel?>(
          initialValue: _experienceLevel,
          decoration: InputDecoration(
            labelText: l10n.experienceLevelLabel,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(l10n.profileOptionalEmptyValue),
            ),
            for (final value in ExperienceLevel.values)
              DropdownMenuItem(
                value: value,
                child: Text(ProfileCopy.experienceLevel(l10n, value)),
              ),
          ],
          onChanged: isLoading
              ? null
              : (value) => setState(() => _experienceLevel = value),
        ),
        const SizedBox(height: 16),
        Text(l10n.workModesLabel, style: Theme.of(context).textTheme.bodyLarge),
        for (final mode in CandidateWorkMode.values)
          CheckboxListTile(
            value: _workModes.contains(mode),
            title: Text(OnboardingCopy.workMode(l10n, mode)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            onChanged: isLoading
                ? null
                : (checked) => setState(() {
                    if (checked ?? false) {
                      _workModes.add(mode);
                    } else {
                      _workModes.remove(mode);
                    }
                  }),
          ),
      ],
    );
  }

  Widget _buildScheduleSection(AppLocalizations l10n, bool isLoading) {
    return ProfileSection(
      title: l10n.profileSectionSchedule,
      children: [
        Text(
          l10n.scheduleCrossesNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _slots.length; i++)
          Row(
            children: [
              Expanded(child: Text(ProfileCopy.slot(l10n, _slots[i]))),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.scheduleDeleteLabel(
                  ProfileCopy.weekDay(l10n, _slots[i].day),
                ),
                onPressed: isLoading
                    ? null
                    : () => setState(() => _slots.removeAt(i)),
              ),
            ],
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : () => _addSlot(l10n),
            icon: const Icon(Icons.add),
            label: Text(l10n.scheduleAdd),
          ),
        ),
      ],
    );
  }

  Future<void> _addSlot(AppLocalizations l10n) async {
    final slot = await showDialog<AvailabilitySlot>(
      context: context,
      builder: (dialogContext) => _SlotDialog(existing: _slots),
    );
    if (slot != null && mounted) {
      setState(() => _slots = [..._slots, slot]);
    }
  }

  Widget _buildSalarySection(AppLocalizations l10n, bool isLoading) {
    return ProfileSection(
      title: l10n.profileSectionSalary,
      children: [
        Text(
          l10n.salaryOptionalNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _salaryMinController,
                enabled: !isLoading,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.salaryMinLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: _validateSalaryField(l10n),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _salaryMaxController,
                enabled: !isLoading,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.salaryMaxLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: _validateSalaryField(l10n),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String? Function(String?) _validateSalaryField(AppLocalizations l10n) {
    return (value) {
      final trimmed = (value ?? '').trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return int.tryParse(trimmed) == null
          ? l10n.profileErrorSalaryFormat
          : null;
    };
  }

  Widget _buildExperienceSection(AppLocalizations l10n, bool isLoading) {
    return ProfileSection(
      title: l10n.profileSectionExperience,
      children: [
        for (var i = 0; i < _workHistory.length; i++)
          _EditableListTile(
            title: '${_workHistory[i].position} · ${_workHistory[i].company}',
            subtitle: _workHistory[i].isCurrent
                ? l10n.profileExperienceCurrent(_workHistory[i].fromMonth)
                : l10n.profileExperiencePeriod(
                    _workHistory[i].fromMonth,
                    _workHistory[i].toMonth!,
                  ),
            enabled: !isLoading,
            canMoveUp: i > 0,
            canMoveDown: i < _workHistory.length - 1,
            moveUpLabel: l10n.experienceMoveUp,
            moveDownLabel: l10n.experienceMoveDown,
            editLabel: l10n.experienceEditAction,
            deleteLabel: l10n.experienceDeleteAction,
            onMoveUp: () => setState(() {
              final entry = _workHistory.removeAt(i);
              _workHistory.insert(i - 1, entry);
            }),
            onMoveDown: () => setState(() {
              final entry = _workHistory.removeAt(i);
              _workHistory.insert(i + 1, entry);
            }),
            onEdit: () => _editExperience(index: i),
            onDelete: () => setState(() => _workHistory.removeAt(i)),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: isLoading || _workHistory.length >= 20
                ? null
                : _editExperience,
            icon: const Icon(Icons.add),
            label: Text(l10n.experienceAdd),
          ),
        ),
      ],
    );
  }

  Future<void> _editExperience({int? index}) async {
    final entry = await showDialog<WorkExperience>(
      context: context,
      builder: (dialogContext) => _ExperienceDialog(
        initial: index == null ? null : _workHistory[index],
      ),
    );
    if (entry != null && mounted) {
      setState(() {
        if (index == null) {
          _workHistory = [..._workHistory, entry];
        } else {
          _workHistory = [..._workHistory]..[index] = entry;
        }
      });
    }
  }

  Widget _buildEducationSection(AppLocalizations l10n, bool isLoading) {
    return ProfileSection(
      title: l10n.profileSectionEducation,
      children: [
        Text(
          l10n.educationOptionalNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _education.length; i++)
          _EditableListTile(
            title:
                '${ProfileCopy.educationLevel(l10n, _education[i].level)} · '
                '${_education[i].institution}',
            subtitle: _education[i].degree,
            enabled: !isLoading,
            canMoveUp: false,
            canMoveDown: false,
            moveUpLabel: l10n.experienceMoveUp,
            moveDownLabel: l10n.experienceMoveDown,
            editLabel: l10n.experienceEditAction,
            deleteLabel: l10n.experienceDeleteAction,
            onEdit: () => _editEducation(index: i),
            onDelete: () => setState(() => _education.removeAt(i)),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: isLoading || _education.length >= 10
                ? null
                : _editEducation,
            icon: const Icon(Icons.add),
            label: Text(l10n.educationAdd),
          ),
        ),
      ],
    );
  }

  Future<void> _editEducation({int? index}) async {
    final entry = await showDialog<EducationEntry>(
      context: context,
      builder: (dialogContext) =>
          _EducationDialog(initial: index == null ? null : _education[index]),
    );
    if (entry != null && mounted) {
      setState(() {
        if (index == null) {
          _education = [..._education, entry];
        } else {
          _education = [..._education]..[index] = entry;
        }
      });
    }
  }
}

/// Dropdown de catálogo (mismo patrón que el wizard de onboarding).
class _CatalogDropdown extends StatelessWidget {
  const _CatalogDropdown({
    required this.label,
    required this.value,
    required this.enabled,
    required this.asyncItems,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final bool enabled;
  final AsyncValue<List<({String id, String name})>> asyncItems;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = asyncItems.value ?? const <({String id, String name})>[];
    final knownValue =
        items.any((({String id, String name}) item) => item.id == value)
        ? value
        : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-${items.length}-$knownValue'),
      initialValue: knownValue,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem(value: item.id, child: Text(item.name)),
      ],
      onChanged: enabled && !asyncItems.isLoading ? onChanged : null,
    );
  }
}

/// Fila editable de una lista (experiencia/educación) con acciones accesibles
/// por teclado y lector: editar, eliminar y reordenar sin drag & drop.
class _EditableListTile extends StatelessWidget {
  const _EditableListTile({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.moveUpLabel,
    required this.moveDownLabel,
    required this.editLabel,
    required this.deleteLabel,
    required this.onEdit,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
  });

  final String title;
  final String? subtitle;
  final bool enabled;
  final bool canMoveUp;
  final bool canMoveDown;
  final String moveUpLabel;
  final String moveDownLabel;
  final String editLabel;
  final String deleteLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  if (subtitle != null)
                    Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (canMoveUp || canMoveDown) ...[
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                tooltip: moveUpLabel,
                onPressed: enabled && canMoveUp ? onMoveUp : null,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward),
                tooltip: moveDownLabel,
                onPressed: enabled && canMoveDown ? onMoveDown : null,
              ),
            ],
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: editLabel,
              onPressed: enabled ? onEdit : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: deleteLabel,
              onPressed: enabled ? onDelete : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Editor de chips (habilidades e idiomas) con validación local.
class _ChipsEditor extends StatefulWidget {
  const _ChipsEditor({
    required this.title,
    required this.addLabel,
    required this.values,
    required this.maxItems,
    required this.maxLength,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String addLabel;
  final List<String> values;
  final int maxItems;
  final int maxLength;
  final bool enabled;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_ChipsEditor> createState() => _ChipsEditorState();
}

class _ChipsEditorState extends State<_ChipsEditor> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(AppLocalizations l10n) {
    final value = _controller.text.trim();
    setState(() {
      if (value.isEmpty) {
        _error = l10n.profileErrorChipEmpty;
      } else if (value.length > widget.maxLength) {
        _error = l10n.profileErrorChipTooLong;
      } else if (widget.values.any(
        (existing) => existing.toLowerCase() == value.toLowerCase(),
      )) {
        _error = l10n.profileErrorChipDuplicate;
      } else if (widget.values.length >= widget.maxItems) {
        _error = l10n.profileErrorTooManyChips;
      } else {
        _error = null;
        widget.onChanged([...widget.values, value]);
        _controller.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ProfileSection(
      title: widget.title,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: widget.enabled,
                maxLength: widget.maxLength,
                decoration: InputDecoration(
                  labelText: widget.addLabel,
                  errorText: _error,
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
                onSubmitted: (_) => _add(l10n),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: widget.enabled ? () => _add(l10n) : null,
              child: Text(l10n.chipAddAction),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in widget.values)
              InputChip(
                label: Text(value),
                deleteButtonTooltipMessage: l10n.chipRemoveLabel(value),
                onDeleted: widget.enabled
                    ? () => widget.onChanged(
                        widget.values
                            .where((existing) => existing != value)
                            .toList(),
                      )
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}

/// Diálogo de alta/edición de una experiencia laboral.
class _ExperienceDialog extends StatefulWidget {
  const _ExperienceDialog({this.initial});

  final WorkExperience? initial;

  @override
  State<_ExperienceDialog> createState() => _ExperienceDialogState();
}

class _ExperienceDialogState extends State<_ExperienceDialog> {
  late final _company = TextEditingController(text: widget.initial?.company);
  late final _position = TextEditingController(text: widget.initial?.position);
  late final _from = TextEditingController(
    text: _toDisplayMonth(widget.initial?.fromMonth),
  );
  late final _to = TextEditingController(
    text: _toDisplayMonth(widget.initial?.toMonth),
  );
  late final _description = TextEditingController(
    text: widget.initial?.description,
  );
  late bool _current = widget.initial?.isCurrent ?? false;
  String? _error;

  static String _toDisplayMonth(String? wire) {
    if (wire == null) {
      return '';
    }
    final parts = wire.split('-');
    return parts.length == 2 ? '${parts[1]}/${parts[0]}' : '';
  }

  static String? _toWireMonth(String display) {
    final match = RegExp(r'^(0[1-9]|1[0-2])/([0-9]{4})$')
        .firstMatch(display.trim());
    if (match == null) {
      return null;
    }
    return '${match.group(2)}-${match.group(1)}';
  }

  @override
  void dispose() {
    _company.dispose();
    _position.dispose();
    _from.dispose();
    _to.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit(AppLocalizations l10n) {
    final company = _company.text.trim();
    final position = _position.text.trim();
    final from = _toWireMonth(_from.text);
    if (company.isEmpty || position.isEmpty || from == null) {
      setState(
        () => _error = company.isEmpty || position.isEmpty
            ? l10n.experienceErrorRequired
            : l10n.experienceErrorDates,
      );
      return;
    }
    String? to;
    if (!_current) {
      to = _toWireMonth(_to.text);
      if (to == null || to.compareTo(from) < 0) {
        setState(() => _error = l10n.experienceErrorDates);
        return;
      }
    }
    final description = _description.text.trim();
    Navigator.of(context).pop(
      WorkExperience(
        company: company,
        position: position,
        fromMonth: from,
        toMonth: _current ? null : to,
        description: description.isEmpty ? null : description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        widget.initial == null ? l10n.experienceAdd : l10n.experienceEditAction,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            TextField(
              controller: _company,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: l10n.experienceCompanyLabel,
                counterText: '',
              ),
            ),
            TextField(
              controller: _position,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: l10n.experiencePositionLabel,
                counterText: '',
              ),
            ),
            TextField(
              controller: _from,
              keyboardType: TextInputType.datetime,
              decoration: InputDecoration(
                labelText: l10n.experienceFromLabel,
                hintText: '03/2021',
              ),
            ),
            CheckboxListTile(
              value: _current,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.experienceCurrentLabel),
              onChanged: (checked) =>
                  setState(() => _current = checked ?? false),
            ),
            if (!_current)
              TextField(
                controller: _to,
                keyboardType: TextInputType.datetime,
                decoration: InputDecoration(
                  labelText: l10n.experienceToLabel,
                  hintText: '11/2023',
                ),
              ),
            TextField(
              controller: _description,
              maxLength: 400,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.experienceDescriptionLabel,
                counterText: '',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.profileDiscardCancel),
        ),
        FilledButton(
          onPressed: () => _submit(l10n),
          child: Text(l10n.experienceDialogSave),
        ),
      ],
    );
  }
}

/// Diálogo de alta/edición de una entrada de educación.
class _EducationDialog extends StatefulWidget {
  const _EducationDialog({this.initial});

  final EducationEntry? initial;

  @override
  State<_EducationDialog> createState() => _EducationDialogState();
}

class _EducationDialogState extends State<_EducationDialog> {
  late EducationLevel? _level = widget.initial?.level;
  late final _institution = TextEditingController(
    text: widget.initial?.institution,
  );
  late final _degree = TextEditingController(text: widget.initial?.degree);
  String? _error;

  @override
  void dispose() {
    _institution.dispose();
    _degree.dispose();
    super.dispose();
  }

  void _submit(AppLocalizations l10n) {
    final institution = _institution.text.trim();
    if (_level == null || institution.isEmpty) {
      setState(() => _error = l10n.educationErrorRequired);
      return;
    }
    final degree = _degree.text.trim();
    Navigator.of(context).pop(
      EducationEntry(
        level: _level!,
        institution: institution,
        degree: degree.isEmpty ? null : degree,
        fromMonth: widget.initial?.fromMonth,
        toMonth: widget.initial?.toMonth,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.educationAdd),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          DropdownButtonFormField<EducationLevel>(
            initialValue: _level,
            decoration: InputDecoration(labelText: l10n.educationLevelLabel),
            items: [
              for (final level in EducationLevel.values)
                DropdownMenuItem(
                  value: level,
                  child: Text(ProfileCopy.educationLevel(l10n, level)),
                ),
            ],
            onChanged: (value) => setState(() => _level = value),
          ),
          TextField(
            controller: _institution,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: l10n.educationInstitutionLabel,
              counterText: '',
            ),
          ),
          TextField(
            controller: _degree,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: l10n.educationDegreeLabel,
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.profileDiscardCancel),
        ),
        FilledButton(
          onPressed: () => _submit(l10n),
          child: Text(l10n.educationDialogSave),
        ),
      ],
    );
  }
}

/// Diálogo de alta de franja horaria, validada contra las ya cargadas.
class _SlotDialog extends StatefulWidget {
  const _SlotDialog({required this.existing});

  final List<AvailabilitySlot> existing;

  @override
  State<_SlotDialog> createState() => _SlotDialogState();
}

class _SlotDialogState extends State<_SlotDialog> {
  WeekDay _day = WeekDay.lun;
  final _start = TextEditingController();
  final _end = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  void _submit(AppLocalizations l10n) {
    final start = AvailabilitySlot.parseTime(_start.text.trim());
    final end = AvailabilitySlot.parseTime(_end.text.trim());
    if (start == null || end == null) {
      setState(() => _error = l10n.scheduleErrorFormat);
      return;
    }
    final slot = AvailabilitySlot(
      day: _day,
      startMinutes: start,
      endMinutes: end,
    );
    final issue = WeeklyAvailabilityValidator.validate([
      ...widget.existing,
      slot,
    ]);
    if (issue != null) {
      setState(
        () => _error = switch (issue) {
          WeeklyAvailabilityIssue.overlap => l10n.scheduleErrorOverlap,
          WeeklyAvailabilityIssue.zeroLength => l10n.scheduleErrorZeroLength,
          WeeklyAvailabilityIssue.tooManySlots ||
          WeeklyAvailabilityIssue.tooManySlotsPerDay =>
            l10n.scheduleErrorTooMany,
        },
      );
      return;
    }
    Navigator.of(context).pop(slot);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.scheduleAdd),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          DropdownButtonFormField<WeekDay>(
            initialValue: _day,
            decoration: InputDecoration(labelText: l10n.scheduleDayLabel),
            items: [
              for (final day in WeekDay.values)
                DropdownMenuItem(
                  value: day,
                  child: Text(ProfileCopy.weekDay(l10n, day)),
                ),
            ],
            onChanged: (value) => setState(() => _day = value ?? WeekDay.lun),
          ),
          TextField(
            controller: _start,
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(
              labelText: l10n.scheduleStartLabel,
              hintText: '18:00',
            ),
          ),
          TextField(
            controller: _end,
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(
              labelText: l10n.scheduleEndLabel,
              hintText: '23:30',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.profileDiscardCancel),
        ),
        FilledButton(
          onPressed: () => _submit(l10n),
          child: Text(l10n.scheduleDialogSave),
        ),
      ],
    );
  }
}
