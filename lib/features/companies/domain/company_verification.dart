import 'dart:typed_data';

import '../data/company_access_repository.dart';

/// Motivo de rechazo de una verificación (T-028).
///
/// Lista CERRADA, idéntica a la que valida `admin_review_company_verification`
/// en la migración 0028. Si acá apareciera un valor que el servidor no acepta,
/// el panel ofrecería un botón que siempre falla; por eso el mapeo es
/// explícito y `fromWire` devuelve null ante cualquier cosa desconocida en vez
/// de inventar un caso.
enum VerificationRejectionReason {
  cuitNoCoincide('cuit_no_coincide'),
  constanciaIlegible('constancia_ilegible'),
  constanciaVencida('constancia_vencida'),
  datosIncompletos('datos_incompletos'),
  empresaNoOperativa('empresa_no_operativa'),
  otro('otro');

  const VerificationRejectionReason(this.wireName);

  final String wireName;

  static VerificationRejectionReason? fromWire(Object? raw) {
    for (final value in VerificationRejectionReason.values) {
      if (value.wireName == raw) {
        return value;
      }
    }
    return null;
  }
}

/// Extensiones aceptadas para la constancia de ARCA.
///
/// El cliente NO elige el path: manda una de estas extensiones y el servidor
/// arma `<company_id>/constancia-arca.<ext>` (0028). `jpeg` y `jpg` colapsan al
/// mismo valor, igual que en SQL.
enum ConstanciaFormat {
  pdf('pdf', 'application/pdf'),
  jpg('jpg', 'image/jpeg'),
  png('png', 'image/png'),
  webp('webp', 'image/webp');

  const ConstanciaFormat(this.wireName, this.contentType);

  final String wireName;
  final String contentType;

  /// Deduce el formato del nombre de archivo elegido. Devuelve null si la
  /// extensión no está en la lista: el servidor la rechazaría igual, pero así
  /// la pantalla lo puede decir sin ida y vuelta.
  static ConstanciaFormat? fromFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) {
      return null;
    }
    final extension = fileName.substring(dot + 1).toLowerCase();
    return switch (extension) {
      'pdf' => ConstanciaFormat.pdf,
      'jpg' || 'jpeg' => ConstanciaFormat.jpg,
      'png' => ConstanciaFormat.png,
      'webp' => ConstanciaFormat.webp,
      _ => null,
    };
  }
}

/// Tamaño máximo de la constancia. Es el mismo límite que declara el bucket
/// `company-docs` (5 MiB, migración 0029): acá solo sirve para avisar antes de
/// gastar la subida; la autoridad es el servidor.
const constanciaMaxBytes = 5 * 1024 * 1024;

/// Archivo elegido por la persona para adjuntar como constancia.
class PickedConstancia {
  const PickedConstancia({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;

  ConstanciaFormat? get format => ConstanciaFormat.fromFileName(fileName);

  bool get isTooLarge => bytes.length > constanciaMaxBytes;
}

/// Selector de archivo inyectable: la implementación real usa el plugin de
/// plataforma; los tests inyectan un doble sin abrir UI nativa.
abstract interface class ConstanciaPicker {
  Future<PickedConstancia?> pickDocument();
}

/// Estado de verificación de MI empresa junto con su última solicitud
/// (respuesta de la RPC `my_company_verification`).
///
/// [companyStatus] es la fuente de verdad para el resto de la app; el resto
/// describe la solicitud y puede no existir todavía.
class CompanyVerification {
  const CompanyVerification({
    required this.companyId,
    required this.companyStatus,
    this.requestId,
    this.requestStatus,
    this.cuitSubmitted,
    this.documentPath,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
  });

  factory CompanyVerification.fromJson(Map<String, dynamic> json) {
    return CompanyVerification(
      companyId: json['company_id'] as String? ?? '',
      companyStatus: CompanyVerificationStatus.fromWire(json['company_status']),
      requestId: json['request_id'] as String?,
      requestStatus: CompanyVerificationStatus.fromWire(json['request_status']),
      cuitSubmitted: json['cuit_submitted'] as String?,
      documentPath: json['document_path'] as String?,
      rejectionReason: VerificationRejectionReason.fromWire(
        json['rejection_reason'],
      ),
      submittedAt: _parseDate(json['submitted_at']),
      reviewedAt: _parseDate(json['reviewed_at']),
    );
  }

  final String companyId;

  /// Null si el servidor devolvió un estado que esta versión del cliente no
  /// conoce. Se trata como "no verificada": jamás como aprobada.
  final CompanyVerificationStatus? companyStatus;

  final String? requestId;
  final CompanyVerificationStatus? requestStatus;
  final String? cuitSubmitted;
  final String? documentPath;
  final VerificationRejectionReason? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  /// Hay una solicitud esperando respuesta.
  bool get hasOpenRequest =>
      requestStatus == CompanyVerificationStatus.pending ||
      requestStatus == CompanyVerificationStatus.inReview;

  /// Se puede (re)enviar la solicitud: nunca cuando ya está aprobada ni
  /// mientras hay una abierta.
  bool get canSubmit =>
      companyStatus != CompanyVerificationStatus.approved && !hasOpenRequest;
}

/// Una solicitud tal como la ve el panel administrativo
/// (`admin_list_company_verifications`).
class CompanyVerificationRequest {
  const CompanyVerificationRequest({
    required this.requestId,
    required this.companyId,
    required this.companyName,
    required this.requestStatus,
    required this.cuitSubmitted,
    this.companyStatus,
    this.documentPath,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
  });

  factory CompanyVerificationRequest.fromJson(Map<String, dynamic> json) {
    return CompanyVerificationRequest(
      requestId: json['request_id'] as String? ?? '',
      companyId: json['company_id'] as String? ?? '',
      companyName: json['company_name'] as String? ?? '',
      requestStatus: CompanyVerificationStatus.fromWire(json['request_status']),
      cuitSubmitted: json['cuit_submitted'] as String? ?? '',
      companyStatus: CompanyVerificationStatus.fromWire(json['company_status']),
      documentPath: json['document_path'] as String?,
      rejectionReason: VerificationRejectionReason.fromWire(
        json['rejection_reason'],
      ),
      submittedAt: _parseDate(json['submitted_at']),
      reviewedAt: _parseDate(json['reviewed_at']),
    );
  }

  final String requestId;
  final String companyId;
  final String companyName;
  final CompanyVerificationStatus? requestStatus;
  final String cuitSubmitted;
  final CompanyVerificationStatus? companyStatus;
  final String? documentPath;
  final VerificationRejectionReason? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
}

DateTime? _parseDate(Object? raw) {
  if (raw is! String || raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}
