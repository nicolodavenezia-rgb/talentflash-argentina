import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/supabase_client_provider.dart';
import '../data/legal_repository.dart';
import '../data/supabase_legal_repository.dart';
import '../domain/legal_document.dart';

/// Repositorio de documentos legales. Se sobreescribe en tests.
final legalRepositoryProvider = Provider<LegalRepository>((ref) {
  return SupabaseLegalRepository(ref.watch(supabaseClientProvider));
});

/// Documento legal vigente por slug; `ref.refresh` reintenta ante error.
final legalDocumentProvider = FutureProvider.family<LegalDocument, LegalSlug>((
  ref,
  slug,
) {
  return ref.watch(legalRepositoryProvider).fetchCurrent(slug);
});
