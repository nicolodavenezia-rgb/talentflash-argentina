import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../domain/job_offer.dart';
import '../providers/job_feed_controller.dart';
import 'jobs_copy.dart';
import 'widgets/job_offer_card.dart';
import 'widgets/job_screen_states.dart';

/// Ofertas publicadas para el candidato (T-030), de la más nueva a la más
/// vieja, de a 20 con paginación keyset.
///
/// Qué ofertas aparecen lo deciden el repositorio y RLS (activas, no
/// descartadas, sin vencer, de empresas verificadas); el orden por zona y
/// compatibilidad es T-035. "Cargar más" es un botón y no scroll infinito:
/// se alcanza con teclado y lector, y el candidato decide cuándo pedir más.
class CandidateFeedScreen extends ConsumerWidget {
  const CandidateFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final feed = ref.watch(jobFeedProvider);
    final refreshing = feed.refreshInProgress;

    // Una recarga que falla con ofertas ya cargadas se avisa en un SnackBar:
    // aparece donde está la persona aunque haya bajado por la lista (el
    // botón "Actualizar" anda desde cualquier lugar) y el lector lo anuncia
    // (es región viva). Un aviso al principio de la lista quedaría fuera de
    // la vista, sin construir ni anunciar, y al aparecer correría hacia
    // abajo lo que se estaba leyendo. Si después una recarga sale bien, el
    // aviso del fallo (a la vista o en cola) ya no es cierto: se limpian los
    // SnackBars y otro corto, también anunciado, dice que las ofertas ya
    // están al día. Que la última había fallado lo sabe el controller
    // (`JobFeedState.lastRefreshFailed`), así vale aunque se haya salido del
    // feed y vuelto. Una recarga que un build fallido dejó marcada en el
    // valor de antes no es una que termina (`refreshInProgress`).
    ref.listen(jobFeedProvider, (previous, next) {
      final before = previous?.value;
      final after = next.value;
      if (!(previous?.refreshInProgress ?? false) ||
          after == null ||
          after.refreshing) {
        return;
      }
      final failure = after.failure;
      if (failure != null) {
        if (!after.failureFromLoadMore) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  l10n.jobsFeedRefreshFailed(JobsCopy.failure(l10n, failure)),
                ),
                // Mismo tiempo que los fallos de "Mis ofertas": son dos
                // oraciones.
                duration: const Duration(seconds: 8),
              ),
            );
        }
      } else if (before!.lastRefreshFailed) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(l10n.jobsFeedUpToDate)));
      }
    });

    final Widget body;
    if (feed.hasValue) {
      body = _FeedList(
        state: feed.value!,
        loadingMore: feed.loadMoreInProgress,
        rebuilding: feed.isLoading,
      );
    } else if (feed.hasError) {
      body = JobCenteredMessage(
        title: l10n.jobsFeedLoadErrorTitle,
        body: JobsCopy.failure(l10n, feed.error),
        actions: [
          FilledButton(
            onPressed: () => ref.invalidate(jobFeedProvider),
            child: Text(l10n.retryLabel),
          ),
        ],
      );
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.goNamed(AppRoute.candidateHome.name),
        ),
        title: Text(l10n.jobsFeedTitle),
        actions: [
          // Alternativa accesible al gesto de deslizar para actualizar.
          // Mientras recarga (por este botón o por el gesto) el ícono pasa a
          // un indicador y el rótulo a "Actualizando ofertas": la acción se
          // nota aunque la lista no cambie. El botón NO se deshabilita: uno
          // deshabilitado pierde el foco (pasaba a "Atrás", y un segundo
          // Enter sacaba del feed). Apretarlo de nuevo no hace nada: el
          // controller no pide otra recarga mientras hay una en vuelo.
          IconButton(
            icon: refreshing
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Icon(Icons.refresh),
            tooltip: refreshing
                ? l10n.jobsFeedRefreshing
                : l10n.jobsFeedRefresh,
            onPressed: feed.hasValue
                ? () => ref.read(jobFeedProvider.notifier).refresh()
                : null,
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}

class _FeedList extends ConsumerStatefulWidget {
  const _FeedList({
    required this.state,
    required this.loadingMore,
    required this.rebuilding,
  });

  final JobFeedState state;

  /// Hay una página en vuelo que mostrar (`loadMoreInProgress`): no
  /// [JobFeedState.loadingMore] tal cual, que puede venir de una página que
  /// un build fallido descartó.
  final bool loadingMore;

  /// La lista se está volviendo a construir y lo que se ve es la de antes:
  /// un build nuevo (cambio de sesión, `invalidate`) o Riverpod reintentando
  /// uno que falló, lo que en producción puede durar unos 38 segundos.
  /// Mientras tanto [JobFeedController.loadMore] no hace nada.
  final bool rebuilding;

  @override
  ConsumerState<_FeedList> createState() => _FeedListState();
}

class _FeedListState extends ConsumerState<_FeedList> {
  /// Alto mínimo de los botones del tema (`AppTheme`): el del botón "Cargar
  /// más" y, por lo tanto, el del indicador que lo reemplaza.
  static const _loadMoreHeight = 56.0;

  /// Pie de la lista: el aviso de "Cargar más" y el botón para reintentar.
  final _footerKey = GlobalKey();

  /// Tras un fallo de "Cargar más", el aviso ocupa el lugar del indicador y
  /// el botón para reintentar queda justo debajo: se desplaza lo mínimo para
  /// que también se vea. Solo hacia arriba y solo si hace falta: nada de lo
  /// ya cargado se corre hacia abajo.
  void _revealFooter() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final footer = _footerKey.currentContext;
      if (!mounted || footer == null) {
        return;
      }
      Scrollable.ensureVisible(
        footer,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final notifier = ref.read(jobFeedProvider.notifier);
    // Si falló "Cargar más", el aviso va al final, junto al botón que se tocó
    // (ahí está la persona y ahí se reintenta) y debajo de lo ya cargado, así
    // la lista no se corre. El fallo de una recarga no va en la lista: lo
    // avisa un SnackBar (ver `CandidateFeedScreen`).
    final loadMoreFailure = state.failureFromLoadMore ? state.failure : null;

    ref.listen(jobFeedProvider, (previous, next) {
      final before = previous?.value;
      final after = next.value;
      if ((before?.loadingMore ?? false) &&
          after != null &&
          after.failure != null &&
          after.failureFromLoadMore) {
        _revealFooter();
      }
    });

    void open(JobOffer offer) => context.goNamed(
      AppRoute.candidateJobDetail.name,
      pathParameters: {'id': offer.id},
    );

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            // Siempre deslizable: el gesto de actualizar anda también con la
            // lista vacía o corta.
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (state.isEmpty)
                Padding(
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
                        liveRegion: true,
                        child: Text(
                          l10n.jobsFeedEmpty,
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.jobsFeedEmptyHint,
                        style: theme.textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: notifier.refresh,
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.jobsFeedRefresh),
                      ),
                    ],
                  ),
                )
              else ...[
                for (final offer in state.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: JobOfferCard(
                      key: ValueKey(offer.id),
                      offer: offer,
                      onTap: () => open(offer),
                    ),
                  ),
                const SizedBox(height: 8),
                // Se anuncia cada vez que cambia: así quien usa lector sabe
                // que "Cargar más" efectivamente sumó ofertas.
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.jobsFeedCount(state.items.length),
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                Column(
                  key: _footerKey,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Región viva (MessageBanner): se anuncia al aparecer y
                    // queda en el lugar del indicador de carga, a la vista.
                    if (loadMoreFailure != null)
                      MessageBanner.error(
                        title: l10n.jobsFeedLoadErrorTitle,
                        message: JobsCopy.failure(l10n, loadMoreFailure),
                      ),
                    // También mientras la lista se vuelve a construir: ahí
                    // "Cargar más" no haría nada, y un botón habilitado que
                    // ignora los toques no puede quedar a la vista.
                    if (widget.loadingMore || widget.rebuilding)
                      // Ocupa lo mismo que el botón al que reemplaza: la
                      // lista no salta mientras carga.
                      SizedBox(
                        height: _loadMoreHeight,
                        child: Center(
                          child: CircularProgressIndicator(
                            semanticsLabel: widget.loadingMore
                                ? l10n.jobsFeedLoadingMore
                                : l10n.jobsFeedRefreshing,
                          ),
                        ),
                      )
                    else if (state.hasMore)
                      OutlinedButton.icon(
                        onPressed: notifier.loadMore,
                        icon: const Icon(Icons.expand_more),
                        label: Text(l10n.jobsFeedLoadMore),
                      )
                    else
                      Text(
                        l10n.jobsFeedEnd,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
