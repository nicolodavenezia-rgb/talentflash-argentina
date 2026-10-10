import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_enums.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_input.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_validation.dart';

import '../../../support/fake_job_offers_repository.dart';

/// Los límites son los de `private.validate_job_content` (0032): cada regla se
/// prueba en el borde exacto, uno adentro y uno afuera.
void main() {
  final now = testJobNow;

  group('textos', () {
    test('el puesto admite 120 caracteres y no 121', () {
      expect(JobOfferValidation.validateTitle('a' * 120), isNull);
      expect(JobOfferValidation.validateTitle('a' * 121), JobTextIssue.tooLong);
    });

    test('se mide recortado, como lo recibe el servidor', () {
      expect(JobOfferValidation.validateTitle('  ${'a' * 120}  '), isNull);
    });

    test('vacío o solo espacios y saltos de línea es vacío', () {
      expect(JobOfferValidation.validateTitle(''), JobTextIssue.empty);
      expect(JobOfferValidation.validateTitle('  \n\t '), JobTextIssue.empty);
    });

    test('cuenta caracteres y no unidades UTF-16 (como length() de '
        'Postgres)', () {
      // Cada emoji ocupa dos unidades UTF-16 pero es UN carácter.
      expect(JobOfferValidation.validateTitle('🍕' * 120), isNull);
      expect(
        JobOfferValidation.validateTitle('🍕' * 121),
        JobTextIssue.tooLong,
      );
    });

    test('la descripción admite 4000 y no 4001', () {
      expect(JobOfferValidation.validateDescription('d' * 4000), isNull);
      expect(
        JobOfferValidation.validateDescription('d' * 4001),
        JobTextIssue.tooLong,
      );
      expect(JobOfferValidation.validateDescription(' '), JobTextIssue.empty);
    });

    test('recorta con String.trim(), el mismo conjunto de espacios que el '
        'servidor: solo tabs y saltos de línea es vacío', () {
      for (final soloEspacios in ['\t', '\n', '\r\n', '\t\n \t', ' ']) {
        expect(
          JobOfferValidation.validateTitle(soloEspacios),
          JobTextIssue.empty,
          reason: soloEspacios.codeUnits.toString(),
        );
        expect(
          JobOfferValidation.validateDescription(soloEspacios),
          JobTextIssue.empty,
        );
        expect(
          JobOfferValidation.validateScheduleDetail(soloEspacios),
          JobTextIssue.empty,
        );
      }
    });

    test('cuenta los caracteres DESPUÉS de recortar: el relleno de espacios '
        'duros (U+00A0) no suma al tope', () {
      const duro = ' ';
      expect(
        JobOfferValidation.validateTitle('$duro$duro${'a' * 120}$duro\t'),
        isNull,
      );
      expect(
        JobOfferValidation.validateTitle('$duro${'a' * 121}$duro'),
        JobTextIssue.tooLong,
      );
      expect(
        JobOfferValidation.validateScheduleDetail('\n${'h' * 200}$duro'),
        isNull,
      );
      // Y viaja recortado: lo que mide el servidor es lo mismo que se midió.
      final enviado = testJobOfferInput(title: '$duro Mozo/a\t\n')
          .toUpdateJson();
      expect(enviado['title'], 'Mozo/a');
    });

    test('el detalle de horario admite 200 y no 201', () {
      expect(JobOfferValidation.validateScheduleDetail('h' * 200), isNull);
      expect(
        JobOfferValidation.validateScheduleDetail('h' * 201),
        JobTextIssue.tooLong,
      );
      expect(JobOfferValidation.validateScheduleDetail(''), JobTextIssue.empty);
    });
  });

  group('días de trabajo', () {
    test('entre 1 y 7, sin repetidos', () {
      expect(
        JobOfferValidation.validateScheduleDays(const []),
        JobScheduleDaysIssue.empty,
      );
      expect(
        JobOfferValidation.validateScheduleDays(const [WeekDay.lun]),
        isNull,
      );
      expect(JobOfferValidation.validateScheduleDays(WeekDay.values), isNull);
      expect(
        JobOfferValidation.validateScheduleDays(const [
          WeekDay.lun,
          WeekDay.lun,
        ]),
        JobScheduleDaysIssue.duplicated,
      );
      expect(
        JobOfferValidation.validateScheduleDays([
          ...WeekDay.values,
          WeekDay.dom,
        ]),
        JobScheduleDaysIssue.duplicated,
        reason: 'más de 7 días solo es posible repitiendo alguno',
      );
    });
  });

  group('sueldo', () {
    test('mínimo y máximo son obligatorios aun en borrador', () {
      expect(
        JobOfferValidation.validateSalaryMin(null, publishing: false),
        JobSalaryIssue.missing,
      );
      expect(
        JobOfferValidation.validateSalaryMax(null, min: 1000),
        JobSalaryIssue.missing,
      );
    });

    test('un mínimo 0 vale en borrador pero no para publicar', () {
      expect(
        JobOfferValidation.validateSalaryMin(0, publishing: false),
        isNull,
      );
      expect(
        JobOfferValidation.validateSalaryMin(0, publishing: true),
        JobSalaryIssue.notPositiveToPublish,
      );
      expect(JobOfferValidation.validateSalaryMin(1, publishing: true), isNull);
    });

    test('negativos fuera', () {
      expect(
        JobOfferValidation.validateSalaryMin(-1, publishing: false),
        JobSalaryIssue.negative,
      );
      expect(
        JobOfferValidation.validateSalaryMax(-1, min: null),
        JobSalaryIssue.negative,
      );
    });

    test('el techo es 999.999.999 inclusive', () {
      expect(JobOfferValidation.validateSalaryMax(999999999, min: 1), isNull);
      expect(
        JobOfferValidation.validateSalaryMax(1000000000, min: 1),
        JobSalaryIssue.tooHigh,
      );
      expect(
        JobOfferValidation.validateSalaryMin(1000000000, publishing: false),
        JobSalaryIssue.tooHigh,
      );
    });

    test('el máximo no puede ser menor que el mínimo; igual sí '
        '(sueldo único)', () {
      expect(
        JobOfferValidation.validateSalaryMax(999, min: 1000),
        JobSalaryIssue.belowMin,
      );
      expect(JobOfferValidation.validateSalaryMax(1000, min: 1000), isNull);
    });

    test('si el mínimo es inválido el error queda en el mínimo', () {
      expect(JobOfferValidation.validateSalaryMax(10, min: -5), isNull);
    });

    test('parseAmount acepta pesos enteros con o sin puntos de miles', () {
      expect(JobOfferValidation.parseAmount('350000'), 350000);
      expect(JobOfferValidation.parseAmount('350.000'), 350000);
      expect(JobOfferValidation.parseAmount(' 1.234.567 '), 1234567);
      expect(JobOfferValidation.parseAmount('0'), 0);
      for (final raw in ['', 'abc', '-5', '35.00', '1,5', '1.2345', '1 000']) {
        expect(JobOfferValidation.parseAmount(raw), isNull, reason: raw);
      }
    });
  });

  group('beneficios', () {
    test('hasta 15, cada uno de 1 a 60 caracteres', () {
      final quince = [for (var i = 0; i < 15; i++) 'Beneficio $i'];
      expect(JobOfferValidation.validateBenefits(quince), isNull);
      expect(
        JobOfferValidation.validateBenefits([...quince, 'Uno más']),
        JobBenefitIssue.tooMany,
      );
      expect(JobOfferValidation.validateBenefits(['b' * 60]), isNull);
      expect(
        JobOfferValidation.validateBenefits(['b' * 61]),
        JobBenefitIssue.tooLong,
      );
      expect(
        JobOfferValidation.validateBenefits(['  ']),
        JobBenefitIssue.empty,
      );
      expect(JobOfferValidation.validateBenefits(const []), isNull);
    });

    test('repetidos ignorando mayúsculas y espacios de los bordes', () {
      expect(
        JobOfferValidation.validateBenefits(['Comida', ' comida ']),
        JobBenefitIssue.duplicated,
      );
    });

    test('recorta con String.trim() y mide después: tabs, saltos de línea y '
        'espacios duros', () {
      const duro = ' ';
      expect(
        JobOfferValidation.validateBenefits(['\t\n']),
        JobBenefitIssue.empty,
      );
      expect(
        JobOfferValidation.validateNewBenefit(duro, const []),
        JobBenefitIssue.empty,
      );
      expect(
        JobOfferValidation.validateBenefits(['$duro${'b' * 60}\t']),
        isNull,
      );
      expect(
        JobOfferValidation.validateBenefits(['$duro${'b' * 61}$duro']),
        JobBenefitIssue.tooLong,
      );
      expect(
        JobOfferValidation.validateBenefits(['Propinas', '${duro}propinas\n']),
        JobBenefitIssue.duplicated,
      );
    });

    test('validateNewBenefit avisa al agregar, no al publicar', () {
      final actuales = ['Comida incluida'];
      expect(
        JobOfferValidation.validateNewBenefit('COMIDA INCLUIDA', actuales),
        JobBenefitIssue.duplicated,
      );
      expect(
        JobOfferValidation.validateNewBenefit('Propinas', actuales),
        isNull,
      );
      expect(
        JobOfferValidation.validateNewBenefit(' ', actuales),
        JobBenefitIssue.empty,
      );
      final quince = [for (var i = 0; i < 15; i++) 'Beneficio $i'];
      expect(
        JobOfferValidation.validateNewBenefit('Otro', quince),
        JobBenefitIssue.tooMany,
      );
    });
  });

  group('vacantes', () {
    test('de 1 a 100', () {
      expect(
        JobOfferValidation.validateVacancies(null),
        JobVacanciesIssue.missing,
      );
      expect(
        JobOfferValidation.validateVacancies(0),
        JobVacanciesIssue.outOfRange,
      );
      expect(JobOfferValidation.validateVacancies(1), isNull);
      expect(JobOfferValidation.validateVacancies(100), isNull);
      expect(
        JobOfferValidation.validateVacancies(101),
        JobVacanciesIssue.outOfRange,
      );
    });

    test('parseVacancies solo acepta dígitos', () {
      expect(JobOfferValidation.parseVacancies(' 3 '), 3);
      expect(JobOfferValidation.parseVacancies('3.5'), isNull);
      expect(JobOfferValidation.parseVacancies(''), isNull);
    });
  });

  group('vencimiento (D1)', () {
    test('es obligatorio siempre', () {
      expect(
        JobOfferValidation.validateExpiresAt(null, publishing: false, now: now),
        JobExpiryIssue.missing,
      );
    });

    test('un borrador acepta cualquier fecha, incluso pasada o lejana', () {
      for (final value in [
        now.subtract(const Duration(days: 400)),
        now.add(const Duration(days: 400)),
      ]) {
        expect(
          JobOfferValidation.validateExpiresAt(
            value,
            publishing: false,
            now: now,
          ),
          isNull,
        );
      }
    });

    test('al publicar tiene que ser estrictamente futuro', () {
      expect(
        JobOfferValidation.validateExpiresAt(now, publishing: true, now: now),
        JobExpiryIssue.notInFuture,
      );
      expect(
        JobOfferValidation.validateExpiresAt(
          now.add(const Duration(minutes: 1)),
          publishing: true,
          now: now,
        ),
        isNull,
      );
    });

    test('al publicar no pasa de 60 días (inclusive)', () {
      final tope = JobOfferValidation.latestExpiry(now);
      expect(tope, now.add(const Duration(days: 60)));
      expect(
        JobOfferValidation.validateExpiresAt(tope, publishing: true, now: now),
        isNull,
      );
      expect(
        JobOfferValidation.validateExpiresAt(
          tope.add(const Duration(seconds: 1)),
          publishing: true,
          now: now,
        ),
        JobExpiryIssue.beyondMaxWindow,
      );
    });
  });

  group('barrio (D2)', () {
    test('al publicar es obligatorio solo si la localidad tiene barrios', () {
      expect(
        JobOfferValidation.validateNeighborhood(
          null,
          localityHasNeighborhoods: true,
          publishing: true,
        ),
        JobChoiceIssue.missing,
      );
      expect(
        JobOfferValidation.validateNeighborhood(
          'barrio-1',
          localityHasNeighborhoods: true,
          publishing: true,
        ),
        isNull,
      );
      expect(
        JobOfferValidation.validateNeighborhood(
          null,
          localityHasNeighborhoods: false,
          publishing: true,
        ),
        isNull,
      );
    });

    test('en borrador es opcional, y sin dato del catálogo decide el '
        'servidor', () {
      expect(
        JobOfferValidation.validateNeighborhood(
          null,
          localityHasNeighborhoods: true,
          publishing: false,
        ),
        isNull,
      );
      expect(
        JobOfferValidation.validateNeighborhood(
          null,
          localityHasNeighborhoods: null,
          publishing: true,
        ),
        isNull,
      );
    });
  });

  group('validate (formulario entero)', () {
    test('un formulario completo pasa como borrador y para publicar', () {
      final input = testJobOfferInput();
      expect(
        JobOfferValidation.validate(
          input,
          mode: JobOfferSaveMode.draft,
          now: now,
        ).isEmpty,
        isTrue,
      );
      expect(
        JobOfferValidation.validate(
          input,
          mode: JobOfferSaveMode.publish,
          now: now,
          localityHasNeighborhoods: true,
        ).isEmpty,
        isTrue,
      );
    });

    test('el borrador exige todas las columnas NOT NULL, en orden de '
        'formulario', () {
      final issues = JobOfferValidation.validate(
        const JobOfferInput(),
        mode: JobOfferSaveMode.draft,
        now: now,
      );

      expect(issues.invalidFields, [
        JobOfferField.title,
        JobOfferField.description,
        JobOfferField.contractType,
        JobOfferField.jornada,
        JobOfferField.scheduleDays,
        JobOfferField.scheduleDetail,
        JobOfferField.workMode,
        JobOfferField.salaryMin,
        JobOfferField.salaryMax,
        JobOfferField.province,
        JobOfferField.locality,
        JobOfferField.experience,
        JobOfferField.availability,
        JobOfferField.expiresAt,
      ]);
      expect(issues.firstInvalidField, JobOfferField.title);
      expect(issues.salaryMin, JobSalaryIssue.missing);
      expect(
        issues.issueFor(JobOfferField.neighborhood),
        isNull,
        reason: 'el barrio nunca es obligatorio en borrador',
      );
    });

    test('lo que solo se exige al publicar queda pendiente en borrador', () {
      final input = testJobOfferInput(
        salaryMin: 0,
        barrioId: null,
        expiresAt: now.subtract(const Duration(days: 1)),
      );

      final borrador = JobOfferValidation.validate(
        input,
        mode: JobOfferSaveMode.draft,
        now: now,
        localityHasNeighborhoods: true,
      );
      final publicar = JobOfferValidation.validate(
        input,
        mode: JobOfferSaveMode.publish,
        now: now,
        localityHasNeighborhoods: true,
      );

      expect(borrador.isEmpty, isTrue);
      expect(publicar.invalidFields, [
        JobOfferField.salaryMin,
        JobOfferField.neighborhood,
        JobOfferField.expiresAt,
      ]);
      expect(publicar.salaryMin, JobSalaryIssue.notPositiveToPublish);
      expect(publicar.expiresAt, JobExpiryIssue.notInFuture);
    });

    test('editar una activa sin tocar sueldo, vencimiento ni lugar no '
        're-chequea la publicación', () {
      // Activa con el vencimiento ya pasado (el cron de T-033 todavía no la
      // marcó): cambiar el título igual se puede, como en el servidor.
      final original = testJobOfferInput(
        expiresAt: now.subtract(const Duration(hours: 1)),
      );
      final editada = original.copyWith(title: 'Mozo/a de salón');

      expect(
        JobOfferValidation.validate(
          editada,
          mode: JobOfferSaveMode.editActive,
          now: now,
          original: original,
        ).isEmpty,
        isTrue,
      );
    });

    test('editar una activa cambiando el vencimiento re-chequea todo lo '
        'de publicar', () {
      final original = testJobOfferInput(salaryMin: 0);
      final editada = original.copyWith(
        expiresAt: () => now.add(const Duration(days: 61)),
      );

      final issues = JobOfferValidation.validate(
        editada,
        mode: JobOfferSaveMode.editActive,
        now: now,
        original: original,
      );

      expect(issues.expiresAt, JobExpiryIssue.beyondMaxWindow);
      expect(issues.salaryMin, JobSalaryIssue.notPositiveToPublish);
    });

    test('sin la versión original, editar una activa es conservador', () {
      final issues = JobOfferValidation.validate(
        testJobOfferInput(salaryMin: 0),
        mode: JobOfferSaveMode.editActive,
        now: now,
      );

      expect(issues.salaryMin, JobSalaryIssue.notPositiveToPublish);
    });

    test('un período de sueldo desconocido obliga a elegir uno', () {
      final issues = JobOfferValidation.validate(
        // `fromOffer` deja en null un período que el cliente no entendió.
        const JobOfferInput(salaryPeriod: null),
        mode: JobOfferSaveMode.draft,
        now: now,
      );

      expect(issues.salaryPeriod, JobChoiceIssue.missing);
    });
  });

  group('validatePublication (publicar o reanudar desde la lista)', () {
    test('solo mira sueldo mínimo, vencimiento y barrio', () {
      final valida = testJobOffer(status: JobStatus.paused);
      expect(
        JobOfferValidation.validatePublication(
          valida,
          now: now,
          localityHasNeighborhoods: true,
        ).isEmpty,
        isTrue,
      );

      final vencida = testJobOffer(
        status: JobStatus.paused,
        salaryMin: 0,
        barrioId: null,
        expiresAt: now.subtract(const Duration(minutes: 1)),
      );
      expect(
        JobOfferValidation.validatePublication(
          vencida,
          now: now,
          localityHasNeighborhoods: true,
        ).invalidFields,
        [
          JobOfferField.salaryMin,
          JobOfferField.neighborhood,
          JobOfferField.expiresAt,
        ],
      );
    });

    test('no re-valida el contenido que no cambia', () {
      final legado = testJobOffer(title: 'x' * 300);
      expect(
        JobOfferValidation.validatePublication(legado, now: now).isEmpty,
        isTrue,
      );
    });
  });
}
