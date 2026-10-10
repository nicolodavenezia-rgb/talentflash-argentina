/// Reglas puras de validación de ofertas (T-030). Cada una existe también
/// server-side (`private.validate_job_content` y las columnas NOT NULL de
/// `public.jobs`, migraciones 0007/0032): esto es UX temprana, no seguridad.
///
/// **Borrador vs. publicar.** La base NO deja guardar un borrador incompleto:
/// todas las columnas NOT NULL sin default (título, descripción, sueldo mínimo
/// y máximo, modalidad, jornada, días, detalle de horario, modalidad de
/// trabajo, provincia, localidad, experiencia, disponibilidad y vencimiento) y
/// las reglas de contenido de 0032 aplican también a `draft`. Por eso el
/// formulario exige esos mismos campos para "Guardar borrador" que para
/// "Publicar" y NO completa ninguno con un valor de relleno (ni un sueldo 0 ni
/// un vencimiento inventado): un dato que la persona no eligió nunca se
/// guarda como si lo hubiera elegido. Lo único que un borrador deja pendiente
/// es lo que el servidor recién controla al entrar a `active`:
/// - sueldo mínimo mayor que 0;
/// - vencimiento en el futuro y como máximo a [maxPublicationDays] días (D1);
/// - barrio, si la localidad tiene barrios cargados (D2).
///
/// Los textos (puesto, descripción, detalle de horario y cada beneficio) se
/// recortan con `String.trim()` y se miden DESPUÉS de recortar, en
/// caracteres (code points, `runes`), igual que `length()` de Postgres. El
/// servidor recorta exactamente el mismo conjunto de espacios que
/// `String.trim()` (tabs, saltos de línea, espacio duro U+00A0, etc.), y
/// `JobOfferInput` manda los textos ya recortados: un texto hecho solo de
/// esos caracteres es vacío en los dos lados, y un relleno de espacios duros
/// no cuenta para el tope.
library;

import 'job_offer.dart';
import 'job_offer_enums.dart';
import 'job_offer_input.dart';

enum JobTextIssue { empty, tooLong }

enum JobScheduleDaysIssue { empty, duplicated }

enum JobSalaryIssue {
  /// Falta el monto: la columna es NOT NULL aun en borrador.
  missing,

  /// Monto negativo.
  negative,

  /// Supera el techo de 999.999.999.
  tooHigh,

  /// Al publicar, el mínimo tiene que ser mayor que 0 ("publicar sin sueldo
  /// falla server-side").
  notPositiveToPublish,

  /// El máximo es menor que el mínimo.
  belowMin,
}

enum JobBenefitIssue { empty, tooLong, duplicated, tooMany }

enum JobVacanciesIssue { missing, outOfRange }

enum JobExpiryIssue {
  /// Falta la fecha: la columna es NOT NULL aun en borrador.
  missing,

  /// Al publicar tiene que quedar en el futuro.
  notInFuture,

  /// Al publicar no puede pasar de [JobOfferValidation.maxPublicationDays].
  beyondMaxWindow,
}

/// Opción obligatoria sin elegir (desplegables y barrio cuando corresponde).
enum JobChoiceIssue { missing }

/// Qué se está por guardar: define qué reglas aplican, igual que el servidor.
enum JobOfferSaveMode {
  /// Alta o edición de un borrador, o edición de una oferta pausada: solo
  /// columnas obligatorias y reglas de contenido.
  draft,

  /// Entrar a `active`: alta directa, borrador → activa o pausada → activa.
  /// Se suman las reglas de publicación.
  publish,

  /// Guardar cambios de una oferta que sigue `active`. Como en 0032, las
  /// reglas de publicación se vuelven a comprobar solo si cambió el sueldo
  /// mínimo, el vencimiento, la localidad o el barrio (y entonces todas).
  editActive,
}

/// Campos del formulario, en el orden en que conviene recorrerlos para llevar
/// el foco al primer error.
enum JobOfferField {
  title,
  description,
  contractType,
  jornada,
  scheduleDays,
  scheduleDetail,
  workMode,
  salaryMin,
  salaryMax,
  salaryPeriod,
  province,
  locality,
  neighborhood,
  experience,
  availability,
  benefits,
  vacancies,
  expiresAt,
}

