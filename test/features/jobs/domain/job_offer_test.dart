import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/companies/data/company_access_repository.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_enums.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_input.dart';

import '../../../support/fake_job_offers_repository.dart';

/// Fila completa tal como la devuelve PostgREST para una oferta del feed.
Map<String, dynamic> filaOferta() => <String, dynamic>{
  'id': '95000000-0000-4000-8000-000000000001',
  'company_id': 'c-1',
  'title': 'Cocinero/a',
  'description': 'Cocina caliente para turno noche.',
  'sector_id': 'sector-1',
  'salary_min': 900000,
  'salary_max': 1100000.5,
  'salary_currency': 'ARS',
  'salary_period': 'mensual',
  'contract_type': 'relacion_dependencia',
  'jornada': 'full_time',
  'schedule_days': <dynamic>['lun', 'mar', 'mie'],
  'schedule_detail': '9 a 18 hs',
  'work_mode': 'presencial',
  'provincia_id': 'prov-1',
  'localidad_id': 'loc-1',
  'barrio_id': 'barrio-1',
  'experience': '1_a_3_anios',
  'availability': 'en_1_semana',
  'benefits': <dynamic>['Comida incluida'],
  'expires_at': '2026-11-09T12:00:00+00:00',
  'vacancies': 2,
  'status': 'active',
  'published_at': '2026-10-01T12:00:00.123456+00:00',
  'closed_at': null,
  'created_at': '2026-10-01T09:00:00+00:00',
  'updated_at': '2026-10-01T12:00:00+00:00',
  'company': <String, dynamic>{
    'name': 'Parrilla de Prueba',
    'verification_status': 'approved',
  },
};

