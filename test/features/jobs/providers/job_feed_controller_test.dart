import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/authentication/providers/auth_providers.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_feed_page.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_enums.dart';
import 'package:talentflash_argentina/features/jobs/providers/job_feed_controller.dart';
import 'package:talentflash_argentina/features/jobs/providers/job_offers_providers.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_job_offers_repository.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeJobOffersRepository jobs;
  late ProviderContainer container;

  List<JobOffer> ofertas(int cantidad) => [
    for (var i = 0; i < cantidad; i++)
      testJobOffer(
        id: testJobId(100 + i),
        status: JobStatus.active,
        publishedAt: DateTime.utc(2026, 10, 9).subtract(Duration(hours: i)),
        company: testJobCompany,
      ),
  ];

  JobFeedController feed() => container.read(jobFeedProvider.notifier);

  JobFeedState actual() => container.read(jobFeedProvider).requireValue;

  int pedidos() =>
      jobs.calls.where((call) => call.startsWith('fetchActiveJobsPage')).length;

  setUp(() {
    auth = FakeAuthRepository();
    addTearDown(auth.dispose);
    jobs = FakeJobOffersRepository(feed: ofertas(45));
    container = ProviderContainer.test(
      // Igual que el harness: sin el retry automático de Riverpod 3, los
      // errores de providers son finales y el test es determinista.
      retry: (retryCount, error) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        jobOffersRepositoryProvider.overrideWithValue(jobs),
        jobClockProvider.overrideWithValue(() => testJobNow),
      ],
    );
    // El feed vive mientras la pantalla lo mira.
    container.listen(jobFeedProvider, (_, _) {});
  });

  test('la primera página trae 20 y avisa que hay más', () async {
    final state = await container.read(jobFeedProvider.future);

    expect(state.items, hasLength(jobFeedPageSize));
    expect(state.hasMore, isTrue);
    expect(state.failure, isNull);
    expect(jobs.lastCursor, isNull);
    expect(state.items.first.company?.name, 'Parrilla de Prueba');
  });

  test('loadMore suma la página siguiente sin perder lo cargado y '
      'detecta el final', () async {
    await container.read(jobFeedProvider.future);

    await feed().loadMore();
    expect(actual().items, hasLength(40));
    expect(jobs.lastCursor?.id, testJobId(119));
    expect(actual().hasMore, isTrue);

    await feed().loadMore();
    expect(actual().items, hasLength(45));
    expect(actual().hasMore, isFalse, reason: 'página incompleta = final');
    expect(
      actual().items.map((offer) => offer.id).toSet(),
      hasLength(45),
      reason: 'ninguna oferta repetida',
    );

    final antes = pedidos();
    await feed().loadMore();
    expect(pedidos(), antes, reason: 'al final no se pide nada más');
  });

  test('con exactamente 20, la segunda página vacía cierra la lista', () async {
    jobs.feed = ofertas(20);
    container.invalidate(jobFeedProvider);
    await container.read(jobFeedProvider.future);
    expect(actual().hasMore, isTrue);

    await feed().loadMore();

    expect(actual().items, hasLength(20));
    expect(actual().hasMore, isFalse);
  });

  test('sin ofertas el estado es vacío y sin más páginas', () async {
    jobs.feed = [];
    container.invalidate(jobFeedProvider);
    final state = await container.read(jobFeedProvider.future);

    expect(state.isEmpty, isTrue);
    expect(state.hasMore, isFalse);
  });

  test('si falla loadMore se conservan las ofertas y se puede '
      'reintentar', () async {
    await container.read(jobFeedProvider.future);
    jobs.nextFeedFailure = const DataFailure(DataFailureCode.network);

    await feed().loadMore();

    expect(actual().items, hasLength(20));
    expect(actual().loadingMore, isFalse);
    expect(
      actual().failure,
      isA<DataFailure>().having((f) => f.code, 'code', DataFailureCode.network),
    );
    // La pantalla lo muestra al final, junto a "Cargar más".
    expect(actual().failureFromLoadMore, isTrue);
    expect(actual().hasMore, isTrue);

    await feed().loadMore();

    expect(actual().items, hasLength(40));
    expect(actual().failure, isNull);
  });

  test(
    'un segundo loadMore mientras el primero está en vuelo se ignora',
    () async {
      await container.read(jobFeedProvider.future);
      final gate = Completer<void>();
      jobs.pendingFeed = gate;

      final primera = feed().loadMore();
      expect(actual().loadingMore, isTrue);
      final segunda = feed().loadMore();
      gate.complete();
      await Future.wait([primera, segunda]);

      expect(pedidos(), 2, reason: 'primera página + UNA siguiente');
      expect(actual().items, hasLength(40));
    },
  );

  test('refresh vuelve a la primera página', () async {
    await container.read(jobFeedProvider.future);
    await feed().loadMore();
    expect(actual().items, hasLength(40));

    jobs.feed = ofertas(3);
    await feed().refresh();

    expect(actual().items, hasLength(3));
    expect(actual().hasMore, isFalse);
    expect(jobs.lastCursor, isNull);
  });

  test('si refresh falla se conservan las ofertas y queda el fallo', () async {
    await container.read(jobFeedProvider.future);
    jobs.nextFeedFailure = const DataFailure(DataFailureCode.network);

    await feed().refresh();

    expect(container.read(jobFeedProvider).hasError, isFalse);
    expect(actual().items, hasLength(20));
    expect(actual().failure?.code, DataFailureCode.network);
    // Es de la recarga, no de "Cargar más": la pantalla lo avisa con un
    // SnackBar y no al pie de la lista.
    expect(actual().failureFromLoadMore, isFalse);
  });

  test('lastRefreshFailed se prende cuando falla una recarga, sigue con '
      '"Cargar más" (salga bien o mal) y se apaga con una recarga que sale '
      'bien', () async {
    await container.read(jobFeedProvider.future);
    expect(actual().lastRefreshFailed, isFalse);

    jobs.nextFeedFailure = const DataFailure(DataFailureCode.network);
    await feed().refresh();
    expect(actual().lastRefreshFailed, isTrue);

    await feed().loadMore();
    expect(actual().items, hasLength(40));
    expect(actual().failure, isNull, reason: '"Cargar más" limpia el fallo');
    expect(actual().lastRefreshFailed, isTrue, reason: 'pero no esto');

    jobs.nextFeedFailure = const DataFailure(DataFailureCode.network);
    await feed().loadMore();
    expect(actual().failureFromLoadMore, isTrue);
    expect(actual().lastRefreshFailed, isTrue);

    final gate = Completer<void>();
    jobs.pendingFeed = gate;
    final recarga = feed().refresh();
    expect(actual().refreshing, isTrue);
    expect(actual().lastRefreshFailed, isTrue, reason: 'mientras recarga');
    gate.complete();
    await recarga;
    expect(actual().lastRefreshFailed, isFalse);
    expect(actual().failure, isNull);
  });

  test('si la lista se vuelve a construir y falla con una recarga en vuelo, '
      'no queda una recarga que mostrar', () async {
    await container.read(jobFeedProvider.future);
    final gate = Completer<void>();
    jobs.pendingFeed = gate;
    final recarga = feed().refresh();
    expect(container.read(jobFeedProvider).refreshInProgress, isTrue);

    // Un build nuevo (como el de un cambio de sesión) cuya primera página
    // falla mientras la recarga sigue en vuelo.
    jobs
      ..pendingFeed = null
      ..nextFeedFailure = const DataFailure(DataFailureCode.network);
    container.invalidate(jobFeedProvider);
    await expectLater(
      container.read(jobFeedProvider.future),
      throwsA(isA<DataFailure>()),
    );
    gate.complete();
    await recarga;

    final estado = container.read(jobFeedProvider);
    expect(estado.hasError, isTrue);
    // Riverpod conserva el valor de antes, con la recarga todavía marcada,
    // y la recarga (de la lista anterior) ya no lo toca...
    expect(estado.value?.refreshing, isTrue);
    // ...pero eso no es una recarga en vuelo que mostrar.
    expect(estado.refreshInProgress, isFalse);

    // Y una recarga nueva anda y deja todo en orden.
    await feed().refresh();
    expect(container.read(jobFeedProvider).hasError, isFalse);
    expect(actual().refreshing, isFalse);
    expect(container.read(jobFeedProvider).refreshInProgress, isFalse);
    expect(actual().items, hasLength(20));
  });

  test('si la lista se vuelve a construir y falla con un "Cargar más" en '
      'vuelo, una recarga que después falla no deja esa página en vuelo y '
      '"Cargar más" vuelve a andar', () async {
    await container.read(jobFeedProvider.future);
    final gate = Completer<void>();
    jobs.pendingFeed = gate;
    final pagina = feed().loadMore();
    expect(actual().loadingMore, isTrue);

    jobs
      ..pendingFeed = null
      ..nextFeedFailure = const DataFailure(DataFailureCode.network);
    container.invalidate(jobFeedProvider);
    await expectLater(
      container.read(jobFeedProvider.future),
      throwsA(isA<DataFailure>()),
    );
    gate.complete();
    await pagina;

    final estado = container.read(jobFeedProvider);
    expect(estado.hasError, isTrue);
    // Riverpod conserva el valor de antes con la página marcada en vuelo,
    // pero esa página (de la lista anterior) ya se descartó.
    expect(estado.value?.loadingMore, isTrue);
    expect(estado.loadMoreInProgress, isFalse);

    jobs.nextFeedFailure = const DataFailure(DataFailureCode.network);
    await feed().refresh();
    expect(container.read(jobFeedProvider).hasError, isFalse);
    expect(actual().failure?.code, DataFailureCode.network);
    expect(actual().refreshing, isFalse);
    expect(actual().loadingMore, isFalse);

    await feed().loadMore();
    expect(actual().items, hasLength(40));
    expect(actual().loadingMore, isFalse);
  });

  test('refreshing marca la recarga en vuelo y se apaga al terminar, '
      'salga bien o mal', () async {
    await container.read(jobFeedProvider.future);
    expect(actual().refreshing, isFalse);

    for (final falla in [false, true]) {
      final gate = Completer<void>();
      jobs.pendingFeed = gate;
      if (falla) {
        jobs.nextFeedFailure = const DataFailure(DataFailureCode.network);
      }
      final recarga = feed().refresh();
      expect(actual().refreshing, isTrue, reason: 'falla: $falla');
      expect(actual().items, hasLength(20), reason: 'falla: $falla');

      gate.complete();
      await recarga;
      expect(actual().refreshing, isFalse, reason: 'falla: $falla');
      expect(actual().failure != null, falla);
    }
  });

  // Antes la segunda recarga pedía su propia lectura y "decidía". Ahora una
  // recarga en vuelo se reutiliza: el botón "Actualizar" ya no se deshabilita
  // mientras recarga (deshabilitarlo le sacaba el foco a quien usa teclado),
  // así que apretarlo de nuevo tiene que no hacer nada.
  test('dos recargas encimadas: la segunda no pide otra lectura, espera a la '
      'primera y refreshing termina en false', () async {
    await container.read(jobFeedProvider.future);
    final gate = Completer<void>();
    jobs.pendingFeed = gate;

    final primera = feed().refresh();
    // La única lectura que hay (la de la primera) falla.
    jobs.nextFeedFailure = const DataFailure(DataFailureCode.network);
    final segunda = feed().refresh();
    expect(pedidos(), 2, reason: 'primera página + UNA recarga');
    var segundaTermino = false;
    unawaited(segunda.then((_) => segundaTermino = true));
    await Future<void>.delayed(Duration.zero);
    expect(segundaTermino, isFalse, reason: 'espera a la que está en vuelo');

    gate.complete();
    await Future.wait([primera, segunda]);

    expect(pedidos(), 2);
    expect(actual().refreshing, isFalse);
    expect(actual().failure?.code, DataFailureCode.network);
    expect(actual().items, hasLength(20));

    // Terminada, la siguiente sí vuelve a pedir.
    await feed().refresh();
    expect(pedidos(), 3);
    expect(actual().failure, isNull);
  });

  test('un "Cargar más" que termina durante una recarga no la da por '
      'terminada', () async {
    await container.read(jobFeedProvider.future);
    final recargaGate = Completer<void>();
    final paginaGate = Completer<void>();

    jobs.pendingFeed = recargaGate;
    final recarga = feed().refresh();
    jobs.pendingFeed = paginaGate;
    final pagina = feed().loadMore();
    paginaGate.complete();
    await pagina;
    expect(actual().refreshing, isTrue);

    recargaGate.complete();
    await recarga;
    expect(actual().refreshing, isFalse);
  });

  test('un "Cargar más" que termina durante una recarga que después falla '
      'conserva su página: la lista no salta', () async {
    await container.read(jobFeedProvider.future);
    final recargaGate = Completer<void>();
    final paginaGate = Completer<void>();

    jobs.pendingFeed = recargaGate;
    final recarga = feed().refresh();
    jobs.pendingFeed = paginaGate;
    final pagina = feed().loadMore();
    paginaGate.complete();
    await pagina;
    expect(actual().items, hasLength(40));

    jobs.nextFeedFailure = const DataFailure(DataFailureCode.network);
    recargaGate.complete();
    await recarga;

    // Lo que se veía al fallar, no lo de antes de pedir la recarga.
    expect(actual().items, hasLength(40));
    expect(actual().items.last.id, testJobId(139));
    expect(actual().refreshing, isFalse);
    expect(actual().loadingMore, isFalse);
    expect(actual().failure?.code, DataFailureCode.network);
    expect(actual().failureFromLoadMore, isFalse);

    // Y "Cargar más" sigue desde la última que se ve.
    await feed().loadMore();
    expect(jobs.lastCursor?.id, testJobId(139));
    expect(actual().items, hasLength(45));
  });

  test('un "Cargar más" que termina después de una recarga fallida suma su '
      'página y no deja la recarga en vuelo', () async {
    await container.read(jobFeedProvider.future);
    final recargaGate = Completer<void>();
    final paginaGate = Completer<void>();

    jobs.pendingFeed = recargaGate;
    final recarga = feed().refresh();
    jobs.pendingFeed = paginaGate;
    final pagina = feed().loadMore();

    jobs.nextFeedFailure = const DataFailure(DataFailureCode.network);
    recargaGate.complete();
    await recarga;
    expect(actual().refreshing, isFalse);
    expect(actual().loadingMore, isTrue, reason: 'la página sigue en vuelo');

    paginaGate.complete();
    await pagina;

    expect(actual().items, hasLength(40));
    expect(actual().refreshing, isFalse);
    expect(actual().loadingMore, isFalse);
  });

  test('una página pedida antes de una recarga que sale bien y que llega '
      'después no se pega a la lista nueva', () async {
    await container.read(jobFeedProvider.future);
    final paginaGate = Completer<void>();
    final recargaGate = Completer<void>();

    jobs.pendingFeed = paginaGate;
    final vieja = feed().loadMore();
    jobs.pendingFeed = recargaGate;
    final recarga = feed().refresh();
    jobs.feed = ofertas(3);
    recargaGate.complete();
    await recarga;
    expect(actual().items, hasLength(3));

    // La página 2 de la lista vieja (que ya no existe) llega tarde.
    jobs.feed = ofertas(45);
    paginaGate.complete();
    await vieja;

    expect(actual().items, hasLength(3));
    expect(actual().loadingMore, isFalse);
  });

  test('una recarga fallida después de un "Cargar más" fallido deja el '
      'fallo como de la recarga', () async {
    await container.read(jobFeedProvider.future);
    jobs.nextFeedFailure = const DataFailure(DataFailureCode.network);
    await feed().loadMore();
    expect(actual().failureFromLoadMore, isTrue);

    jobs.nextFeedFailure = const DataFailure(DataFailureCode.unknown);
    await feed().refresh();

    expect(actual().failure?.code, DataFailureCode.unknown);
    expect(actual().failureFromLoadMore, isFalse);
  });

  test('una página que llega después de un refresh no se pega a la lista '
      'nueva', () async {
    await container.read(jobFeedProvider.future);
    final gate = Completer<void>();
    jobs.pendingFeed = gate;

    final vieja = feed().loadMore();
    jobs.feed = ofertas(3);
    final recarga = feed().refresh();
    gate.complete();
    await Future.wait([vieja, recarga]);

    expect(actual().items, hasLength(3));
    expect(actual().loadingMore, isFalse);
  });

  test(
    'si falla la primera página el provider queda en error tipado',
    () async {
      jobs.nextFeedFailure = const DataFailure(DataFailureCode.network);
      container.invalidate(jobFeedProvider);

      await expectLater(
        container.read(jobFeedProvider.future),
        throwsA(isA<DataFailure>()),
      );
      expect(container.read(jobFeedProvider).error, isA<DataFailure>());
    },
  );

  test('un cambio de sesión vuelve a la primera página', () async {
    await container.read(jobFeedProvider.future);
    await feed().loadMore();
    expect(actual().items, hasLength(40));

    auth.emitSignedIn(BusinessRole.candidate);
    await Future<void>.delayed(Duration.zero);
    final state = await container.read(jobFeedProvider.future);

    expect(state.items, hasLength(20));
    expect(jobs.lastCursor, isNull);
  });
}
