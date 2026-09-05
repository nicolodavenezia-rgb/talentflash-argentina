import '../../../core/localization/gen/app_localizations.dart';
import '../../../shared/models/data_failure.dart';
import '../domain/avatar.dart';
import '../domain/candidate_profile.dart';
import '../domain/profile_completeness.dart';
import '../domain/weekly_availability.dart';

/// Textos es-AR de la feature de perfiles: todo sale del ARB, nunca de un
/// mensaje interno de Postgres ni de la Edge Function.
abstract final class ProfileCopy {
  static String dataFailure(AppLocalizations l10n, DataFailure failure) {
    return switch (failure.code) {
      DataFailureCode.notAllowed => l10n.dataFailureNotAllowed,
      DataFailureCode.underage => l10n.dataFailureInvalidData,
      DataFailureCode.invalidData => l10n.dataFailureInvalidData,
      DataFailureCode.staleConsent => l10n.dataFailureStaleConsent,
      DataFailureCode.duplicate => l10n.dataFailureDuplicate,
      DataFailureCode.invalidCuit => l10n.dataFailureInvalidCuit,
      DataFailureCode.secondFactorRequired => l10n.dataFailureSecondFactor,
      DataFailureCode.ambiguousCompany => l10n.dataFailureAmbiguousCompany,
      DataFailureCode.network => l10n.dataFailureNetwork,
      DataFailureCode.unknown => l10n.dataFailureUnknown,
    };
  }

  static String avatarFailure(AppLocalizations l10n, AvatarFailure failure) {
    return switch (failure.code) {
      AvatarFailureCode.tooLarge => l10n.avatarErrorTooLarge,
      AvatarFailureCode.invalidImage => l10n.avatarErrorInvalid,
      AvatarFailureCode.unsupportedFormat => l10n.avatarErrorUnsupported,
      AvatarFailureCode.notAllowed => l10n.avatarErrorNotAllowed,
      AvatarFailureCode.network => l10n.avatarErrorNetwork,
      AvatarFailureCode.unknown => l10n.avatarErrorUnknown,
    };
  }

  static String weekDay(AppLocalizations l10n, WeekDay day) {
    return switch (day) {
      WeekDay.lun => l10n.dayLun,
      WeekDay.mar => l10n.dayMar,
      WeekDay.mie => l10n.dayMie,
      WeekDay.jue => l10n.dayJue,
      WeekDay.vie => l10n.dayVie,
      WeekDay.sab => l10n.daySab,
      WeekDay.dom => l10n.dayDom,
    };
  }

  static String experienceLevel(AppLocalizations l10n, ExperienceLevel level) {
    return switch (level) {
      ExperienceLevel.sinExperiencia => l10n.experienceLevelSinExperiencia,
      ExperienceLevel.hasta1Anio => l10n.experienceLevelHasta1Anio,
      ExperienceLevel.de1A3Anios => l10n.experienceLevel1a3,
      ExperienceLevel.de3A5Anios => l10n.experienceLevel3a5,
      ExperienceLevel.masDe5Anios => l10n.experienceLevelMas5,
    };
  }

  static String educationLevel(AppLocalizations l10n, EducationLevel level) {
    return switch (level) {
      EducationLevel.primario => l10n.educationLevelPrimario,
      EducationLevel.secundario => l10n.educationLevelSecundario,
      EducationLevel.terciario => l10n.educationLevelTerciario,
      EducationLevel.universitario => l10n.educationLevelUniversitario,
      EducationLevel.posgrado => l10n.educationLevelPosgrado,
      EducationLevel.curso => l10n.educationLevelCurso,
    };
  }

  static String slot(AppLocalizations l10n, AvailabilitySlot slot) {
    final day = weekDay(l10n, slot.day);
    return slot.crossesMidnight
        ? l10n.profileScheduleNextDay(day, slot.startLabel, slot.endLabel)
        : l10n.profileScheduleSameDay(day, slot.startLabel, slot.endLabel);
  }

  static String presentationStatus(
    AppLocalizations l10n,
    PresentationStatus status,
  ) {
    return switch (status) {
      PresentationStatus.none ||
      PresentationStatus.removed => l10n.profilePresentationNone,
      PresentationStatus.uploading ||
      PresentationStatus.processing => l10n.profilePresentationProcessing,
      PresentationStatus.ready => l10n.profilePresentationReady,
      PresentationStatus.failed => l10n.profilePresentationFailed,
      PresentationStatus.expired => l10n.profilePresentationExpired,
    };
  }

  static String completenessItem(AppLocalizations l10n, CompletenessItem item) {
    return switch (item.labelKey) {
      'base' => l10n.profileCompletenessItemBase,
      'headline' => l10n.profileCompletenessItemHeadline,
      'bio' => l10n.profileCompletenessItemBio,
      'experience' => l10n.profileCompletenessItemExperience,
      'skills' => l10n.profileCompletenessItemSkills,
      'languages' => l10n.profileCompletenessItemLanguages,
      'schedule' => l10n.profileCompletenessItemSchedule,
      'education' => l10n.profileCompletenessItemEducation,
      'avatar' => l10n.profileCompletenessItemAvatar,
      'presentation' => l10n.profileCompletenessItemPresentation,
      _ => item.labelKey,
    };
  }
}
