import '../domain/catalog.dart';

/// Catálogos de geografía (cascada provincia → localidad → barrio) y de
/// sectores. Solo lectura; los datos viven en la base (T-016: sin IDs
/// hardcodeados en la app).
abstract interface class CatalogRepository {
  Future<List<GeoProvince>> fetchProvinces();

  Future<List<GeoLocality>> fetchLocalities(String provinceId);

  /// Puede ser vacío: no toda localidad tiene barrios cargados. Cuando los
  /// tiene, el barrio es obligatorio en el onboarding de candidato.
  Future<List<GeoNeighborhood>> fetchNeighborhoods(String localityId);

  Future<List<Sector>> fetchSectors();
}
