import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/data_failure.dart';
import '../domain/catalog.dart';
import 'catalog_repository.dart';

/// Implementación sobre PostgREST (tablas `geo_*`, `sectors`,
/// `sector_translations`; lectura pública, ver 0015).
class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository(this._client, {this.locale = 'es-AR'});

  final SupabaseClient _client;
  final String locale;

  @override
  Future<List<GeoProvince>> fetchProvinces() => _guard(() async {
    final rows = await _client
        .from('geo_provincias')
        .select('id, name')
        .order('name', ascending: true);
    return [
      for (final row in rows)
        GeoProvince(id: row['id'] as String, name: row['name'] as String),
    ];
  });

  @override
  Future<List<GeoLocality>> fetchLocalities(String provinceId) =>
      _guard(() async {
        final rows = await _client
            .from('geo_localidades')
            .select('id, name')
            .eq('provincia_id', provinceId)
            .order('name', ascending: true);
        return [
          for (final row in rows)
            GeoLocality(id: row['id'] as String, name: row['name'] as String),
        ];
      });

  @override
  Future<List<GeoNeighborhood>> fetchNeighborhoods(String localityId) => _guard(
    () async {
      final rows = await _client
          .from('geo_barrios')
          .select('id, name')
          .eq('localidad_id', localityId)
          .order('name', ascending: true);
      return [
        for (final row in rows)
          GeoNeighborhood(id: row['id'] as String, name: row['name'] as String),
      ];
    },
  );

  @override
  Future<List<Sector>> fetchSectors() => _guard(() async {
    final sectors = await _client
        .from('sectors')
        .select('id, code, sort_order')
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    final translations = await _client
        .from('sector_translations')
        .select('sector_id, name')
        .eq('locale', locale);

    final nameById = {
      for (final row in translations)
        row['sector_id'] as String: row['name'] as String,
    };
    return [
      for (final row in sectors)
        Sector(
          id: row['id'] as String,
          code: row['code'] as String,
          // Sin traducción cargada se muestra el código antes que nada roto.
          name: nameById[row['id']] ?? (row['code'] as String),
        ),
    ];
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw DataFailure.from(error);
    }
  }
}
