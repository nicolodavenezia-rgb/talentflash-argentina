import 'package:intl/intl.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../shared/models/data_failure.dart';
import '../domain/job_offer.dart';
import '../domain/job_offer_enums.dart';
import '../domain/job_offer_lifecycle.dart';
import '../domain/job_offer_validation.dart';
import '../providers/job_offer_actions_controller.dart';
import '../providers/job_offer_editor_controller.dart';

/// Textos es-AR de la feature de ofertas (T-030). Todo sale del ARB por un
/// `switch` exhaustivo: ni un `wireName` ni un mensaje de Postgres llegan a
/// la pantalla (SECURITY.md §2).
abstract final class JobsCopy {
  /// Fallo de lectura o escritura de ofertas. Recibe `Object?` porque los
  /// estados de Riverpod tipan el error así; cualquier cosa que no sea un
  /// [DataFailure] se trata como desconocida.
  static String failure(AppLocalizations l10n, Object? error) {
    final code = error is DataFailure ? error.code : DataFailureCode.unknown;
    return switch (code) {
      DataFailureCode.notAllowed => l10n.jobsFailureNotAllowed,
      DataFailureCode.invalidData ||
      DataFailureCode.underage => l10n.jobsFailureInvalidData,
      DataFailureCode.jobStateConflict => l10n.dataFailureJobStateConflict,
      DataFailureCode.ambiguousCompany => l10n.dataFailureAmbiguousCompany,
      DataFailureCode.secondFactorRequired => l10n.dataFailureSecondFactor,
      DataFailureCode.staleConsent => l10n.dataFailureStaleConsent,
      DataFailureCode.network => l10n.dataFailureNetwork,
      // Ninguna escritura de ofertas puede dar un CUIT inválido ni un
      // duplicado: si llegara, el texto honesto es el genérico, no el del
      // formulario de empresa.
      DataFailureCode.duplicate ||
      DataFailureCode.invalidCuit ||
      DataFailureCode.unknown => l10n.dataFailureUnknown,
    };
  }

  /// Estado de la oferta. Null (estado que este cliente no conoce) tiene
  /// texto propio: nunca se disfraza de uno conocido.
  static String status(AppLocalizations l10n, JobStatus? status) {
    return switch (status) {
      JobStatus.draft => l10n.jobStatusDraft,
      JobStatus.active => l10n.jobStatusActive,
      JobStatus.paused => l10n.jobStatusPaused,
      JobStatus.expired => l10n.jobStatusExpired,
      JobStatus.closed => l10n.jobStatusClosed,
      null => l10n.jobStatusUnknown,
    };
  }

  static String contractType(AppLocalizations l10n, ContractType value) {
    return switch (value) {
      ContractType.relacionDependencia => l10n.jobContractRelacionDependencia,
      ContractType.monotributo => l10n.jobContractMonotributo,
      ContractType.plazoFijo => l10n.jobContractPlazoFijo,
      ContractType.temporal => l10n.jobContractTemporal,
      ContractType.pasantia => l10n.jobContractPasantia,
      ContractType.freelance => l10n.jobContractFreelance,
    };
  }

  static String jornada(AppLocalizations l10n, JornadaType value) {
    return switch (value) {
      JornadaType.fullTime => l10n.jobJornadaFullTime,
      JornadaType.partTime => l10n.jobJornadaPartTime,
      JornadaType.porTurnos => l10n.jobJornadaPorTurnos,
      JornadaType.finDeSemana => l10n.jobJornadaFinDeSemana,
      JornadaType.porHoras => l10n.jobJornadaPorHoras,
    };
  }

  /// Nombre del período para el desplegable ("Mensual").
  static String salaryPeriod(AppLocalizations l10n, SalaryPeriod value) {
    return switch (value) {
      SalaryPeriod.mensual => l10n.jobSalaryPeriodMonthly,
      SalaryPeriod.anual => l10n.jobSalaryPeriodYearly,
      SalaryPeriod.porHora => l10n.jobSalaryPeriodHourly,
    };
  }

  /// Sufijo del período para mostrar un monto ("por mes").
  static String salaryPeriodSuffix(AppLocalizations l10n, SalaryPeriod value) {
    return switch (value) {
      SalaryPeriod.mensual => l10n.jobSalaryPerMonth,
      SalaryPeriod.anual => l10n.jobSalaryPerYear,
      SalaryPeriod.porHora => l10n.jobSalaryPerHour,
    };
  }

  /// Monto en pesos con separador de miles es-AR ("900.000"). Nunca un "$"
  /// escrito a mano: la moneda la nombra el texto del ARB.
  static String amount(num value) =>
      NumberFormat.decimalPattern('es_AR').format(value);

  /// Sueldo tal como se muestra SIEMPRE en la oferta (UX_FLOWS §6.1): rango o
  /// monto único, en ARS y con su período.
  static String salary(AppLocalizations l10n, JobOffer offer) {
    final amountText = offer.salaryMin == offer.salaryMax
        ? l10n.jobSalarySingle(amount(offer.salaryMin))
        : l10n.jobSalaryRange(amount(offer.salaryMin), amount(offer.salaryMax));
    final period = offer.salaryPeriod;
    if (period == null) {
      // Un período que este cliente no conoce no se adivina: se muestra el
      // monto solo, que es lo que se sabe con certeza.
      return amountText;
    }
    return l10n.jobSalaryWithPeriod(
      amountText,
      salaryPeriodSuffix(l10n, period),
    );
  }

