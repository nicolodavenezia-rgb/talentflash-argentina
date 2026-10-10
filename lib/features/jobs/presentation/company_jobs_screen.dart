import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/models/data_failure.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../companies/data/company_access_repository.dart';
import '../../companies/providers/company_verification_providers.dart';
import '../../onboarding/providers/onboarding_providers.dart';
import '../domain/job_offer.dart';
import '../domain/job_offer_enums.dart';
import '../domain/job_offer_lifecycle.dart';
import '../providers/job_offer_actions_controller.dart';
import '../providers/job_offers_providers.dart';
import 'jobs_copy.dart';
import 'widgets/job_status_chip.dart';

/// "Mis ofertas" de la empresa (T-030): todas las de la empresa salvo las
/// descartadas, con su estado y las acciones que el ciclo de vida permite.
///
/// Todo lo que se oculta o deshabilita acá es UX. Quién escribe (owner,
/// admin o recruiter, D3) y quién publica (empresa verificada) lo deciden
/// las policies de `jobs` y los triggers de 0032; si la pantalla se
/// equivocara, el servidor rechaza la escritura y el error se explica.
class CompanyJobsScreen extends ConsumerStatefulWidget {
  const CompanyJobsScreen({super.key});

  @override
  ConsumerState<CompanyJobsScreen> createState() => _CompanyJobsScreenState();
}

class _CompanyJobsScreenState extends ConsumerState<CompanyJobsScreen> {
  /// Última acción pedida: un `invalidData` al publicar o reanudar se explica
  /// con las reglas de publicación, no con el texto genérico.
  JobOfferAction? _lastAction;

  /// La recarga en vuelo la pidió la persona ("Actualizar" o "Reintentar").
  /// Solo el fallo de una así se avisa con un SnackBar; las automáticas (la
  /// que sigue a una acción o a un guardado del formulario, la que se
  /// reintenta sola al volver) no tapan lo que esté a la vista. Vuelve a
  /// false cuando termina cualquier recarga.
  bool _manualReload = false;

  /// El SnackBar de esta pantalla que está a la vista, si es un aviso de
  /// lista vieja; null si no lo es o si ya se fue (se limpia cuando se
  /// cierra, ver [_showSnackBar]).
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _staleNotice;

  /// El messenger que muestra [_staleNotice], para cerrarlo al salir.
  ScaffoldMessengerState? _staleNoticeMessenger;

  /// Orden fijo de los botones de cada oferta.
  static const _actionOrder = [
    JobOfferAction.edit,
    JobOfferAction.publish,
    JobOfferAction.resume,
    JobOfferAction.pause,
    JobOfferAction.duplicate,
    JobOfferAction.close,
    JobOfferAction.discard,
  ];

