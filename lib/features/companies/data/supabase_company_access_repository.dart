import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/data_failure.dart';
import 'company_access_repository.dart';

/// Lectura del estado de verificación propio vía PostgREST bajo RLS
/// (`cm_select` + `comp_member_select`: la empresa solo ve lo suyo).
class SupabaseCompanyAccessRepository implements CompanyAccessRepository {
  SupabaseCompanyAccessRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CompanyVerificationStatus?> fetchOwnVerificationStatus() async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) {
        throw const DataFailure(DataFailureCode.notAllowed);
      }
      final row = await _client
          .from('company_members')
          .select('company_profiles(verification_status)')
          .eq('profile_id', uid)
          .limit(1)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      final company = row['company_profiles'];
      if (company is! Map<String, dynamic>) {
        return null;
      }
      return CompanyVerificationStatus.fromWire(company['verification_status']);
    } catch (error) {
      if (error is DataFailure) {
        rethrow;
      }
      throw DataFailure.from(error);
    }
  }
}