/// Resultado de validar el formulario entero: un problema (o ninguno) por
/// campo, tipado para que la UI elija el texto del ARB.
class JobOfferIssues {
  const JobOfferIssues({
    this.title,
    this.description,
    this.contractType,
    this.jornada,
    this.scheduleDays,
    this.scheduleDetail,
    this.workMode,
    this.salaryMin,
    this.salaryMax,
    this.salaryPeriod,
    this.province,
    this.locality,
    this.neighborhood,
    this.experience,
    this.availability,
    this.benefits,
    this.vacancies,
    this.expiresAt,
  });

  final JobTextIssue? title;
  final JobTextIssue? description;
  final JobChoiceIssue? contractType;
  final JobChoiceIssue? jornada;
  final JobScheduleDaysIssue? scheduleDays;
  final JobTextIssue? scheduleDetail;
  final JobChoiceIssue? workMode;
  final JobSalaryIssue? salaryMin;
  final JobSalaryIssue? salaryMax;
  final JobChoiceIssue? salaryPeriod;
  final JobChoiceIssue? province;
  final JobChoiceIssue? locality;
  final JobChoiceIssue? neighborhood;
  final JobChoiceIssue? experience;
  final JobChoiceIssue? availability;
  final JobBenefitIssue? benefits;
  final JobVacanciesIssue? vacancies;
  final JobExpiryIssue? expiresAt;

  /// Problema del [field], o null.
  Enum? issueFor(JobOfferField field) => switch (field) {
    JobOfferField.title => title,
    JobOfferField.description => description,
    JobOfferField.contractType => contractType,
    JobOfferField.jornada => jornada,
    JobOfferField.scheduleDays => scheduleDays,
    JobOfferField.scheduleDetail => scheduleDetail,
    JobOfferField.workMode => workMode,
    JobOfferField.salaryMin => salaryMin,
    JobOfferField.salaryMax => salaryMax,
    JobOfferField.salaryPeriod => salaryPeriod,
    JobOfferField.province => province,
    JobOfferField.locality => locality,
    JobOfferField.neighborhood => neighborhood,
    JobOfferField.experience => experience,
    JobOfferField.availability => availability,
    JobOfferField.benefits => benefits,
    JobOfferField.vacancies => vacancies,
    JobOfferField.expiresAt => expiresAt,
  };

  /// Campos con problema, en el orden de [JobOfferField].
  List<JobOfferField> get invalidFields => [
    for (final field in JobOfferField.values)
      if (issueFor(field) != null) field,
  ];

  /// Primer campo con problema (al que va el foco), o null si no hay.
  JobOfferField? get firstInvalidField {
    for (final field in JobOfferField.values) {
      if (issueFor(field) != null) {
        return field;
      }
    }
    return null;
  }

  bool get isEmpty => firstInvalidField == null;
}

abstract final class JobOfferValidation {
  static const titleMaxLength = 120;
  static const descriptionMaxLength = 4000;
  static const scheduleDetailMaxLength = 200;

  /// Techo de los montos (mismo que la expectativa salarial del candidato).
  static const salaryMaxAmount = 999999999;

  static const benefitsMaxItems = 15;
  static const benefitMaxLength = 60;
  static const vacanciesMin = 1;
  static const vacanciesMax = 100;

  /// D1: una oferta publicada vence como máximo a 60 días de ahora.
  static const maxPublicationDays = 60;

  /// Último instante de vencimiento que acepta una publicación hecha en
  /// [now]. Un selector de fecha que trabaje por días tiene que convertir el
  /// día elegido a un instante que no pase de acá (p. ej. el menor entre el
  /// fin de ese día y este valor): el servidor compara instantes, no días.
  static DateTime latestExpiry(DateTime now) =>
      now.add(const Duration(days: maxPublicationDays));

  static JobTextIssue? validateTitle(String raw) =>
      _validateText(raw, titleMaxLength);

  static JobTextIssue? validateDescription(String raw) =>
      _validateText(raw, descriptionMaxLength);

  static JobTextIssue? validateScheduleDetail(String raw) =>
      _validateText(raw, scheduleDetailMaxLength);

  /// Entre 1 y 7 días, sin repetidos (con [WeekDay] no hay valores fuera de
  /// `lun..dom`, y más de 7 implica un repetido).
  static JobScheduleDaysIssue? validateScheduleDays(List<WeekDay> days) {
    if (days.isEmpty) {
      return JobScheduleDaysIssue.empty;
    }
    if (days.toSet().length != days.length) {
      return JobScheduleDaysIssue.duplicated;
    }
    return null;
  }