  /// Fecha de vencimiento legible en la zona del dispositivo
  /// ("9 de noviembre de 2026").
  static String date(DateTime value, String locale) =>
      DateFormat.yMMMMd(locale).format(value.toLocal());

  static String textIssue(
    AppLocalizations l10n,
    JobTextIssue issue, {
    required int maxLength,
  }) {
    return switch (issue) {
      JobTextIssue.empty => l10n.jobErrorTextEmpty,
      JobTextIssue.tooLong => l10n.jobErrorTextTooLong(maxLength),
    };
  }

  static String scheduleDaysIssue(
    AppLocalizations l10n,
    JobScheduleDaysIssue issue,
  ) {
    return switch (issue) {
      JobScheduleDaysIssue.empty => l10n.jobErrorDaysEmpty,
      JobScheduleDaysIssue.duplicated => l10n.jobErrorDaysDuplicated,
    };
  }

  static String salaryIssue(AppLocalizations l10n, JobSalaryIssue issue) {
    return switch (issue) {
      JobSalaryIssue.missing => l10n.jobErrorSalaryMissing,
      JobSalaryIssue.negative => l10n.jobErrorSalaryNegative,
      JobSalaryIssue.tooHigh => l10n.jobErrorSalaryTooHigh(
        amount(JobOfferValidation.salaryMaxAmount),
      ),
      JobSalaryIssue.notPositiveToPublish => l10n.jobErrorSalaryNotPositive,
      JobSalaryIssue.belowMin => l10n.jobErrorSalaryBelowMin,
    };
  }

  static String benefitIssue(AppLocalizations l10n, JobBenefitIssue issue) {
    return switch (issue) {
      JobBenefitIssue.empty => l10n.jobErrorBenefitEmpty,
      JobBenefitIssue.tooLong => l10n.jobErrorBenefitTooLong(
        JobOfferValidation.benefitMaxLength,
      ),
      JobBenefitIssue.duplicated => l10n.jobErrorBenefitDuplicated,
      JobBenefitIssue.tooMany => l10n.jobErrorBenefitTooMany(
        JobOfferValidation.benefitsMaxItems,
      ),
    };
  }

  static String vacanciesIssue(AppLocalizations l10n, JobVacanciesIssue issue) {
    return switch (issue) {
      JobVacanciesIssue.missing => l10n.jobErrorVacanciesMissing,
      JobVacanciesIssue.outOfRange => l10n.jobErrorVacanciesOutOfRange(
        JobOfferValidation.vacanciesMin,
        JobOfferValidation.vacanciesMax,
      ),
    };
  }

  static String expiryIssue(AppLocalizations l10n, JobExpiryIssue issue) {
    return switch (issue) {
      JobExpiryIssue.missing => l10n.jobErrorExpiryMissing,
      JobExpiryIssue.notInFuture => l10n.jobErrorExpiryNotInFuture,
      JobExpiryIssue.beyondMaxWindow => l10n.jobErrorExpiryBeyondWindow(
        JobOfferValidation.maxPublicationDays,
      ),
    };
  }

  /// Desplegable obligatorio sin elegir. El barrio tiene su propio texto
  /// porque solo es obligatorio en algunas localidades y al publicar (D2).
  static String choiceIssue(
    AppLocalizations l10n,
    JobChoiceIssue issue, {
    bool neighborhood = false,
  }) {
    return switch (issue) {
      JobChoiceIssue.missing =>
        neighborhood
            ? l10n.jobErrorNeighborhoodRequired
            : l10n.selectOptionError,
    };
  }

  static String action(AppLocalizations l10n, JobOfferAction action) {
    return switch (action) {
      JobOfferAction.edit => l10n.jobActionEdit,
      JobOfferAction.publish => l10n.jobActionPublish,
      JobOfferAction.pause => l10n.jobActionPause,
      JobOfferAction.resume => l10n.jobActionResume,
      JobOfferAction.close => l10n.jobActionClose,
      JobOfferAction.discard => l10n.jobActionDiscard,
      JobOfferAction.duplicate => l10n.jobActionDuplicate,
    };
  }

  static String actionOutcome(
    AppLocalizations l10n,
    JobOfferActionOutcome outcome,
  ) {
    return switch (outcome) {
      JobOfferActionOutcome.published => l10n.jobOutcomePublished,
      JobOfferActionOutcome.paused => l10n.jobOutcomePaused,
      JobOfferActionOutcome.resumed => l10n.jobOutcomeResumed,
      JobOfferActionOutcome.closed => l10n.jobOutcomeClosed,
      JobOfferActionOutcome.discarded => l10n.jobOutcomeDiscarded,
    };
  }

  static String editorOutcome(
    AppLocalizations l10n,
    JobOfferEditorOutcome outcome,
  ) {
    return switch (outcome) {
      JobOfferEditorOutcome.draftSaved => l10n.jobOutcomeDraftSaved,
      JobOfferEditorOutcome.published => l10n.jobOutcomePublished,
      JobOfferEditorOutcome.changesSaved => l10n.jobOutcomeChangesSaved,
    };
  }
}