  @override
  void initState() {
    super.initState();
    // Un error de una visita anterior no tiene que aparecer al volver.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(jobOfferActionsControllerProvider.notifier).reset();
      // Si la última recarga falló con la lista ya cargada, esa lista puede
      // estar vieja: al volver se reintenta sola. Es automática: si vuelve a
      // fallar, no tapa el SnackBar que esté a la vista (por ejemplo, el del
      // guardado que trajo hasta acá).
      final jobs = ref.read(companyJobsProvider);
      if (jobs.hasError && !jobs.isLoading && jobs.hasValue) {
        ref.invalidate(companyJobsProvider);
      }
    });
  }

  @override
  void dispose() {
    // El aviso de lista vieja habla del "Actualizar" de ESTA pantalla, pero
    // el ScaffoldMessenger es de toda la app: si no se cierra, sigue a la
    // persona a otra pantalla y, al volver, el State nuevo ya no sabe que es
    // suyo. Mientras el árbol se desmonta no se puede tocar el messenger
    // (está bloqueado): se cierra después del frame, y solo si sigue abierto.
    // Si lo que se desmonta es la app entera, el messenger ya no está.
    final notice = _staleNotice;
    final messenger = _staleNoticeMessenger;
    if (notice != null && messenger != null) {
      var closed = false;
      notice.closed.whenComplete(() => closed = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!closed && messenger.mounted) {
          notice.close();
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final jobs = ref.watch(companyJobsProvider);
    final canWriteAsync = ref.watch(canWriteCompanyJobsProvider);
    // Mientras se averigua, o si falla, la cuenta NO escribe: es fail-closed.
    final canWrite = canWriteAsync.value == true;
    final verification = ref.watch(myCompanyVerificationProvider).value;
    final approved =
        verification?.companyStatus == CompanyVerificationStatus.approved;
    final actionState = ref.watch(jobOfferActionsControllerProvider);
    final busy = actionState.isLoading;
    final now = ref.watch(jobClockProvider)();

    // El resultado de una acción (éxito o fallo) va en un SnackBar apenas
    // termina la acción: aparece donde está la persona, aunque haya tocado
    // una oferta del fondo de la lista, y el lector lo anuncia (es región
    // viva). Un cartel al principio de la lista quedaría fuera de la vista y,
    // como la lista es perezosa, ni siquiera se construiría.
    //
    // No espera a la recarga que sigue a la acción: el resultado ya es
    // cierto cuando la acción termina, y una recarga lenta no tiene por qué
    // demorarlo. Si salió bien, la tarjeta ya muestra lo confirmado
    // (`CompanyJobsController.applyConfirmedWrite`); si esa recarga falla,
    // no tapa este SnackBar (ver el `listen` de `companyJobsProvider`).
    ref.listen(jobOfferActionsControllerProvider, (previous, next) {
      if (!(previous?.isLoading ?? false) || next.isLoading) {
        return;
      }
      if (next.hasError) {
        _showSnackBar(
          SnackBar(
            content: Text(_actionFailure(l10n, next.error)),
            // Algunos fallos se explican con dos oraciones: más tiempo para
            // leerlos que un "Oferta pausada".
            duration: const Duration(seconds: 8),
          ),
        );
        return;
      }
      final outcome = next.value;
      if (outcome == null) {
        return;
      }
      _showSnackBar(
        SnackBar(content: Text(JobsCopy.actionOutcome(l10n, outcome))),
      );
    });

    // Cuando termina una recarga con la lista ya cargada y falla:
    // - si la pidió la persona ("Actualizar"), un SnackBar nuevo con el aviso
    //   de lista vieja, que reemplaza al que esté a la vista, así cada fallo
    //   se vuelve a anunciar. Sin acción, porque con acción Flutter lo
    //   dejaría fijo hasta tocarlo; se reintenta con "Actualizar".
    // - si fue automática (tras una acción o un guardado del formulario, o
    //   la que se reintenta sola al volver), ningún SnackBar: no se reemplaza
    //   lo que se está leyendo (el resultado de la acción, el "Cambios
    //   guardados." del formulario). Se anuncia una vez al lector y lo sigue
    //   diciendo el ícono de "Actualizar".
    // Una recarga que sale bien se lleva el aviso de lista vieja que siga a
    // la vista, porque ya no es cierto. La lista no se corre: nada se agrega
    // arriba de ella.
    ref.listen(companyJobsProvider, (previous, next) {
      if (!(previous?.isLoading ?? false) || next.isLoading) {
        return;
      }
      final manual = _manualReload;
      _manualReload = false;
      if (!next.hasError) {
        if (_staleNotice != null) {
          _staleNotice = null;
          _staleNoticeMessenger = null;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
        return;
      }
      if (!next.hasValue) {
        // Sin lista: lo dice el cartel del cuerpo, con su "Reintentar".
        return;
      }
      if (manual) {
        _showSnackBar(
          SnackBar(
            content: Text(l10n.jobsListStale),
            // El mismo tiempo que los fallos de una acción.
            duration: const Duration(seconds: 8),
          ),
          staleNotice: true,
        );
      } else {
        SemanticsService.sendAnnouncement(
          View.of(context),
          l10n.jobsListStale,
          Directionality.of(context),
        );
      }
    });

    final offers = jobs.value;
    final children = <Widget>[
      if (verification != null && !approved) ...[
        MessageBanner.info(message: l10n.jobsUnverifiedBanner),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: () => context.goNamed(AppRoute.companyVerification.name),
            icon: const Icon(Icons.verified_user_outlined),
            label: Text(l10n.jobsGoToVerification),
          ),
        ),
        const SizedBox(height: 16),
      ],
      if (canWriteAsync.hasValue && !canWrite)
        MessageBanner.info(message: l10n.jobsReadOnlyBanner),
      if (canWriteAsync.hasError && !canWriteAsync.isLoading) ...[
        MessageBanner.info(message: l10n.jobsPermissionsError),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton(
            onPressed: () => ref.invalidate(canWriteCompanyJobsProvider),
            child: Text(l10n.retryLabel),
          ),
        ),
        const SizedBox(height: 16),
      ],
      // Solo sin lista: con lista, el fallo de una recarga lo avisa el ícono
      // de "Actualizar" y, si la pidió la persona, un SnackBar.
      if (jobs.hasError && !jobs.isLoading && offers == null) ...[
        MessageBanner.error(
          title: l10n.jobsLoadErrorTitle,
          message: JobsCopy.failure(l10n, jobs.error),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton(onPressed: _retry, child: Text(l10n.retryLabel)),
        ),
        const SizedBox(height: 16),
      ],
      // También al reintentar después de que falló la primera carga: el
      // error sigue en el valor mientras carga, y sin esto el cuerpo quedaba
      // vacío (ni el cartel ni el indicador).
      if (offers == null && (jobs.isLoading || !jobs.hasError))
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (offers != null && offers.isEmpty)
        _EmptyState(canWrite: canWrite, onCreate: _create)
      else if (offers != null) ...[
        if (canWrite)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: Text(l10n.jobsNewOffer),
              ),
            ),
          ),
        for (final offer in offers)
          _CompanyJobCard(
            key: ValueKey(offer.id),
            offer: offer,
            actions: canWrite
                ? [
                    for (final action in _actionOrder)
                      if (JobOfferLifecycle.allows(offer.status, action))
                        action,
                  ]
                : const [],
            approved: approved,
            busy: busy,
            now: now,
            onAction: _onAction,
          ),
      ],
    ];

    // Recarga con la lista a la vista (no la primera carga, que ya muestra
    // su indicador en el cuerpo).
    final reloading = jobs.isLoading && offers != null;
    // La última recarga falló y lo que se ve puede estar viejo. Una acción
    // que sale bien deja la lista sin error (`applyConfirmedWrite`), pero
    // enseguida la recarga, y esa recarga decide.
    final stale = !reloading && jobs.hasError && offers != null;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.goNamed(AppRoute.companyHome.name),
        ),
        title: Text(l10n.jobsCompanyTitle),
        actions: [
          // Siempre disponible y siempre del mismo tamaño: volver a pedir la
          // lista no depende de un SnackBar que vence, y nada se corre en la
          // pantalla cuando cambia de estado. Mientras recarga, el ícono
          // pasa a un indicador y el rótulo a "Actualizando tus ofertas",
          // pero el botón NO se deshabilita: uno deshabilitado pierde el foco
          // del teclado. Apretarlo de nuevo no hace nada. Si la última
          // recarga falló, el ícono y el rótulo dicen que la lista puede no
          // estar al día: tras una recarga automática es lo único a la vista
          // que lo dice, y tras "Actualizar", lo que queda cuando el SnackBar
          // se va.
          IconButton(
            icon: reloading
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Icon(stale ? Icons.sync_problem : Icons.refresh),
            tooltip: reloading
                ? l10n.jobsCompanyRefreshing
                : stale
                ? l10n.jobsCompanyRefreshStale
                : l10n.jobsCompanyRefresh,
            onPressed: _reloadIfIdle,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  void _create() => context.goNamed(AppRoute.companyJobNew.name);

  /// Recarga que pide la persona ("Reintentar" sin lista, o "Actualizar"):
  /// si falla con la lista a la vista, se avisa con un SnackBar.
  void _retry() {
    _manualReload = true;
    _reloadList(ProviderScope.containerOf(context, listen: false));
  }

  /// "Actualizar": con una recarga en vuelo no hace nada (ni pide otra ni
  /// reinicia la que va). Por eso puede quedar habilitado y no le saca el
  /// foco a quien usa teclado.
  void _reloadIfIdle() {
    if (ref.read(companyJobsProvider).isLoading) {
      return;
    }
    _retry();
  }

  static void _reloadList(ProviderContainer container) {
    // Si lo que falló fue el estado de la empresa (de donde sale su id), hay
    // que volver a pedirlo; si no, alcanza con la lista.
    if (container.read(myCompanyVerificationProvider).hasError) {
      container.invalidate(myCompanyVerificationProvider);
    }
    container.invalidate(companyJobsProvider);
  }

  /// Todos los SnackBars de esta pantalla pasan por acá: reemplazan al que
  /// esté a la vista y nunca quedan en cola (uno en cola aparecería tarde,
  /// cuando lo que dice ya puede no ser cierto). [staleNotice]: es un aviso
  /// de lista vieja, que una recarga que sale bien se lleva.
  void _showSnackBar(SnackBar snackBar, {bool staleNotice = false}) {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final controller = messenger.showSnackBar(snackBar);
    _staleNotice = staleNotice ? controller : null;
    _staleNoticeMessenger = staleNotice ? messenger : null;
    // El que se ocultó se cierra después de que este ya se muestra: solo el
    // cierre del aviso actual lo olvida.
    controller.closed.then((_) {
      if (identical(_staleNotice, controller)) {
        _staleNotice = null;
        _staleNoticeMessenger = null;
      }
    });
  }

  String _actionFailure(AppLocalizations l10n, Object? error) {
    final enteringActive =
        _lastAction == JobOfferAction.publish ||
        _lastAction == JobOfferAction.resume;
    if (enteringActive &&
        error is DataFailure &&
        error.code == DataFailureCode.invalidData) {
      return l10n.jobsFailurePublishRules;
    }
    return JobsCopy.failure(l10n, error);
  }

  Future<void> _onAction(JobOfferAction action, JobOffer offer) async {
    final notifier = ref.read(jobOfferActionsControllerProvider.notifier);
    switch (action) {
      case JobOfferAction.edit:
        context.goNamed(
          AppRoute.companyJobEdit.name,
          pathParameters: {'id': offer.id},
        );
      case JobOfferAction.duplicate:
        context.goNamed(
          AppRoute.companyJobNew.name,
          queryParameters: {JobQueryParams.duplicateOf: offer.id},
        );
      case JobOfferAction.publish:
        setState(() => _lastAction = action);
        final hasNeighborhoods = await _localityHasNeighborhoods(offer);
        if (!mounted) {
          return;
        }
        await notifier.publish(
          offer,
          localityHasNeighborhoods: hasNeighborhoods,
        );
      case JobOfferAction.resume:
        setState(() => _lastAction = action);
        final hasNeighborhoods = await _localityHasNeighborhoods(offer);
        if (!mounted) {
          return;
        }
        await notifier.resume(
          offer,
          localityHasNeighborhoods: hasNeighborhoods,
        );
      case JobOfferAction.pause:
        setState(() => _lastAction = action);
        await notifier.pause(offer);
      case JobOfferAction.close:
        if (await _confirm(_ConfirmKind.close)) {
          setState(() => _lastAction = action);
          await notifier.close(offer);
        }
      case JobOfferAction.discard:
        if (await _confirm(_ConfirmKind.discard)) {
          setState(() => _lastAction = action);
          await notifier.discard(offer);
        }
    }
  }

  /// D2: ¿la localidad tiene barrios cargados? Null si no se pudo saber; en
  /// ese caso no se bloquea y decide el servidor.
  Future<bool?> _localityHasNeighborhoods(JobOffer offer) async {
    if (offer.localidadId.isEmpty) {
      return null;
    }
    try {
      final neighborhoods = await ref.read(
        neighborhoodsProvider(offer.localidadId).future,
      );
      return neighborhoods.isNotEmpty;
    } on Object {
      return null;
    }
  }

  /// Cerrar y descartar no tienen vuelta atrás: se confirman siempre.
  Future<bool> _confirm(_ConfirmKind kind) async {
    final l10n = AppLocalizations.of(context);
    final (title, body, confirm) = switch (kind) {
      _ConfirmKind.close => (
        l10n.jobCloseDialogTitle,
        l10n.jobCloseDialogBody,
        l10n.jobCloseDialogConfirm,
      ),
      _ConfirmKind.discard => (
        l10n.jobDiscardDialogTitle,
        l10n.jobDiscardDialogBody,
        l10n.jobDiscardDialogConfirm,
      ),
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.jobDialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirm),
          ),
        ],
      ),
    );
    return confirmed == true && mounted;
  }
}