  /// Sueldo mínimo. [publishing] suma la regla de publicación (mayor que 0).
  static JobSalaryIssue? validateSalaryMin(
    num? value, {
    required bool publishing,
  }) {
    final common = _validateAmount(value);
    if (common != null) {
      return common;
    }
    if (publishing && value! <= 0) {
      return JobSalaryIssue.notPositiveToPublish;
    }
    return null;
  }

  /// Sueldo máximo: obligatorio, en rango y no menor que [min] (si [min] es
  /// válido; si no, el problema se informa en el mínimo).
  static JobSalaryIssue? validateSalaryMax(num? value, {required num? min}) {
    final common = _validateAmount(value);
    if (common != null) {
      return common;
    }
    if (min != null && _validateAmount(min) == null && value! < min) {
      return JobSalaryIssue.belowMin;
    }
    return null;
  }

  /// Lista completa de beneficios (puede estar vacía).
  static JobBenefitIssue? validateBenefits(List<String> benefits) {
    if (benefits.length > benefitsMaxItems) {
      return JobBenefitIssue.tooMany;
    }
    final seen = <String>{};
    for (final benefit in benefits) {
      final issue = _validateBenefitText(benefit);
      if (issue != null) {
        return issue;
      }
      if (!seen.add(_benefitKey(benefit))) {
        return JobBenefitIssue.duplicated;
      }
    }
    return null;
  }

  /// Un beneficio nuevo que se quiere sumar a [current] (para el editor de
  /// chips: el error aparece al agregarlo, no al publicar).
  static JobBenefitIssue? validateNewBenefit(String raw, List<String> current) {
    final issue = _validateBenefitText(raw);
    if (issue != null) {
      return issue;
    }
    final key = _benefitKey(raw);
    if (current.any((benefit) => _benefitKey(benefit) == key)) {
      return JobBenefitIssue.duplicated;
    }
    if (current.length >= benefitsMaxItems) {
      return JobBenefitIssue.tooMany;
    }
    return null;
  }

  static JobVacanciesIssue? validateVacancies(int? value) {
    if (value == null) {
      return JobVacanciesIssue.missing;
    }
    if (value < vacanciesMin || value > vacanciesMax) {
      return JobVacanciesIssue.outOfRange;
    }
    return null;
  }

  /// Vencimiento. En borrador basta con que exista (la columna es NOT NULL);
  /// al publicar tiene que caer en `(now, now + 60 días]` (D1). [now] es el
  /// reloj del dispositivo: cerca del borde manda el del servidor.
  static JobExpiryIssue? validateExpiresAt(
    DateTime? value, {
    required bool publishing,
    required DateTime now,
  }) {
    if (value == null) {
      return JobExpiryIssue.missing;
    }
    if (!publishing) {
      return null;
    }
    if (!value.isAfter(now)) {
      return JobExpiryIssue.notInFuture;
    }
    if (value.isAfter(latestExpiry(now))) {
      return JobExpiryIssue.beyondMaxWindow;
    }
    return null;
  }

  /// D2: al publicar, el barrio es obligatorio si la localidad tiene barrios
  /// cargados. [localityHasNeighborhoods] null significa "todavía no se sabe"
  /// (catálogo cargando): no se bloquea y decide el servidor.
  static JobChoiceIssue? validateNeighborhood(
    String? barrioId, {
    required bool? localityHasNeighborhoods,
    required bool publishing,
  }) {
    if (publishing && localityHasNeighborhoods == true && barrioId == null) {
      return JobChoiceIssue.missing;
    }
    return null;
  }

  /// Desplegable obligatorio.
  static JobChoiceIssue? validateChoice(Object? value) =>
      value == null ? JobChoiceIssue.missing : null;

  /// Interpreta un monto tipeado en pesos enteros: dígitos, con o sin puntos
  /// de miles a la argentina ("350000" o "350.000"). Null si no es eso. Los
  /// centavos no se ofrecen en el formulario aunque la columna los admita.
  static int? parseAmount(String raw) {
    final value = raw.trim();
    if (!RegExp(r'^(\d+|\d{1,3}(\.\d{3})+)$').hasMatch(value)) {
      return null;
    }
    return int.tryParse(value.replaceAll('.', ''));
  }

