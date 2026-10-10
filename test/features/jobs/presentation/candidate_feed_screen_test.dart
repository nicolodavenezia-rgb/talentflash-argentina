import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/companies/data/company_access_repository.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_enums.dart';
import 'package:talentflash_argentina/features/jobs/presentation/widgets/job_offer_card.dart';
import 'package:talentflash_argentina/features/jobs/providers/job_feed_controller.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';
import 'package:talentflash_argentina/shared/widgets/feedback_widgets.dart';

import '../../../support/fake_job_offers_repository.dart';
import '../../../support/gestures.dart';
import '../../../support/pump_app.dart';
import 'job_test_helpers.dart';

/// T-030, feed de ofertas del candidato: estados, paginación keyset con
/// "Cargar más" y la tarjeta de oferta con el distintivo de empresa
/// verificada (la parte de T-029 que se había diferido a T-030).
///
/// Qué ofertas puede leer un candidato lo decide RLS (pgTAP 019); acá se
/// prueba lo que la pantalla hace con lo que recibe.
void main() {
  const ruta = '/candidato/feed';
  const verificadaSemantics =
      'Empresa verificada: verificamos su CUIT con la constancia de ARCA.';

  JobOffer publicada(int n, {JobOfferCompany? company = testJobCompany}) {
    return testJobOffer(
      id: testJobId(n),
      title: 'Oferta $n',
      status: JobStatus.active,
      company: company,
    );
  }

  Future<TalentFlashHarness> entrar(
    WidgetTester tester,
    FakeJobOffersRepository jobs, {
    bool settle = true,
  }) {
    return entrarA(
      tester,
      ruta,
      role: BusinessRole.candidate,
      jobs: jobs,
      settle: settle,
      // Alta como para que entren 25 tarjetas y el pie de la lista.
      surface: const Size(1000, 9000),
    );
  }

  group('estados', () {
    testWidgets('mientras carga la primera página se ve el indicador', (
      tester,
    ) async {
      final pending = Completer<void>();
      final jobs = FakeJobOffersRepository(feed: [publicada(1)])
        ..pendingFeed = pending;
      await entrar(tester, jobs, settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Oferta 1'), findsOneWidget);
    });

    testWidgets('sin ofertas: lo dice y deja actualizar', (tester) async {
      final jobs = FakeJobOffersRepository();
      await entrar(tester, jobs);

      expect(find.text('Todavía no hay ofertas publicadas.'), findsOneWidget);
      jobs.feed = [publicada(1)];
      await ensureAndTap(tester, boton('Actualizar'));
      expect(find.text('Oferta 1'), findsOneWidget);
      expect(
        jobs.calls.where((call) => call == 'fetchActiveJobsPage:inicio'),
        hasLength(2),
      );
    });

    testWidgets('si falla la primera página, explica y reintenta', (
      tester,
    ) async {
      final jobs = FakeJobOffersRepository(feed: [publicada(1)])
        ..nextFeedFailure = const DataFailure(DataFailureCode.network);
      await entrar(tester, jobs);

      expect(find.text('No pudimos cargar las ofertas'), findsOneWidget);
      expect(find.text('Oferta 1'), findsNothing);
      await ensureAndTap(tester, find.text('Reintentar'));
      expect(find.text('Oferta 1'), findsOneWidget);
    });
  });

  group('paginación', () {
    testWidgets('"Cargar más" pide la página siguiente desde la última', (
      tester,
    ) async {
      final jobs = FakeJobOffersRepository(
        feed: [for (var n = 1; n <= 25; n++) publicada(n)],
      );
      await entrar(tester, jobs);

      expect(find.text('Mostrando 20 ofertas'), findsOneWidget);
      expect(find.byType(JobOfferCard), findsNWidgets(20));
      expect(find.text('Oferta 21'), findsNothing);

      await ensureAndTap(tester, find.text('Cargar más ofertas'));

      expect(jobs.calls, contains('fetchActiveJobsPage:${testJobId(20)}'));
      expect(find.text('Mostrando 25 ofertas'), findsOneWidget);
      expect(find.text('Oferta 25'), findsOneWidget);
      expect(find.text('Cargar más ofertas'), findsNothing);
      expect(find.text('No hay más ofertas por ahora.'), findsOneWidget);
    });

    testWidgets('una página completa seguida de una vacía termina la lista', (
      tester,
    ) async {
      final jobs = FakeJobOffersRepository(
        feed: [for (var n = 1; n <= 20; n++) publicada(n)],
      );
      await entrar(tester, jobs);

      await ensureAndTap(tester, find.text('Cargar más ofertas'));
      expect(find.text('Mostrando 20 ofertas'), findsOneWidget);
      expect(find.text('No hay más ofertas por ahora.'), findsOneWidget);
    });

    testWidgets('si falla una página siguiente, conserva lo cargado', (
      tester,
    ) async {
      final jobs = FakeJobOffersRepository(
        feed: [for (var n = 1; n <= 25; n++) publicada(n)],
      );
      await entrar(tester, jobs);
      jobs.nextFeedFailure = const DataFailure(DataFailureCode.network);

      await ensureAndTap(tester, find.text('Cargar más ofertas'));

      expect(find.text('No pudimos cargar las ofertas'), findsOneWidget);
      expect(find.text('Mostrando 20 ofertas'), findsOneWidget);
      await ensureAndTap(tester, find.text('Cargar más ofertas'));
      expect(find.text('Mostrando 25 ofertas'), findsOneWidget);
      expect(find.text('No pudimos cargar las ofertas'), findsNothing);
    });
  });

  testWidgets(
    'en un teléfono, si falla "Cargar más" el aviso aparece junto al botón, '
    'a la vista y anunciado, sin correr la lista',
    (tester) async {
      final handle = tester.ensureSemantics();
      final jobs = FakeJobOffersRepository(
        feed: [for (var n = 1; n <= 25; n++) publicada(n)],
      );
      const pantalla = Size(360, 640);
      await entrarA(
        tester,
        ruta,
        role: BusinessRole.candidate,
        jobs: jobs,
        surface: pantalla,
      );
      jobs.nextFeedFailure = const DataFailure(DataFailureCode.network);

      final cargarMas = find.text('Cargar más ofertas');
      await tester.scrollUntilVisible(
        cargarMas,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(cargarMas);
      await tester.pumpAndSettle();
      final contador = find.text('Mostrando 20 ofertas');
      final contadorAntes = tester.getTopLeft(contador);

      await tester.tap(cargarMas);
      await tester.pumpAndSettle();

      final aviso = find.text('No pudimos cargar las ofertas');
      expect(aviso, findsOneWidget);
      // El aviso y el botón para reintentar, los dos a la vista en el
      // teléfono, y el aviso al final, entre lo cargado y el botón (no
      // arriba de todo: "Oferta 1" ni siquiera está construida).
      final avisoRect = tester.getRect(aviso);
      final botonRect = tester.getRect(cargarMas);
      expect(avisoRect.top, greaterThanOrEqualTo(0));
      expect(botonRect.bottom, lessThanOrEqualTo(pantalla.height));
      expect(avisoRect.top, greaterThan(tester.getRect(contador).bottom));
      expect(avisoRect.bottom, lessThan(botonRect.top));
      expect(find.text('Oferta 1'), findsNothing);
      // Lo ya cargado no se corrió hacia abajo (a lo sumo sube lo justo
      // para mostrar el botón).
      expect(
        tester.getTopLeft(contador).dy,
        lessThanOrEqualTo(contadorAntes.dy),
      );
      // Región viva: el lector lo anuncia.
      var regionViva = false;
      for (
        SemanticsNode? nodo = tester.getSemantics(aviso);
        nodo != null;
        nodo = nodo.parent
      ) {
        regionViva |= nodo.getSemanticsData().flagsCollection.isLiveRegion;
      }
      expect(regionViva, isTrue);

      // Reintentar desde ahí mismo funciona y el aviso se va.
      await ensureAndTap(tester, cargarMas);
      expect(aviso, findsNothing);
      await tester.scrollUntilVisible(
        find.text('Mostrando 25 ofertas'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Mostrando 25 ofertas'), findsOneWidget);
      handle.dispose();
    },
  );

  group('si falla una recarga', () {
    const mensaje =
        'Las ofertas no se actualizaron. '
        'No pudimos conectarnos. Revisá tu conexión y reintentá.';
    final aviso = find.descendant(
      of: find.byType(SnackBar),
      matching: find.text(mensaje),
    );

    testWidgets(
      'en un teléfono, "Actualizar" con la lista bajada muestra que está '
      'actualizando y el fallo aparece a la vista y anunciado, sin correr lo '
      'que se estaba leyendo',
      (tester) async {
        final handle = tester.ensureSemantics();
        final jobs = FakeJobOffersRepository(
          feed: [for (var n = 1; n <= 25; n++) publicada(n)],
        );
        const pantalla = Size(360, 640);
        await entrarA(
          tester,
          ruta,
          role: BusinessRole.candidate,
          jobs: jobs,
          surface: pantalla,
        );

        // Bien abajo: el principio de la lista ni siquiera está construido.
        await tester.scrollUntilVisible(
          find.text('Oferta 12'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Oferta 1'), findsNothing);
        // La primera tarjeta entera a la vista, debajo de la barra superior.
        final barra = tester.getRect(find.byType(AppBar)).bottom;
        final primera =
            [
              for (var n = 2; n <= 20; n++)
                find.widgetWithText(JobOfferCard, 'Oferta $n'),
            ].firstWhere(
              (tarjeta) =>
                  tarjeta.evaluate().isNotEmpty &&
                  tester.getRect(tarjeta).top >= barra,
            );
        final antes = tester.getTopLeft(primera);

        final pendiente = Completer<void>();
        jobs
          ..pendingFeed = pendiente
          ..nextFeedFailure = const DataFailure(DataFailureCode.network);
        await tester.tap(find.byTooltip('Actualizar'));
        await tester.pump();

        // Mientras recarga, la barra lo muestra y no pide otra recarga. El
        // botón sigue habilitado a propósito (deshabilitado perdía el foco
        // del teclado, ver jobs_accessibility_test): apretarlo de nuevo no
        // hace nada.
        final enVuelo = find.byTooltip('Actualizando ofertas');
        expect(enVuelo, findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<IconButton>(
                find.ancestor(of: enVuelo, matching: find.byType(IconButton)),
              )
              .onPressed,
          isNotNull,
        );
        await tester.tap(enVuelo);
        await tester.pump();
        expect(
          jobs.calls.where((call) => call == 'fetchActiveJobsPage:inicio'),
          hasLength(2),
          reason: 'la primera página + UNA recarga',
        );

        pendiente.complete();
        await tester.pumpAndSettle();

        expect(aviso, findsOneWidget);
        final rect = tester.getRect(aviso);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(pantalla.height));
        // Región viva: el lector lo anuncia.
        var regionViva = false;
        for (
          SemanticsNode? nodo = tester.getSemantics(aviso);
          nodo != null;
          nodo = nodo.parent
        ) {
          regionViva |= nodo.getSemanticsData().flagsCollection.isLiveRegion;
        }
        expect(regionViva, isTrue);
        // Nada se corrió: ni un cartel arriba ni la tarjeta que se leía.
        expect(find.byType(MessageBanner), findsNothing);
        expect(tester.getTopLeft(primera), antes);
        // La barra vuelve a ofrecer "Actualizar".
        expect(find.byTooltip('Actualizar'), findsOneWidget);
        expect(find.byTooltip('Actualizando ofertas'), findsNothing);
        handle.dispose();
      },
    );

    testWidgets('al deslizar para actualizar también avisa y conserva las '
        'ofertas', (tester) async {
      final jobs = FakeJobOffersRepository(feed: [publicada(1), publicada(2)]);
      // En un teléfono: el gesto se arma con una fracción del alto visible.
      await entrarA(
        tester,
        ruta,
        role: BusinessRole.candidate,
        jobs: jobs,
        surface: const Size(360, 640),
      );
      jobs.nextFeedFailure = const DataFailure(DataFailureCode.network);

      await tester.fling(find.text('Oferta 1'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(
        jobs.calls.where((call) => call == 'fetchActiveJobsPage:inicio'),
        hasLength(2),
      );
      expect(aviso, findsOneWidget);
      expect(find.text('Oferta 1'), findsOneWidget);
      expect(find.text('Oferta 2'), findsOneWidget);
      expect(find.byType(MessageBanner), findsNothing);
    });

    void mostrarOtroAviso(WidgetTester tester, String texto) {
      ScaffoldMessenger.of(tester.element(find.byType(AppBar)))
          .showSnackBar(SnackBar(content: Text(texto)));
    }

    final alDia = find.descendant(
      of: find.byType(SnackBar),
      matching: find.text('Las ofertas ya están al día.'),
    );

    int lecturas(FakeJobOffersRepository jobs) =>
        jobs.calls.where((call) => call == 'fetchActiveJobsPage:inicio').length;

    // En la ronda anterior la pantalla seguía su propio SnackBar (con su
    // ScaffoldFeatureController) para cerrar solo ese, y uno que esperaba en
    // la cola se cerraba solo al aparecer. Eso abría casos borde y se
    // reemplazó: una recarga que sale bien después de una fallida limpia los
    // SnackBars y dice, también en un SnackBar, que las ofertas ya están al
    // día.
    testWidgets('si después una recarga sale bien, el aviso del fallo se va '
        'y otro, anunciado, dice que las ofertas ya están al día; las '
        'siguientes que salen bien no dicen nada', (tester) async {
      final handle = tester.ensureSemantics();
      final jobs = FakeJobOffersRepository(feed: [publicada(1), publicada(2)]);
      await entrar(tester, jobs);
      jobs.nextFeedFailure = const DataFailure(DataFailureCode.network);

      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(aviso, findsOneWidget);

      // Reintentar sale bien: el aviso ya no es cierto y se va sin esperar
      // sus 8 segundos.
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(lecturas(jobs), 3);
      expect(aviso, findsNothing);
      expect(alDia, findsOneWidget);
      var regionViva = false;
      for (
        SemanticsNode? nodo = tester.getSemantics(alDia);
        nodo != null;
        nodo = nodo.parent
      ) {
        regionViva |= nodo.getSemanticsData().flagsCollection.isLiveRegion;
      }
      expect(regionViva, isTrue);
      // Corto: se va solo.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);

      // Otra que sale bien, sin un fallo antes: nada que avisar.
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(lecturas(jobs), 4);
      expect(find.byType(SnackBar), findsNothing);
      handle.dispose();
    });

    testWidgets('un aviso de fallo que quedó en la cola detrás de otros no '
        'aparece si mientras tanto una recarga salió bien', (tester) async {
      final jobs = FakeJobOffersRepository(feed: [publicada(1), publicada(2)]);
      await entrar(tester, jobs);
      mostrarOtroAviso(tester, 'Aviso A');
      mostrarOtroAviso(tester, 'Aviso B');
      await tester.pumpAndSettle();

      // Falla: "A" se oculta, pero "B" sigue en la cola antes que el aviso.
      jobs.nextFeedFailure = const DataFailure(DataFailureCode.network);
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(find.text('Aviso B'), findsOneWidget);
      expect(aviso, findsNothing);

      // Sale bien mientras el aviso espera su turno: se limpia la cola (el
      // aviso del fallo ya no es cierto) y se dice que ya está al día.
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(alDia, findsOneWidget);
      expect(find.text('Aviso B'), findsNothing);

      // El aviso del fallo no aparece nunca.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(aviso, findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('que la última recarga falló se sabe aunque se salga del feed '
        'y se vuelva', (tester) async {
      final jobs = FakeJobOffersRepository(feed: [publicada(1), publicada(2)]);
      final harness = await entrar(tester, jobs);
      jobs.nextFeedFailure = const DataFailure(DataFailureCode.network);
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(aviso, findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);

      harness.router.go('/candidato');
      await tester.pumpAndSettle();
      harness.router.go(ruta);
      await tester.pumpAndSettle();
      expect(find.text('Oferta 1'), findsOneWidget);

      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(lecturas(jobs), 3);
      expect(alDia, findsOneWidget);
    });

    testWidgets('si la lista se vuelve a construir y falla con una recarga en '
        'vuelo, "Actualizar" no queda girando para siempre', (tester) async {
      final jobs = FakeJobOffersRepository(feed: [publicada(1), publicada(2)]);
      final harness = await entrar(tester, jobs);
      final enLaBarra = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(CircularProgressIndicator),
      );

      final pendiente = Completer<void>();
      jobs.pendingFeed = pendiente;
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pump();
      expect(find.byTooltip('Actualizando ofertas'), findsOneWidget);

      // Cambia la sesión (otro mail): el feed se vuelve a construir y esa
      // primera página falla mientras la recarga sigue en vuelo.
      jobs
        ..pendingFeed = null
        ..nextFeedFailure = const DataFailure(DataFailureCode.network);
      harness.authRepository.emitSignedIn(
        BusinessRole.candidate,
        email: 'otra@tests.local',
      );
      await tester.pump();
      await tester.pump();
      pendiente.complete();
      // Sin pumpAndSettle: con el indicador girando no se asentaría nunca.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(harness.location, ruta);
      expect(lecturas(jobs), 3, reason: 'primera página, recarga y build');
      expect(find.byTooltip('Actualizando ofertas'), findsNothing);
      expect(enLaBarra, findsNothing);
      expect(find.byTooltip('Actualizar'), findsOneWidget);

      // Y "Actualizar" vuelve a andar.
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(lecturas(jobs), 4);
      expect(find.byTooltip('Actualizar'), findsOneWidget);
      expect(find.text('Oferta 1'), findsOneWidget);
    });

    testWidgets('si la lista se vuelve a construir y falla con una recarga en '
        'vuelo, "Cargar más" anda y no vuelve a mostrar "Actualizando '
        'ofertas" ni avisa nada', (tester) async {
      final jobs = FakeJobOffersRepository(
        feed: [for (var n = 1; n <= 25; n++) publicada(n)],
      );
      final harness = await entrar(tester, jobs);
      final enLaBarra = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(CircularProgressIndicator),
      );

      // Antes, una recarga que falla: la próxima que termine bien diría que
      // las ofertas ya están al día.
      jobs.nextFeedFailure = const DataFailure(DataFailureCode.network);
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(aviso, findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);

      // Una recarga en vuelo y un build nuevo (cambio de sesión) que falla.
      final pendiente = Completer<void>();
      jobs.pendingFeed = pendiente;
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pump();
      expect(find.byTooltip('Actualizando ofertas'), findsOneWidget);
      jobs
        ..pendingFeed = null
        ..nextFeedFailure = const DataFailure(DataFailureCode.network);
      harness.authRepository.emitSignedIn(
        BusinessRole.candidate,
        email: 'otra@tests.local',
      );
      await tester.pump();
      await tester.pump();
      pendiente.complete();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byTooltip('Actualizando ofertas'), findsNothing);

      // "Cargar más": la recarga descartada no vuelve como si siguiera en
      // vuelo, ni mientras llega la página ni después.
      await tester.tap(find.text('Cargar más ofertas'));
      await tester.pump();
      expect(find.byTooltip('Actualizando ofertas'), findsNothing);
      expect(enLaBarra, findsNothing);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Mostrando 25 ofertas'), findsOneWidget);
      expect(find.byTooltip('Actualizando ofertas'), findsNothing);
      expect(enLaBarra, findsNothing);
      expect(find.byTooltip('Actualizar'), findsOneWidget);
      // Ninguna recarga terminó: nada que avisar (tampoco "ya están al día").
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('si la lista se vuelve a construir y falla con un "Cargar '
        'más" en vuelo, el indicador del pie no queda girando y "Cargar más" '
        'vuelve a andar', (tester) async {
      final jobs = FakeJobOffersRepository(
        feed: [for (var n = 1; n <= 25; n++) publicada(n)],
      );
      final harness = await entrar(tester, jobs);
      final enElPie = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(CircularProgressIndicator),
      );

      final pendiente = Completer<void>();
      jobs.pendingFeed = pendiente;
      await tester.tap(find.text('Cargar más ofertas'));
      await tester.pump();
      expect(enElPie, findsOneWidget);

      jobs
        ..pendingFeed = null
        ..nextFeedFailure = const DataFailure(DataFailureCode.network);
      harness.authRepository.emitSignedIn(
        BusinessRole.candidate,
        email: 'otra@tests.local',
      );
      await tester.pump();
      await tester.pump();
      pendiente.complete();
      // Sin pumpAndSettle: con el indicador girando no se asentaría nunca.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // La página en vuelo era de la lista anterior y se descartó.
      expect(enElPie, findsNothing);
      expect(find.text('Mostrando 20 ofertas'), findsOneWidget);
      expect(find.text('Cargar más ofertas'), findsOneWidget);

      await tester.tap(find.text('Cargar más ofertas'));
      await tester.pumpAndSettle();
      expect(find.text('Mostrando 25 ofertas'), findsOneWidget);
      expect(enElPie, findsNothing);
      expect(
        jobs.calls.where(
          (call) => call == 'fetchActiveJobsPage:${testJobId(20)}',
        ),
        hasLength(2),
        reason: 'la descartada y la de ahora',
      );
    });

    // En producción `bootstrap.dart` usa un ProviderScope sin `retry`:
    // Riverpod reintenta con backoff un build que falla con una `Exception`
    // y, mientras tanto, el feed sigue cargando con la lista de antes (unos
    // 38 segundos si no se cura). Ahí `loadMore` no hace nada, así que el
    // pie no puede ofrecer un "Cargar más" habilitado. El resto de los tests
    // apaga el reintento y esa ventana no existe; este no.
    testWidgets('con el reintento de producción, mientras la lista se vuelve '
        'a construir el pie muestra el indicador y no un "Cargar más" que '
        'ignora los toques', (tester) async {
      final handle = tester.ensureSemantics();
      final jobs = FakeJobOffersRepository(
        feed: [for (var n = 1; n <= 25; n++) publicada(n)],
      );
      final harness = await entrarA(
        tester,
        ruta,
        role: BusinessRole.candidate,
        jobs: jobs,
        surface: const Size(1000, 9000),
        riverpodRetry: true,
      );
      final cargarMas = find.text('Cargar más ofertas');
      final enElPie = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(CircularProgressIndicator),
      );
      Future<void> avanzar(Duration total) async {
        const paso = Duration(milliseconds: 100);
        for (var t = Duration.zero; t < total; t += paso) {
          await tester.pump(paso);
        }
      }

      expect(cargarMas, findsOneWidget);
      expect(enElPie, findsNothing);

      // Cambia la sesión (otro mail): el feed se vuelve a construir y esa
      // primera página falla hasta nuevo aviso, así que Riverpod reintenta.
      jobs.persistentFeedFailure = const DataFailure(DataFailureCode.network);
      harness.authRepository.emitSignedIn(
        BusinessRole.candidate,
        email: 'otra@tests.local',
      );
      await avanzar(const Duration(seconds: 1));

      final reintentando = harness.container.read(jobFeedProvider);
      expect(reintentando.isLoading, isTrue);
      expect(reintentando.retrying, isTrue);
      // Se sigue viendo la lista de antes, con el indicador en el pie.
      expect(find.text('Mostrando 20 ofertas'), findsOneWidget);
      expect(cargarMas, findsNothing);
      expect(enElPie, findsOneWidget);
      expect(find.bySemanticsLabel('Actualizando ofertas'), findsOneWidget);

      // Vuelve la red: el próximo reintento construye la lista y "Cargar
      // más" vuelve, y anda.
      jobs.persistentFeedFailure = null;
      await avanzar(const Duration(seconds: 3));
      expect(harness.container.read(jobFeedProvider).isLoading, isFalse);
      expect(enElPie, findsNothing);
      expect(cargarMas, findsOneWidget);
      await tester.tap(cargarMas);
      await tester.pumpAndSettle();
      expect(find.text('Mostrando 25 ofertas'), findsOneWidget);
      handle.dispose();
    });
  });

  group('tarjeta de oferta', () {
    testWidgets('muestra lugar, sueldo siempre visible, jornada y modalidad', (
      tester,
    ) async {
      await entrar(tester, FakeJobOffersRepository(feed: [publicada(1)]));

      expect(find.text('Oferta 1'), findsOneWidget);
      expect(find.text('Parrilla de Prueba'), findsOneWidget);
      expect(
        find.text('Palermo, Ciudad Autónoma de Buenos Aires'),
        findsOneWidget,
      );
      expect(find.text('ARS 900.000 a 1.100.000 por mes'), findsOneWidget);
      expect(find.text('Jornada parcial · Presencial'), findsOneWidget);
      // Ningún botón falso en la tarjeta: ni postularse ni guardar.
      expect(find.textContaining('Postular'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(JobOfferCard),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'es UN nodo semántico con etiqueta completa que se puede tocar',
      (tester) async {
        final handle = tester.ensureSemantics();
        await entrar(tester, FakeJobOffersRepository(feed: [publicada(1)]));

        expect(
          tester.getSemantics(find.byType(JobOfferCard)),
          isSemantics(
            label:
                'Oferta 1. Parrilla de Prueba. $verificadaSemantics '
                'Palermo, Ciudad Autónoma de Buenos Aires. '
                'ARS 900.000 a 1.100.000 por mes. Jornada parcial. Presencial.',
            isButton: true,
            hasTapAction: true,
          ),
        );
        // Los textos sueltos de la tarjeta no son nodos aparte.
        expect(find.bySemanticsLabel('Parrilla de Prueba'), findsNothing);
        handle.dispose();
      },
    );

    testWidgets('el distintivo aparece y se anuncia SOLO con approved', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await entrar(
        tester,
        FakeJobOffersRepository(
          feed: [
            publicada(1),
            publicada(
              2,
              company: const JobOfferCompany(
                name: 'Pendiente SA',
                verificationStatus: CompanyVerificationStatus.pending,
              ),
            ),
            publicada(
              3,
              company: const JobOfferCompany(
                name: 'Estado raro SA',
                verificationStatus: null,
              ),
            ),
            publicada(4, company: null),
          ],
        ),
      );

      expect(find.text('Empresa verificada'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^Oferta 1\\..*Empresa verificada:')),
        findsOneWidget,
      );
      for (final n in [2, 3, 4]) {
        final label = tester.getSemantics(find.byType(JobOfferCard).at(n - 1));
        expect(
          label.label,
          isNot(contains('Empresa verificada')),
          reason: 'la oferta $n no es de una empresa aprobada',
        );
      }
      expect(find.text('Empresa sin nombre disponible'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('tocarla abre el detalle', (tester) async {
      final jobs = FakeJobOffersRepository(
        jobs: [publicada(1)],
        feed: [publicada(1)],
      );
      final harness = await entrar(tester, jobs);

      await ensureAndTap(tester, find.byType(JobOfferCard));
      expect(harness.location, '/candidato/ofertas/${testJobId(1)}');
      expect(find.text('Detalle de la oferta'), findsOneWidget);
    });
  });

  testWidgets('el inicio del candidato lleva al feed', (tester) async {
    final harness = await entrarA(
      tester,
      '/candidato',
      role: BusinessRole.candidate,
      jobs: FakeJobOffersRepository(),
    );

    await ensureAndTap(tester, find.text('Ofertas de trabajo'));
    expect(harness.location, ruta);
  });

  testWidgets('la empresa no entra al feed de candidatos', (tester) async {
    final harness = await entrarA(
      tester,
      ruta,
      jobs: FakeJobOffersRepository(feed: [publicada(1)]),
    );

    expect(harness.location, '/empresa');
    expect(find.byType(JobOfferCard), findsNothing);
  });
}
