import 'consent_type.dart';

/// Versión vigente de un consentimiento (fila de `consent_versions`).
class ConsentRequirement {
  const ConsentRequirement({
    required this.type,
    required this.version,
    required this.documentSlug,
    required this.isMandatory,
  });

  final ConsentType type;
  final String version;
  final String documentSlug;
  final bool isMandatory;

  @override
  bool operator ==(Object other) =>
      other is ConsentRequirement &&
      other.type == type &&
      other.version == version &&
      other.documentSlug == documentSlug &&
      other.isMandatory == isMandatory;

  @override
  int get hashCode => Object.hash(type, version, documentSlug, isMandatory);
}

/// Último evento del ledger para un consentimiento del usuario.
class ConsentDecision {
  const ConsentDecision({
    required this.type,
    required this.granted,
    required this.version,
  });

  final ConsentType type;
  final bool granted;
  final String version;

  @override
  bool operator ==(Object other) =>
      other is ConsentDecision &&
      other.type == type &&
      other.granted == granted &&
      other.version == version;

  @override
  int get hashCode => Object.hash(type, granted, version);
}

/// Estado de consentimientos del usuario: versiones vigentes + su última
/// decisión por tipo. El estado "vigente" exige otorgamiento **y** versión
/// actual (fail-closed, igual que `private.consent_current` en la base).
class ConsentSnapshot {
  const ConsentSnapshot({
    required this.requirements,
    required this.latestByType,
  });

  const ConsentSnapshot.empty()
    : requirements = const [],
      latestByType = const {};

  final List<ConsentRequirement> requirements;
  final Map<ConsentType, ConsentDecision> latestByType;

  ConsentRequirement? requirementFor(ConsentType type) {
    for (final requirement in requirements) {
      if (requirement.type == type) {
        return requirement;
      }
    }
    return null;
  }

  /// `true` solo si la última decisión es un otorgamiento de la versión
  /// vigente.
  bool isCurrentlyGranted(ConsentType type) {
    final requirement = requirementFor(type);
    final decision = latestByType[type];
    if (requirement == null || decision == null) {
      return false;
    }
    return decision.granted && decision.version == requirement.version;
  }

  /// Obligatorios que faltan (nunca aceptados, revocados o de versión vieja):
  /// esto dispara el reconsentimiento aunque el onboarding esté completo.
  List<ConsentRequirement> get pendingMandatory => [
    for (final requirement in requirements)
      if (requirement.isMandatory && !isCurrentlyGranted(requirement.type))
        requirement,
  ];
}
