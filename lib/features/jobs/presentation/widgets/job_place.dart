import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../onboarding/domain/catalog.dart';
import '../../../onboarding/providers/onboarding_providers.dart';

/// Lugar de trabajo de una oferta con los nombres del catálogo geográfico:
/// "Barrio, Localidad" si hay barrio, si no "Localidad, Provincia" (o solo la
/// localidad cuando se llama igual que la provincia, como CABA).
///
/// La oferta guarda ids; los nombres salen de los mismos providers de
/// catálogo que usa el onboarding, que quedan en caché toda la sesión.
/// Devuelve null mientras cargan o si no se pudieron leer: la pantalla decide
/// qué mostrar en ese caso, nunca un id crudo.
String? watchJobPlace(
  WidgetRef ref, {
  required String? provinciaId,
  required String? localidadId,
  required String? barrioId,
}) {
  if (provinciaId == null ||
      provinciaId.isEmpty ||
      localidadId == null ||
      localidadId.isEmpty) {
    return null;
  }
  final provinces = ref.watch(provincesProvider).value;
  final localities = ref.watch(localitiesProvider(provinciaId)).value;
  final neighborhoods = barrioId == null
      ? null
      : ref.watch(neighborhoodsProvider(localidadId)).value;

  final provinceName = _nameOf<GeoProvince>(
    provinces,
    provinciaId,
    (item) => item.id,
    (item) => item.name,
  );
  final localityName = _nameOf<GeoLocality>(
    localities,
    localidadId,
    (item) => item.id,
    (item) => item.name,
  );
  if (localityName == null) {
    return null;
  }
  if (barrioId != null) {
    final neighborhoodName = _nameOf<GeoNeighborhood>(
      neighborhoods,
      barrioId,
      (item) => item.id,
      (item) => item.name,
    );
    if (neighborhoodName == null) {
      return null;
    }
    return '$neighborhoodName, $localityName';
  }
  if (provinceName == null || provinceName == localityName) {
    return localityName;
  }
  return '$localityName, $provinceName';
}

String? _nameOf<T>(
  List<T>? items,
  String id,
  String Function(T item) idOf,
  String Function(T item) nameOf,
) {
  for (final item in items ?? <T>[]) {
    if (idOf(item) == id) {
      return nameOf(item);
    }
  }
  return null;
}
