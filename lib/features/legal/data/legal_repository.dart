import '../domain/legal_document.dart';

/// Acceso de solo lectura a los documentos legales publicados (T-020).
/// Debe funcionar también sin sesión: las rutas `/legal/*` son públicas.
abstract interface class LegalRepository {
  /// Versión vigente (la última publicada) del documento pedido.
  Future<LegalDocument> fetchCurrent(LegalSlug slug);
}
