import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/companies/data/company_access_repository.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_enums.dart';
import 'package:talentflash_argentina/features/jobs/providers/job_offers_providers.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';
import 'package:talentflash_argentina/shared/widgets/feedback_widgets.dart';

import '../../../support/fake_job_offers_repository.dart';
import '../../../support/gestures.dart';
import 'job_test_helpers.dart';

/// T-030, "Mis ofertas" de la empresa: estados de la lista, acciones por
/// estado, rol viewer y empresa sin verificar.
///
/// Todo lo que se oculta o deshabilita acá es UX. Quién escribe y quién
/// publica lo deciden las policies y los triggers de 0032, cubiertos por
/// `supabase/tests/database/019_job_offer_lifecycle_test.sql`.
void main() {
  const ruta = '/empresa/ofertas';

  /// El aviso de una recarga que falló con la lista a la vista: un SnackBar.
  const textoListaVieja =
      'La lista no se actualizó y puede no estar al día: tocá "Actualizar" '
      'arriba para reintentar.';
  final avisoListaVieja = find.descendant(
    of: find.byType(SnackBar),
    matching: find.text(textoListaVieja),
  );

  /// Un SnackBar que dice exactamente [texto].
  Finder enSnackBar(String texto) =>
      find.descendant(of: find.byType(SnackBar), matching: find.text(texto));

  const pausada = 'Oferta pausada: los candidatos ya no la ven.';

  /// Rótulo de "Actualizar" mientras la última recarga está fallida.
  const actualizarListaVieja = 'Actualizar: la lista puede no estar al día';

  /// Los textos que la app le anuncia al lector de pantalla con
  /// `SemanticsService` durante el test (los SnackBars no pasan por acá: son
  /// regiones vivas).
  List<String> anunciosAlLector(WidgetTester tester) {
    final anuncios = <String>[];
    final mensajero = tester.binding.defaultBinaryMessenger
      ..setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
        mensaje,
      ) async {
        final evento = mensaje! as Map<Object?, Object?>;
        if (evento['type'] == 'announce') {
          final datos = evento['data']! as Map<Object?, Object?>;
          anuncios.add(datos['message']! as String);
        }
        return null;
      });
    addTearDown(
      () => mensajero.setMockDecodedMessageHandler<Object?>(
        SystemChannels.accessibility,
        null,
      ),
    );
    return anuncios;
  }

  /// Una oferta por estado, con títulos distintos para ubicar su tarjeta.
  FakeJobOffersRepository unaPorEstado() {
    return FakeJobOffersRepository(
      jobs: [
        testJobOffer(id: testJobId(1), title: 'Oferta borrador'),
        testJobOffer(
          id: testJobId(2),
          title: 'Oferta activa',
          status: JobStatus.active,
        ),
        testJobOffer(
          id: testJobId(3),
          title: 'Oferta pausada',
          status: JobStatus.paused,
        ),
        testJobOffer(
          id: testJobId(4),
          title: 'Oferta vencida',
          status: JobStatus.expired,
        ),
        testJobOffer(
          id: testJobId(5),
          title: 'Oferta cerrada',
          status: JobStatus.closed,
        ),
      ],
    );
  }

  group('estados de la lista', () {
    testWidgets('mientras cargan las ofertas se ve el indicador', (
      tester,
    ) async {
      final pending = Completer<void>();
      final jobs = unaPorEstado()..pendingCompanyJobs = pending;
      final harness = await entrarA(tester, ruta, jobs: jobs, settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Oferta borrador'), findsNothing);

      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Oferta borrador'), findsOneWidget);
      expect(harness.location, ruta);
    });

    testWidgets('sin ofertas: explica y ofrece crear la primera', (
      tester,
    ) async {
      final harness = await entrarA(
        tester,
        ruta,
        jobs: FakeJobOffersRepository(),
      );

      expect(find.text('Todavía no creaste ofertas'), findsOneWidget);
      await ensureAndTap(tester, find.text('Crear mi primera oferta'));
      expect(harness.location, '/empresa/ofertas/nueva');
    });

    testWidgets('si la carga falla, dice qué pasó y deja reintentar', (
      tester,
    ) async {
      final jobs = unaPorEstado()
        ..nextFetchFailure = const DataFailure(DataFailureCode.network);
      await entrarA(tester, ruta, jobs: jobs);

      expect(find.text('No pudimos cargar tus ofertas'), findsOneWidget);
      expect(
        find.text('No pudimos conectarnos. Revisá tu conexión y reintentá.'),
        findsOneWidget,
      );
      expect(find.text('Oferta borrador'), findsNothing);

      await ensureAndTap(tester, find.text('Reintentar'));
      expect(find.text('Oferta borrador'), findsOneWidget);
      expect(
        jobs.calls.where((call) => call.startsWith('fetchCompanyJobs')),
        hasLength(2),
      );
    });

    testWidgets('mientras se reintenta la primera carga que falló se ve el '
        'indicador, no un cuerpo vacío', (tester) async {
      final jobs = unaPorEstado()
        ..nextFetchFailure = const DataFailure(DataFailureCode.network);
      await entrarA(tester, ruta, jobs: jobs);
      expect(find.text('No pudimos cargar tus ofertas'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      final pendiente = Completer<void>();
      jobs.pendingCompanyJobs = pendiente;
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump();

      expect(find.text('No pudimos cargar tus ofertas'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      pendiente.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Oferta borrador'), findsOneWidget);
    });

    testWidgets('lee solo las ofertas de SU empresa', (tester) async {
      final jobs = FakeJobOffersRepository(
        jobs: [
          testJobOffer(id: testJobId(1), title: 'Propia'),
          testJobOffer(
            id: testJobId(2),
            title: 'Ajena',
            companyId: 'c0000000-0000-4000-8000-000000000999',
            status: JobStatus.active,
          ),
        ],
      );
      await entrarA(tester, ruta, jobs: jobs);

      expect(jobs.calls, contains('fetchCompanyJobs:$testJobCompanyId'));
      expect(find.text('Propia'), findsOneWidget);
      expect(find.text('Ajena'), findsNothing);
    });
  });

  group('acciones por estado (empresa verificada)', () {
    Future<FakeJobOffersRepository> entrar(WidgetTester tester) async {
      final jobs = unaPorEstado();
      await entrarA(
        tester,
        ruta,
        jobs: jobs,
        verification: verificacion(CompanyVerificationStatus.approved),
      );
      return jobs;
    }

    void esperarAcciones(String titulo, List<String> si, List<String> no) {
      for (final label in si) {
        expect(
          boton(label, titulo: titulo),
          findsOneWidget,
          reason: '$titulo debería ofrecer "$label"',
        );
      }
      for (final label in no) {
        expect(
          boton(label, titulo: titulo),
          findsNothing,
          reason: '$titulo NO debería ofrecer "$label"',
        );
      }
    }

    testWidgets('cada estado ofrece solo lo que su ciclo de vida permite', (
      tester,
    ) async {
      await entrar(tester);

      esperarAcciones(
        'Oferta borrador',
        ['Editar', 'Publicar', 'Duplicar', 'Descartar borrador'],
        ['Pausar', 'Reanudar', 'Cerrar'],
      );
      esperarAcciones(
        'Oferta activa',
        ['Editar', 'Pausar', 'Duplicar', 'Cerrar'],
        ['Publicar', 'Reanudar', 'Descartar borrador'],
      );
      esperarAcciones(
        'Oferta pausada',
        ['Editar', 'Reanudar', 'Duplicar', 'Cerrar'],
        ['Publicar', 'Pausar', 'Descartar borrador'],
      );
      esperarAcciones(
        'Oferta vencida',
        ['Duplicar', 'Cerrar'],
        ['Editar', 'Publicar', 'Pausar', 'Reanudar', 'Descartar borrador'],
      );
      esperarAcciones(
        'Oferta cerrada',
        ['Duplicar'],
        ['Editar', 'Publicar', 'Pausar', 'Reanudar', 'Cerrar'],
      );
    });

    testWidgets('el estado se dice con texto (no solo color) y al lector', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await entrar(tester);

      for (final estado in [
        'Borrador',
        'Activa',
        'Pausada',
        'Vencida',
        'Cerrada',
      ]) {
        expect(find.text(estado), findsOneWidget);
        expect(find.bySemanticsLabel('Estado: $estado'), findsOneWidget);
      }
      // Cada botón dice sobre qué oferta actúa.
      expect(find.bySemanticsLabel('Pausar: Oferta activa'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('pausar escribe el estado y lo confirma', (tester) async {
      final jobs = await entrar(tester);

      await ensureAndTap(tester, boton('Pausar', titulo: 'Oferta activa'));

      expect(jobs.calls, contains('changeStatus:${testJobId(2)}:paused'));
      expect(
        find.text('Oferta pausada: los candidatos ya no la ven.'),
        findsOneWidget,
      );
      // La lista se recargó con el estado nuevo.
      expect(find.text('Pausada'), findsNWidgets(2));
    });

    testWidgets('reanudar y publicar desde la lista', (tester) async {
      final jobs = await entrar(tester);

      await ensureAndTap(tester, boton('Reanudar', titulo: 'Oferta pausada'));
      expect(jobs.calls, contains('changeStatus:${testJobId(3)}:active'));
      expect(find.text('Oferta reanudada.'), findsOneWidget);

      await ensureAndTap(tester, boton('Publicar', titulo: 'Oferta borrador'));
      expect(jobs.calls, contains('changeStatus:${testJobId(1)}:active'));
    });

    testWidgets('cerrar pide confirmación y cancelar no escribe nada', (
      tester,
    ) async {
      final jobs = await entrar(tester);

      await ensureAndTap(tester, boton('Cerrar', titulo: 'Oferta activa'));
      expect(find.text('¿Cerrar la oferta?'), findsOneWidget);
      await ensureAndTap(tester, find.text('Cancelar'));
      expect(
        jobs.calls.where((call) => call.startsWith('changeStatus')),
        isEmpty,
      );

      await ensureAndTap(tester, boton('Cerrar', titulo: 'Oferta activa'));
      await ensureAndTap(tester, find.text('Cerrar oferta'));
      expect(jobs.calls, contains('changeStatus:${testJobId(2)}:closed'));
      expect(find.text('Oferta cerrada.'), findsOneWidget);
    });

    testWidgets('descartar un borrador pide confirmación y lo saca', (
      tester,
    ) async {
      final jobs = await entrar(tester);

      await ensureAndTap(
        tester,
        boton('Descartar borrador', titulo: 'Oferta borrador'),
      );
      expect(find.text('¿Descartar el borrador?'), findsOneWidget);
      await ensureAndTap(tester, find.text('Descartar'));

      expect(jobs.calls, contains('discardDraft:${testJobId(1)}'));
      expect(find.text('Borrador descartado.'), findsOneWidget);
      expect(find.text('Oferta borrador'), findsNothing);
    });

    testWidgets('editar y duplicar navegan al formulario', (tester) async {
      final jobs = unaPorEstado();
      final harness = await entrarA(
        tester,
        ruta,
        jobs: jobs,
        verification: verificacion(CompanyVerificationStatus.approved),
      );

      await ensureAndTap(tester, boton('Editar', titulo: 'Oferta activa'));
      expect(harness.location, '/empresa/ofertas/${testJobId(2)}/editar');

      harness.router.go(ruta);
      await tester.pumpAndSettle();
      await ensureAndTap(tester, boton('Duplicar', titulo: 'Oferta cerrada'));
      expect(
        harness.location,
        '/empresa/ofertas/nueva?duplicar=${testJobId(5)}',
      );
    });

    testWidgets('publicar fuera de la ventana de 60 días no viaja y explica', (
      tester,
    ) async {
      final jobs = FakeJobOffersRepository(
        jobs: [
          testJobOffer(
            title: 'Vence lejos',
            expiresAt: testJobNow.add(const Duration(days: 90)),
          ),
        ],
      );
      await entrarA(
        tester,
        ruta,
        jobs: jobs,
        verification: verificacion(CompanyVerificationStatus.approved),
      );

      await ensureAndTap(tester, boton('Publicar', titulo: 'Vence lejos'));

      expect(
        jobs.calls.where((call) => call.startsWith('changeStatus')),
        isEmpty,
      );
      expect(
        find.textContaining('dentro de los próximos 60 días'),
        findsOneWidget,
      );
    });

    testWidgets('un conflicto de estado del servidor se explica', (
      tester,
    ) async {
      final jobs = await entrar(tester);
      jobs.nextStatusFailure = const DataFailure(
        DataFailureCode.jobStateConflict,
      );

      await ensureAndTap(tester, boton('Pausar', titulo: 'Oferta activa'));

      expect(find.textContaining('La oferta cambió de estado'), findsOneWidget);
    });

    testWidgets(
      'en un teléfono, el fallo de una acción sobre una oferta del fondo se '
      've donde está la persona y se anuncia',
      (tester) async {
        final handle = tester.ensureSemantics();
        final jobs = FakeJobOffersRepository(
          jobs: [
            for (var n = 1; n <= 6; n++)
              testJobOffer(id: testJobId(n), title: 'Borrador $n'),
            testJobOffer(
              id: testJobId(7),
              title: 'Activa del fondo',
              status: JobStatus.active,
            ),
          ],
        );
        const pantalla = Size(360, 640);
        await entrarA(
          tester,
          ruta,
          jobs: jobs,
          verification: verificacion(CompanyVerificationStatus.approved),
          surface: pantalla,
        );
        jobs.nextStatusFailure = const DataFailure(DataFailureCode.network);

        // La lista es perezosa: la última tarjeta recién existe al bajar.
        await tester.scrollUntilVisible(
          find.text('Activa del fondo'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await ensureAndTap(tester, boton('Pausar', titulo: 'Activa del fondo'));

        const mensaje =
            'No pudimos conectarnos. Revisá tu conexión y reintentá.';
        final aviso = find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(mensaje),
        );
        expect(aviso, findsOneWidget);
        // A la vista, dentro de la pantalla del teléfono, aunque el principio
        // de la lista quedó muy arriba.
        final rect = tester.getRect(aviso);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(pantalla.height));
        expect(find.text('Borrador 1'), findsNothing);
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
        // No depende de un cartel al principio de la lista.
        expect(find.byType(MessageBanner), findsNothing);
        handle.dispose();
      },
    );

    // En la ronda anterior el fallo de esta recarga era un aviso fijo entre
    // la barra y la lista: empujaba hacia abajo la tarjeta que se acababa de
    // tocar. Vuelve a ser un SnackBar, ahora sin acción (se reintenta con
    // "Actualizar", cuyo ícono lo sigue diciendo), y vuelve a pedirse lo de
    // antes: la tarjeta no se mueve EN LA PANTALLA.
    //
    // Adaptado en la ronda 8: antes el resultado de la acción y el aviso de
    // la recarga eran dos SnackBars, el aviso en cola detrás del resultado.
    // Ahora ningún SnackBar de la pantalla queda en cola: es uno solo, cuando
    // la recarga termina, con el resultado y el aviso de lista vieja.
    //
    // Adaptado de nuevo: ese SnackBar combinado esperaba a la recarga, y en
    // producción, con el reintento de Riverpod, una recarga que falla tarda
    // unos 38 segundos en terminar: el resultado quedaba mudo todo ese
    // tiempo. Ahora el resultado va solo, apenas termina la acción, y el
    // fallo de la recarga automática no se avisa con otro SnackBar: lo dice
    // "Actualizar" (y se anuncia al lector, ver el test de la recarga
    // automática). Lo demás se sigue pidiendo igual.
    testWidgets(
      'en un teléfono, si falla la recarga que sigue a una acción que salió '
      'bien, la tarjeta muestra lo confirmado sin moverse, el resultado se ve '
      'donde está la persona sin que otro SnackBar lo reemplace y '
      '"Actualizar" dice que la lista puede no estar al día',
      (tester) async {
        final handle = tester.ensureSemantics();
        final jobs = FakeJobOffersRepository(
          jobs: [
            for (var n = 1; n <= 6; n++)
              testJobOffer(id: testJobId(n), title: 'Borrador $n'),
            testJobOffer(
              id: testJobId(7),
              title: 'Activa del fondo',
              status: JobStatus.active,
            ),
          ],
        );
        const pantalla = Size(360, 640);
        await entrarA(
          tester,
          ruta,
          jobs: jobs,
          verification: verificacion(CompanyVerificationStatus.approved),
          surface: pantalla,
        );
        int lecturas() => jobs.calls
            .where((call) => call.startsWith('fetchCompanyJobs'))
            .length;

        await tester.scrollUntilVisible(
          find.text('Activa del fondo'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        final pausar = boton('Pausar', titulo: 'Activa del fondo');
        await tester.ensureVisible(pausar);
        await tester.pumpAndSettle();
        final titulo = find.text('Activa del fondo');
        final antes = tester.getTopLeft(titulo);

        jobs.nextFetchFailure = const DataFailure(DataFailureCode.network);
        await tester.tap(pausar);
        await tester.pumpAndSettle();

        expect(jobs.calls, contains('changeStatus:${testJobId(7)}:paused'));
        expect(lecturas(), 2, reason: 'la recarga automática se intentó');
        // Un solo SnackBar: el resultado, que la tarjeta ya muestra (pausada,
        // con "Reanudar"). El fallo de la recarga no lo reemplaza.
        final aviso = enSnackBar(pausada);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(aviso, findsOneWidget);
        expect(avisoListaVieja, findsNothing);
        expect(
          find.descendant(
            of: tarjeta('Activa del fondo'),
            matching: find.text('Pausada'),
          ),
          findsOneWidget,
        );
        expect(boton('Reanudar', titulo: 'Activa del fondo'), findsOneWidget);
        expect(boton('Pausar', titulo: 'Activa del fondo'), findsNothing);
        expect(tester.getTopLeft(titulo), antes);
        // El botón de la barra también lo dice.
        expect(find.byTooltip(actualizarListaVieja), findsOneWidget);
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
        // Sin acción: con acción, Flutter lo dejaría fijo.
        expect(find.byType(SnackBarAction), findsNothing);
        // Ni un cartel arriba ni la tarjeta corrida.
        expect(find.byType(MessageBanner), findsNothing);
        expect(tester.getTopLeft(titulo), antes);

        // Se va solo, a los 4 segundos de cualquier resultado, y no queda
        // otro en cola; el botón de la barra lo sigue diciendo y nada se
        // movió.
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byTooltip(actualizarListaVieja), findsOneWidget);
        expect(tester.getTopLeft(titulo), antes);

        // "Actualizar" reintenta; sale bien y el botón vuelve a ser el de
        // siempre, sin otro aviso.
        await tester.tap(find.byTooltip(actualizarListaVieja));
        await tester.pumpAndSettle();
        expect(lecturas(), 3);
        expect(find.byTooltip('Actualizar'), findsOneWidget);
        expect(find.byTooltip(actualizarListaVieja), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        expect(tester.getTopLeft(titulo), antes);
        expect(boton('Reanudar', titulo: 'Activa del fondo'), findsOneWidget);
        handle.dispose();
      },
    );

    // Adaptado en la ronda 8: antes el aviso de cada recarga fallida iba en
    // cola detrás del SnackBar a la vista y, tras una acción, llegaba después
    // de su resultado. Ahora ningún SnackBar de la pantalla queda en cola:
    // reemplaza al que esté a la vista y, tras una acción, va en el mismo
    // SnackBar que el resultado.
    //
    // Adaptado de nuevo: tras una acción ya no hay SnackBar combinado (hacía
    // esperar al resultado, ver el test del teléfono de arriba). El resultado
    // va solo y el fallo de la recarga automática no se avisa con un
    // SnackBar; el de "Actualizar", sí, como antes.
    testWidgets('cada "Actualizar" que falla con la lista a la vista avisa con '
        'un SnackBar nuevo que reemplaza al que esté a la vista, sin cola, y '
        'nada se corre', (tester) async {
      final jobs = unaPorEstado();
      await entrarA(
        tester,
        ruta,
        jobs: jobs,
        verification: verificacion(CompanyVerificationStatus.approved),
      );
      int lecturas() => jobs.calls
          .where((call) => call.startsWith('fetchCompanyJobs'))
          .length;
      final titulo = find.text('Oferta borrador');
      final antes = tester.getTopLeft(titulo);
      final lista = tester.getRect(find.byType(ListView));
      final vieja = find.byTooltip(actualizarListaVieja);

      // Falla la recarga de "Actualizar": se avisa.
      jobs.nextFetchFailure = const DataFailure(DataFailureCode.network);
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(lecturas(), 2);
      expect(avisoListaVieja, findsOneWidget);
      expect(vieja, findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);

      // Vuelve a fallar: otro SnackBar, que se vuelve a anunciar.
      jobs.nextFetchFailure = const DataFailure(DataFailureCode.network);
      await tester.tap(vieja);
      await tester.pumpAndSettle();
      expect(lecturas(), 3);
      expect(avisoListaVieja, findsOneWidget);

      // Y otra vez, con ese a la vista hace 6 segundos: uno nuevo lo
      // reemplaza y dura sus propios 8 segundos. No queda nada en cola.
      await tester.pump(const Duration(seconds: 6));
      jobs.nextFetchFailure = const DataFailure(DataFailureCode.network);
      await tester.tap(vieja);
      await tester.pumpAndSettle();
      expect(lecturas(), 4);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(avisoListaVieja, findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      expect(
        avisoListaVieja,
        findsOneWidget,
        reason: 'es uno nuevo: el anterior ya se habría ido',
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing, reason: 'nada en cola');

      // Una acción cuya recarga (automática) vuelve a fallar: un solo
      // SnackBar, el del resultado, que el fallo no reemplaza.
      jobs.nextFetchFailure = const DataFailure(DataFailureCode.network);
      await ensureAndTap(tester, boton('Pausar', titulo: 'Oferta activa'));
      expect(lecturas(), 5);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(enSnackBar(pausada), findsOneWidget);
      expect(avisoListaVieja, findsNothing);
      expect(vieja, findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);

      // En todo esto, nada se corrió.
      expect(tester.getTopLeft(titulo), antes);
      expect(tester.getRect(find.byType(ListView)), lista);

      // Una acción cuya recarga sale bien: solo el resultado, y el botón
      // vuelve a "Actualizar".
      await ensureAndTap(tester, boton('Reanudar', titulo: 'Oferta pausada'));
      expect(lecturas(), 6);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(enSnackBar('Oferta reanudada.'), findsOneWidget);
      expect(find.byTooltip('Actualizar'), findsOneWidget);
      expect(vieja, findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.getTopLeft(titulo), antes);
    });

    // Reemplaza al test que pedía lo contrario ("el resultado de una acción
    // no se avisa mientras sigue la recarga que la sigue"): esa espera, con
    // el reintento de producción, dejaba el resultado mudo unos 38 segundos.
    testWidgets('el resultado de una acción se avisa apenas termina, aunque '
        'la recarga que la sigue siga en vuelo, y esa recarga no lo reemplaza '
        'ni si sale bien ni si falla', (tester) async {
      final jobs = unaPorEstado();
      await entrarA(
        tester,
        ruta,
        jobs: jobs,
        verification: verificacion(CompanyVerificationStatus.approved),
      );
      // Con la recarga en vuelo gira el indicador de la barra: sin
      // pumpAndSettle.
      Future<void> unRato() async {
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      // Pausar, con la recarga que sigue retenida.
      var pendiente = Completer<void>();
      jobs.pendingCompanyJobs = pendiente;
      await tester.tap(boton('Pausar', titulo: 'Oferta activa'));
      await unRato();
      expect(jobs.calls, contains('changeStatus:${testJobId(2)}:paused'));
      expect(find.byTooltip('Actualizando tus ofertas'), findsOneWidget);
      // La tarjeta ya muestra lo confirmado y el resultado ya está a la vista.
      expect(
        find.descendant(
          of: tarjeta('Oferta activa'),
          matching: find.text('Pausada'),
        ),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsOneWidget);
      expect(enSnackBar(pausada), findsOneWidget);
      final resultado = tester.element(find.byType(SnackBar));
      // La recarga sale bien: el mismo SnackBar sigue a la vista.
      pendiente.complete();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Actualizar'), findsOneWidget);
      expect(enSnackBar(pausada), findsOneWidget);
      expect(tester.element(find.byType(SnackBar)), same(resultado));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);

      // Reanudar, con la recarga retenida y después fallida.
      pendiente = Completer<void>();
      jobs
        ..pendingCompanyJobs = pendiente
        ..nextFetchFailure = const DataFailure(DataFailureCode.network);
      await tester.tap(boton('Reanudar', titulo: 'Oferta pausada'));
      await unRato();
      expect(jobs.calls, contains('changeStatus:${testJobId(3)}:active'));
      expect(find.byTooltip('Actualizando tus ofertas'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(enSnackBar('Oferta reanudada.'), findsOneWidget);
      final reanudada = tester.element(find.byType(SnackBar));
      pendiente.complete();
      await tester.pumpAndSettle();
      expect(find.byTooltip(actualizarListaVieja), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(enSnackBar('Oferta reanudada.'), findsOneWidget);
      expect(tester.element(find.byType(SnackBar)), same(reanudada));
      expect(avisoListaVieja, findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing, reason: 'nada en cola');
    });

    // Adaptado: antes un aviso de lista vieja podía ir junto al resultado de
    // una acción, en el mismo SnackBar. Ya no: tras una acción, el resultado
    // va solo, y una recarga que sale bien no se lo lleva.
    testWidgets('una recarga que sale bien se lleva el aviso de lista vieja '
        'que esté a la vista, y no otro SnackBar ni el resultado de una '
        'acción', (tester) async {
      final jobs = unaPorEstado();
      await entrarA(
        tester,
        ruta,
        jobs: jobs,
        verification: verificacion(CompanyVerificationStatus.approved),
      );
      final vieja = find.byTooltip(actualizarListaVieja);

      // El aviso solo: "Actualizar" falla y después sale bien.
      jobs.nextFetchFailure = const DataFailure(DataFailureCode.network);
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(avisoListaVieja, findsOneWidget);
      await tester.tap(vieja);
      await tester.pumpAndSettle();
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason: 'se va enseguida, sin esperar sus 8 segundos',
      );
      expect(find.byTooltip('Actualizar'), findsOneWidget);

      // El resultado de una acción cuya recarga falla no es un aviso de
      // lista vieja: "Actualizar" sale bien y se queda.
      jobs.nextFetchFailure = const DataFailure(DataFailureCode.network);
      await ensureAndTap(tester, boton('Pausar', titulo: 'Oferta activa'));
      expect(enSnackBar(pausada), findsOneWidget);
      expect(vieja, findsOneWidget);
      await tester.tap(vieja);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Actualizar'), findsOneWidget);
      expect(enSnackBar(pausada), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);

      // Un SnackBar que no es un aviso de lista vieja se queda.
      await ensureAndTap(tester, boton('Reanudar', titulo: 'Oferta pausada'));
      expect(enSnackBar('Oferta reanudada.'), findsOneWidget);
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(enSnackBar('Oferta reanudada.'), findsOneWidget);
    });

    testWidgets('si la acción falla, se avisa solo el fallo aunque la recarga '
        'que sigue a un conflicto también falle', (tester) async {
      final jobs = unaPorEstado();
      await entrarA(
        tester,
        ruta,
        jobs: jobs,
        verification: verificacion(CompanyVerificationStatus.approved),
      );
      jobs
        ..nextStatusFailure = const DataFailure(
          DataFailureCode.jobStateConflict,
        )
        ..nextFetchFailure = const DataFailure(DataFailureCode.network);

      await ensureAndTap(tester, boton('Pausar', titulo: 'Oferta activa'));

      expect(
        jobs.calls.where((call) => call.startsWith('fetchCompanyJobs')),
        hasLength(2),
        reason: 'el conflicto recargó la lista',
      );
      final fallo = enSnackBar(
        'La oferta cambió de estado mientras la tenías abierta. Ya te '
        'mostramos cómo quedó: revisala y volvé a intentarlo.',
      );
      expect(find.byType(SnackBar), findsOneWidget);
      expect(fallo, findsOneWidget);
      expect(avisoListaVieja, findsNothing);
      // El botón de la barra dice que la lista puede no estar al día.
      expect(find.byTooltip(actualizarListaVieja), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(fallo, findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('"Actualizar" en la barra está siempre y no cambia de tamaño: '
        'recarga la lista, sigue habilitado mientras recarga, otro toque no '
        'pide otra y, si falla, su ícono y su rótulo lo dicen', (tester) async {
      final handle = tester.ensureSemantics();
      final jobs = unaPorEstado();
      await entrarA(
        tester,
        ruta,
        jobs: jobs,
        verification: verificacion(CompanyVerificationStatus.approved),
      );
      int lecturas() => jobs.calls
          .where((call) => call.startsWith('fetchCompanyJobs'))
          .length;
      Finder botonDe(Finder tooltip) =>
          find.ancestor(of: tooltip, matching: find.byType(IconButton));
      Finder enLaBarra(Finder finder) =>
          find.descendant(of: find.byType(AppBar), matching: finder);
      final lista = tester.getRect(find.byType(ListView));

      final actualizar = find.byTooltip('Actualizar');
      expect(actualizar, findsOneWidget);
      expect(enLaBarra(find.byIcon(Icons.refresh)), findsOneWidget);
      final tamanio = tester.getSize(botonDe(actualizar));
      expect(lecturas(), 1);

      final pendiente = Completer<void>();
      jobs
        ..pendingCompanyJobs = pendiente
        ..nextFetchFailure = const DataFailure(DataFailureCode.network);
      await tester.tap(actualizar);
      await tester.pump();
      final enVuelo = find.byTooltip('Actualizando tus ofertas');
      expect(enVuelo, findsOneWidget);
      expect(enLaBarra(find.byType(CircularProgressIndicator)), findsOneWidget);
      expect(tester.widget<IconButton>(botonDe(enVuelo)).onPressed, isNotNull);
      expect(tester.getSize(botonDe(enVuelo)), tamanio);
      await tester.tap(enVuelo);
      await tester.pump();
      expect(lecturas(), 2, reason: 'el segundo toque no pide otra');
      // La lista sigue a la vista mientras recarga.
      expect(find.text('Oferta activa'), findsOneWidget);

      pendiente.complete();
      await tester.pumpAndSettle();
      expect(avisoListaVieja, findsOneWidget);
      final vieja = find.byTooltip(actualizarListaVieja);
      expect(vieja, findsOneWidget);
      expect(actualizar, findsNothing);
      expect(enLaBarra(find.byIcon(Icons.sync_problem)), findsOneWidget);
      expect(enLaBarra(find.byIcon(Icons.refresh)), findsNothing);
      expect(
        tester.getSemantics(botonDe(vieja)),
        isSemantics(tooltip: actualizarListaVieja, isButton: true),
      );
      expect(tester.widget<IconButton>(botonDe(vieja)).onPressed, isNotNull);
      expect(tester.getSize(botonDe(vieja)), tamanio);
      // Nada se agregó arriba de la lista.
      expect(tester.getRect(find.byType(ListView)), lista);

      // Con una recarga que sale bien, vuelve a ser "Actualizar".
      await tester.tap(vieja);
      await tester.pumpAndSettle();
      expect(lecturas(), 3);
      expect(actualizar, findsOneWidget);
      expect(vieja, findsNothing);
      expect(enLaBarra(find.byIcon(Icons.refresh)), findsOneWidget);
      expect(tester.getSize(botonDe(actualizar)), tamanio);
      expect(tester.getRect(find.byType(ListView)), lista);
      handle.dispose();
    });

    testWidgets('al volver a la pantalla, una recarga que había fallado con '
        'la lista cargada se reintenta sola', (tester) async {
      final jobs = unaPorEstado();
      final harness = await entrarA(
        tester,
        ruta,
        jobs: jobs,
        verification: verificacion(CompanyVerificationStatus.approved),
      );
      jobs.nextFetchFailure = const DataFailure(DataFailureCode.network);
      await ensureAndTap(tester, boton('Pausar', titulo: 'Oferta activa'));
      expect(
        jobs.calls.where((call) => call.startsWith('fetchCompanyJobs')),
        hasLength(2),
      );

      harness.router.go('/empresa');
      await tester.pumpAndSettle();
      harness.router.go(ruta);
      await tester.pumpAndSettle();

      expect(
        jobs.calls.where((call) => call.startsWith('fetchCompanyJobs')),
        hasLength(3),
      );
      expect(find.text('Oferta activa'), findsOneWidget);
      expect(find.byType(MessageBanner), findsNothing);
    });

    testWidgets('una activa con el vencimiento pasado avisa que no se ve', (
      tester,
    ) async {
      await entrarA(
        tester,
        ruta,
        jobs: FakeJobOffersRepository(
          jobs: [
            testJobOffer(
              title: 'Vencida sin cron',
              status: JobStatus.active,
              expiresAt: testJobNow.subtract(const Duration(days: 1)),
            ),
          ],
        ),
        verification: verificacion(CompanyVerificationStatus.approved),
      );

      expect(
        find.textContaining('ya no se muestra a los candidatos'),
        findsOneWidget,
      );
    });
  });

  // Una recarga automática (tras una acción, tras un guardado del
  // formulario, la que se reintenta sola al volver) que falla no avisa con
  // un SnackBar: no reemplaza lo que la persona está leyendo. Lo dice
  // "Actualizar" y se anuncia una vez al lector. Una que pide la persona con
  // "Actualizar", sí.
  group('recargas automáticas y pedidas', () {
    Future<FakeJobOffersRepository> entrar(WidgetTester tester) async {
      final jobs = unaPorEstado();
      await entrarA(
        tester,
        ruta,
        jobs: jobs,
        verification: verificacion(CompanyVerificationStatus.approved),
      );
      return jobs;
    }

    int lecturas(FakeJobOffersRepository jobs) =>
        jobs.calls.where((call) => call.startsWith('fetchCompanyJobs')).length;

    final enLaBarra = find.descendant(
      of: find.byType(AppBar),
      matching: find.byIcon(Icons.sync_problem),
    );

    testWidgets('si falla la recarga automática que sigue a una acción, '
        'ningún aviso reemplaza el resultado: "Actualizar" dice que la lista '
        'puede no estar al día y se anuncia una sola vez al lector', (
      tester,
    ) async {
      final anuncios = anunciosAlLector(tester);
      final jobs = await entrar(tester);

      jobs.nextFetchFailure = const DataFailure(DataFailureCode.network);
      await ensureAndTap(tester, boton('Pausar', titulo: 'Oferta activa'));

      expect(lecturas(jobs), 2, reason: 'la recarga automática falló');
      expect(find.byType(SnackBar), findsOneWidget);
      expect(enSnackBar(pausada), findsOneWidget);
      expect(avisoListaVieja, findsNothing);
      expect(find.byTooltip(actualizarListaVieja), findsOneWidget);
      expect(enLaBarra, findsOneWidget);
      expect(anuncios, [textoListaVieja]);

      // El resultado se va a su tiempo y no llega nada detrás.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byTooltip(actualizarListaVieja), findsOneWidget);
      expect(anuncios, hasLength(1));
    });

    testWidgets('si falla la recarga que sigue a un guardado del formulario, '
        'el SnackBar del guardado sigue a la vista y lo dice "Actualizar"', (
      tester,
    ) async {
      final anuncios = anunciosAlLector(tester);
      final jobs = unaPorEstado();
      final harness = await entrarA(
        tester,
        ruta,
        jobs: jobs,
        verification: verificacion(CompanyVerificationStatus.approved),
      );
      expect(lecturas(jobs), 1);

      await ensureAndTap(tester, boton('Editar', titulo: 'Oferta activa'));
      expect(harness.location, '/empresa/ofertas/${testJobId(2)}/editar');
      await tester.enterText(
        find.widgetWithText(TextField, 'Puesto'),
        'Oferta activa (turno noche)',
      );
      await soltarFoco(tester);
      jobs.nextFetchFailure = const DataFailure(DataFailureCode.network);
      await ensureAndTap(tester, boton('Guardar cambios'));

      expect(jobs.calls, contains('updateJob:${testJobId(2)}'));
      expect(harness.location, ruta);
      expect(lecturas(jobs), 2, reason: 'la recarga al volver falló');
      // La lista que se ve es la de antes y "Actualizar" lo dice.
      expect(find.text('Oferta activa'), findsOneWidget);
      expect(find.byTooltip(actualizarListaVieja), findsOneWidget);
      // El resultado del guardado no se reemplaza.
      expect(find.byType(SnackBar), findsOneWidget);
      expect(enSnackBar('Cambios guardados.'), findsOneWidget);
      expect(avisoListaVieja, findsNothing);
      expect(anuncios.where((anuncio) => anuncio == textoListaVieja), [
        textoListaVieja,
      ]);
    });

    testWidgets('"Actualizar" que falla avisa con un SnackBar, cada fallo con '
        'uno nuevo, y una recarga pedida que después sale bien lo saca', (
      tester,
    ) async {
      final anuncios = anunciosAlLector(tester);
      final jobs = await entrar(tester);
      final vieja = find.byTooltip(actualizarListaVieja);

      jobs.nextFetchFailure = const DataFailure(DataFailureCode.network);
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(lecturas(jobs), 2);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(avisoListaVieja, findsOneWidget);
      expect(vieja, findsOneWidget);
      final primero = tester.element(find.byType(SnackBar));

      // Otro fallo, con el primero a la vista hace 6 segundos: uno nuevo lo
      // reemplaza y dura sus propios 8 segundos.
      await tester.pump(const Duration(seconds: 6));
      jobs.nextFetchFailure = const DataFailure(DataFailureCode.network);
      await tester.tap(vieja);
      await tester.pumpAndSettle();
      expect(lecturas(jobs), 3);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(avisoListaVieja, findsOneWidget);
      expect(tester.element(find.byType(SnackBar)), isNot(same(primero)));
      await tester.pump(const Duration(seconds: 7));
      expect(
        avisoListaVieja,
        findsOneWidget,
        reason: 'es uno nuevo: el primero ya se habría ido',
      );

      // Sale bien: el aviso se va enseguida, sin esperar sus 8 segundos, y
      // no aparece ningún otro.
      await tester.tap(vieja);
      await tester.pumpAndSettle();
      expect(lecturas(jobs), 4);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byTooltip('Actualizar'), findsOneWidget);
      // Los fallos de "Actualizar" los anuncia su SnackBar (región viva), no
      // un anuncio aparte.
      expect(anuncios, isEmpty);
    });

    // En producción `bootstrap.dart` usa un ProviderScope sin `retry`, y
    // Riverpod reintenta con backoff (unos 38 segundos) todo provider que
    // falla con una `Exception`. `companyJobsProvider` lo apaga para sí: un
    // fallo de la lista se informa enseguida. Este test deja el reintento de
    // producción en el contenedor para probar que la lista no lo hereda (el
    // resto de los tests lo apaga para todos y no lo vería).
    testWidgets('con el reintento de producción, la lista no reintenta sola: '
        'el resultado de una acción aparece enseguida, su recarga fallida se '
        'anuncia sin tapar nada, y un "Actualizar" que falla avisa enseguida', (
      tester,
    ) async {
      final anuncios = anunciosAlLector(tester);
      final jobs = unaPorEstado();
      final harness = await entrarA(
        tester,
        ruta,
        jobs: jobs,
        verification: verificacion(CompanyVerificationStatus.approved),
        riverpodRetry: true,
      );
      expect(lecturas(jobs), 1);
      Future<void> avanzar(Duration total) async {
        const paso = Duration(milliseconds: 100);
        for (var t = Duration.zero; t < total; t += paso) {
          await tester.pump(paso);
        }
      }

      jobs.persistentFetchFailure = const DataFailure(DataFailureCode.network);
      await tester.tap(boton('Pausar', titulo: 'Oferta activa'));
      await avanzar(const Duration(seconds: 1));

      // Sin reintentos: la recarga que sigue a la acción ya falló.
      final fallida = harness.container.read(companyJobsProvider);
      expect(fallida.isLoading, isFalse);
      expect(fallida.retrying, isFalse);
      expect(fallida.hasError, isTrue);
      expect(fallida.hasValue, isTrue);
      expect(lecturas(jobs), 2, reason: 'carga y recarga, ningún reintento');
      // El resultado está a la vista, la tarjeta muestra lo confirmado, y la
      // recarga automática fallida solo se anuncia al lector y en el ícono.
      expect(find.byType(SnackBar), findsOneWidget);
      expect(enSnackBar(pausada), findsOneWidget);
      expect(
        find.descendant(
          of: tarjeta('Oferta activa'),
          matching: find.text('Pausada'),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip(actualizarListaVieja), findsOneWidget);
      expect(anuncios, [textoListaVieja]);

      // "Actualizar" a mano que vuelve a fallar: el aviso aparece enseguida,
      // no después de una ventana de reintentos.
      await tester.tap(find.byTooltip(actualizarListaVieja));
      await avanzar(const Duration(seconds: 1));
      expect(lecturas(jobs), 3);
      expect(enSnackBar(textoListaVieja), findsOneWidget);
      expect(find.byTooltip(actualizarListaVieja), findsOneWidget);
    });

    testWidgets('el aviso de lista vieja no sigue a la persona cuando sale '
        'de "Mis ofertas"', (tester) async {
      final jobs = unaPorEstado();
      final harness = await entrarA(
        tester,
        ruta,
        jobs: jobs,
        verification: verificacion(CompanyVerificationStatus.approved),
      );

      jobs.persistentFetchFailure = const DataFailure(DataFailureCode.network);
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(enSnackBar(textoListaVieja), findsOneWidget);

      harness.router.go('/empresa');
      await tester.pumpAndSettle();
      expect(enSnackBar(textoListaVieja), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('permisos', () {
    testWidgets(
      'empresa sin verificar: aviso persistente, Publicar deshabilitado '
      'con su motivo y acceso a la verificación',
      (tester) async {
        final harness = await entrarA(
          tester,
          ruta,
          jobs: unaPorEstado(),
          verification: verificacion(CompanyVerificationStatus.pending),
        );

        expect(
          find.textContaining('Tu empresa todavía no está verificada'),
          findsOneWidget,
        );
        final publicar = boton('Publicar', titulo: 'Oferta borrador');
        expect(publicar, findsOneWidget);
        expect(habilitado(tester, publicar), isFalse);
        expect(
          habilitado(tester, boton('Reanudar', titulo: 'Oferta pausada')),
          isFalse,
        );
        // Lo que no exige verificación sigue disponible.
        expect(
          habilitado(tester, boton('Pausar', titulo: 'Oferta activa')),
          isTrue,
        );
        expect(
          find.text('Para publicar, tu empresa tiene que estar verificada.'),
          findsWidgets,
        );

        await ensureAndTap(tester, find.text('Ir a la verificación'));
        expect(harness.location, '/empresa/verificacion');
      },
    );

    testWidgets('empresa verificada: sin aviso de verificación', (
      tester,
    ) async {
      await entrarA(
        tester,
        ruta,
        jobs: unaPorEstado(),
        verification: verificacion(CompanyVerificationStatus.approved),
      );

      expect(
        find.textContaining('Tu empresa todavía no está verificada'),
        findsNothing,
      );
      expect(
        habilitado(tester, boton('Publicar', titulo: 'Oferta borrador')),
        isTrue,
      );
    });

    testWidgets('rol viewer: ve las ofertas, ninguna acción y el porqué', (
      tester,
    ) async {
      final jobs = unaPorEstado()..canWrite = false;
      await entrarA(
        tester,
        ruta,
        jobs: jobs,
        verification: verificacion(CompanyVerificationStatus.approved),
      );

      expect(find.text('Oferta activa'), findsOneWidget);
      expect(find.textContaining('Tu rol en la empresa'), findsOneWidget);
      for (final label in [
        'Nueva oferta',
        'Editar',
        'Publicar',
        'Pausar',
        'Reanudar',
        'Cerrar',
        'Descartar borrador',
        'Duplicar',
      ]) {
        expect(boton(label), findsNothing, reason: label);
      }
    });

    testWidgets('si no se puede comprobar el permiso, no hay acciones', (
      tester,
    ) async {
      final jobs = unaPorEstado()
        ..nextCanWriteFailure = const DataFailure(DataFailureCode.network);
      await entrarA(
        tester,
        ruta,
        jobs: jobs,
        verification: verificacion(CompanyVerificationStatus.approved),
      );

      expect(
        find.textContaining('No pudimos comprobar si tu cuenta'),
        findsOneWidget,
      );
      expect(boton('Editar'), findsNothing);

      await ensureAndTap(tester, find.text('Reintentar'));
      expect(boton('Editar', titulo: 'Oferta activa'), findsOneWidget);
    });
  });

  testWidgets('el inicio de la empresa lleva a Mis ofertas', (tester) async {
    final harness = await entrarA(
      tester,
      '/empresa',
      jobs: FakeJobOffersRepository(),
    );

    await ensureAndTap(tester, find.text('Mis ofertas'));
    expect(harness.location, ruta);
  });

  testWidgets('el candidato no entra a Mis ofertas', (tester) async {
    final harness = await entrarA(
      tester,
      ruta,
      role: BusinessRole.candidate,
      jobs: unaPorEstado(),
    );

    expect(harness.location, '/candidato');
    expect(find.text('Oferta activa'), findsNothing);
  });
}
