import 'job_offer.dart';
import 'job_offer_enums.dart';

/// Lo que la empresa edita de una oferta (alta, borrador o edición).
///
/// Inmutable: el formulario arma una nueva con [copyWith] en cada cambio. Solo
/// contiene columnas de CONTENIDO: `status`, `published_at`, `closed_at`,
/// `deleted_at`, `id` y las marcas de tiempo no tienen forma de viajar en este
/// tipo, porque las deriva o las protege el servidor (0032) y cualquier
/// intento del cliente termina en 42501.
///
/// Los defaults son los de la tabla (`salary_period = mensual`, `vacancies =
/// 1`, `benefits = {}`) para que el formulario los muestre y los mande
/// explícitos; ninguno inventa un dato que la persona no eligió.
class JobOfferInput {
  const JobOfferInput({
    this.title = '',
    this.description = '',
    this.sectorId,
    this.salaryMin,
    this.salaryMax,
    this.salaryPeriod = SalaryPeriod.mensual,
    this.contractType,
    this.jornada,
    this.scheduleDays = const [],
    this.scheduleDetail = '',
    this.workMode,
    this.provinciaId,
    this.localidadId,
    this.barrioId,
    this.experience,
    this.availability,
    this.benefits = const [],
    this.expiresAt,
    this.vacancies = 1,
  });

  /// Punto de partida para editar una oferta existente.
  factory JobOfferInput.fromOffer(JobOffer offer) {
    return JobOfferInput(
      title: offer.title,
      description: offer.description,
      sectorId: offer.sectorId,
      salaryMin: offer.salaryMin,
      salaryMax: offer.salaryMax,
      // Un período desconocido queda en null y la validación obliga a elegir
      // uno: editar no reescribe en silencio un valor que no se entendió.
      salaryPeriod: offer.salaryPeriod,
      contractType: offer.contractType,
      jornada: offer.jornada,
      scheduleDays: List<WeekDay>.unmodifiable(offer.scheduleDays),
      scheduleDetail: offer.scheduleDetail,
      workMode: offer.workMode,
      provinciaId: offer.provinciaId.isEmpty ? null : offer.provinciaId,
      localidadId: offer.localidadId.isEmpty ? null : offer.localidadId,
      barrioId: offer.barrioId,
      experience: offer.experience,
      availability: offer.availability,
      benefits: List<String>.unmodifiable(offer.benefits),
      expiresAt: offer.expiresAt,
      vacancies: offer.vacancies,
    );
  }

  /// Copia de una oferta para crear OTRA (acción "duplicar"): conserva todo
  /// el contenido salvo el vencimiento, que la persona elige de nuevo porque
  /// el de la original suele estar vencido o fuera de la ventana de 60 días.
  factory JobOfferInput.duplicateOf(JobOffer offer) =>
      JobOfferInput.fromOffer(offer).copyWith(expiresAt: () => null);

  /// Única moneda que acepta la base para `jobs.salary_currency` (0032).
  static const currency = 'ARS';

  final String title;
  final String description;
  final String? sectorId;
  final num? salaryMin;
  final num? salaryMax;
  final SalaryPeriod? salaryPeriod;
  final ContractType? contractType;
  final JornadaType? jornada;
  final List<WeekDay> scheduleDays;
  final String scheduleDetail;
  final JobWorkMode? workMode;
  final String? provinciaId;
  final String? localidadId;
  final String? barrioId;
  final ExperienceLevel? experience;
  final JobAvailability? availability;
  final List<String> benefits;
  final DateTime? expiresAt;
  final int? vacancies;

