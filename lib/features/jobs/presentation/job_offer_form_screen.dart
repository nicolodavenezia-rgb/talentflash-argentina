import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../companies/data/company_access_repository.dart';
import '../../companies/providers/company_verification_providers.dart';
import '../../onboarding/domain/catalog.dart';
import '../../onboarding/presentation/onboarding_copy.dart';
import '../../onboarding/providers/onboarding_providers.dart';
import '../../profiles/presentation/profile_copy.dart';
import '../domain/job_offer.dart';
import '../domain/job_offer_enums.dart';
import '../domain/job_offer_input.dart';
import '../domain/job_offer_lifecycle.dart';
import '../domain/job_offer_validation.dart';
import '../providers/job_offer_editor_controller.dart';
import '../providers/job_offers_providers.dart';
import 'jobs_copy.dart';
import 'widgets/job_offer_details_view.dart';
import 'widgets/job_screen_states.dart';
import 'widgets/job_section.dart';
import 'widgets/rune_length_limiting_formatter.dart';

/// Líneas que puede ocupar un error o una ayuda debajo de un campo. Sin
/// esto Material los corta en UNA línea con "…": con texto al 200 % en un
/// teléfono de 360 dp el error más largo (el del barrio, D2) ocupa tres.
/// Cinco deja margen sin cortar nunca un mensaje.
const _messageMaxLines = 5;

/// Relleno de los desplegables, que además se arman con `isDense: false` e
/// `itemHeight: null` para que el valor elegido crezca con el texto: el
/// desplegable "denso" de Material lo encierra en un renglón y, con texto
/// grande, "Ciudad Autónoma de Buenos Aires" quedaba cortado. Cada opción
/// mide al menos 48 de alto; con este relleno, a tamaño normal el campo
/// mide lo mismo que antes (56).
const _dropdownPadding = EdgeInsetsDirectional.fromSTEB(12, 4, 12, 4);

/// Formulario de oferta (T-030): alta (`/empresa/ofertas/nueva`), alta
/// copiando otra (`?duplicar=<id>`) y edición (`/empresa/ofertas/:id/editar`).
///
/// Un solo formulario desplazable, por secciones con encabezado. Es el camino
/// manual: el asistente "Contámelo con tus palabras" es T-060 y no se ofrece
/// hasta que exista. La validación es la de [JobOfferValidation] (espejo de
/// 0032) con el mismo modo que va a usar el controller; los errores van
/// pegados a su campo y el foco salta al primero. El servidor vuelve a
/// validar todo: lo de acá solo evita idas y vueltas obvias.
class JobOfferFormScreen extends ConsumerStatefulWidget {
  const JobOfferFormScreen({this.jobId, this.duplicateOfId, super.key});

  /// Oferta a editar. Null = alta.
  final String? jobId;

  /// Oferta cuyo contenido se copia en un alta (acción "Duplicar").
  final String? duplicateOfId;

  bool get isEdit => jobId != null;

  @override
  ConsumerState<JobOfferFormScreen> createState() => _JobOfferFormScreenState();
}

/// Botón que se tocó, para saber qué modo de validación aplica y en cuál
/// mostrar el progreso.
enum _Submit { draft, publish, save }

class _JobOfferFormScreenState extends ConsumerState<JobOfferFormScreen> {
  /// Orden VISUAL de los campos (el de las secciones), para llevar el foco
  /// al primer error que la persona ve, no al primero del enum.
  static const _visualOrder = [
    JobOfferField.title,
    JobOfferField.description,
    JobOfferField.salaryMin,
    JobOfferField.salaryMax,
    JobOfferField.salaryPeriod,
    JobOfferField.contractType,
    JobOfferField.jornada,
    JobOfferField.scheduleDays,
    JobOfferField.scheduleDetail,
    JobOfferField.workMode,
    JobOfferField.province,
    JobOfferField.locality,
    JobOfferField.neighborhood,
    JobOfferField.experience,
    JobOfferField.availability,
    JobOfferField.benefits,
    JobOfferField.vacancies,
    JobOfferField.expiresAt,
  ];

  final _scrollController = ScrollController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _scheduleDetail = TextEditingController();
  final _salaryMin = TextEditingController();
  final _salaryMax = TextEditingController();
  final _vacancies = TextEditingController();
  final _expiryText = TextEditingController();
  final _newBenefit = TextEditingController();
  final _focus = {for (final field in JobOfferField.values) field: FocusNode()};

  bool _initialized = false;

  /// Lo que había al abrir el formulario: contra esto se decide si hay
  /// cambios sin guardar.
  JobOfferInput _base = const JobOfferInput();

  /// Oferta que se está editando, con el estado que la pantalla muestra.
  JobOffer? _editing;

  /// Oferta de la que se copió el contenido (acción "Duplicar"): de ahí sale
  /// la empresa de la vista previa.
  JobOffer? _duplicating;

  /// La oferta tenía un sector que ya no está activo y el formulario lo
  /// quitó: se explica junto al desplegable hasta que se elija otro.
  bool _sectorUnavailable = false;

  SalaryPeriod? _salaryPeriod = SalaryPeriod.mensual;
  ContractType? _contractType;
  JornadaType? _jornada;
  List<WeekDay> _scheduleDays = const [];
  JobWorkMode? _workMode;
  String? _provinceId;
  String? _localityId;
  String? _neighborhoodId;
  String? _sectorId;
  ExperienceLevel? _experience;
  JobAvailability? _availability;
  List<String> _benefits = const [];
  DateTime? _expiresAt;
  JobBenefitIssue? _newBenefitIssue;

  /// Modo del último intento de guardar: desde ahí los errores se muestran
  /// y se recalculan en vivo mientras la persona corrige.
  JobOfferSaveMode? _attemptedMode;

  /// Botón en vuelo (para el indicador de progreso).
  _Submit? _pending;

