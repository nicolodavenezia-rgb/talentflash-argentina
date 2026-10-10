/// Enums de cable de las ofertas laborales (T-030), espejo exacto de los enums
/// de Postgres de `0002_enums.sql`.
///
/// Igual que en el resto de la app, `fromWire` devuelve `null` ante un valor
/// que esta versión del cliente no conoce: un estado nuevo de la base nunca se
/// interpreta como uno de los conocidos (fail-closed). Las etiquetas visibles
/// salen del ARB por un `switch` exhaustivo en la capa de presentación, nunca
/// de `wireName`.
library;

import '../../onboarding/domain/candidate_onboarding_data.dart';

export '../../onboarding/domain/candidate_onboarding_data.dart'
    show CandidateAvailability, CandidateWorkMode;
export '../../profiles/domain/candidate_profile.dart' show ExperienceLevel;
export '../../profiles/domain/weekly_availability.dart' show WeekDay;

/// Estado de la oferta (`job_status`). Las transiciones que puede pedir el
/// cliente están en `JobOfferLifecycle`; `expired` solo lo pone el sistema.
enum JobStatus {
  draft('draft'),
  active('active'),
  paused('paused'),
  expired('expired'),
  closed('closed');

  const JobStatus(this.wireName);

  final String wireName;

  static JobStatus? fromWire(Object? raw) {
    for (final value in JobStatus.values) {
      if (value.wireName == raw) {
        return value;
      }
    }
    return null;
  }
}

/// Modalidad contractual (`contract_type`). Una sola columna cubre la
/// "modalidad" y el "relación de dependencia o monotributo" de la spec.
enum ContractType {
  relacionDependencia('relacion_dependencia'),
  monotributo('monotributo'),
  plazoFijo('plazo_fijo'),
  temporal('temporal'),
  pasantia('pasantia'),
  freelance('freelance');

  const ContractType(this.wireName);

  final String wireName;

  static ContractType? fromWire(Object? raw) {
    for (final value in ContractType.values) {
      if (value.wireName == raw) {
        return value;
      }
    }
    return null;
  }
}

/// Jornada (`jornada_type`).
enum JornadaType {
  fullTime('full_time'),
  partTime('part_time'),
  porTurnos('por_turnos'),
  finDeSemana('fin_de_semana'),
  porHoras('por_horas');

  const JornadaType(this.wireName);

  final String wireName;

  static JornadaType? fromWire(Object? raw) {
    for (final value in JornadaType.values) {
      if (value.wireName == raw) {
        return value;
      }
    }
    return null;
  }
}

/// Período al que corresponde el sueldo (`salary_period`). El monto siempre
/// es en ARS: la base no acepta otra moneda (0032).
enum SalaryPeriod {
  mensual('mensual'),
  anual('anual'),
  porHora('por_hora');

  const SalaryPeriod(this.wireName);

  final String wireName;

  static SalaryPeriod? fromWire(Object? raw) {
    for (final value in SalaryPeriod.values) {
      if (value.wireName == raw) {
        return value;
      }
    }
    return null;
  }
}

/// Modalidad de trabajo de la oferta. Es el MISMO enum `work_mode` de Postgres
/// que el candidato usa para sus preferencias, así que se reutiliza su mapeo
/// de cable en vez de duplicarlo: el alias solo le da un nombre neutro del
/// lado de las ofertas.
typedef JobWorkMode = CandidateWorkMode;

/// Disponibilidad pedida por la oferta: mismo enum `availability_type` que la
/// disponibilidad declarada por el candidato (mismo motivo que [JobWorkMode]).
typedef JobAvailability = CandidateAvailability;
