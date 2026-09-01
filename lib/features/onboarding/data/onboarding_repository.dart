import '../domain/candidate_onboarding_data.dart';
import '../domain/company_onboarding_data.dart';

/// Frontera de la app con la persistencia del onboarding (T-016/T-017).
///
/// La finalización es SIEMPRE server-side: las RPC validan datos, edad y
/// consentimientos y fallan cerradas. El cliente no puede marcar
/// `onboarding_completed` por su cuenta (trigger de 0022).
abstract interface class OnboardingRepository {
  /// `profiles.onboarding_completed` del usuario actual.
  Future<bool> fetchOnboardingCompleted();

  /// Avance guardado del wizard de candidato, para retomar donde quedó.
  Future<CandidateOnboardingData> fetchCandidateDraft();

  /// Persiste la instantánea completa del wizard (RPC transaccional e
  /// idempotente; si un dato es inválido no queda NADA persistido).
  Future<void> saveCandidateData(CandidateOnboardingData data);

  /// Valida y marca el onboarding de candidato como completo (RPC).
  Future<void> completeCandidateOnboarding();

  /// Crea empresa + owner + datos del solicitante atómicamente y marca el
  /// onboarding completo (RPC idempotente). Devuelve el id de la empresa.
  Future<String> completeCompanyOnboarding(CompanyOnboardingData data);
}
