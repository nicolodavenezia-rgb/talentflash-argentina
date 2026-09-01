/// Consentimientos que la aplicación puede solicitar (T-018, PRIVACY.md §4).
///
/// `ai_training` NO existe acá a propósito: el MVP no lo solicita (SPEC §6) y
/// no debe haber ninguna superficie de UI capaz de otorgarlo. En la base
/// tampoco tiene versión vigente, así que un intento directo también falla.
enum ConsentType {
  /// Aceptación de los Términos y condiciones (aceptación contractual;
  /// se registra en el mismo ledger auditable que los consentimientos).
  termsAcceptance('terms_acceptance'),

  /// Tratamiento de datos para operar la cuenta (obligatorio).
  dataProcessing('data_processing'),

  /// Declaración de mayoría de 18 años (obligatoria).
  ageDeclaration('age_declaration'),

  /// Publicación del perfil y el video ante empresas (opcional, revocable).
  videoProfilePublication('video_profile_publication'),

  /// Funciones de IA sobre los datos propios (opcional, revocable).
  aiFeatures('ai_features');

  const ConsentType(this.wireName);

  /// Valor exacto del enum `consent_type` en Postgres.
  final String wireName;

  /// Correspondencia exacta o `null` (fail-closed): un tipo desconocido que
  /// aparezca en la base se ignora, nunca se adivina.
  static ConsentType? fromWire(Object? raw) {
    for (final type in ConsentType.values) {
      if (raw == type.wireName) {
        return type;
      }
    }
    return null;
  }
}