  /// Se guardó y se está saliendo: ya no hay cambios que proteger.
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(jobOfferEditorControllerProvider.notifier).reset();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _title.dispose();
    _description.dispose();
    _scheduleDetail.dispose();
    _salaryMin.dispose();
    _salaryMax.dispose();
    _vacancies.dispose();
    _expiryText.dispose();
    _newBenefit.dispose();
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Estado del formulario
  // ---------------------------------------------------------------------------

  void _initFrom(JobOfferInput input, String locale) {
    _title.text = input.title;
    _description.text = input.description;
    _scheduleDetail.text = input.scheduleDetail;
    _salaryMin.text = _amountText(input.salaryMin);
    _salaryMax.text = _amountText(input.salaryMax);
    _vacancies.text = input.vacancies?.toString() ?? '';
    _salaryPeriod = input.salaryPeriod;
    _contractType = input.contractType;
    _jornada = input.jornada;
    _scheduleDays = [...input.scheduleDays];
    _workMode = input.workMode;
    _provinceId = input.provinciaId;
    _localityId = input.localidadId;
    _neighborhoodId = input.barrioId;
    _sectorId = input.sectorId;
    _experience = input.experience;
    _availability = input.availability;
    _benefits = [...input.benefits];
    _setExpiry(input.expiresAt, locale);
    _base = input;
    _initialized = true;
  }

  static String _amountText(num? value) {
    if (value == null) {
      return '';
    }
    return value == value.truncate()
        ? value.toInt().toString()
        : value.toString();
  }

  void _setExpiry(DateTime? value, String locale) {
    _expiresAt = value;
    _expiryText.text = value == null ? '' : JobsCopy.date(value, locale);
  }

  /// El sector de la oferta tiene que estar entre los ACTIVOS. Si se
  /// desactivó, el desplegable no lo puede mostrar ("Sin especificar"), y lo
  /// que se ve tiene que ser lo que se guarda: se quita, en alta, duplicado y
  /// edición. (El servidor rechaza un sector inactivo en un alta y en una
  /// edición lo conservaría sin que se viera.) También sale de [_base]: que
  /// el formulario lo quite no es un cambio de la persona que haya que
  /// proteger al salir.
  void _dropInactiveSector(List<Sector>? activeSectors) {
    final sectorId = _sectorId;
    if (activeSectors == null ||
        sectorId == null ||
        activeSectors.any((sector) => sector.id == sectorId)) {
      return;
    }
    _sectorId = null;
    _base = _base.copyWith(sectorId: () => null);
    _sectorUnavailable = true;
  }

  /// El formulario tal como está ahora. Un monto o una cantidad que no se
  /// pueden interpretar viajan como null: la validación lo marca en el campo.
  JobOfferInput get _input => JobOfferInput(
    title: _title.text,
    description: _description.text,
    sectorId: _sectorId,
    salaryMin: JobOfferValidation.parseAmount(_salaryMin.text),
    salaryMax: JobOfferValidation.parseAmount(_salaryMax.text),
    salaryPeriod: _salaryPeriod,
    contractType: _contractType,
    jornada: _jornada,
    scheduleDays: _scheduleDays,
    scheduleDetail: _scheduleDetail.text,
    workMode: _workMode,
    provinciaId: _provinceId,
    localidadId: _localityId,
    barrioId: _neighborhoodId,
    experience: _experience,
    availability: _availability,
    benefits: _benefits,
    expiresAt: _expiresAt,
    vacancies: JobOfferValidation.parseVacancies(_vacancies.text),
  );

  bool get _isDirty => _initialized && !_leaving && _input != _base;

  /// D2: ¿la localidad elegida tiene barrios? Null mientras no se sabe; en
  /// ese caso no se bloquea y decide el servidor.
  bool? get _localityHasNeighborhoods {
    final localityId = _localityId;
    if (localityId == null) {
      return null;
    }
    return ref.read(neighborhoodsProvider(localityId)).value?.isNotEmpty;
  }

  JobOfferSaveMode _modeFor(_Submit submit) {
    final editing = _editing;
    return switch (submit) {
      _Submit.publish => JobOfferSaveMode.publish,
      _Submit.draft => JobOfferSaveMode.draft,
      _Submit.save =>
        editing?.status == JobStatus.active
            ? JobOfferSaveMode.editActive
            : JobOfferSaveMode.draft,
    };
  }

  JobOfferIssues _validate(JobOfferSaveMode mode) {
    final editing = _editing;
    return JobOfferValidation.validate(
      _input,
      mode: mode,
      now: ref.read(jobClockProvider)(),
      original: editing == null ? null : JobOfferInput.fromOffer(editing),
      localityHasNeighborhoods: _localityHasNeighborhoods,
    );
  }

