import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/data_failure.dart';
import '../../authentication/providers/auth_providers.dart';
import '../domain/job_feed_page.dart';
import '../domain/job_offer.dart';
import 'job_offers_providers.dart';

/// Lo que muestra el feed de candidatos: las ofertas cargadas hasta ahora y
/// desde dónde seguir.
class JobFeedState {
  const JobFeedState({
    required this.items,
    required this.nextCursor,
    this.loadingMore = false,
    this.refreshing = false,
    this.failure,
    this.failureFromLoadMore = false,
    this.lastRefreshFailed = false,
  });

  final List<JobOffer> items;

  /// Null cuando ya no hay más (fin de la lista).
  final JobFeedCursor? nextCursor;

  /// Hay una página siguiente en vuelo.
  final bool loadingMore;

  /// Hay una recarga ([JobFeedController.refresh]) en vuelo, venga del botón
  /// "Actualizar" o del gesto de deslizar. La pantalla lo muestra mientras
  /// dura (ver [JobFeedRefreshInProgress.refreshInProgress]) y, si termina
  /// con [failure], lo avisa donde está la persona.
  final bool refreshing;

  /// Fallo de la última carga incremental o recarga. La lista sigue
  /// mostrando lo anterior: la UI lo explica y ofrece reintentar con
  /// [JobFeedController.loadMore] o [JobFeedController.refresh]. (Si falla la
  /// PRIMERA página no hay nada que conservar y el provider queda en error.)
  final DataFailure? failure;

  /// [failure] vino de [JobFeedController.loadMore] (la página siguiente) y
  /// no de una recarga. La UI lo muestra al final de la lista, junto a
  /// "Cargar más", que es donde está la persona que lo tocó: un aviso arriba
  /// quedaría fuera de la vista (y, en una lista perezosa, sin construir ni
  /// anunciar). El fallo de una recarga, por lo mismo, va en un SnackBar.
  final bool failureFromLoadMore;

  /// La última recarga falló y ninguna salió bien después: la pantalla ya
  /// avisó que las ofertas no se actualizaron. Cuando una recarga sale bien
  /// con esto en true, avisa que ya están al día (el aviso del fallo dejó de
  /// ser cierto) y vuelve a false, porque la lista se reemplaza. Está acá y
  /// no en la pantalla para que siga valiendo al salir del feed y volver (el
  /// provider no es autoDispose). A diferencia de [failure], "Cargar más" no
  /// lo borra: no vuelve a pedir la primera página.
  final bool lastRefreshFailed;

  bool get hasMore => nextCursor != null;

  bool get isEmpty => items.isEmpty;

  JobFeedState copyWith({
    bool? loadingMore,
    bool? refreshing,
    DataFailure? Function()? failure,
    bool? failureFromLoadMore,
    bool? lastRefreshFailed,
  }) {
    return JobFeedState(
      items: items,
      nextCursor: nextCursor,
      loadingMore: loadingMore ?? this.loadingMore,
      refreshing: refreshing ?? this.refreshing,
      failure: failure == null ? this.failure : failure(),
      failureFromLoadMore: failureFromLoadMore ?? this.failureFromLoadMore,
      lastRefreshFailed: lastRefreshFailed ?? this.lastRefreshFailed,
    );
  }
}

/// Lo que el feed tiene que mostrar de [JobFeedState.refreshing].
extension JobFeedRefreshInProgress on AsyncValue<JobFeedState> {
  /// Hay una recarga en vuelo que mostrar. Con el provider en error no: si un
  /// build nuevo (p. ej. un cambio de sesión) falla mientras hay una recarga
  /// en vuelo, Riverpod conserva el valor de antes, con `refreshing` en true,
  /// y esa recarga ya no lo toca al terminar (es de la lista anterior). Sin
  /// esto, "Actualizando ofertas" quedaba girando para siempre.
  bool get refreshInProgress => !hasError && (value?.refreshing ?? false);

  /// Hay una página de "Cargar más" en vuelo que mostrar. Con el provider en
  /// error no, por lo mismo que [refreshInProgress]: la página que estaba en
  /// vuelo era de la lista anterior y ya no apaga `loadingMore` al llegar.
  bool get loadMoreInProgress => !hasError && (value?.loadingMore ?? false);
}

/// Feed de ofertas para candidatos: primera página al construirse,
/// [loadMore] para seguir sin perder lo cargado y [refresh] para volver a
/// empezar (pull-to-refresh).
///
/// El orden y los filtros (activas, no descartadas, sin vencer, de empresas
/// verificadas) los define el repositorio y RLS; el ranking por zona y
/// categoría es T-035.
class JobFeedController extends AsyncNotifier<JobFeedState> {
  /// Sube cada vez que la lista se reemplaza (una recarga que salió bien o un
  /// build nuevo): una página o una recarga que llega después pertenece a una
  /// lista que ya no existe y se descarta.
  int _generation = 0;

  /// La recarga en vuelo: mientras dure, [refresh] la devuelve en vez de
  /// pedir otra.
  Future<void>? _refreshInFlight;

