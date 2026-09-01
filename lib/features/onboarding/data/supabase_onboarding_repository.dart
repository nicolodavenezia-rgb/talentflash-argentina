import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/data_failure.dart';
import '../domain/candidate_onboarding_data.dart';
import '../domain/company_onboarding_data.dart';
import '../domain/onboarding_validation.dart';
import 'onboarding_repository.dart';

/// Implementación sobre PostgREST + las RPC de la migración 0022. Recibe el
/// [SupabaseClient] por constructor para testearse sin proyecto remoto.
class SupabaseOnboardingRepository implements OnboardingRepository {
  SupabaseOnboardingRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const DataFailure(
        DataFailureCode.notAllowed,
        debugDetail: 'sin sesión',
      );
    }
    return user.id;
  }

  @override
  Future<bool> fetchOnboardingCompleted() => _guard(() async {
    final row = await _client
        .from('profiles')
        .select('onboarding_completed')
        .eq('id', _uid)
        .single();
    return row['onboarding_completed'] as bool;
  });

  @override
  Future<CandidateOnboardingData> fetchCandidateDraft() => _guard(() async {
    final profile = await _client
        .from('profiles')
        .select('full_name')
        .eq('id', _uid)
        .single();

    final row = await _client
        .from('candidate_profiles')
        .select(
          'birth_date, provincia_id, localidad_id, barrio_id, sector_id, '
          'availability, work_mode_prefs',
        )
        .eq('profile_id', _uid)
        .maybeSingle();

    final workModesRaw = (row?['work_mode_prefs'] as List?) ?? const [];
    return CandidateOnboardingData(
      fullName: profile['full_name'] as String?,
      birthDate: switch (row?['birth_date'] as String?) {
        null => null,
        final raw => DateTime.tryParse(raw),
      },
      provinceId: row?['provincia_id'] as String?,
      localityId: row?['localidad_id'] as String?,
      neighborhoodId: row?['barrio_id'] as String?,
      sectorId: row?['sector_id'] as String?,
      availability: CandidateAvailability.fromWire(row?['availability']),
      workModes: {
        for (final mode in workModesRaw) ?CandidateWorkMode.fromWire(mode),
      },
    );
  });

  @override
  Future<void> saveCandidateData(CandidateOnboardingData data) =>
      _guard(() async {
        await _client.rpc<void>(
          'save_candidate_onboarding',
          params: {
            'p_full_name': data.fullName,
            'p_birth_date': switch (data.birthDate) {
              null => null,
              final date =>
                '${date.year.toString().padLeft(4, '0')}-'
                    '${date.month.toString().padLeft(2, '0')}-'
                    '${date.day.toString().padLeft(2, '0')}',
            },
            'p_provincia_id': data.provinceId,
            'p_localidad_id': data.localityId,
            'p_barrio_id': data.neighborhoodId,
            'p_sector_id': data.sectorId,
            'p_availability': data.availability?.wireName,
            'p_work_modes': [for (final mode in data.workModes) mode.wireName],
          },
        );
      });

  @override
  Future<void> completeCandidateOnboarding() => _guard(() async {
    await _client.rpc<void>('complete_candidate_onboarding');
  });

  @override
  Future<String> completeCompanyOnboarding(CompanyOnboardingData data) =>
      _guard(() async {
        final companyId = await _client.rpc<String>(
          'complete_company_onboarding',
          params: {
            'p_legal_name': data.legalName,
            'p_trade_name': data.tradeName,
            'p_cuit': OnboardingValidation.normalizeCuit(data.cuit ?? ''),
            'p_sector_id': data.sectorId,
            'p_size_range': data.sizeRange?.wireName,
            'p_provincia_id': data.provinceId,
            'p_localidad_id': data.localityId,
            'p_website': switch (data.website) {
              null => null,
              final raw => OnboardingValidation.normalizeWebsite(raw),
            },
            'p_applicant_full_name': data.applicantFullName,
            'p_applicant_position': data.applicantPosition,
            'p_applicant_relationship': data.applicantRelationship?.wireName,
          },
        );
        return companyId;
      });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw DataFailure.from(error);
    }
  }
}