  /// Los campos que pueden volver a `null` (sector opcional, localidad y
  /// barrio al cambiar la provincia o la localidad, montos y vacantes al
  /// vaciar el texto, vencimiento) reciben una función y no un valor, igual
  /// que en el resto de los datos de formulario de la app.
  JobOfferInput copyWith({
    String? title,
    String? description,
    String? Function()? sectorId,
    num? Function()? salaryMin,
    num? Function()? salaryMax,
    SalaryPeriod? salaryPeriod,
    ContractType? contractType,
    JornadaType? jornada,
    List<WeekDay>? scheduleDays,
    String? scheduleDetail,
    JobWorkMode? workMode,
    String? provinciaId,
    String? Function()? localidadId,
    String? Function()? barrioId,
    ExperienceLevel? experience,
    JobAvailability? availability,
    List<String>? benefits,
    DateTime? Function()? expiresAt,
    int? Function()? vacancies,
  }) {
    return JobOfferInput(
      title: title ?? this.title,
      description: description ?? this.description,
      sectorId: sectorId == null ? this.sectorId : sectorId(),
      salaryMin: salaryMin == null ? this.salaryMin : salaryMin(),
      salaryMax: salaryMax == null ? this.salaryMax : salaryMax(),
      salaryPeriod: salaryPeriod ?? this.salaryPeriod,
      contractType: contractType ?? this.contractType,
      jornada: jornada ?? this.jornada,
      scheduleDays: scheduleDays ?? this.scheduleDays,
      scheduleDetail: scheduleDetail ?? this.scheduleDetail,
      workMode: workMode ?? this.workMode,
      provinciaId: provinciaId ?? this.provinciaId,
      localidadId: localidadId == null ? this.localidadId : localidadId(),
      barrioId: barrioId == null ? this.barrioId : barrioId(),
      experience: experience ?? this.experience,
      availability: availability ?? this.availability,
      benefits: benefits ?? this.benefits,
      expiresAt: expiresAt == null ? this.expiresAt : expiresAt(),
      vacancies: vacancies == null ? this.vacancies : vacancies(),
    );
  }

  /// Cuerpo del INSERT. [status] solo puede ser `draft` o `active`: el
  /// servidor rechaza cualquier otro con `TFJOB`. `created_by` tiene que ser
  /// el uid de la sesión (lo exigen la policy y `protect_job_write`) y
  /// `company_id` la empresa del caller: ninguno de los dos decide autoridad,
  /// RLS los vuelve a comprobar.
  Map<String, Object?> toInsertJson({
    required String companyId,
    required String createdBy,
    required JobStatus status,
  }) {
    return {
      'company_id': companyId,
      'created_by': createdBy,
      'status': status.wireName,
      ..._contentJson(),
    };
  }

  /// Cuerpo del UPDATE de contenido. No lleva `status`: cambiar de estado es
  /// una escritura aparte (o explícita al publicar un borrador).
  Map<String, Object?> toUpdateJson() => _contentJson();

  /// Los textos viajan recortados: el servidor valida longitud y vacío sobre
  /// lo que recibe, y la validación local mide exactamente eso.
  Map<String, Object?> _contentJson() {
    return {
      'title': title.trim(),
      'description': description.trim(),
      'sector_id': sectorId,
      'salary_min': salaryMin,
      'salary_max': salaryMax,
      'salary_currency': currency,
      'salary_period': salaryPeriod?.wireName,
      'contract_type': contractType?.wireName,
      'jornada': jornada?.wireName,
      'schedule_days': [for (final day in scheduleDays) day.wireName],
      'schedule_detail': scheduleDetail.trim(),
      'work_mode': workMode?.wireName,
      'provincia_id': provinciaId,
      'localidad_id': localidadId,
      'barrio_id': barrioId,
      'experience': experience?.wireName,
      'availability': availability?.wireName,
      'benefits': [for (final benefit in benefits) benefit.trim()],
      'expires_at': expiresAt?.toUtc().toIso8601String(),
      'vacancies': vacancies,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is JobOfferInput &&
      other.title == title &&
      other.description == description &&
      other.sectorId == sectorId &&
      other.salaryMin == salaryMin &&
      other.salaryMax == salaryMax &&
      other.salaryPeriod == salaryPeriod &&
      other.contractType == contractType &&
      other.jornada == jornada &&
      _listEquals(other.scheduleDays, scheduleDays) &&
      other.scheduleDetail == scheduleDetail &&
      other.workMode == workMode &&
      other.provinciaId == provinciaId &&
      other.localidadId == localidadId &&
      other.barrioId == barrioId &&
      other.experience == experience &&
      other.availability == availability &&
      _listEquals(other.benefits, benefits) &&
      other.expiresAt == expiresAt &&
      other.vacancies == vacancies;

  @override
  int get hashCode => Object.hash(
    JobOfferInput,
    title,
    description,
    sectorId,
    salaryMin,
    salaryMax,
    salaryPeriod,
    contractType,
    jornada,
    Object.hashAll(scheduleDays),
    scheduleDetail,
    workMode,
    provinciaId,
    localidadId,
    barrioId,
    experience,
    availability,
    Object.hashAll(benefits),
    Object.hash(expiresAt, vacancies),
  );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
