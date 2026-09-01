import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/data_failure.dart';
import '../domain/legal_document.dart';
import 'legal_repository.dart';

/// Implementación sobre PostgREST (`legal_documents` es de lectura pública,
/// también para `anon`: el copy legal se puede leer sin cuenta).
class SupabaseLegalRepository implements LegalRepository {
  SupabaseLegalRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<LegalDocument> fetchCurrent(LegalSlug slug) async {
    try {
      final row = await _client
          .from('legal_documents')
          .select('slug, version, title, body')
          .eq('slug', slug.wireName)
          .order('published_at', ascending: false)
          .limit(1)
          .single();
      return LegalDocument(
        slug: row['slug'] as String,
        version: row['version'] as String,
        title: row['title'] as String,
        body: row['body'] as String,
      );
    } catch (error) {
      throw DataFailure.from(error);
    }
  }
}
