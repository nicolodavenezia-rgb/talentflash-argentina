import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/companies/data/company_access_repository.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_enums.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

import '../../../support/fake_job_offers_repository.dart';
import '../../../support/gestures.dart';
import 'job_test_helpers.dart';

/// T-030, pasada de accesibilidad automatizable del checklist WCAG AA de
/// CONTRIBUTING.md sobre las cuatro pantallas de ofertas:
/// - objetivos táctiles de 48 dp, todo lo tocable con etiqueta y contraste
///   del texto;
/// - texto al 200 % en un teléfono de 360 dp: se recorre el árbol de render y
///   ningún párrafo visible puede quedar cortado (pasado de su máximo de
///   líneas, recortado o desvanecido), también con los errores del
///   formulario a la vista;
/// - teclado: Tab recorre el formulario en el orden visual, las acciones de
///   "Mis ofertas" y del feed se alcanzan con Tab y se activan con Enter o
///   Espacio, y "Actualizar" no pierde el foco mientras recarga.
/// El lector de pantalla (nodos, encabezados, etiquetas, regiones vivas) se
/// prueba en los tests de cada pantalla.
///
/// El 200 % se mide con Roboto, la fuente de Material que usan Android y la
/// Web, cargada del SDK de Flutter: la fuente propia de los tests dibuja cada
/// letra como un cuadrado de 1 em, más del doble de ancha que cualquier
/// fuente real, y marcaría cortes que ningún usuario ve.
///
/// Excepción, explícita y acotada: el rótulo de un campo de Material
/// (`labelText`) y el título de la barra superior se dibujan por diseño en
/// UNA línea (la barra además limita su texto a 1,34x). Al 200 % en 360 dp
/// los rótulos más largos del formulario ("Disponibilidad requerida",
/// "Modalidad de contratación"…) terminan en "…". Resolverlo es una decisión
/// de diseño (rótulos arriba del campo o más cortos) que queda pendiente; el
/// resto —contenido, errores, ayudas, ejemplos, contadores, botones y
/// avisos— no se puede cortar.
void main() {
  /// Beneficio del largo máximo (60 caracteres): no puede cortarse en ningún
  /// lado.
  const beneficioLargo =
      'Beneficio de sesenta caracteres justos, para ver si entra ok';
  assert(beneficioLargo.length == 60, 'tiene que medir el máximo');

  FakeJobOffersRepository ofertas() => FakeJobOffersRepository(
    jobs: [
      testJobOffer(id: testJobId(1), title: 'Oferta borrador'),
      variante(
        testJobOffer(
          id: testJobId(2),
          title: 'Oferta activa',
          status: JobStatus.active,
          company: testJobCompany,
        ),
        benefits: ['Comida incluida', beneficioLargo],
      ),
      testJobOffer(
        id: testJobId(3),
        title: 'Oferta pausada',
        status: JobStatus.paused,
      ),
    ],
    feed: [
      for (var n = 1; n <= 3; n++)
        testJobOffer(
          id: testJobId(10 + n),
          title: 'Publicada $n',
          status: JobStatus.active,
          company: testJobCompany,
        ),
    ],
  );

  const pantallas = <(String, BusinessRole)>[
    ('/empresa/ofertas', BusinessRole.company),
    ('/empresa/ofertas/nueva', BusinessRole.company),
    ('/candidato/feed', BusinessRole.candidate),
    (
      '/candidato/ofertas/95000000-0000-4000-8000-000000000002',
      BusinessRole.candidate,
    ),
  ];

  /// Texto al 200 % en un teléfono de 360 dp.
  Future<void> alDoble(WidgetTester tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  const telefono = Size(360, 8000);

  // El orden de los grupos importa: la guía de contraste de flutter_test mide
  // píxeles y, con los bordes suavizados de una fuente real, informa
  // contrastes que no existen. Por eso se corre con la fuente de los tests,
  // ANTES del grupo de 200 %, que carga Roboto para el resto del archivo.
  group('objetivos táctiles, etiquetas y contraste', () {
    for (final (ruta, role) in pantallas) {
      testWidgets(ruta, (tester) async {
        expect(
          _robotoCargada,
          isFalse,
          reason: 'el contraste se mide con la fuente de los tests',
        );
        final handle = tester.ensureSemantics();
        await entrarA(
          tester,
          ruta,
          role: role,
          jobs: ofertas(),
          verification: verificacion(CompanyVerificationStatus.approved),
          surface: const Size(800, 2400),
        );

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  });

  group('texto al 200 % en un teléfono sin cortes ni desbordes', () {
    setUpAll(_cargarRoboto);

    for (final (ruta, role) in pantallas) {
      testWidgets(ruta, (tester) async {
        await alDoble(tester);
        await entrarA(
          tester,
          ruta,
          role: role,
          jobs: ofertas(),
          verification: verificacion(CompanyVerificationStatus.pending),
          surface: telefono,
        );

        expect(tester.takeException(), isNull);
        expect(textosCortados(tester), isEmpty);
      });
    }

    // El aviso de lista vieja ya no es un cartel fijo entre la barra y la
    // lista (le quitaba lugar y corría la tarjeta que se acababa de tocar):
    // es un SnackBar, y lo que queda es el ícono de "Actualizar". Con texto
    // grande, el SnackBar se lee entero y la lista no pierde lugar.
    for (final pantalla in const [Size(360, 640), Size(640, 360)]) {
      testWidgets('Mis ofertas con el aviso de lista vieja en '
          '${pantalla.width.toInt()}×${pantalla.height.toInt()}', (
        tester,
      ) async {
        await alDoble(tester);
        final jobs = ofertas();
        await entrarA(
          tester,
          '/empresa/ofertas',
          jobs: jobs,
          verification: verificacion(CompanyVerificationStatus.approved),
          surface: pantalla,
        );
        final lista = tester.getRect(find.byType(ListView));
        jobs.nextFetchFailure = const DataFailure(DataFailureCode.network);
        await tester.tap(find.byTooltip('Actualizar'));
        await tester.pumpAndSettle();

        final aviso = find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(
            'La lista no se actualizó y puede no estar al día: tocá '
            '"Actualizar" arriba para reintentar.',
          ),
        );
        expect(aviso, findsOneWidget);
        expect(tester.getRect(aviso).top, greaterThanOrEqualTo(0));
        expect(
          tester.getRect(aviso).bottom,
          lessThanOrEqualTo(pantalla.height),
        );
        expect(tester.takeException(), isNull);
        expect(textosCortados(tester), isEmpty);
        // La lista no cambió de lugar ni de tamaño.
        expect(tester.getRect(find.byType(ListView)), lista);
        expect(
          find.byTooltip('Actualizar: la lista puede no estar al día'),
          findsOneWidget,
        );

        // Adaptado: antes, tras una acción cuya recarga fallaba, el aviso iba
        // en el mismo SnackBar que el resultado (el más largo de la
        // pantalla), y por eso el resultado esperaba a la recarga. Ahora el
        // resultado va solo, apenas termina la acción, y el fallo de esa
        // recarga automática no se avisa con un SnackBar: el más largo
        // vuelve a ser el aviso de "Actualizar" de arriba. Se sigue pidiendo
        // que el resultado se lea entero y a la vista.
        await tester.pump(const Duration(seconds: 8));
        await tester.pumpAndSettle();
        jobs.nextFetchFailure = const DataFailure(DataFailureCode.network);
        // La lista es perezosa: la tarjeta recién existe al bajar.
        await tester.scrollUntilVisible(
          find.text('Oferta activa'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await ensureAndTap(tester, boton('Pausar', titulo: 'Oferta activa'));
        final resultado = find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Oferta pausada: los candidatos ya no la ven.'),
        );
        expect(resultado, findsOneWidget);
        expect(aviso, findsNothing);
        expect(tester.getRect(resultado).top, greaterThanOrEqualTo(0));
        expect(
          tester.getRect(resultado).bottom,
          lessThanOrEqualTo(pantalla.height),
        );
        expect(
          find.byTooltip('Actualizar: la lista puede no estar al día'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        expect(textosCortados(tester), isEmpty);
      });
    }

    testWidgets('formulario con los errores de un borrador vacío', (
      tester,
    ) async {
      await alDoble(tester);
      await entrarA(
        tester,
        '/empresa/ofertas/nueva',
        jobs: ofertas(),
        verification: verificacion(CompanyVerificationStatus.pending),
        surface: telefono,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Cantidad de vacantes'),
        '150',
      );
      await soltarFoco(tester);
      await ensureAndTap(tester, boton('Guardar borrador'));

      // Los errores están a la vista (y el foco, en el primero).
      expect(find.text('Elegí al menos un día.'), findsOneWidget);
      expect(
        find.text('Tiene que ser un número entero entre 1 y 100.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(textosCortados(tester), isEmpty);
    });

    testWidgets('formulario con los errores de publicación (sueldo, 60 días y '
        'barrio) y valores elegidos largos', (tester) async {
      await alDoble(tester);
      final borrador = variante(
        testJobOffer(
          id: testJobId(9),
          salaryMin: 0,
          expiresAt: testJobNow.add(const Duration(days: 90)),
        ),
        barrioId: () => null,
        benefits: [beneficioLargo],
      );
      await entrarA(
        tester,
        '/empresa/ofertas/${borrador.id}/editar',
        jobs: FakeJobOffersRepository(jobs: [borrador]),
        verification: verificacion(CompanyVerificationStatus.approved),
        surface: telefono,
      );

      await soltarFoco(tester);
      await ensureAndTap(tester, boton('Publicar'));

      expect(
        find.text(
          'Elegí el barrio: es obligatorio para publicar en esta localidad.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Para publicar, el vencimiento puede estar como máximo a 60 días '
          'de hoy.',
        ),
        findsOneWidget,
      );
      expect(find.text(beneficioLargo), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(textosCortados(tester), isEmpty);
    });
  });

  group('teclado', () {
    testWidgets('Tab recorre el formulario en el orden en que se ve', (
      tester,
    ) async {
      final base = testJobOffer();
      await entrarA(
        tester,
        '/empresa/ofertas/${base.id}/editar',
        jobs: FakeJobOffersRepository(jobs: [base]),
        verification: verificacion(CompanyVerificationStatus.approved),
      );

      await tester.tap(find.widgetWithText(TextField, 'Puesto'));
      await tester.pumpAndSettle();
      final recorrido = <String>[enfocado()];
      for (var i = 0; i < 80 && recorrido.last != 'Publicar'; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        recorrido.add(enfocado());
      }

      const ordenVisual = [
        'Puesto',
        'Descripción y requisitos',
        'Sueldo mínimo',
        'Sueldo máximo',
        'Período del sueldo',
        'Modalidad de contratación',
        'Jornada',
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
        'Domingo',
        'Horario',
        'Modalidad de trabajo',
        'Provincia',
        'Localidad',
        'Barrio',
        'Sector o rubro (opcional)',
        'Experiencia requerida',
        'Disponibilidad requerida',
        'Agregar beneficio',
        'Agregar',
        'Quitar Comida incluida',
        'Quitar Propinas',
        'Cantidad de vacantes',
        'Fecha de vencimiento',
        'Elegir la fecha de vencimiento',
        'Vista previa',
        'Guardar borrador',
        'Publicar',
      ];
      expect(
        recorrido.where(ordenVisual.contains).toList(),
        ordenVisual,
        reason: 'recorrido completo: $recorrido',
      );
    });

    testWidgets('en Mis ofertas cada acción se alcanza con Tab y se activa '
        'con Enter o Espacio', (tester) async {
      final jobs = FakeJobOffersRepository(
        jobs: [
          testJobOffer(id: testJobId(1), title: 'Oferta borrador'),
          testJobOffer(
            id: testJobId(2),
            title: 'Oferta activa',
            status: JobStatus.active,
          ),
        ],
      );
      await entrarA(
        tester,
        '/empresa/ofertas',
        jobs: jobs,
        verification: verificacion(CompanyVerificationStatus.approved),
      );

      await tabHasta(tester, (foco) => foco == 'Pausar');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(jobs.calls, contains('changeStatus:${testJobId(2)}:paused'));
      expect(
        find.text('Oferta pausada: los candidatos ya no la ven.'),
        findsOneWidget,
      );

      await tabHasta(tester, (foco) => foco == 'Publicar');
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(jobs.calls, contains('changeStatus:${testJobId(1)}:active'));
      expect(find.text('Oferta publicada.'), findsOneWidget);
    });

    testWidgets('en el feed las tarjetas y "Cargar más" se alcanzan con Tab '
        'y se activan con Espacio o Enter', (tester) async {
      final feed = [
        for (var n = 1; n <= 25; n++)
          testJobOffer(
            id: testJobId(n),
            title: 'Oferta $n',
            status: JobStatus.active,
            company: testJobCompany,
          ),
      ];
      final jobs = FakeJobOffersRepository(jobs: feed, feed: feed);
      final harness = await entrarA(
        tester,
        '/candidato/feed',
        role: BusinessRole.candidate,
        jobs: jobs,
        surface: const Size(1000, 9000),
      );

      await tabHasta(tester, (foco) => foco == 'Cargar más ofertas');
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('Mostrando 25 ofertas'), findsOneWidget);

      await tabHasta(tester, (foco) => foco.startsWith('Oferta 3 '));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(harness.location, '/candidato/ofertas/${testJobId(3)}');
    });

    testWidgets('en el feed, Enter en "Actualizar" deja el foco ahí mientras '
        'recarga y aunque falle: un segundo Enter no saca del feed', (
      tester,
    ) async {
      final feed = [
        for (var n = 1; n <= 3; n++)
          testJobOffer(
            id: testJobId(n),
            title: 'Oferta $n',
            status: JobStatus.active,
            company: testJobCompany,
          ),
      ];
      final jobs = FakeJobOffersRepository(jobs: feed, feed: feed);
      final harness = await entrarA(
        tester,
        '/candidato/feed',
        role: BusinessRole.candidate,
        jobs: jobs,
      );
      int lecturas() => jobs.calls
          .where((call) => call == 'fetchActiveJobsPage:inicio')
          .length;

      await tabHasta(tester, (foco) => foco == 'Actualizar');
      final pendiente = Completer<void>();
      jobs
        ..pendingFeed = pendiente
        ..nextFeedFailure = const DataFailure(DataFailureCode.network);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(enfocado(), 'Actualizando ofertas');

      // Un segundo Enter mientras recarga no hace nada: ni otra lectura ni
      // salir del feed (antes el botón se deshabilitaba, el foco pasaba a
      // "Atrás" y este Enter volvía al inicio).
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(harness.location, '/candidato/feed');
      expect(lecturas(), 2);
      expect(enfocado(), 'Actualizando ofertas');

      pendiente.complete();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Las ofertas no se actualizaron.'),
        findsOneWidget,
      );
      expect(enfocado(), 'Actualizar');

      // Enter de nuevo reintenta, sin salir del feed.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(harness.location, '/candidato/feed');
      expect(lecturas(), 3);
      expect(enfocado(), 'Actualizar');
    });

    // Antes el fallo dejaba un aviso fijo con "Reintentar", que se alcanzaba
    // con Tab. Ahora se reintenta con el mismo "Actualizar", que conserva el
    // foco y cambia de rótulo para decir que la lista puede no estar al día.
    testWidgets('en Mis ofertas, "Actualizar" deja el foco ahí mientras '
        'recarga y aunque falle, dice que la lista puede no estar al día y '
        'un Enter reintenta', (tester) async {
      final jobs = FakeJobOffersRepository(
        jobs: [testJobOffer(id: testJobId(1), title: 'Oferta borrador')],
      );
      final harness = await entrarA(
        tester,
        '/empresa/ofertas',
        jobs: jobs,
        verification: verificacion(CompanyVerificationStatus.approved),
      );
      int lecturas() => jobs.calls
          .where((call) => call.startsWith('fetchCompanyJobs'))
          .length;
      final aviso = find.textContaining('La lista no se actualizó');

      await tabHasta(tester, (foco) => foco == 'Actualizar');
      final pendiente = Completer<void>();
      jobs
        ..pendingCompanyJobs = pendiente
        ..nextFetchFailure = const DataFailure(DataFailureCode.network);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(enfocado(), 'Actualizando tus ofertas');
      // Un segundo Enter mientras recarga no hace nada.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(harness.location, '/empresa/ofertas');
      expect(lecturas(), 2);

      pendiente.complete();
      await tester.pumpAndSettle();
      expect(aviso, findsOneWidget);
      expect(enfocado(), 'Actualizar: la lista puede no estar al día');

      // Enter de nuevo reintenta, sin salir de la pantalla; sale bien.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(lecturas(), 3);
      expect(enfocado(), 'Actualizar');
      expect(harness.location, '/empresa/ofertas');
    });
  });
}

/// Ya se cargó Roboto: desde ahí vale para todo el archivo.
var _robotoCargada = false;

/// Carga Roboto (la fuente de Material) desde el SDK de Flutter con el
/// nombre que usa el tema, así el texto se mide como en un teléfono real.
Future<void> _cargarRoboto() async {
  final raiz = Platform.environment['FLUTTER_ROOT'];
  final candidatas = [
    if (raiz != null) '$raiz/bin/cache/artifacts/material_fonts',
    // `flutter_tester` vive en <sdk>/bin/cache/artifacts/engine/<plataforma>.
    '${File(Platform.resolvedExecutable).parent.parent.parent.path}'
        '/material_fonts',
  ];
  final carpeta = candidatas
      .map(Directory.new)
      .where((dir) => dir.existsSync())
      .firstOrNull;
  if (carpeta == null) {
    fail('No están las fuentes de Material del SDK en $candidatas');
  }
  final fuentes = carpeta.listSync().whereType<File>().where((file) {
    // Sin distinguir mayúsculas: el fonts.zip de Flutter trae
    // `Roboto-Regular.ttf`, pero el SDK de Windows los tiene en minúscula.
    final nombre = file.uri.pathSegments.last.toLowerCase();
    return nombre.startsWith('roboto-') && nombre.endsWith('.ttf');
  }).toList();
  if (fuentes.isEmpty) {
    fail('No hay archivos de Roboto en ${carpeta.path}');
  }
  final loader = FontLoader('Roboto');
  for (final fuente in fuentes) {
    loader.addFont(
      Future.value(ByteData.sublistView(fuente.readAsBytesSync())),
    );
  }
  await loader.load();
  _robotoCargada = true;
}

/// Textos visibles que quedaron cortados: pasados de su máximo de líneas
/// (con o sin "…"), recortados o desvanecidos porque no entran en su caja.
/// Salvo la excepción del encabezado (rótulo de un campo de Material y
/// título de la barra superior).
List<String> textosCortados(WidgetTester tester) {
  final cortados = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final parrafo = element.renderObject;
    if (parrafo is! RenderParagraph ||
        !parrafo.hasSize ||
        _invisible(parrafo) ||
        _exceptuado(element, parrafo.text.toPlainText())) {
      continue;
    }
    final recortado =
        parrafo.textSize.width > parrafo.size.width + 0.5 ||
        parrafo.textSize.height > parrafo.size.height + 0.5;
    if (parrafo.didExceedMaxLines ||
        recortado ||
        parrafo.debugHasOverflowShader) {
      cortados.add(parrafo.text.toPlainText());
    }
  }
  return cortados;
}

/// Dibujado con opacidad 0 (p. ej. el ejemplo de un campo con rótulo).
bool _invisible(RenderObject objeto) {
  for (RenderObject? actual = objeto.parent; actual != null;) {
    if (actual is RenderAnimatedOpacityMixin && actual.opacity.value == 0) {
      return true;
    }
    if (actual is RenderOpacity && actual.opacity == 0) {
      return true;
    }
    actual = actual.parent;
  }
  return false;
}

bool _exceptuado(Element element, String texto) {
  var exceptuado = false;
  element.visitAncestorElements((ancestro) {
    final widget = ancestro.widget;
    if (widget is AppBar) {
      exceptuado = true;
      return false;
    }
    if (widget is InputDecorator) {
      exceptuado = widget.decoration.labelText == texto;
      return false;
    }
    return true;
  });
  return exceptuado;
}

/// El control que tiene el foco, dicho como lo ve la persona: el rótulo del
/// campo, el tooltip del ícono o el texto del botón.
String enfocado() {
  final contexto = FocusManager.instance.primaryFocus?.context;
  if (contexto is! Element) {
    return '';
  }
  final propio = find.byElementPredicate(
    (element) => identical(element, contexto),
  );
  // Un desplegable tiene el campo adentro; un campo de texto, afuera.
  final campoAdentro = find
      .descendant(of: propio, matching: find.byType(InputDecorator))
      .evaluate();
  if (campoAdentro.isNotEmpty) {
    return (campoAdentro.first.widget as InputDecorator).decoration.labelText ??
        '';
  }
  final tooltip = contexto.findAncestorWidgetOfExactType<Tooltip>();
  if (tooltip != null) {
    return tooltip.message ?? '';
  }
  final campoAfuera = contexto.findAncestorWidgetOfExactType<InputDecorator>();
  if (campoAfuera != null) {
    return campoAfuera.decoration.labelText ?? '';
  }
  return find
      .descendant(of: propio, matching: find.byType(Text))
      .evaluate()
      .map((element) => (element.widget as Text).data ?? '')
      .join(' ');
}

/// Aprieta Tab hasta que el foco llega a lo que busca [objetivo]. Que llegue
/// es parte de lo que se prueba: lo que no se alcanza con Tab no se usa con
/// teclado.
Future<void> tabHasta(
  WidgetTester tester,
  bool Function(String foco) objetivo,
) async {
  final recorrido = <String>[];
  for (var i = 0; i < 80; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final foco = enfocado();
    if (objetivo(foco)) {
      return;
    }
    recorrido.add(foco);
  }
  fail('Con Tab no se llega al control buscado. Recorrido: $recorrido');
}