  @override
  Future<JobFeedState> build() async {
    // Un build nuevo (cambio de sesión, invalidate) es otra lista: lo que
    // estaba en vuelo para la anterior no la toca, y se puede volver a
    // recargar enseguida.
    _generation++;
    _refreshInFlight = null;
    // No es autoDispose: sin depender de la sesión, la cuenta siguiente
    // arrancaría con el feed cargado por la anterior.
    ref.watch(authStatusProvider);
    final page = await ref
        .watch(jobOffersRepositoryProvider)
        .fetchActiveJobsPage();
    return JobFeedState(items: page.items, nextCursor: page.nextCursor);
  }

  /// Lo que se ve, listo para empezar una operación. Si un build nuevo falló,
  /// el provider quedó en error con el valor de antes y lo que estaba en
  /// vuelo se descartó (era de la lista anterior): sus marcas (`refreshing`,
  /// `loadingMore`) ya no las apaga nadie. Se limpian antes de seguir, así
  /// ningún indicador vuelve con la operación nueva ni queda girando.
  JobFeedState? _settledValue() {
    final current = state.value;
    if (current == null || !state.hasError) {
      return current;
    }
    return current.copyWith(refreshing: false, loadingMore: false);
  }

  /// Pide la página siguiente y la agrega al final. No hace nada si todavía
  /// no hay primera página, si ya hay una en vuelo o si la lista terminó.
  Future<void> loadMore() async {
    final current = _settledValue();
    if (current == null ||
        state.isLoading ||
        current.loadingMore ||
        !current.hasMore) {
      return;
    }
    final generation = _generation;
    state = AsyncValue.data(
      current.copyWith(loadingMore: true, failure: () => null),
    );
    try {
      final page = await ref
          .read(jobOffersRepositoryProvider)
          .fetchActiveJobsPage(cursor: current.nextCursor);
      if (!ref.mounted || generation != _generation) {
        return;
      }
      // Lo de ahora y no `current`: una recarga pudo empezar o fallar
      // mientras tanto (y entonces ya no está en vuelo).
      final latest = state.value ?? current;
      // El keyset no repite filas; el filtro por id es solo un seguro para
      // que una oferta nunca aparezca dos veces en la lista.
      final seen = {for (final offer in latest.items) offer.id};
      state = AsyncValue.data(
        JobFeedState(
          items: [
            ...latest.items,
            for (final offer in page.items)
              if (seen.add(offer.id)) offer,
          ],
          nextCursor: page.nextCursor,
          // Si hay una recarga en vuelo, sigue en vuelo.
          refreshing: latest.refreshing,
          lastRefreshFailed: latest.lastRefreshFailed,
        ),
      );
    } catch (error) {
      if (!ref.mounted || generation != _generation) {
        return;
      }
      state = AsyncValue.data(
        (state.value ?? current).copyWith(
          loadingMore: false,
          failure: () => DataFailure.from(error),
          failureFromLoadMore: true,
        ),
      );
    }
  }

  /// Vuelve a la primera página; mientras tanto [JobFeedState.refreshing] es
  /// true. Con una recarga ya en vuelo (el botón "Actualizar" apretado otra
  /// vez, o el botón y el gesto de deslizar) no pide otra: devuelve esa.
  ///
  /// Si falla y ya había ofertas, se queda con lo que la lista muestra AL
  /// FALLAR (también una página de "Cargar más" que llegó mientras tanto) y
  /// deja el fallo en [JobFeedState.failure].
  Future<void> refresh() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    late final Future<void> started;
    started = _refresh().whenComplete(() {
      // Un build nuevo pudo soltarla y arrancar otra: esa no se toca.
      if (identical(_refreshInFlight, started)) {
        _refreshInFlight = null;
      }
    });
    return _refreshInFlight = started;
  }

  Future<void> _refresh() async {
    final generation = _generation;
    final previous = _settledValue();
    if (previous != null) {
      state = AsyncValue.data(previous.copyWith(refreshing: true));
    }
    final next = await AsyncValue.guard(() async {
      final page = await ref
          .read(jobOffersRepositoryProvider)
          .fetchActiveJobsPage();
      return JobFeedState(items: page.items, nextCursor: page.nextCursor);
    });
    if (!ref.mounted || generation != _generation) {
      return;
    }
    final current = state.value;
    if (next.hasError && current != null) {
      // La lista no cambió: sigue la que se ve, con lo que "Cargar más"
      // sumó durante la recarga, y un "Cargar más" que siga en vuelo todavía
      // le corresponde. Volver a `previous` la haría saltar y tiraría esa
      // página.
      state = AsyncValue.data(
        current.copyWith(
          refreshing: false,
          failure: () => DataFailure.from(next.error!),
          failureFromLoadMore: false,
          lastRefreshFailed: true,
        ),
      );
      return;
    }
    // La lista se reemplaza: una página de "Cargar más" que siga en vuelo
    // pertenece a la anterior y no se puede pegar a esta. El estado nuevo
    // arranca con `lastRefreshFailed` en false.
    _generation++;
    state = next;
  }
}

final jobFeedProvider = AsyncNotifierProvider<JobFeedController, JobFeedState>(
  JobFeedController.new,
);