  Duration get _scrollDuration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 250);

  void _focusFirstInvalid(JobOfferIssues issues) {
    for (final field in _visualOrder) {
      if (issues.issueFor(field) != null) {
        // Después del frame: el campo tiene que estar dibujado con su error.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          final node = _focus[field]!;
          node.requestFocus();
          final target = node.context;
          if (target != null) {
            Scrollable.ensureVisible(
              target,
              alignment: 0.2,
              duration: _scrollDuration,
            );
          }
        });
        return;
      }
    }
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) {
      return;
    }
    final duration = _scrollDuration;
    if (duration == Duration.zero) {
      _scrollController.jumpTo(0);
    } else {
      _scrollController.animateTo(0, duration: duration, curve: Curves.easeOut);
    }
  }

  // ---------------------------------------------------------------------------
  // Acciones
  // ---------------------------------------------------------------------------

  Future<void> _submit(_Submit submit) async {
    final mode = _modeFor(submit);
    final issues = _validate(mode);
    setState(() => _attemptedMode = mode);
    if (!issues.isEmpty) {
      _focusFirstInvalid(issues);
      return;
    }
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(jobOfferEditorControllerProvider.notifier);
    final input = _input;
    final hasNeighborhoods = _localityHasNeighborhoods;
    final editing = _editing;
    setState(() => _pending = submit);

    final JobOffer? saved;
    if (editing == null) {
      saved = submit == _Submit.publish
          ? await notifier.publish(
              input,
              localityHasNeighborhoods: hasNeighborhoods,
            )
          : await notifier.saveDraft(input);
    } else if (submit == _Submit.publish) {
      saved = await notifier.publishDraft(
        editing,
        input,
        localityHasNeighborhoods: hasNeighborhoods,
      );
    } else {
      saved = await notifier.saveChanges(
        editing,
        input,
        localityHasNeighborhoods: hasNeighborhoods,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() => _pending = null);
    if (saved == null) {
      // El cartel de error ya está arriba (y es región viva): se lo muestra.
      _scrollToTop();
      return;
    }
    final outcome =
        ref.read(jobOfferEditorControllerProvider).value ??
        JobOfferEditorOutcome.changesSaved;
    setState(() => _leaving = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(JobsCopy.editorOutcome(l10n, outcome))),
    );
    context.goNamed(AppRoute.companyJobs.name);
  }

  Future<void> _handleClose() async {
    if (!_isDirty) {
      context.goNamed(AppRoute.companyJobs.name);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.jobLeaveTitle),
        content: Text(l10n.jobLeaveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.jobLeaveCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.jobLeaveConfirm),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() => _leaving = true);
      context.goNamed(AppRoute.companyJobs.name);
    }
  }

  Future<void> _pickExpiry() async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final now = ref.read(jobClockProvider)();
    final localNow = now.toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    // (hoy, hoy + 60 días]: el mismo rango que acepta el servidor al
    // publicar (D1), en días del calendario de la persona.
    final first = DateTime(today.year, today.month, today.day + 1);
    final last = DateTime(
      today.year,
      today.month,
      today.day + JobOfferValidation.maxPublicationDays,
    );
    final suggested = DateTime(today.year, today.month, today.day + 30);
    final current = _expiresAt?.toLocal();
    final currentDay = current == null
        ? null
        : DateTime(current.year, current.month, current.day);
    final initial =
        currentDay != null &&
            !currentDay.isBefore(first) &&
            !currentDay.isAfter(last)
        ? currentDay
        : suggested;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: l10n.jobExpiryLabel,
    );
    if (picked == null || !mounted) {
      return;
    }
    // El servidor compara instantes, no días: la oferta vence al final del
    // día elegido, salvo el último día de la ventana, que se recorta al
    // límite exacto de D1 para no pasarse por unas horas.
    final endOfDay = DateTime(
      picked.year,
      picked.month,
      picked.day,
      23,
      59,
      59,
    );
    final latest = JobOfferValidation.latestExpiry(now);
    setState(
      () => _setExpiry(endOfDay.isAfter(latest) ? latest : endOfDay, locale),
    );
  }

  void _addBenefit() {
    final raw = _newBenefit.text;
    final issue = JobOfferValidation.validateNewBenefit(raw, _benefits);
    setState(() {
      _newBenefitIssue = issue;
      if (issue == null) {
        _benefits = [..._benefits, raw.trim()];
        _newBenefit.clear();
      }
    });
  }

  void _openPreview() {
    final issues = _validate(JobOfferSaveMode.draft);
    if (!issues.isEmpty) {
      // La vista previa muestra lo que se guardaría: sin los obligatorios no
      // hay nada fiel para mostrar.
      setState(() => _attemptedMode ??= JobOfferSaveMode.draft);
      _focusFirstInvalid(issues);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final editing = _editing;
    final input = _input;
    // La empresa como la verá el candidato: la embebida en la oferta que se
    // edita o se duplica, y para un alta la fila de MI empresa. Solo si esa
    // lectura falló queda un nombre provisorio.
    final company =
        editing?.company ??
        _duplicating?.company ??
        ref.read(myCompanySummaryProvider).value ??
        JobOfferCompany(
          name: l10n.jobPreviewCompanyName,
          verificationStatus: ref
              .read(myCompanyVerificationProvider)
              .value
              ?.companyStatus,
        );
    final preview = JobOffer(
      id: editing?.id ?? '',
      companyId: editing?.companyId ?? '',
      title: input.title.trim(),
      description: input.description.trim(),
      sectorId: input.sectorId,
      salaryMin: input.salaryMin ?? 0,
      salaryMax: input.salaryMax ?? 0,
      salaryPeriod: input.salaryPeriod,
      contractType: input.contractType,
      jornada: input.jornada,
      scheduleDays: input.scheduleDays,
      scheduleDetail: input.scheduleDetail.trim(),
      workMode: input.workMode,
      provinciaId: input.provinciaId ?? '',
      localidadId: input.localidadId ?? '',
      barrioId: input.barrioId,
      experience: input.experience,
      availability: input.availability,
      benefits: [for (final benefit in input.benefits) benefit.trim()],
      expiresAt: input.expiresAt,
      vacancies: input.vacancies ?? 1,
      status: JobStatus.active,
      company: company,
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: const CloseButton(),
            title: Text(l10n.jobPreview),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MessageBanner.info(message: l10n.jobPreviewNote),
                      JobOfferDetailsView(offer: preview),
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

  // ---------------------------------------------------------------------------
  // Pantalla
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
          title: Text(
            widget.isEdit ? l10n.jobFormEditTitle : l10n.jobFormNewTitle,
          ),
        ),
        body: SafeArea(child: _buildBody(context, l10n)),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    final sourceId = widget.jobId ?? widget.duplicateOfId;
    if (sourceId != null && !isWellFormedJobId(sourceId)) {
      return _notFound(l10n);
    }
    // Se pide junto con el permiso, no después, para no encadenar esperas.
    final sourceAsync = sourceId == null
        ? null
        : ref.watch(jobOfferProvider(sourceId));

    // Permiso de escritura (D3). Es UX: sin él ni siquiera se ofrece el
    // formulario, pero quien decide es la policy de `jobs`.
    final canWrite = ref.watch(canWriteCompanyJobsProvider);
    if (!canWrite.hasValue) {
      if (canWrite.hasError) {
        // El motivo real (sin red, cuenta en más de una empresa…) dice más
        // que un "no pudimos comprobar" genérico.
        return JobCenteredMessage(
          title: l10n.jobsErrorTitle,
          body: JobsCopy.failure(l10n, canWrite.error),
          actions: [
            FilledButton(
              onPressed: () {
                if (ref.read(myCompanyVerificationProvider).hasError) {
                  ref.invalidate(myCompanyVerificationProvider);
                }
                ref.invalidate(canWriteCompanyJobsProvider);
              },
              child: Text(l10n.retryLabel),
            ),
          ],
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (canWrite.value != true) {
      return JobCenteredMessage(
        title: l10n.jobsCompanyTitle,
        body: l10n.jobsReadOnlyBanner,
        actions: [_backToListButton(l10n)],
      );
    }

    JobOffer? source;
    if (sourceId != null && sourceAsync != null) {
      if (!sourceAsync.hasValue) {
        if (sourceAsync.hasError) {
          return JobCenteredMessage(
            title: l10n.jobLoadError,
            actions: [
              FilledButton(
                onPressed: () => ref.invalidate(jobOfferProvider(sourceId)),
                child: Text(l10n.retryLabel),
              ),
              _backToListButton(l10n),
            ],
          );
        }
        return const Center(child: CircularProgressIndicator());
      }
      source = sourceAsync.value;
      // La lectura por id también devuelve ofertas activas públicas de OTRAS
      // empresas: acá solo se editan o duplican las propias.
      final companyId = ref.watch(myCompanyIdProvider).value;
      if (source == null ||
          companyId == null ||
          source.companyId != companyId) {
        return _notFound(l10n);
      }
      if (widget.isEdit &&
          !JobOfferLifecycle.editableStatuses.contains(source.status)) {
        return _notEditable(l10n, source);
      }
    }

    final locale = Localizations.localeOf(context).toString();
    if (!_initialized) {
      _initFrom(switch (source) {
        null => const JobOfferInput(),
        final JobOffer offer when widget.isEdit => JobOfferInput.fromOffer(
          offer,
        ),
        final JobOffer offer => JobOfferInput.duplicateOf(offer),
      }, locale);
    }
    _dropInactiveSector(ref.watch(sectorsProvider).value);
    _editing = widget.isEdit ? source : null;
    _duplicating = widget.isEdit ? null : source;
    return _buildForm(
      context,
      l10n,
      duplicatedFrom: widget.isEdit ? null : source,
    );
  }

  Widget _backToListButton(AppLocalizations l10n) => OutlinedButton(
    onPressed: () => context.goNamed(AppRoute.companyJobs.name),
    child: Text(l10n.jobBackToList),
  );

  Widget _notFound(AppLocalizations l10n) => JobCenteredMessage(
    title: l10n.jobNotFoundTitle,
    body: l10n.jobNotFoundBody,
    actions: [_backToListButton(l10n)],
  );

  Widget _notEditable(AppLocalizations l10n, JobOffer offer) {
    return JobCenteredMessage(
      title: l10n.jobNotEditableTitle,
      body: l10n.jobNotEditableBody,
      actions: [
        if (JobOfferLifecycle.allows(offer.status, JobOfferAction.duplicate))
          FilledButton.icon(
            onPressed: () => context.goNamed(
              AppRoute.companyJobNew.name,
              queryParameters: {JobQueryParams.duplicateOf: offer.id},
            ),
            icon: const Icon(Icons.copy_outlined),
            label: Text(l10n.jobActionDuplicate),
          ),
        _backToListButton(l10n),
      ],
    );
  }

  Widget _buildForm(
    BuildContext context,
    AppLocalizations l10n, {
    required JobOffer? duplicatedFrom,
  }) {
    final theme = Theme.of(context);
    final editorState = ref.watch(jobOfferEditorControllerProvider);
    final busy = editorState.isLoading;
    final approved =
        ref.watch(myCompanyVerificationProvider).value?.companyStatus ==
        CompanyVerificationStatus.approved;
    final attempted = _attemptedMode;
    final issues = attempted == null
        ? const JobOfferIssues()
        : _validate(attempted);
    final editing = _editing;
    if (editing == null) {
      // Se pide de entrada para que la vista previa de un alta ya tenga el
      // nombre real de la empresa cuando se abra.
      ref.watch(myCompanySummaryProvider);
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (editorState.hasError)
                MessageBanner.error(
                  title: l10n.jobsErrorTitle,
                  message: JobsCopy.failure(l10n, editorState.error),
                ),
              if (!issues.isEmpty)
                MessageBanner.error(
                  title: l10n.jobFormErrorsTitle,
                  message: l10n.jobFormErrorsBody,
                ),
              if (duplicatedFrom != null)
                MessageBanner.info(
                  message: l10n.jobFormDuplicateNote(duplicatedFrom.title),
                ),
              Text(l10n.jobFormIntro, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 24),
              _positionSection(l10n, issues, busy),
              _salarySection(l10n, issues, busy),
              _contractSection(l10n, issues, busy),
              _scheduleSection(l10n, issues, busy),
              JobSection(
                title: l10n.jobSectionWorkMode,
                children: [
                  _enumDropdown<JobWorkMode>(
                    field: JobOfferField.workMode,
                    label: l10n.jobWorkModeLabel,
                    value: _workMode,
                    values: JobWorkMode.values,
                    labelOf: (value) => OnboardingCopy.workMode(l10n, value),
                    error: _errorFor(l10n, issues, JobOfferField.workMode),
                    enabled: !busy,
                    onChanged: (value) => setState(() => _workMode = value),
                  ),
                ],
              ),
              _locationSection(l10n, issues, busy),
              _sectorSection(l10n, busy),
              JobSection(
                title: l10n.jobSectionExperience,
                children: [
                  _enumDropdown<ExperienceLevel>(
                    field: JobOfferField.experience,
                    label: l10n.jobExperienceLabel,
                    value: _experience,
                    values: ExperienceLevel.values,
                    labelOf: (value) =>
                        ProfileCopy.experienceLevel(l10n, value),
                    error: _errorFor(l10n, issues, JobOfferField.experience),
                    enabled: !busy,
                    onChanged: (value) => setState(() => _experience = value),
                  ),
                ],
              ),
              JobSection(
                title: l10n.jobSectionAvailability,
                children: [
                  _enumDropdown<JobAvailability>(
                    field: JobOfferField.availability,
                    label: l10n.jobAvailabilityLabel,
                    value: _availability,
                    values: JobAvailability.values,
                    labelOf: (value) =>
                        OnboardingCopy.availability(l10n, value),
                    error: _errorFor(l10n, issues, JobOfferField.availability),
                    enabled: !busy,
                    onChanged: (value) => setState(() => _availability = value),
                  ),
                ],
              ),
              _benefitsSection(l10n, issues, busy),
              JobSection(
                title: l10n.jobSectionVacancies,
                children: [
                  TextField(
                    controller: _vacancies,
                    focusNode: _focus[JobOfferField.vacancies],
                    enabled: !busy,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.jobVacanciesLabel,
                      helperText: l10n.jobVacanciesHelp(
                        JobOfferValidation.vacanciesMin,
                        JobOfferValidation.vacanciesMax,
                      ),
                      helperMaxLines: _messageMaxLines,
                      errorText: _errorFor(
                        l10n,
                        issues,
                        JobOfferField.vacancies,
                      ),
                      errorMaxLines: _messageMaxLines,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
              JobSection(
                title: l10n.jobSectionExpiry,
                children: [
                  TextField(
                    controller: _expiryText,
                    focusNode: _focus[JobOfferField.expiresAt],
                    enabled: !busy,
                    readOnly: true,
                    onTap: _pickExpiry,
                    decoration: InputDecoration(
                      labelText: l10n.jobExpiryLabel,
                      hintText: l10n.jobExpiryHint,
                      helperText: l10n.jobExpiryHelp(
                        JobOfferValidation.maxPublicationDays,
                      ),
                      helperMaxLines: _messageMaxLines,
                      errorText: _errorFor(
                        l10n,
                        issues,
                        JobOfferField.expiresAt,
                      ),
                      errorMaxLines: _messageMaxLines,
                      border: const OutlineInputBorder(),
                      // Alcanzable con teclado y lector: el toque sobre el
                      // campo es solo un atajo.
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_month_outlined),
                        tooltip: l10n.jobExpiryPick,
                        onPressed: busy ? null : _pickExpiry,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._buttons(l10n, theme, editing, approved: approved, busy: busy),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buttons(
    AppLocalizations l10n,
    ThemeData theme,
    JobOffer? editing, {
    required bool approved,
    required bool busy,
  }) {
    final explanation = theme.textTheme.bodyMedium;
    final preview = OutlinedButton.icon(
      onPressed: busy ? null : _openPreview,
      icon: const Icon(Icons.visibility_outlined),
      label: Text(l10n.jobPreview),
    );
    // Alta o borrador: "Guardar borrador" y "Publicar". Activa o pausada:
    // "Guardar cambios" (y si sigue activa, valen las reglas de publicación).
    if (editing == null || editing.status == JobStatus.draft) {
      return [
        preview,
        const SizedBox(height: 12),
        _SubmitButton(
          label: l10n.jobSaveDraft,
          filled: false,
          loading: busy && _pending == _Submit.draft,
          onPressed: busy ? null : () => _submit(_Submit.draft),
        ),
        const SizedBox(height: 12),
        _SubmitButton(
          label: l10n.jobPublish,
          filled: true,
          loading: busy && _pending == _Submit.publish,
          onPressed: busy || !approved ? null : () => _submit(_Submit.publish),
        ),
        if (!approved) ...[
          const SizedBox(height: 8),
          Text(l10n.jobPublishBlockedUnverified, style: explanation),
        ],
      ];
    }
    final needsVerification = editing.status == JobStatus.active && !approved;
    return [
      preview,
      const SizedBox(height: 12),
      _SubmitButton(
        label: l10n.jobSaveChanges,
        filled: true,
        loading: busy && _pending == _Submit.save,
        onPressed: busy || needsVerification
            ? null
            : () => _submit(_Submit.save),
      ),
      if (needsVerification) ...[
        const SizedBox(height: 8),
        Text(l10n.jobEditActiveNeedsVerification, style: explanation),
      ],
    ];
  }

  // ---------------------------------------------------------------------------
  // Secciones
  // ---------------------------------------------------------------------------

  Widget _positionSection(
    AppLocalizations l10n,
    JobOfferIssues issues,
    bool busy,
  ) {
    final titleCounter = runeCounter(
      context,
      _title.text,
      JobOfferValidation.titleMaxLength,
    );
    final descriptionCounter = runeCounter(
      context,
      _description.text,
      JobOfferValidation.descriptionMaxLength,
    );
    return JobSection(
      title: l10n.jobSectionPosition,
      children: [
        // Tope y contador en code points, como el validador y `length()`
        // de Postgres (no el `maxLength` de Flutter, que cuenta grafemas).
        TextField(
          controller: _title,
          focusNode: _focus[JobOfferField.title],
          enabled: !busy,
          inputFormatters: const [
            RuneLengthLimitingFormatter(JobOfferValidation.titleMaxLength),
          ],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.jobTitleLabel,
            hintText: l10n.jobTitleHint,
            hintMaxLines: _messageMaxLines,
            errorText: _errorFor(l10n, issues, JobOfferField.title),
            errorMaxLines: _messageMaxLines,
            counterText: titleCounter.text,
            semanticCounterText: titleCounter.semantics,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        // La guía va arriba del campo y no como ayuda debajo: ahí comparte
        // renglón con el contador y, con texto grande, Material la cortaba.
        Text(
          l10n.jobDescriptionHelp,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          focusNode: _focus[JobOfferField.description],
          enabled: !busy,
          inputFormatters: const [
            RuneLengthLimitingFormatter(
              JobOfferValidation.descriptionMaxLength,
            ),
          ],
          minLines: 4,
          maxLines: 10,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            labelText: l10n.jobDescriptionLabel,
            errorText: _errorFor(l10n, issues, JobOfferField.description),
            errorMaxLines: _messageMaxLines,
            counterText: descriptionCounter.text,
            semanticCounterText: descriptionCounter.semantics,
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _salarySection(
    AppLocalizations l10n,
    JobOfferIssues issues,
    bool busy,
  ) {
    Widget amountField(
      JobOfferField field,
      TextEditingController controller,
      String label,
    ) {
      return TextField(
        controller: controller,
        focusNode: _focus[field],
        enabled: !busy,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          prefixText: '${JobOfferInput.currency} ',
          errorText: _errorFor(l10n, issues, field),
          errorMaxLines: _messageMaxLines,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      );
    }

    return JobSection(
      title: l10n.jobSectionSalary,
      children: [
        Text(l10n.jobSalaryHelp, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        amountField(
          JobOfferField.salaryMin,
          _salaryMin,
          l10n.jobSalaryMinLabel,
        ),
        const SizedBox(height: 16),
        amountField(
          JobOfferField.salaryMax,
          _salaryMax,
          l10n.jobSalaryMaxLabel,
        ),
        const SizedBox(height: 16),
        _enumDropdown<SalaryPeriod>(
          field: JobOfferField.salaryPeriod,
          label: l10n.jobSalaryPeriodLabel,
          value: _salaryPeriod,
          values: SalaryPeriod.values,
          labelOf: (value) => JobsCopy.salaryPeriod(l10n, value),
          error: _errorFor(l10n, issues, JobOfferField.salaryPeriod),
          enabled: !busy,
          onChanged: (value) => setState(() => _salaryPeriod = value),
        ),
      ],
    );
  }

  Widget _contractSection(
    AppLocalizations l10n,
    JobOfferIssues issues,
    bool busy,
  ) {
    return JobSection(
      title: l10n.jobSectionContract,
      children: [
        _enumDropdown<ContractType>(
          field: JobOfferField.contractType,
          label: l10n.jobContractTypeLabel,
          value: _contractType,
          values: ContractType.values,
          labelOf: (value) => JobsCopy.contractType(l10n, value),
          error: _errorFor(l10n, issues, JobOfferField.contractType),
          enabled: !busy,
          onChanged: (value) => setState(() => _contractType = value),
        ),
        const SizedBox(height: 16),
        _enumDropdown<JornadaType>(
          field: JobOfferField.jornada,
          label: l10n.jobJornadaLabel,
          value: _jornada,
          values: JornadaType.values,
          labelOf: (value) => JobsCopy.jornada(l10n, value),
          error: _errorFor(l10n, issues, JobOfferField.jornada),
          enabled: !busy,
          onChanged: (value) => setState(() => _jornada = value),
        ),
      ],
    );
  }

  Widget _scheduleSection(
    AppLocalizations l10n,
    JobOfferIssues issues,
    bool busy,
  ) {
    final theme = Theme.of(context);
    final daysError = _errorFor(l10n, issues, JobOfferField.scheduleDays);
    final detailCounter = runeCounter(
      context,
      _scheduleDetail.text,
      JobOfferValidation.scheduleDetailMaxLength,
    );
    return JobSection(
      title: l10n.jobSectionSchedule,
      children: [
        // Los días son un GRUPO con nombre y, si hay, con su error: así quien
        // usa lector y cae en un día (el foco del error va al primero)
        // también oye de qué grupo es y qué falta, igual que en un campo de
        // texto con su error.
        Semantics(
          key: const ValueKey('dias-de-trabajo'),
          container: true,
          explicitChildNodes: true,
          label: l10n.jobScheduleDaysLabel,
          hint: daysError,
          validationResult: daysError == null
              ? SemanticsValidationResult.none
              : SemanticsValidationResult.invalid,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // El nombre del grupo ya lo dice el contenedor.
              ExcludeSemantics(
                child: Text(
                  l10n.jobScheduleDaysLabel,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final day in WeekDay.values)
                    FilterChip(
                      // El foco del error de "días" cae en el primer día.
                      focusNode: day == WeekDay.values.first
                          ? _focus[JobOfferField.scheduleDays]
                          : null,
                      label: Text(ProfileCopy.weekDay(l10n, day)),
                      selected: _scheduleDays.contains(day),
                      onSelected: busy
                          ? null
                          : (selected) => setState(() {
                              _scheduleDays = [
                                for (final value in WeekDay.values)
                                  if (value == day
                                      ? selected
                                      : _scheduleDays.contains(value))
                                    value,
                              ];
                            }),
                    ),
                ],
              ),
              if (daysError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  // Región viva: se anuncia apenas aparece.
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      daysError,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _scheduleDetail,
          focusNode: _focus[JobOfferField.scheduleDetail],
          enabled: !busy,
          inputFormatters: const [
            RuneLengthLimitingFormatter(
              JobOfferValidation.scheduleDetailMaxLength,
            ),
          ],
          decoration: InputDecoration(
            labelText: l10n.jobScheduleDetailLabel,
            hintText: l10n.jobScheduleDetailHint,
            hintMaxLines: _messageMaxLines,
            errorText: _errorFor(l10n, issues, JobOfferField.scheduleDetail),
            errorMaxLines: _messageMaxLines,
            counterText: detailCounter.text,
            semanticCounterText: detailCounter.semantics,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _locationSection(
    AppLocalizations l10n,
    JobOfferIssues issues,
    bool busy,
  ) {
    final provinceId = _provinceId;
    final localityId = _localityId;
    final provinces = ref.watch(provincesProvider);
    final localities = provinceId == null
        ? const AsyncValue<List<GeoLocality>>.data([])
        : ref.watch(localitiesProvider(provinceId));
    final neighborhoods = localityId == null
        ? const AsyncValue<List<GeoNeighborhood>>.data([])
        : ref.watch(neighborhoodsProvider(localityId));
    return JobSection(
      title: l10n.jobSectionLocation,
      children: [
        _CatalogDropdown(
          key: const ValueKey('provincia'),
          label: l10n.provinceLabel,
          value: provinceId,
          focusNode: _focus[JobOfferField.province],
          enabled: !busy,
          asyncItems: provinces.whenData(
            (items) => [
              for (final item in items) (id: item.id, name: item.name),
            ],
          ),
          errorText: _errorFor(l10n, issues, JobOfferField.province),
          onChanged: (value) => setState(() {
            _provinceId = value;
            _localityId = null;
            _neighborhoodId = null;
          }),
        ),
        const SizedBox(height: 16),
        _CatalogDropdown(
          // Cambiar la provincia rehace el desplegable: sin esto conservaría
          // la localidad de la provincia anterior.
          key: ValueKey('localidad-$provinceId'),
          label: l10n.localityLabel,
          value: localityId,
          focusNode: _focus[JobOfferField.locality],
          enabled: !busy && provinceId != null,
          asyncItems: localities.whenData(
            (items) => [
              for (final item in items) (id: item.id, name: item.name),
            ],
          ),
          errorText: _errorFor(l10n, issues, JobOfferField.locality),
          onChanged: (value) => setState(() {
            _localityId = value;
            _neighborhoodId = null;
          }),
        ),
        // D2: el barrio aparece solo si la localidad tiene barrios cargados,
        // y entonces es obligatorio para publicar.
        if (neighborhoods.value?.isNotEmpty ?? false) ...[
          const SizedBox(height: 16),
          _CatalogDropdown(
            key: ValueKey('barrio-$localityId'),
            label: l10n.neighborhoodLabel,
            helperText: l10n.jobNeighborhoodHelp,
            value: _neighborhoodId,
            focusNode: _focus[JobOfferField.neighborhood],
            enabled: !busy,
            asyncItems: neighborhoods.whenData(
              (items) => [
                for (final item in items) (id: item.id, name: item.name),
              ],
            ),
            errorText: _errorFor(l10n, issues, JobOfferField.neighborhood),
            onChanged: (value) => setState(() => _neighborhoodId = value),
          ),
        ],
      ],
    );
  }

  Widget _sectorSection(AppLocalizations l10n, bool busy) {
    final sectors = ref.watch(sectorsProvider);
    final items = sectors.value ?? const <Sector>[];
    final known = items.any((sector) => sector.id == _sectorId)
        ? _sectorId
        : null;
    return JobSection(
      title: l10n.jobSectionSector,
      children: [
        DropdownButtonFormField<String?>(
          key: ValueKey('sector-${items.length}-$known'),
          isExpanded: true,
          isDense: false,
          itemHeight: null,
          initialValue: known,
          decoration: InputDecoration(
            labelText: l10n.jobSectorLabel,
            contentPadding: _dropdownPadding,
            border: const OutlineInputBorder(),
            helperText: _sectorUnavailable ? l10n.jobSectorUnavailable : null,
            helperMaxLines: _messageMaxLines,
            errorText: sectors.hasError ? l10n.dataFailureNetwork : null,
            errorMaxLines: _messageMaxLines,
          ),
          items: [
            DropdownMenuItem<String?>(child: Text(l10n.jobSectorNone)),
            for (final sector in items)
              DropdownMenuItem<String?>(
                value: sector.id,
                child: Text(sector.name),
              ),
          ],
          onChanged: busy || sectors.isLoading
              ? null
              : (value) => setState(() {
                  _sectorId = value;
                  _sectorUnavailable = false;
                }),
        ),
      ],
    );
  }

  Widget _benefitsSection(
    AppLocalizations l10n,
    JobOfferIssues issues,
    bool busy,
  ) {
    final theme = Theme.of(context);
    final newIssue = _newBenefitIssue;
    final error = newIssue != null
        ? JobsCopy.benefitIssue(l10n, newIssue)
        : _errorFor(l10n, issues, JobOfferField.benefits);
    return JobSection(
      title: l10n.jobSectionBenefits,
      children: [
        // La guía va arriba del campo (como la del sueldo) y el botón debajo:
        // con texto grande, al lado del botón el campo quedaba tan angosto
        // que Material cortaba la ayuda y el rótulo.
        Text(
          l10n.jobBenefitsHelp(
            JobOfferValidation.benefitsMaxItems,
            JobOfferValidation.benefitMaxLength,
          ),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newBenefit,
          focusNode: _focus[JobOfferField.benefits],
          enabled: !busy,
          // Mismo conteo que el validador (code points), sin contador
          // visible: el tope ya lo dice la guía de arriba.
          inputFormatters: const [
            RuneLengthLimitingFormatter(JobOfferValidation.benefitMaxLength),
          ],
          decoration: InputDecoration(
            labelText: l10n.jobBenefitAddLabel,
            errorText: error,
            errorMaxLines: _messageMaxLines,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _addBenefit(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton(
            onPressed: busy ? null : _addBenefit,
            child: Text(l10n.chipAddAction),
          ),
        ),
        const SizedBox(height: 8),
        // Un renglón por beneficio y no un chip: el texto de un chip va en
        // una sola línea y uno de 60 caracteres se cortaba.
        for (final benefit in _benefits)
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.check,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(benefit, style: theme.textTheme.bodyLarge)),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.chipRemoveLabel(benefit),
                onPressed: busy
                    ? null
                    : () => setState(() {
                        _newBenefitIssue = null;
                        _benefits = [
                          for (final value in _benefits)
                            if (value != benefit) value,
                        ];
                      }),
              ),
            ],
          ),
        const SizedBox(height: 4),
        Semantics(
          liveRegion: true,
          child: Text(
            l10n.jobBenefitsCount(
              _benefits.length,
              JobOfferValidation.benefitsMaxItems,
            ),
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _enumDropdown<T extends Enum>({
    required JobOfferField field,
    required String label,
    required T? value,
    required List<T> values,
    required String Function(T value) labelOf,
    required String? error,
    required bool enabled,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      isExpanded: true,
      isDense: false,
      itemHeight: null,
      initialValue: value,
      focusNode: _focus[field],
      decoration: InputDecoration(
        labelText: label,
        contentPadding: _dropdownPadding,
        errorText: error,
        errorMaxLines: _messageMaxLines,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final item in values)
          DropdownMenuItem<T>(value: item, child: Text(labelOf(item))),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }

  /// Texto del error de [field], o null. Un monto o una cantidad que no se
  /// pudieron interpretar se explican como formato, no como "falta".
  String? _errorFor(
    AppLocalizations l10n,
    JobOfferIssues issues,
    JobOfferField field,
  ) {
    final issue = issues.issueFor(field);
    return switch (issue) {
      null => null,
      final JobTextIssue textIssue => JobsCopy.textIssue(
        l10n,
        textIssue,
        maxLength: switch (field) {
          JobOfferField.description => JobOfferValidation.descriptionMaxLength,
          JobOfferField.scheduleDetail =>
            JobOfferValidation.scheduleDetailMaxLength,
          _ => JobOfferValidation.titleMaxLength,
        },
      ),
      final JobSalaryIssue salaryIssue =>
        salaryIssue == JobSalaryIssue.missing &&
                _rawAmount(field).trim().isNotEmpty
            ? l10n.jobErrorSalaryFormat
            : JobsCopy.salaryIssue(l10n, salaryIssue),
      final JobVacanciesIssue vacanciesIssue =>
        vacanciesIssue == JobVacanciesIssue.missing &&
                _vacancies.text.trim().isNotEmpty
            ? JobsCopy.vacanciesIssue(l10n, JobVacanciesIssue.outOfRange)
            : JobsCopy.vacanciesIssue(l10n, vacanciesIssue),
      final JobScheduleDaysIssue daysIssue => JobsCopy.scheduleDaysIssue(
        l10n,
        daysIssue,
      ),
      final JobBenefitIssue benefitIssue => JobsCopy.benefitIssue(
        l10n,
        benefitIssue,
      ),
      final JobExpiryIssue expiryIssue => JobsCopy.expiryIssue(
        l10n,
        expiryIssue,
      ),
      final JobChoiceIssue choiceIssue => JobsCopy.choiceIssue(
        l10n,
        choiceIssue,
        neighborhood: field == JobOfferField.neighborhood,
      ),
      _ => l10n.jobsFailureInvalidData,
    };
  }

  String _rawAmount(JobOfferField field) =>
      field == JobOfferField.salaryMax ? _salaryMax.text : _salaryMin.text;
}

/// Botón de guardado con progreso. A diferencia de `ProgressButton`, puede
/// quedar deshabilitado por una razón que no es la carga (empresa sin
/// verificar): la razón se explica debajo, en texto.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.filled,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: label,
            ),
          )
        : Text(label);
    return filled
        ? FilledButton(onPressed: onPressed, child: child)
        : OutlinedButton(onPressed: onPressed, child: child);
  }
}

/// Desplegable de catálogo (mismo patrón que el onboarding): estados de
/// carga y de error del propio dataset, y el error de validación del campo.
class _CatalogDropdown extends StatelessWidget {
  const _CatalogDropdown({
    required this.label,
    required this.value,
    required this.focusNode,
    required this.enabled,
    required this.asyncItems,
    required this.onChanged,
    this.errorText,
    this.helperText,
    super.key,
  });

  final String label;
  final String? value;
  final FocusNode? focusNode;
  final bool enabled;
  final AsyncValue<List<({String id, String name})>> asyncItems;
  final ValueChanged<String?> onChanged;
  final String? errorText;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = asyncItems.value ?? const <({String id, String name})>[];
    final known = items.any((item) => item.id == value) ? value : null;
    return DropdownButtonFormField<String>(
      // Se rehace cuando llegan los ítems: `initialValue` solo se lee al
      // crear el campo.
      key: ValueKey('$label-${items.length}-$known'),
      isExpanded: true,
      isDense: false,
      itemHeight: null,
      initialValue: known,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: _dropdownPadding,
        helperText: helperText,
        helperMaxLines: _messageMaxLines,
        border: const OutlineInputBorder(),
        errorText: asyncItems.hasError ? l10n.dataFailureNetwork : errorText,
        errorMaxLines: _messageMaxLines,
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
      onChanged: enabled && !asyncItems.isLoading ? onChanged : null,
    );
  }
}
