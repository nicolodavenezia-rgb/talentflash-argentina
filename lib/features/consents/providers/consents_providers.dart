import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/supabase_client_provider.dart';
import '../data/consents_repository.dart';
import '../data/supabase_consents_repository.dart';

/// Repositorio de consentimientos. En tests se sobreescribe con un fake.
final consentsRepositoryProvider = Provider<ConsentsRepository>((ref) {
  return SupabaseConsentsRepository(ref.watch(supabaseClientProvider));
});
