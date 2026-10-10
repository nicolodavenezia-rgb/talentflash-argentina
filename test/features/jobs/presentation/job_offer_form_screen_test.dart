import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/companies/data/company_access_repository.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_enums.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_validation.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

import '../../../support/fake_job_offers_repository.dart';
import '../../../support/fake_onboarding_repositories.dart';
import '../../../support/gestures.dart';
import 'job_test_helpers.dart';

/// T-030, formulario de oferta: alta, borrador, publicación, edición y
/// duplicado, con la validación de [JobOfferValidation] (espejo de 0032).
///
/// La validación de acá es UX: el servidor vuelve a validar todo
/// (`validate_job_content`, `protect_job_lifecycle`, pgTAP 019).
void main() {
  const nueva = '/empresa/ofertas/nueva';
  String editar(String id) => '/empresa/ofertas/$id/editar';

  Finder campo(String label) => find.widgetWithText(TextField, label);

  TextField textField(WidgetTester tester, String label) =>
      tester.widget<TextField>(campo(label));

  /// Elige en el calendario el día [dia] del mes que muestra al abrirse.
  Future<void> elegirVencimiento(WidgetTester tester, String dia) async {
    await soltarFoco(tester);
    await ensureAndTap(
      tester,
      find.byTooltip('Elegir la fecha de vencimiento'),
    );
    await tester.tap(find.text(dia));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ACEPTAR'));
    await tester.pumpAndSettle();
  }

  Future<void> tocar(WidgetTester tester, String label) async {
    await soltarFoco(tester);
    await ensureAndTap(tester, boton(label));
  }

  /// Completa un alta con lo mínimo que exige un borrador (La Plata, sin
  /// barrio), para poder abrir la vista previa.
  Future<void> completarAlta(WidgetTester tester) async {
    await tester.enterText(campo('Puesto'), 'Bachero/a');
    await tester.enterText(
      campo('Descripción y requisitos'),
      'Lavado de vajilla.',
    );
    await tester.enterText(campo('Sueldo mínimo'), '700000');
    await tester.enterText(campo('Sueldo máximo'), '800000');
    await soltarFoco(tester);
    await selectDropdownOption(
      tester,
      find.text('Modalidad de contratación'),
      'Relación de dependencia',
    );
    await selectDropdownOption(tester, find.text('Jornada'), 'Por turnos');
    await ensureAndTap(tester, find.text('Lunes'));
    await tester.enterText(campo('Horario'), '18 a 24 hs');
    await soltarFoco(tester);
    await selectDropdownOption(
      tester,
      find.text('Modalidad de trabajo'),
      'Presencial',
    );
    await selectDropdownOption(tester, find.text('Provincia'), 'Buenos Aires');
    await selectDropdownOption(tester, find.text('Localidad'), 'La Plata');
    await selectDropdownOption(
      tester,
      find.text('Experiencia requerida'),
      'Sin experiencia',
    );
    await selectDropdownOption(
      tester,
      find.text('Disponibilidad requerida'),
      'Inmediata',
    );
    await elegirVencimiento(tester, '20');
  }

  /// Lo que MUESTRA el desplegable de sector (null = "Sin especificar").
  String? sectorElegido(WidgetTester tester) => tester
      .widget<DropdownButton<String?>>(find.byType(DropdownButton<String?>))
      .value;

  /// Catálogo en el que el sector de las ofertas de prueba se desactivó.
  FakeCatalogRepository sinGastronomia() => FakeCatalogRepository(
    inactiveSectorIds: {FakeCatalogRepository.gastronomiaSectorId},
  );

  const sectorNoDisponible =
      'El sector que tenía la oferta ya no está disponible. Elegí otro o '
      'dejalo sin especificar.';

  group('validación', () {
    testWidgets(
      'guardar un borrador vacío marca cada obligatorio, avisa y lleva el '
      'foco al primero',
      (tester) async {
        final jobs = FakeJobOffersRepository();
        await entrarA(tester, nueva, jobs: jobs);

        await tocar(tester, 'Guardar borrador');

        expect(find.text('Revisá los campos marcados'), findsOneWidget);
        // Puesto, descripción y horario.
        expect(find.text('Completá este campo.'), findsNWidgets(3));
        expect(find.text('Ingresá el monto.'), findsNWidgets(2));
        expect(find.text('Elegí al menos un día.'), findsOneWidget);
        expect(find.text('Elegí la fecha de vencimiento.'), findsOneWidget);
        // Contratación, jornada, modalidad, provincia, localidad,
        // experiencia y disponibilidad.
        expect(find.text('Elegí una opción.'), findsNWidgets(7));
        // El error queda pegado a su campo, no solo en el cartel.
        expect(
          textField(tester, 'Puesto').decoration?.errorText,
          'Completá este campo.',
        );
        expect(textField(tester, 'Puesto').focusNode?.hasFocus, isTrue);
        expect(
          jobs.calls.where((call) => call.startsWith('createJob')),
          isEmpty,
        );
      },
    );

    testWidgets(
      'los días son un grupo con nombre y, tras validar, con su error: el '
      'día que recibe el foco está adentro',
      (tester) async {
        final handle = tester.ensureSemantics();
        await entrarA(tester, nueva, jobs: FakeJobOffersRepository());
        final grupo = find.byKey(const ValueKey('dias-de-trabajo'));

        expect(
          tester.getSemantics(grupo),
          isSemantics(
            label: 'Días de trabajo',
            hint: '',
            validationResult: SemanticsValidationResult.none,
          ),
        );

        await tocar(tester, 'Guardar borrador');

        final nodo = tester.getSemantics(grupo);
        expect(
          nodo,
          isSemantics(
            label: 'Días de trabajo',
            hint: 'Elegí al menos un día.',
            validationResult: SemanticsValidationResult.invalid,
          ),
        );
        // "Lunes" (donde cae el foco del error de días) cuelga del grupo:
        // el lector lo ubica con su nombre y su error.
        var adentro = false;
        for (
          SemanticsNode? actual = tester.getSemantics(find.text('Lunes'));
          actual != null;
          actual = actual.parent
        ) {
          adentro |= identical(actual, nodo);
        }
        expect(adentro, isTrue);
        handle.dispose();
      },
    );

    testWidgets('los errores se corrigen en vivo después del primer intento', (
      tester,
    ) async {
      await entrarA(tester, nueva, jobs: FakeJobOffersRepository());

      await tocar(tester, 'Guardar borrador');
      expect(
        textField(tester, 'Puesto').decoration?.errorText,
        'Completá este campo.',
      );

      await tester.enterText(campo('Puesto'), 'Bachero/a');
      await tester.pumpAndSettle();
      expect(textField(tester, 'Puesto').decoration?.errorText, isNull);
    });

    testWidgets('sueldo: formato, y máximo nunca menor que el mínimo', (
      tester,
    ) async {
      await entrarA(tester, nueva, jobs: FakeJobOffersRepository());

      await tester.enterText(campo('Sueldo mínimo'), '900 mil');
      await tocar(tester, 'Guardar borrador');
      expect(
        textField(tester, 'Sueldo mínimo').decoration?.errorText,
        startsWith('Ingresá solo números'),
      );

      await tester.enterText(campo('Sueldo mínimo'), '900.000');
      await tester.enterText(campo('Sueldo máximo'), '500000');
      await tester.pumpAndSettle();
      expect(textField(tester, 'Sueldo mínimo').decoration?.errorText, isNull);
      expect(
        textField(tester, 'Sueldo máximo').decoration?.errorText,
        'El máximo no puede ser menor que el mínimo.',
      );
    });

    testWidgets('vacantes: entre 1 y 100', (tester) async {
      await entrarA(tester, nueva, jobs: FakeJobOffersRepository());

      await tester.enterText(campo('Cantidad de vacantes'), '150');
      await tocar(tester, 'Guardar borrador');
      expect(
        textField(tester, 'Cantidad de vacantes').decoration?.errorText,
        'Tiene que ser un número entero entre 1 y 100.',
      );
    });

    testWidgets('beneficios: sin vacíos y sin repetidos', (tester) async {
      final base = variante(testJobOffer(), benefits: const ['Propinas']);
      await entrarA(
        tester,
        editar(base.id),
        jobs: FakeJobOffersRepository(jobs: [base]),
      );

      await tocar(tester, 'Agregar');
      expect(
        find.text('Escribí el beneficio antes de agregarlo.'),
        findsOneWidget,
      );

      await tester.enterText(campo('Agregar beneficio'), '  propinas ');
      await tocar(tester, 'Agregar');
      expect(find.text('Ese beneficio ya está en la lista.'), findsOneWidget);

      await tester.enterText(campo('Agregar beneficio'), 'Uniforme');
      await tocar(tester, 'Agregar');
      expect(find.text('Uniforme'), findsOneWidget);
      expect(find.text('2 de 15 beneficios'), findsOneWidget);

      // Quitar uno tiene su propia etiqueta accesible.
      await ensureAndTap(tester, find.byTooltip('Quitar Propinas'));
      expect(find.text('Propinas'), findsNothing);
      expect(find.text('1 de 15 beneficios'), findsOneWidget);
    });

    testWidgets('beneficios: hasta 15, de hasta 60 caracteres', (tester) async {
      final base = variante(
        testJobOffer(),
        benefits: [for (var i = 1; i <= 15; i++) 'Beneficio $i'],
      );
      await entrarA(
        tester,
        editar(base.id),
        jobs: FakeJobOffersRepository(jobs: [base]),
      );

      await tester.enterText(campo('Agregar beneficio'), 'Uno más');
      await tocar(tester, 'Agregar');
      expect(find.text('Podés cargar hasta 15 beneficios.'), findsOneWidget);

      // Más de 60 caracteres no se pueden escribir.
      final largo = List.filled(61, 'a').join();
      await tester.enterText(campo('Agregar beneficio'), largo);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(campo('Agregar beneficio')).controller?.text,
        hasLength(JobOfferValidation.benefitMaxLength),
      );
    });

    testWidgets(
      'puesto, descripción y horario: el tope y el contador cuentan code '
      'points como el servidor, también con un emoji compuesto (ZWJ)',
      (tester) async {
        // 👨‍🍳 se ve como UN carácter pero son 3 code points (hombre, ZWJ,
        // olla): Postgres cuenta 3.
        const chef = '\u{1F468}‍\u{1F373}';
        expect(chef.runes.length, 3);
        await entrarA(tester, nueva, jobs: FakeJobOffersRepository());

        // 110 + 5 × 3 = 125 code points: entran 3 chefs enteros (119), no
        // medio chef ni el cuarto (122).
        await tester.enterText(campo('Puesto'), '${'a' * 110}${chef * 5}');
        await tester.pumpAndSettle();
        expect(
          textField(tester, 'Puesto').controller?.text,
          '${'a' * 110}${chef * 3}',
        );
        expect(find.text('119/120'), findsOneWidget);

        await tester.enterText(campo('Horario'), '${'h' * 198}$chef');
        await tester.pumpAndSettle();
        expect(textField(tester, 'Horario').controller?.text, 'h' * 198);
        expect(find.text('198/200'), findsOneWidget);

        await tester.enterText(
          campo('Descripción y requisitos'),
          '${'d' * 3997}$chef$chef',
        );
        await tester.pumpAndSettle();
        expect(
          textField(tester, 'Descripción y requisitos').controller?.text,
          '${'d' * 3997}$chef',
        );
        expect(find.text('4000/4000'), findsOneWidget);

        // Lo que deja escribir, el validador lo acepta: el contador y el
        // error nunca se contradicen.
        await tocar(tester, 'Guardar borrador');
        for (final label in ['Puesto', 'Horario', 'Descripción y requisitos']) {
          expect(
            textField(tester, label).decoration?.errorText,
            isNull,
            reason: label,
          );
        }
      },
    );

    testWidgets('beneficio: el tope cuenta code points, sin partir un emoji', (
      tester,
    ) async {
      const chef = '\u{1F468}‍\u{1F373}';
      final base = variante(testJobOffer(), benefits: const []);
      final jobs = FakeJobOffersRepository(jobs: [base]);
      await entrarA(tester, editar(base.id), jobs: jobs);

      await tester.enterText(campo('Agregar beneficio'), '${'b' * 58}$chef');
      await tester.pumpAndSettle();
      expect(textField(tester, 'Agregar beneficio').controller?.text, 'b' * 58);

      await tester.enterText(campo('Agregar beneficio'), '${'b' * 57}$chef');
      await tocar(tester, 'Agregar');
      expect(find.text('${'b' * 57}$chef'), findsOneWidget);
      expect(find.text('1 de 15 beneficios'), findsOneWidget);
    });

    testWidgets(
      'el calendario de vencimiento ofrece (hoy, hoy + 60 días] y propone '
      '30 días',
      (tester) async {
        await entrarA(tester, nueva, jobs: FakeJobOffersRepository());

        await soltarFoco(tester);
        await ensureAndTap(
          tester,
          find.byTooltip('Elegir la fecha de vencimiento'),
        );

        final local = testJobNow.toLocal();
        final dialog = tester.widget<DatePickerDialog>(
          find.byType(DatePickerDialog),
        );
        expect(
          dialog.firstDate,
          DateTime(local.year, local.month, local.day + 1),
        );
        expect(
          dialog.lastDate,
          DateTime(local.year, local.month, local.day + 60),
        );
        expect(
          dialog.initialDate,
          DateTime(local.year, local.month, local.day + 30),
        );
      },
    );
  });

  group('borrador y publicación', () {
    testWidgets('completar todo y guardar borrador crea la oferta', (
      tester,
    ) async {
      final jobs = FakeJobOffersRepository();
      final harness = await entrarA(tester, nueva, jobs: jobs);

      await tester.enterText(campo('Puesto'), 'Bachero/a');
      await tester.enterText(
        campo('Descripción y requisitos'),
        'Lavado de vajilla. Se pide experiencia en cocina.',
      );
      await tester.enterText(campo('Sueldo mínimo'), '700.000');
      await tester.enterText(campo('Sueldo máximo'), '800000');
      await soltarFoco(tester);
      await selectDropdownOption(
        tester,
        find.text('Modalidad de contratación'),
        'Relación de dependencia',
      );
      await selectDropdownOption(tester, find.text('Jornada'), 'Por turnos');
      await ensureAndTap(tester, find.text('Viernes'));
      await ensureAndTap(tester, find.text('Lunes'));
      await tester.enterText(campo('Horario'), '18 a 24 hs');
      await soltarFoco(tester);
      await selectDropdownOption(
        tester,
        find.text('Modalidad de trabajo'),
        'Presencial',
      );
      await selectDropdownOption(
        tester,
        find.text('Provincia'),
        'Buenos Aires',
      );
      await selectDropdownOption(tester, find.text('Localidad'), 'La Plata');
      // La Plata no tiene barrios cargados: no se pide barrio.
      expect(find.text('Barrio'), findsNothing);
      await selectDropdownOption(
        tester,
        find.text('Experiencia requerida'),
        'Sin experiencia',
      );
      await selectDropdownOption(
        tester,
        find.text('Disponibilidad requerida'),
        'Inmediata',
      );
      await tester.enterText(campo('Agregar beneficio'), 'Comida incluida');
      await tocar(tester, 'Agregar');
      await elegirVencimiento(tester, '20');

      await tocar(tester, 'Guardar borrador');

      expect(jobs.calls, contains('createJob:draft'));
      expect(jobs.lastCompanyId, testJobCompanyId);
      final input = jobs.lastInput!;
      expect(input.title, 'Bachero/a');
      expect(input.salaryMin, 700000);
      expect(input.salaryMax, 800000);
      expect(input.salaryPeriod, SalaryPeriod.mensual);
      expect(input.contractType, ContractType.relacionDependencia);
      expect(input.jornada, JornadaType.porTurnos);
      // Los días viajan en el orden de la semana, no en el del toque.
      expect(input.scheduleDays, [WeekDay.lun, WeekDay.vie]);
      expect(input.scheduleDetail, '18 a 24 hs');
      expect(input.workMode, JobWorkMode.presencial);
      expect(input.provinciaId, FakeCatalogRepository.baProvinceId);
      expect(input.localidadId, FakeCatalogRepository.laPlataLocalityId);
      expect(input.barrioId, isNull);
      expect(input.sectorId, isNull);
      expect(input.experience, ExperienceLevel.sinExperiencia);
      expect(input.availability, JobAvailability.inmediata);
      expect(input.benefits, ['Comida incluida']);
      expect(input.vacancies, 1);
      final vence = input.expiresAt!.toLocal();
      expect([vence.year, vence.month, vence.day], [2026, 11, 20]);
      expect(vence.hour, 23, reason: 'vence al final del día elegido');

      expect(harness.location, '/empresa/ofertas');
      expect(find.text('Borrador guardado.'), findsOneWidget);
      expect(find.text('Bachero/a'), findsOneWidget);
    });

    testWidgets(
      'un borrador incompleto para publicar se guarda igual como borrador',
      (tester) async {
        final base = variante(
          testJobOffer(
            salaryMin: 0,
            expiresAt: testJobNow.add(const Duration(days: 90)),
          ),
          barrioId: () => null,
        );
        final jobs = FakeJobOffersRepository(jobs: [base]);
        await entrarA(
          tester,
          editar(base.id),
          jobs: jobs,
          verification: verificacion(CompanyVerificationStatus.approved),
        );

        await tocar(tester, 'Guardar borrador');

        expect(jobs.calls, contains('updateJob:${base.id}'));
        expect(jobs.lastPublish, isFalse);
      },
    );

    testWidgets(
      'publicar exige sueldo mayor que 0, la ventana de 60 días y el barrio '
      'en una localidad con barrios',
      (tester) async {
        final base = variante(
          testJobOffer(
            salaryMin: 0,
            expiresAt: testJobNow.add(const Duration(days: 90)),
          ),
          barrioId: () => null,
        );
        final jobs = FakeJobOffersRepository(jobs: [base]);
        final harness = await entrarA(
          tester,
          editar(base.id),
          jobs: jobs,
          verification: verificacion(CompanyVerificationStatus.approved),
        );

        await tocar(tester, 'Publicar');

        expect(
          find.text(
            'Para publicar, el sueldo mínimo tiene que ser mayor que 0.',
          ),
          findsOneWidget,
        );
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
        expect(
          jobs.calls.where((call) => call.startsWith('updateJob')),
          isEmpty,
        );

        await tester.enterText(campo('Sueldo mínimo'), '900000');
        await soltarFoco(tester);
        await selectDropdownOption(tester, find.text('Barrio'), 'Palermo');
        await elegirVencimiento(tester, '20');
        await tocar(tester, 'Publicar');

        expect(jobs.calls, contains('updateJob:${base.id}:publish'));
        expect(jobs.lastInput?.barrioId, FakeCatalogRepository.palermoId);
        expect(jobs.lastInput?.salaryMin, 900000);
        expect(harness.location, '/empresa/ofertas');
        expect(find.text('Oferta publicada.'), findsOneWidget);
      },
    );

    testWidgets('en una localidad sin barrios no se pide barrio al publicar', (
      tester,
    ) async {
      final base = variante(
        testJobOffer(),
        provinciaId: FakeCatalogRepository.baProvinceId,
        localidadId: FakeCatalogRepository.laPlataLocalityId,
        barrioId: () => null,
      );
      final jobs = FakeJobOffersRepository(jobs: [base]);
      await entrarA(
        tester,
        editar(base.id),
        jobs: jobs,
        verification: verificacion(CompanyVerificationStatus.approved),
      );

      expect(find.text('Barrio'), findsNothing);
      await tocar(tester, 'Publicar');

      expect(jobs.calls, contains('updateJob:${base.id}:publish'));
      expect(jobs.lastInput?.barrioId, isNull);
    });

    testWidgets('empresa sin verificar: Publicar deshabilitado con su motivo', (
      tester,
    ) async {
      await entrarA(
        tester,
        nueva,
        jobs: FakeJobOffersRepository(),
        verification: verificacion(CompanyVerificationStatus.pending),
      );

      expect(habilitado(tester, boton('Publicar')), isFalse);
      expect(habilitado(tester, boton('Guardar borrador')), isTrue);
      expect(
        find.textContaining('Vas a poder publicar cuando verifiquemos'),
        findsOneWidget,
      );
    });

    testWidgets('un rechazo del servidor se explica arriba del formulario', (
      tester,
    ) async {
      final base = testJobOffer();
      final jobs = FakeJobOffersRepository(jobs: [base])
        ..nextUpdateFailure = const DataFailure(DataFailureCode.notAllowed);
      final harness = await entrarA(tester, editar(base.id), jobs: jobs);

      await tocar(tester, 'Guardar borrador');

      expect(find.text('No pudimos completar la acción'), findsOneWidget);
      expect(
        find.textContaining('Tu cuenta no puede hacer esta acción'),
        findsOneWidget,
      );
      expect(harness.location, editar(base.id));
    });
  });

  group('edición', () {
    testWidgets('una activa guarda cambios sin cambiar de estado', (
      tester,
    ) async {
      final base = testJobOffer(status: JobStatus.active);
      final jobs = FakeJobOffersRepository(jobs: [base]);
      final harness = await entrarA(
        tester,
        editar(base.id),
        jobs: jobs,
        verification: verificacion(CompanyVerificationStatus.approved),
      );

      expect(textField(tester, 'Puesto').controller?.text, base.title);
      expect(boton('Publicar'), findsNothing);
      expect(boton('Guardar borrador'), findsNothing);

      await tester.enterText(campo('Puesto'), 'Mozo/a de salón (turno noche)');
      await tocar(tester, 'Guardar cambios');

      expect(jobs.calls, contains('updateJob:${base.id}'));
      expect(jobs.lastPublish, isFalse);
      expect(jobs.lastInput?.title, 'Mozo/a de salón (turno noche)');
      expect(harness.location, '/empresa/ofertas');
      expect(find.text('Cambios guardados.'), findsOneWidget);
    });

    testWidgets(
      'un sector que ya no está activo se quita: lo que se ve es lo que se '
      'guarda',
      (tester) async {
        final base = testJobOffer(status: JobStatus.active);
        final jobs = FakeJobOffersRepository(jobs: [base]);
        await entrarA(
          tester,
          editar(base.id),
          jobs: jobs,
          verification: verificacion(CompanyVerificationStatus.approved),
          catalog: sinGastronomia(),
        );

        expect(sectorElegido(tester), isNull);
        expect(find.text(sectorNoDisponible), findsOneWidget);

        await tester.enterText(campo('Puesto'), 'Mozo/a de salón (noche)');
        await tocar(tester, 'Guardar cambios');

        expect(jobs.calls, contains('updateJob:${base.id}'));
        expect(jobs.lastInput?.sectorId, isNull);
      },
    );

    testWidgets(
      'que el formulario quite un sector inactivo no cuenta como un cambio '
      'sin guardar',
      (tester) async {
        final base = testJobOffer();
        final harness = await entrarA(
          tester,
          editar(base.id),
          jobs: FakeJobOffersRepository(jobs: [base]),
          catalog: sinGastronomia(),
        );
        expect(sectorElegido(tester), isNull);

        await ensureAndTap(tester, find.byType(BackButton));
        expect(find.text('¿Salir sin guardar?'), findsNothing);
        expect(harness.location, '/empresa/ofertas');
      },
    );

    testWidgets('elegir otro sector saca la explicación', (tester) async {
      final base = testJobOffer();
      final jobs = FakeJobOffersRepository(jobs: [base]);
      await entrarA(
        tester,
        editar(base.id),
        jobs: jobs,
        catalog: sinGastronomia(),
      );

      await soltarFoco(tester);
      await selectDropdownOption(
        tester,
        find.text('Sector o rubro (opcional)'),
        'Comercio',
      );
      expect(sectorElegido(tester), FakeCatalogRepository.comercioSectorId);
      expect(find.text(sectorNoDisponible), findsNothing);

      await tocar(tester, 'Guardar borrador');
      expect(jobs.lastInput?.sectorId, FakeCatalogRepository.comercioSectorId);
    });

    testWidgets('una activa de una empresa sin verificar no se modifica', (
      tester,
    ) async {
      final base = testJobOffer(status: JobStatus.active);
      await entrarA(
        tester,
        editar(base.id),
        jobs: FakeJobOffersRepository(jobs: [base]),
        verification: verificacion(CompanyVerificationStatus.pending),
      );

      expect(habilitado(tester, boton('Guardar cambios')), isFalse);
      expect(
        find.textContaining('Para modificar una oferta publicada'),
        findsOneWidget,
      );
    });

    testWidgets('una cerrada no se edita: se ofrece duplicarla', (
      tester,
    ) async {
      final base = testJobOffer(status: JobStatus.closed);
      final harness = await entrarA(
        tester,
        editar(base.id),
        jobs: FakeJobOffersRepository(jobs: [base]),
      );

      expect(find.text('Esta oferta ya no se puede editar'), findsOneWidget);
      expect(campo('Puesto'), findsNothing);

      await ensureAndTap(tester, boton('Duplicar'));
      expect(harness.location, '$nueva?duplicar=${base.id}');
    });

    testWidgets('la oferta de otra empresa no se abre', (tester) async {
      final ajena = testJobOffer(
        companyId: 'c0000000-0000-4000-8000-000000000999',
        status: JobStatus.active,
      );
      await entrarA(
        tester,
        editar(ajena.id),
        jobs: FakeJobOffersRepository(jobs: [ajena]),
      );

      expect(find.text('No encontramos esa oferta'), findsOneWidget);
      expect(campo('Puesto'), findsNothing);
    });

    testWidgets('un id malformado ni siquiera se pide al servidor', (
      tester,
    ) async {
      final jobs = FakeJobOffersRepository();
      await entrarA(tester, editar('no-es-un-uuid'), jobs: jobs);

      expect(find.text('No encontramos esa oferta'), findsOneWidget);
      expect(jobs.calls.where((call) => call.startsWith('fetchJob')), isEmpty);
    });

    testWidgets('si no se puede comprobar el permiso, explica y reintenta', (
      tester,
    ) async {
      final jobs = FakeJobOffersRepository()
        ..nextCanWriteFailure = const DataFailure(DataFailureCode.network);
      await entrarA(tester, nueva, jobs: jobs);

      expect(
        find.text('No pudimos conectarnos. Revisá tu conexión y reintentá.'),
        findsOneWidget,
      );
      expect(campo('Puesto'), findsNothing);

      await ensureAndTap(tester, find.text('Reintentar'));
      expect(campo('Puesto'), findsOneWidget);
    });

    testWidgets('el rol viewer no ve el formulario', (tester) async {
      final jobs = FakeJobOffersRepository()..canWrite = false;
      await entrarA(tester, nueva, jobs: jobs);

      expect(find.textContaining('Tu rol en la empresa'), findsOneWidget);
      expect(campo('Puesto'), findsNothing);
    });
  });

  group('duplicar', () {
    testWidgets('precarga todo salvo el vencimiento y crea una oferta NUEVA', (
      tester,
    ) async {
      final original = testJobOffer(status: JobStatus.closed);
      final jobs = FakeJobOffersRepository(jobs: [original]);
      await entrarA(
        tester,
        '$nueva?duplicar=${original.id}',
        jobs: jobs,
        verification: verificacion(CompanyVerificationStatus.approved),
      );

      expect(find.textContaining('Copiamos el contenido'), findsOneWidget);
      expect(textField(tester, 'Puesto').controller?.text, original.title);
      expect(textField(tester, 'Sueldo mínimo').controller?.text, '900000');
      expect(find.text('Comida incluida'), findsOneWidget);
      expect(
        textField(tester, 'Fecha de vencimiento').controller?.text,
        isEmpty,
      );
      // Con el sector activo, se copia y se ve.
      expect(sectorElegido(tester), FakeCatalogRepository.gastronomiaSectorId);
      expect(find.textContaining('ya no está disponible'), findsNothing);

      await tocar(tester, 'Publicar');
      expect(find.text('Elegí la fecha de vencimiento.'), findsOneWidget);
      expect(jobs.calls.where((call) => call.startsWith('createJob')), isEmpty);

      await elegirVencimiento(tester, '20');
      await tocar(tester, 'Publicar');

      expect(jobs.calls, contains('createJob:active'));
      expect(
        jobs.calls.where((call) => call.startsWith('updateJob')),
        isEmpty,
        reason: 'duplicar nunca reescribe la original',
      );
      expect(jobs.lastInput?.title, original.title);
      expect(jobs.lastInput?.benefits, original.benefits);
      expect(
        jobs.lastInput?.sectorId,
        FakeCatalogRepository.gastronomiaSectorId,
      );
      expect(jobs.jobs, hasLength(2));
    });

    testWidgets(
      'un sector que ya no está activo no viaja escondido: el desplegable '
      'dice "Sin especificar", lo explica y el alta sale sin sector',
      (tester) async {
        final original = testJobOffer(status: JobStatus.closed);
        final jobs = FakeJobOffersRepository(jobs: [original]);
        await entrarA(
          tester,
          '$nueva?duplicar=${original.id}',
          jobs: jobs,
          verification: verificacion(CompanyVerificationStatus.approved),
          catalog: sinGastronomia(),
        );

        expect(sectorElegido(tester), isNull);
        expect(find.text(sectorNoDisponible), findsOneWidget);

        await elegirVencimiento(tester, '20');
        await tocar(tester, 'Publicar');

        expect(jobs.calls, contains('createJob:active'));
        expect(jobs.lastInput?.sectorId, isNull);
      },
    );
  });

  group('vista previa', () {
    testWidgets('muestra la oferta como la verá el candidato', (tester) async {
      final base = variante(testJobOffer(), company: () => testJobCompany);
      await entrarA(
        tester,
        editar(base.id),
        jobs: FakeJobOffersRepository(jobs: [base]),
        verification: verificacion(CompanyVerificationStatus.approved),
      );

      await tocar(tester, 'Vista previa');

      expect(find.text('Así va a ver la oferta un candidato.'), findsOneWidget);
      expect(find.text('Parrilla de Prueba'), findsOneWidget);
      expect(find.text('Empresa verificada'), findsOneWidget);
      expect(find.text('ARS 900.000 a 1.100.000 por mes'), findsOneWidget);
      expect(
        find.text('Palermo, Ciudad Autónoma de Buenos Aires'),
        findsOneWidget,
      );
      expect(find.text('Jueves, Viernes, Sábado'), findsOneWidget);
      // Ningún botón falso: ni postularse ni compartir.
      expect(find.textContaining('Postular'), findsNothing);
      expect(find.textContaining('Compartir'), findsNothing);

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.text('Así va a ver la oferta un candidato.'), findsNothing);
    });

    testWidgets('en un alta muestra el nombre real de la empresa', (
      tester,
    ) async {
      final jobs = FakeJobOffersRepository(
        companySummary: const JobOfferCompany(
          name: 'Bodegón Nuevo SRL',
          verificationStatus: CompanyVerificationStatus.approved,
        ),
      );
      await entrarA(
        tester,
        nueva,
        jobs: jobs,
        verification: verificacion(CompanyVerificationStatus.approved),
      );
      await completarAlta(tester);

      await tocar(tester, 'Vista previa');

      expect(find.text('Así va a ver la oferta un candidato.'), findsOneWidget);
      expect(find.text('Bodegón Nuevo SRL'), findsOneWidget);
      expect(find.text('Tu empresa'), findsNothing);
      expect(find.text('Empresa verificada'), findsOneWidget);
      expect(jobs.calls, contains('fetchCompanySummary:$testJobCompanyId'));
    });

    testWidgets('en un duplicado muestra la empresa de la oferta original', (
      tester,
    ) async {
      final original = variante(
        testJobOffer(status: JobStatus.closed),
        company: () => const JobOfferCompany(
          name: 'Parrilla Original',
          verificationStatus: CompanyVerificationStatus.approved,
        ),
      );
      await entrarA(
        tester,
        '$nueva?duplicar=${original.id}',
        jobs: FakeJobOffersRepository(jobs: [original]),
        verification: verificacion(CompanyVerificationStatus.approved),
      );
      await elegirVencimiento(tester, '20');

      await tocar(tester, 'Vista previa');

      expect(find.text('Parrilla Original'), findsOneWidget);
      expect(find.text('Tu empresa'), findsNothing);
    });

    testWidgets('si no se puede leer la empresa, sigue con un nombre '
        'provisorio', (tester) async {
      final jobs = FakeJobOffersRepository()
        ..nextCompanySummaryFailure = const DataFailure(
          DataFailureCode.network,
        );
      await entrarA(tester, nueva, jobs: jobs);
      await completarAlta(tester);

      await tocar(tester, 'Vista previa');

      expect(find.text('Así va a ver la oferta un candidato.'), findsOneWidget);
      expect(find.text('Tu empresa'), findsOneWidget);
    });

    testWidgets('con obligatorios vacíos no abre y marca los errores', (
      tester,
    ) async {
      await entrarA(tester, nueva, jobs: FakeJobOffersRepository());

      await tocar(tester, 'Vista previa');

      expect(find.text('Así va a ver la oferta un candidato.'), findsNothing);
      expect(find.text('Revisá los campos marcados'), findsOneWidget);
    });
  });

  group('salir sin guardar', () {
    testWidgets('con cambios pide confirmación', (tester) async {
      final harness = await entrarA(
        tester,
        nueva,
        jobs: FakeJobOffersRepository(),
      );

      await tester.enterText(campo('Puesto'), 'Cambio sin guardar');
      await soltarFoco(tester);
      await ensureAndTap(tester, find.byType(BackButton));
      expect(find.text('¿Salir sin guardar?'), findsOneWidget);
      await ensureAndTap(tester, find.text('Seguir editando'));
      expect(harness.location, nueva);

      await ensureAndTap(tester, find.byType(BackButton));
      await ensureAndTap(tester, find.text('Salir sin guardar'));
      expect(harness.location, '/empresa/ofertas');
    });

    testWidgets('sin cambios sale directo', (tester) async {
      final base = testJobOffer();
      final harness = await entrarA(
        tester,
        editar(base.id),
        jobs: FakeJobOffersRepository(jobs: [base]),
      );

      await ensureAndTap(tester, find.byType(BackButton));
      expect(find.text('¿Salir sin guardar?'), findsNothing);
      expect(harness.location, '/empresa/ofertas');
    });
  });
}