enum _ConfirmKind { close, discard }

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.canWrite, required this.onCreate});

  final bool canWrite;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.work_outline,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              canWrite ? l10n.jobsEmptyTitle : l10n.jobsEmptyReadOnlyBody,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          if (canWrite) ...[
            const SizedBox(height: 8),
            Text(
              l10n.jobsEmptyBody,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(l10n.jobsEmptyAction),
            ),
          ],
        ],
      ),
    );
  }
}

/// Una oferta de la lista: el puesto es encabezado (se salta de oferta en
/// oferta con el lector), el estado va con ícono y texto, y cada botón dice
/// sobre qué oferta actúa.
class _CompanyJobCard extends StatelessWidget {
  const _CompanyJobCard({
    required this.offer,
    required this.actions,
    required this.approved,
    required this.busy,
    required this.now,
    required this.onAction,
    super.key,
  });

  final JobOffer offer;

  /// Acciones que el ciclo de vida permite y la cuenta puede hacer (vacío
  /// para el rol `viewer`).
  final List<JobOfferAction> actions;
  final bool approved;
  final bool busy;
  final DateTime now;
  final Future<void> Function(JobOfferAction action, JobOffer offer) onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final expiresAt = offer.expiresAt;
    final passedExpiry = offer.hasPassedExpiry(now);
    final stillPublished = passedExpiry && offer.status == JobStatus.active;
    final blockedByVerification =
        !approved && actions.any((action) => action.requiresApprovedCompany);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(offer.title, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            JobStatusChip(status: offer.status),
            const SizedBox(height: 8),
            Text(
              JobsCopy.salary(l10n, offer),
              style: theme.textTheme.bodyMedium,
            ),
            if (expiresAt != null) ...[
              const SizedBox(height: 4),
              if (stillPublished)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      size: 20,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.jobExpiredOn(JobsCopy.date(expiresAt, locale)),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  passedExpiry
                      ? l10n.jobExpiredOnShort(JobsCopy.date(expiresAt, locale))
                      : l10n.jobExpiresOn(JobsCopy.date(expiresAt, locale)),
                  style: theme.textTheme.bodyMedium,
                ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final action in actions) _button(l10n, action)],
              ),
            ],
            if (blockedByVerification) ...[
              const SizedBox(height: 8),
              Text(
                l10n.jobsPublishNeedsVerification,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _button(AppLocalizations l10n, JobOfferAction action) {
    final label = JobsCopy.action(l10n, action);
    final enabled = !busy && (approved || !action.requiresApprovedCompany);
    final onPressed = enabled ? () => onAction(action, offer) : null;
    final text = Text(
      label,
      semanticsLabel: l10n.jobActionSemantics(label, offer.title),
    );
    final icon = Icon(switch (action) {
      JobOfferAction.edit => Icons.edit_outlined,
      JobOfferAction.publish => Icons.publish_outlined,
      JobOfferAction.pause => Icons.pause_outlined,
      JobOfferAction.resume => Icons.play_arrow_outlined,
      JobOfferAction.close => Icons.lock_outline,
      JobOfferAction.discard => Icons.delete_outline,
      JobOfferAction.duplicate => Icons.copy_outlined,
    });
    return switch (action) {
      JobOfferAction.publish || JobOfferAction.resume => FilledButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: text,
      ),
      _ => OutlinedButton.icon(onPressed: onPressed, icon: icon, label: text),
    };
  }
}
