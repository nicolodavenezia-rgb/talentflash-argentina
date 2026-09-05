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
  /// Estado de verificación de LA empresa del caller.
  ///
  /// - Sin ninguna empresa: `null`.
  /// - Con una: su estado exacto (o `null` si la base informa un valor que este
  ///   enum no conoce — un estado desconocido NO se muestra como verificado).
  /// - Con más de una: lanza `DataFailure(DataFailureCode.ambiguousCompany)`.
  ///   NO elige una. La versión anterior devolvía "la primera", que era la que
  ///   el planner tuviera a mano, y podía informar el estado de la empresa
  ///   equivocada.
  Future<CompanyVerificationStatus?> fetchOwnVerificationStatus();
}
