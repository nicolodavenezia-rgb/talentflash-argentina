import 'candidate_profile.dart';

/// Un componente de la completitud, con su peso y si está cumplido.
/// `labelKey` es un identificador estable que la UI traduce vía ARB.
class CompletenessItem {
  const CompletenessItem({
    required this.labelKey,
    required this.weight,
    required this.achieved,
  });

  final String labelKey;
  final int weight;
  final bool achieved;
}

/// Score de completitud del perfil (T-025).
///
/// Es una AYUDA VISUAL para el dueño del perfil, nada más: no se persiste, no
/// viaja en la proyección para empresas, no participa de ningún ranking y no
/// mide empleabilidad ni aptitud. Los pesos están documentados en
/// UX_FLOWS.md; foto, presentación y educación SUMAN pero jamás son requisito
/// (la preparación para postularse es un booleano aparte que no los mira).
class ProfileCompleteness {
  const ProfileCompleteness({required this.items});

  final List<CompletenessItem> items;

  int get score {
    var total = 0;
    for (final item in items) {
      if (item.achieved) {
        total += item.weight;
      }
    }
    return total.clamp(0, 100);
  }

  List<CompletenessItem> get pending =>
      items.where((item) => !item.achieved).toList(growable: false);

  /// Cálculo puro y determinista: mismo resultado sin importar el orden de
  /// las listas; texto de solo espacios no cuenta; duplicados no inflan.
  factory ProfileCompleteness.of(CandidateProfile profile) {
    bool filled(String? value) => value != null && value.trim().isNotEmpty;

    final baseComplete =
        filled(profile.fullName) &&
        profile.province != null &&
        profile.locality != null &&
        profile.sector != null &&
        profile.availability != null &&
        profile.workModes.isNotEmpty;

    final distinctSkills = profile.skills
        .map((skill) => skill.trim().toLowerCase())
        .where((skill) => skill.isNotEmpty)
        .toSet();
    final distinctLanguages = profile.languages
        .map((language) => language.trim().toLowerCase())
        .where((language) => language.isNotEmpty)
        .toSet();

    return ProfileCompleteness(
      items: [
        CompletenessItem(labelKey: 'base', weight: 25, achieved: baseComplete),
        CompletenessItem(
          labelKey: 'headline',
          weight: 10,
          achieved: filled(profile.headline),
        ),
        CompletenessItem(
          labelKey: 'bio',
          weight: 10,
          achieved: filled(profile.bio),
        ),
        CompletenessItem(
          labelKey: 'experience',
          weight: 15,
          achieved: profile.workHistory.isNotEmpty,
        ),
        CompletenessItem(
          labelKey: 'skills',
          weight: 10,
          achieved: distinctSkills.length >= 3,
        ),
        CompletenessItem(
          labelKey: 'languages',
          weight: 5,
          achieved: distinctLanguages.isNotEmpty,
        ),
        CompletenessItem(
          labelKey: 'schedule',
          weight: 10,
          achieved: profile.weeklyAvailability.isNotEmpty,
        ),
        CompletenessItem(
          labelKey: 'education',
          weight: 5,
          achieved: profile.education.isNotEmpty,
        ),
        CompletenessItem(
          labelKey: 'avatar',
          weight: 5,
          achieved: profile.avatarPath != null,
        ),
        CompletenessItem(
          labelKey: 'presentation',
          weight: 5,
          achieved: profile.presentationStatus == PresentationStatus.ready,
        ),
      ],
    );
  }
}
