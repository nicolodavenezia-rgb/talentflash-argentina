/// Catálogos de solo lectura que alimentan los wizards (geo INDEC y sectores).
/// Vienen SIEMPRE de la base (`DATA_MODEL.md` §2.9): ningún ID hardcodeado.
library;

class GeoProvince {
  const GeoProvince({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is GeoProvince && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

class GeoLocality {
  const GeoLocality({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is GeoLocality && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

class GeoNeighborhood {
  const GeoNeighborhood({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is GeoNeighborhood && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

class Sector {
  const Sector({required this.id, required this.code, required this.name});

  final String id;
  final String code;

  /// Nombre localizado (es-AR en el MVP), desde `sector_translations`.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is Sector &&
      other.id == id &&
      other.code == code &&
      other.name == name;

  @override
  int get hashCode => Object.hash(id, code, name);
}
