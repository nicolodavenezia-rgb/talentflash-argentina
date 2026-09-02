/// Estado de verificación de la empresa del caller (enum
/// `verification_status` de la base).
enum CompanyVerificationStatus {
  pending('pending'),
  inReview('in_review'),
  approved('approved'),
  rejected('rejected');

  const CompanyVerificationStatus(this.wireName);

  final String wireName;

  static CompanyVerificationStatus? fromWire(Object? raw) {
    for (final value in CompanyVerificationStatus.values) {
      if (value.wireName == raw) {
        return value;
      }
    }
    return null;
  }
}

/// Acceso mínimo de la empresa a SU propio estado (Bloque D): la vista de
/// candidato necesita distinguir "mi empresa está pendiente" de "candidato no
/// disponible" usando SOLO datos propios de la empresa (nunca del candidato).
/// El CRUD completo de empresa es T-026 (Bloque E).
abstract interface class CompanyAccessRepository {
  /// Estado de verificación de la primera empresa de la que el caller es
  /// miembro, o null si todavía no integra ninguna.
  Future<CompanyVerificationStatus?> fetchOwnVerificationStatus();
}