  /// Interpreta la cantidad de vacantes tipeada.
  static int? parseVacancies(String raw) {
    final value = raw.trim();
    if (!RegExp(r'^\d{1,4}$').hasMatch(value)) {
      return null;
    }
    return int.parse(value);
  }

  /// Valida el formulario entero para [mode].
  ///
  /// [original] es la oferta tal como estaba antes de editarla: solo se usa
  /// en [JobOfferSaveMode.editActive] para saber si cambió algo que obliga a
  /// re-chequear la publicación (sin [original] se asume que sí, que es lo
  /// conservador). [localityHasNeighborhoods] alimenta D2 (ver
  /// [validateNeighborhood]).
  static JobOfferIssues validate(
    JobOfferInput input, {
    required JobOfferSaveMode mode,
    required DateTime now,
    JobOfferInput? original,
    bool? localityHasNeighborhoods,
  }) {
    final publishing = switch (mode) {
      JobOfferSaveMode.draft => false,
      JobOfferSaveMode.publish => true,
      JobOfferSaveMode.editActive =>
        original == null ||
            original.salaryMin != input.salaryMin ||
            original.expiresAt != input.expiresAt ||
            original.localidadId != input.localidadId ||
            original.barrioId != input.barrioId,
    };
    return JobOfferIssues(
      title: validateTitle(input.title),
      description: validateDescription(input.description),
      contractType: validateChoice(input.contractType),
      jornada: validateChoice(input.jornada),
      scheduleDays: validateScheduleDays(input.scheduleDays),
      scheduleDetail: validateScheduleDetail(input.scheduleDetail),
      workMode: validateChoice(input.workMode),
      salaryMin: validateSalaryMin(input.salaryMin, publishing: publishing),
      salaryMax: validateSalaryMax(input.salaryMax, min: input.salaryMin),
      salaryPeriod: validateChoice(input.salaryPeriod),
      province: validateChoice(input.provinciaId),
      locality: validateChoice(input.localidadId),
      neighborhood: validateNeighborhood(
        input.barrioId,
        localityHasNeighborhoods: localityHasNeighborhoods,
        publishing: publishing,
      ),
      experience: validateChoice(input.experience),
      availability: validateChoice(input.availability),
      benefits: validateBenefits(input.benefits),
      vacancies: validateVacancies(input.vacancies),
      expiresAt: validateExpiresAt(
        input.expiresAt,
        publishing: publishing,
        now: now,
      ),
    );
  }

  /// Solo las reglas que el servidor agrega al entrar a `active` cuando NO
  /// cambia el contenido (publicar o reanudar desde la lista, sin pasar por
  /// el formulario): sueldo mínimo mayor que 0, vencimiento en la ventana de
  /// D1 y barrio según D2. El contenido no se re-valida porque el servidor
  /// tampoco lo hace sobre columnas que no cambiaron.
  static JobOfferIssues validatePublication(
    JobOffer offer, {
    required DateTime now,
    bool? localityHasNeighborhoods,
  }) {
    return JobOfferIssues(
      salaryMin: validateSalaryMin(offer.salaryMin, publishing: true),
      neighborhood: validateNeighborhood(
        offer.barrioId,
        localityHasNeighborhoods: localityHasNeighborhoods,
        publishing: true,
      ),
      expiresAt: validateExpiresAt(offer.expiresAt, publishing: true, now: now),
    );
  }

  static JobTextIssue? _validateText(String raw, int maxLength) {
    final value = raw.trim();
    if (value.isEmpty) {
      return JobTextIssue.empty;
    }
    if (value.runes.length > maxLength) {
      return JobTextIssue.tooLong;
    }
    return null;
  }

  static JobSalaryIssue? _validateAmount(num? value) {
    if (value == null) {
      return JobSalaryIssue.missing;
    }
    if (value < 0) {
      return JobSalaryIssue.negative;
    }
    if (value > salaryMaxAmount) {
      return JobSalaryIssue.tooHigh;
    }
    return null;
  }

  static JobBenefitIssue? _validateBenefitText(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return JobBenefitIssue.empty;
    }
    if (value.runes.length > benefitMaxLength) {
      return JobBenefitIssue.tooLong;
    }
    return null;
  }

  /// Dos beneficios son el mismo si solo difieren en mayúsculas o en los
  /// espacios de los bordes (mismo criterio que `lower(btrim(...))`).
  static String _benefitKey(String raw) => raw.trim().toLowerCase();
}
