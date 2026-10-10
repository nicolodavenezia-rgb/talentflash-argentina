import '../../companies/data/company_access_repository.dart';
import 'job_offer_enums.dart';

/// Resumen de la empresa que publica, embebido en las lecturas que lo piden
/// (`company:company_profiles(name, verification_status)`): el feed y el
/// detalle lo necesitan para el nombre y el distintivo de verificada.
class JobOfferCompany {
  const JobOfferCompany({required this.name, required this.verificationStatus});

  final String name;

  /// Null si la base informa un estado que este cliente no conoce: se trata
  /// como "no verificada", jamás como aprobada.
  final CompanyVerificationStatus? verificationStatus;

  /// Devuelve null si el embed no vino (la policy de la empresa no la deja ver
  /// o la lectura no lo pidió): la oferta se muestra igual, sin distintivo.
  static JobOfferCompany? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final name = raw['name'];
    if (name is! String) {
      return null;
    }
    return JobOfferCompany(
      name: name,
      verificationStatus: CompanyVerificationStatus.fromWire(
        raw['verification_status'],
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is JobOfferCompany &&
      other.name == name &&
      other.verificationStatus == verificationStatus;

  @override
  int get hashCode => Object.hash(JobOfferCompany, name, verificationStatus);
}

/// Una oferta laboral tal como la devuelve `public.jobs` (T-030). Inmutable;
/// lo editable vive en `JobOfferInput`.
///
/// Los enums son nullables a propósito: un valor que este cliente no conoce
/// llega como `null` (fail-closed) en vez de romper la lectura o disfrazarse
/// de otro. En particular, un [status] desconocido no habilita ninguna acción
/// (`JobOfferLifecycle`). `created_by` y `video_id` no se leen: el primero es
/// el uid de quien la cargó y no hace falta en ninguna pantalla, y el video de
/// la oferta es T-032.
class JobOffer {
  const JobOffer({
    required this.id,
    required this.companyId,
    required this.title,
    required this.description,
    required this.salaryMin,
    required this.salaryMax,
    required this.salaryPeriod,
    required this.contractType,
    required this.jornada,
    required this.scheduleDays,
    required this.scheduleDetail,
    required this.workMode,
    required this.provinciaId,
    required this.localidadId,
    required this.experience,
    required this.availability,
    required this.benefits,
    required this.expiresAt,
    required this.vacancies,
    required this.status,
    this.sectorId,
    this.barrioId,
    this.salaryCurrency = 'ARS',
    this.publishedAt,
    this.closedAt,
    this.createdAt,
    this.updatedAt,
    this.company,
  });

  factory JobOffer.fromJson(Map<String, dynamic> json) {
    return JobOffer(
      id: _string(json['id']),
      companyId: _string(json['company_id']),
      title: _string(json['title']),
      description: _string(json['description']),
      sectorId: _optionalString(json['sector_id']),
      salaryMin: _parseNum(json['salary_min']) ?? 0,
      salaryMax: _parseNum(json['salary_max']) ?? 0,
      salaryCurrency: _optionalString(json['salary_currency']) ?? 'ARS',
      salaryPeriod: SalaryPeriod.fromWire(json['salary_period']),
      contractType: ContractType.fromWire(json['contract_type']),
      jornada: JornadaType.fromWire(json['jornada']),
      scheduleDays: _parseWeekDays(json['schedule_days']),
      scheduleDetail: _string(json['schedule_detail']),
      workMode: JobWorkMode.fromWire(json['work_mode']),
      provinciaId: _string(json['provincia_id']),
      localidadId: _string(json['localidad_id']),
      barrioId: _optionalString(json['barrio_id']),
      experience: ExperienceLevel.fromWire(json['experience']),
      availability: JobAvailability.fromWire(json['availability']),
      benefits: _parseStringList(json['benefits']),
      expiresAt: _parseDate(json['expires_at']),
      vacancies: _parseInt(json['vacancies']) ?? 1,
      status: JobStatus.fromWire(json['status']),
      publishedAt: _parseDate(json['published_at']),
      closedAt: _parseDate(json['closed_at']),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      company: JobOfferCompany.fromJson(json['company']),
    );
  }

  final String id;
  final String companyId;
  final String title;
  final String description;
  final String? sectorId;

  /// Montos en [salaryCurrency] (siempre ARS) por [salaryPeriod]. Un sueldo
  /// único se guarda con mínimo y máximo iguales.
  final num salaryMin;
  final num salaryMax;
  final String salaryCurrency;
  final SalaryPeriod? salaryPeriod;

  final ContractType? contractType;
  final JornadaType? jornada;
  final List<WeekDay> scheduleDays;
  final String scheduleDetail;
  final JobWorkMode? workMode;
  final String provinciaId;
  final String localidadId;
  final String? barrioId;
  final ExperienceLevel? experience;
  final JobAvailability? availability;
  final List<String> benefits;

  /// Instante de vencimiento (UTC tal como lo devuelve el servidor). La
  /// columna es NOT NULL; null acá solo si el valor no se pudo interpretar.
  final DateTime? expiresAt;

  final int vacancies;
  final JobStatus? status;

  /// Lo fija el servidor al publicar y se conserva al pausar y reanudar
  /// (0032): ordena el feed y el cliente no puede escribirlo.
  final DateTime? publishedAt;

  /// Lo fija el servidor al cerrar.
  final DateTime? closedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Solo viene en las lecturas que embeben la empresa (feed y detalle).
  final JobOfferCompany? company;

  /// ¿Ya pasó su vencimiento a [now]? Hasta que el cron de T-033 la marque
  /// `expired`, una oferta `active` vencida sigue figurando así en la base;
  /// el feed de candidatos ya la excluye y esto deja que la vista de la
  /// empresa lo diga.
  bool hasPassedExpiry(DateTime now) {
    final expiry = expiresAt;
    return expiry != null && !expiry.isAfter(now);
  }
}

String _string(Object? raw) => raw is String ? raw : '';

String? _optionalString(Object? raw) => raw is String ? raw : null;

/// `numeric` llega como número JSON; algunos proxies lo serializan como texto.
num? _parseNum(Object? raw) {
  if (raw is num) {
    return raw;
  }
  if (raw is String) {
    return num.tryParse(raw);
  }
  return null;
}

int? _parseInt(Object? raw) {
  if (raw is int) {
    return raw;
  }
  if (raw is num && raw == raw.truncate()) {
    return raw.toInt();
  }
  if (raw is String) {
    return int.tryParse(raw);
  }
  return null;
}

DateTime? _parseDate(Object? raw) {
  if (raw is! String || raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}

List<String> _parseStringList(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  return raw.whereType<String>().toList(growable: false);
}

/// Un día que este cliente no conoce se descarta en vez de inventar uno.
List<WeekDay> _parseWeekDays(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  return List<WeekDay>.unmodifiable([
    for (final entry in raw) ?WeekDay.fromWire(entry),
  ]);
}
