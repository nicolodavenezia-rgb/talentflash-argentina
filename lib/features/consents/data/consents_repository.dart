import '../domain/consent_snapshot.dart';
import '../domain/consent_type.dart';

/// Frontera de la app con el ledger `consents` (T-018).
///
/// El ledger es append-only: otorgar y revocar insertan filas nuevas, jamás
/// se edita ni borra nada. La base rechaza otorgamientos de una versión que
/// no sea la vigente y deduplica el comando idéntico repetido.
abstract interface class ConsentsRepository {
  /// Versiones vigentes + última decisión del usuario por tipo.
  Future<ConsentSnapshot> loadSnapshot();

  /// Registra un otorgamiento de la versión vigente [version].
  Future<void> grant(ConsentType type, {required String version});

  /// Registra una revocación (fila nueva con `granted = false`).
  Future<void> revoke(ConsentType type, {required String version});
}