void main() {
  group('enums de cable (espejo de 0002_enums.sql)', () {
    test('JobStatus tiene exactamente los valores de job_status', () {
      expect(JobStatus.values.map((value) => value.wireName), [
        'draft',
        'active',
        'paused',
        'expired',
        'closed',
      ]);
    });

    test('ContractType tiene exactamente los valores de contract_type', () {
      expect(ContractType.values.map((value) => value.wireName), [
        'relacion_dependencia',
        'monotributo',
        'plazo_fijo',
        'temporal',
        'pasantia',
        'freelance',
      ]);
    });

    test('JornadaType tiene exactamente los valores de jornada_type', () {
      expect(JornadaType.values.map((value) => value.wireName), [
        'full_time',
        'part_time',
        'por_turnos',
        'fin_de_semana',
        'por_horas',
      ]);
    });

    test('SalaryPeriod tiene exactamente los valores de salary_period', () {
      expect(SalaryPeriod.values.map((value) => value.wireName), [
        'mensual',
        'anual',
        'por_hora',
      ]);
    });

    test('cada valor vuelve de su wireName', () {
      for (final value in JobStatus.values) {
        expect(JobStatus.fromWire(value.wireName), value);
      }
      for (final value in ContractType.values) {
        expect(ContractType.fromWire(value.wireName), value);
      }
      for (final value in JornadaType.values) {
        expect(JornadaType.fromWire(value.wireName), value);
      }
      for (final value in SalaryPeriod.values) {
        expect(SalaryPeriod.fromWire(value.wireName), value);
      }
    });

    test('un valor desconocido falla cerrado en null', () {
      for (final raw in <Object?>[null, '', 'archived', 'ACTIVE', 1, true]) {
        expect(JobStatus.fromWire(raw), isNull, reason: '$raw');
        expect(ContractType.fromWire(raw), isNull, reason: '$raw');
        expect(JornadaType.fromWire(raw), isNull, reason: '$raw');
        expect(SalaryPeriod.fromWire(raw), isNull, reason: '$raw');
      }
    });

    test('los alias de oferta reutilizan el mapeo del candidato, sin '
        'duplicarlo', () {
      expect(JobWorkMode.fromWire('remoto'), CandidateWorkMode.remoto);
      expect(JobAvailability.fromWire('a_convenir'), isA<JobAvailability>());
      expect(
        JobAvailability.fromWire('a_convenir'),
        CandidateAvailability.aConvenir,
      );
    });
  });

  group('JobOffer.fromJson', () {
    test('lee una fila completa con la empresa embebida', () {
      final offer = JobOffer.fromJson(filaOferta());

      expect(offer.id, '95000000-0000-4000-8000-000000000001');
      expect(offer.companyId, 'c-1');
      expect(offer.title, 'Cocinero/a');
      expect(offer.salaryMin, 900000);
      expect(offer.salaryMax, 1100000.5);
      expect(offer.salaryPeriod, SalaryPeriod.mensual);
      expect(offer.contractType, ContractType.relacionDependencia);
      expect(offer.jornada, JornadaType.fullTime);
      expect(offer.scheduleDays, [WeekDay.lun, WeekDay.mar, WeekDay.mie]);
      expect(offer.workMode, JobWorkMode.presencial);
      expect(offer.barrioId, 'barrio-1');
      expect(offer.experience, ExperienceLevel.de1A3Anios);
      expect(offer.availability, JobAvailability.en1Semana);
      expect(offer.benefits, ['Comida incluida']);
      expect(offer.expiresAt, DateTime.utc(2026, 11, 9, 12));
      expect(offer.vacancies, 2);
      expect(offer.status, JobStatus.active);
      expect(offer.publishedAt, isNotNull);
      expect(offer.closedAt, isNull);
      expect(
        offer.company,
        const JobOfferCompany(
          name: 'Parrilla de Prueba',
          verificationStatus: CompanyVerificationStatus.approved,
        ),
      );
    });

    test('valores que el cliente no conoce quedan en null o se descartan', () {
      final fila = filaOferta()
        ..['status'] = 'archived'
        ..['contract_type'] = 'changa'
        ..['jornada'] = null
        ..['salary_period'] = 'semanal'
        ..['work_mode'] = 'teletrabajo'
        ..['schedule_days'] = <dynamic>['lun', 'feriado', 3];

      final offer = JobOffer.fromJson(fila);

      expect(
        offer.status,
        isNull,
        reason:
            'un estado desconocido no habilita '
            'ninguna acción',
      );
      expect(offer.contractType, isNull);
      expect(offer.jornada, isNull);
      expect(offer.salaryPeriod, isNull);
      expect(offer.workMode, isNull);
      expect(offer.scheduleDays, [WeekDay.lun]);
    });

    test('tipos inesperados no rompen la lectura', () {
      final offer = JobOffer.fromJson(<String, dynamic>{
        'id': 7,
        'salary_min': '350000.50',
        'salary_max': <dynamic>[],
        'vacancies': '3',
        'benefits': 'no es lista',
        'expires_at': 'mañana',
        'company': 'no es objeto',
      });

      expect(offer.id, '');
      expect(offer.salaryMin, 350000.5);
      expect(offer.salaryMax, 0);
      expect(offer.vacancies, 3);
      expect(offer.benefits, isEmpty);
      expect(offer.expiresAt, isNull);
      expect(offer.company, isNull);
      expect(offer.salaryCurrency, 'ARS');
    });

    test('una empresa con estado desconocido no se lee como aprobada', () {
      final fila = filaOferta()
        ..['company'] = <String, dynamic>{
          'name': 'Rara SA',
          'verification_status': 'super_approved',
        };

      final company = JobOffer.fromJson(fila).company;

      expect(company?.name, 'Rara SA');
      expect(company?.verificationStatus, isNull);
    });

    test('hasPassedExpiry compara contra el instante dado', () {
      final offer = JobOffer.fromJson(filaOferta());

      expect(offer.hasPassedExpiry(DateTime.utc(2026, 11, 9, 11)), isFalse);
      expect(offer.hasPassedExpiry(DateTime.utc(2026, 11, 9, 12)), isTrue);
      expect(offer.hasPassedExpiry(DateTime.utc(2026, 12)), isTrue);
    });
  });

  group('JobOfferInput', () {
    const protegidas = {
      'id',
      'published_at',
      'closed_at',
      'deleted_at',
      'created_at',
      'updated_at',
      'video_id',
    };

    test('toInsertJson lleva empresa, autor, estado y todo el contenido', () {
      final json = testJobOfferInput().toInsertJson(
        companyId: 'c-1',
        createdBy: 'uid-1',
        status: JobStatus.draft,
      );

      expect(json.keys.toSet(), {
        'company_id',
        'created_by',
        'status',
        'title',
        'description',
        'sector_id',
        'salary_min',
        'salary_max',
        'salary_currency',
        'salary_period',
        'contract_type',
        'jornada',
        'schedule_days',
        'schedule_detail',
        'work_mode',
        'provincia_id',
        'localidad_id',
        'barrio_id',
        'experience',
        'availability',
        'benefits',
        'expires_at',
        'vacancies',
      });
      expect(json['company_id'], 'c-1');
      expect(json['created_by'], 'uid-1');
      expect(json['status'], 'draft');
      expect(json['salary_currency'], 'ARS');
      expect(json['salary_period'], 'mensual');
      expect(json['schedule_days'], ['jue', 'vie', 'sab']);
      expect(json['contract_type'], 'relacion_dependencia');
      expect(json['jornada'], 'part_time');
      expect(json['experience'], 'hasta_1_anio');
      expect(json['availability'], 'inmediata');
      expect(json['vacancies'], 1);
    });

    test('ni el alta ni la edición escriben columnas protegidas', () {
      final input = testJobOfferInput();
      final insert = input.toInsertJson(
        companyId: 'c-1',
        createdBy: 'uid-1',
        status: JobStatus.active,
      );
      final update = input.toUpdateJson();

      expect(insert.keys.toSet().intersection(protegidas), isEmpty);
      expect(update.keys.toSet().intersection(protegidas), isEmpty);
      expect(
        update.keys,
        isNot(anyOf(contains('status'), contains('company_id'))),
        reason: 'el estado cambia en otra escritura y la empresa no se mueve',
      );
      expect(update.keys, isNot(contains('created_by')));
    });

    test('los textos y beneficios viajan recortados', () {
      final json = testJobOfferInput()
          .copyWith(
            title: '  Bachero/a  ',
            description: '\nLavado de vajilla.\n',
            scheduleDetail: ' 8 a 16 ',
            benefits: const [' Comida ', 'Uniforme'],
          )
          .toUpdateJson();

      expect(json['title'], 'Bachero/a');
      expect(json['description'], 'Lavado de vajilla.');
      expect(json['schedule_detail'], '8 a 16');
      expect(json['benefits'], ['Comida', 'Uniforme']);
    });

    test('el vencimiento viaja como instante UTC en ISO 8601', () {
      final json = testJobOfferInput(
        expiresAt: DateTime.utc(2026, 11, 1, 23, 59),
      ).toUpdateJson();

      expect(json['expires_at'], '2026-11-01T23:59:00.000Z');
    });

    test('copyWith limpia con función y conserva sin ella', () {
      final input = testJobOfferInput();

      expect(input.copyWith(title: 'Otro').barrioId, input.barrioId);
      expect(input.copyWith(barrioId: () => null).barrioId, isNull);
      expect(input.copyWith(localidadId: () => null).localidadId, isNull);
      expect(input.copyWith(sectorId: () => null).sectorId, isNull);
      expect(input.copyWith(salaryMin: () => null).salaryMin, isNull);
      expect(input.copyWith(salaryMax: () => 5).salaryMax, 5);
      expect(input.copyWith(vacancies: () => null).vacancies, isNull);
      expect(input.copyWith(expiresAt: () => null).expiresAt, isNull);
    });

    test('fromOffer reproduce el formulario de la oferta', () {
      final input = testJobOfferInput();
      final offer = testJobOffer();

      expect(JobOfferInput.fromOffer(offer), input);
      expect(JobOfferInput.fromOffer(offer).hashCode, input.hashCode);
    });

    test('duplicar copia el contenido pero obliga a elegir otro '
        'vencimiento', () {
      final copia = JobOfferInput.duplicateOf(
        testJobOffer(status: JobStatus.closed),
      );

      expect(copia.expiresAt, isNull);
      expect(copia.title, 'Mozo/a para salón');
      expect(copia.copyWith(expiresAt: () => testJobNow).expiresAt, testJobNow);
    });

    test('la igualdad compara listas por contenido', () {
      final a = testJobOfferInput();
      final b = testJobOfferInput().copyWith(
        scheduleDays: [WeekDay.jue, WeekDay.vie, WeekDay.sab],
      );
      final c = testJobOfferInput().copyWith(scheduleDays: const [WeekDay.jue]);

      expect(a, b);
      expect(a == c, isFalse);
      expect(a == a.copyWith(benefits: const ['Comida incluida']), isFalse);
    });
  });
}
