import '../../../core/localization/gen/app_localizations.dart';
import '../../../shared/models/data_failure.dart';
import '../../notifications/domain/notification_prefs.dart';
import '../domain/candidate_onboarding_data.dart';
import '../domain/company_onboarding_data.dart';
import '../domain/onboarding_validation.dart';

/// Traducción de códigos de dominio a textos es-AR del ARB. Ningún mensaje
/// interno de Postgres/PostgREST llega a la pantalla (SECURITY.md §2).
abstract final class OnboardingCopy {
  static String failure(AppLocalizations l10n, DataFailure failure) =>
      switch (failure.code) {
        DataFailureCode.notAllowed => l10n.dataFailureNotAllowed,
        // La minoría de edad tiene pantalla propia; si igual llega como
        // error genérico, el texto honesto es el de datos inválidos.
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

  static String fullNameIssue(AppLocalizations l10n, FullNameIssue issue) =>
      switch (issue) {
        FullNameIssue.empty || FullNameIssue.tooShort => l10n.fullNameError,
      };

  static String birthDateIssue(AppLocalizations l10n, BirthDateIssue issue) =>
      switch (issue) {
        BirthDateIssue.empty => l10n.birthDateErrorRequired,
        BirthDateIssue.invalidFormat => l10n.birthDateErrorInvalid,
        BirthDateIssue.inFuture => l10n.birthDateErrorFuture,
        // La minoría no se muestra como error de campo: bloquea el wizard con
        // su propia pantalla, sin persistir nada.
        BirthDateIssue.underage => l10n.birthDateErrorInvalid,
      };

  static String cuitIssue(AppLocalizations l10n, CuitIssue issue) =>
      switch (issue) {
        CuitIssue.empty => l10n.cuitErrorRequired,
        CuitIssue.invalidCharacters => l10n.cuitErrorCharacters,
        CuitIssue.wrongLength => l10n.cuitErrorLength,
        CuitIssue.checkDigit => l10n.cuitErrorCheckDigit,
      };

  static String availability(
    AppLocalizations l10n,
    CandidateAvailability value,
  ) => switch (value) {
    CandidateAvailability.inmediata => l10n.availabilityImmediate,
    CandidateAvailability.en1Semana => l10n.availabilityOneWeek,
    CandidateAvailability.en2Semanas => l10n.availabilityTwoWeeks,
    CandidateAvailability.en1Mes => l10n.availabilityOneMonth,
    CandidateAvailability.aConvenir => l10n.availabilityToAgree,
  };

  static String workMode(AppLocalizations l10n, CandidateWorkMode value) =>
      switch (value) {
        CandidateWorkMode.presencial => l10n.workModeOnSite,
        CandidateWorkMode.hibrido => l10n.workModeHybrid,
        CandidateWorkMode.remoto => l10n.workModeRemote,
      };

  static String companySize(AppLocalizations l10n, CompanySizeRange value) =>
      switch (value) {
        CompanySizeRange.from1To10 => l10n.companySize1to10,
        CompanySizeRange.from11To50 => l10n.companySize11to50,
        CompanySizeRange.from51To200 => l10n.companySize51to200,
        CompanySizeRange.from201To500 => l10n.companySize201to500,
        CompanySizeRange.moreThan500 => l10n.companySizeMoreThan500,
      };

  static String relationship(
    AppLocalizations l10n,
    CompanyRelationship value,
  ) => switch (value) {
    CompanyRelationship.owner => l10n.relationshipOwner,
    CompanyRelationship.partner => l10n.relationshipPartner,
    CompanyRelationship.manager => l10n.relationshipManager,
    CompanyRelationship.hr => l10n.relationshipHr,
    CompanyRelationship.other => l10n.relationshipOther,
  };

  static String notificationCategory(
    AppLocalizations l10n,
    NotificationCategory category,
  ) => switch (category) {
    NotificationCategory.applicationUpdate =>
      l10n.notifCategoryApplicationUpdate,
    NotificationCategory.newApplication => l10n.notifCategoryNewApplication,
    NotificationCategory.invitation => l10n.notifCategoryInvitation,
    NotificationCategory.message => l10n.notifCategoryMessage,
    NotificationCategory.verificationUpdate =>
      l10n.notifCategoryVerificationUpdate,
    NotificationCategory.system => l10n.notifCategorySystem,
  };

  static String birthDateText(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}
