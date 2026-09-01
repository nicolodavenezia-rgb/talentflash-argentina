import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/data_failure.dart';
import '../../authentication/domain/business_role.dart';
import '../../consents/domain/consent_snapshot.dart';
import '../../consents/providers/consents_providers.dart';
import '../../notifications/domain/notification_prefs.dart';
import '../../notifications/providers/notification_prefs_providers.dart';
import '../domain/company_onboarding_data.dart';
import 'onboarding_providers.dart';

/// Pasos del wizard de empresa (T-017), en orden.
enum CompanyStep { consents, company, place, applicant, notifications, summary }

class CompanyWizardState {
  const CompanyWizardState({
    required this.step,
    required this.data,
    required this.consents,
    required this.prefs,
    this.submitting = false,
    this.failure,
  });

  final CompanyStep step;

  /// Datos de la empresa, SOLO en memoria hasta el paso final: la empresa
  /// nace atómica en `complete_company_onboarding` y así nunca queda una a
  /// medio crear. El avance durable son los consentimientos y preferencias.
  final CompanyOnboardingData data;
  final ConsentSnapshot consents;
  final List<NotificationChannelPrefs> prefs;
  final bool submitting;
  final DataFailure? failure;

  int get stepNumber => CompanyStep.values.indexOf(step) + 1;

  int get stepCount => CompanyStep.values.length;

  bool get mandatoryConsentsCurrent => consents.pendingMandatory.isEmpty;

  CompanyWizardState copyWith({
    CompanyStep? step,
    CompanyOnboardingData? data,
    ConsentSnapshot? consents,
    List<NotificationChannelPrefs>? prefs,
    bool? submitting,
    DataFailure? Function()? failure,
  }) {
    return CompanyWizardState(
      step: step ?? this.step,
      data: data ?? this.data,
      consents: consents ?? this.consents,
      prefs: prefs ?? this.prefs,
      submitting: submitting ?? this.submitting,
      failure: failure == null ? this.failure : failure(),
    );
  }
}

class CompanyOnboardingController extends AsyncNotifier<CompanyWizardState> {
  @override
  Future<CompanyWizardState> build() async {
    final consents = await ref.read(consentsRepositoryProvider).loadSnapshot();
    final stored = await ref
        .read(notificationPrefsRepositoryProvider)
        .fetchOwn();
    return CompanyWizardState(
      step: consents.pendingMandatory.isEmpty
          ? CompanyStep.company
          : CompanyStep.consents,
      data: const CompanyOnboardingData(),
      consents: consents,
      prefs: _mergePrefs(stored),
    );
  }

  static List<NotificationChannelPrefs> _mergePrefs(
    List<NotificationChannelPrefs> stored,
  ) {
    final byCategory = {for (final pref in stored) pref.category: pref};
    return [
      for (final category in NotificationCategory.forRole(BusinessRole.company))
        byCategory[category] ?? NotificationChannelPrefs.defaultsFor(category),
    ];
  }

  Future<void> submitMandatoryConsents() => _run((current) async {
    final consentsRepository = ref.read(consentsRepositoryProvider);
    for (final requirement in current.consents.pendingMandatory) {
      await consentsRepository.grant(
        requirement.type,
        version: requirement.version,
      );
    }
    final snapshot = await consentsRepository.loadSnapshot();
    return current.copyWith(
      consents: snapshot,
      submitting: false,
      step: CompanyStep.company,
    );
  });

  /// Los pasos de datos solo avanzan en memoria (ver [CompanyWizardState]).
  void submitCompanyData({
    required String legalName,
    required String tradeName,
    required String cuit,
    required String sectorId,
    required CompanySizeRange sizeRange,
  }) {
    _advance(
      (current) => current.copyWith(
        data: current.data.copyWith(
          legalName: legalName.trim(),
          tradeName: tradeName.trim(),
          cuit: cuit,
          sectorId: sectorId,
          sizeRange: sizeRange,
        ),
        step: CompanyStep.place,
      ),
    );
  }

  void submitPlace({
    required String provinceId,
    required String localityId,
    String? website,
  }) {
    _advance(
      (current) => current.copyWith(
        data: current.data.copyWith(
          provinceId: provinceId,
          localityId: localityId,
          website: () => website,
        ),
        step: CompanyStep.applicant,
      ),
    );
  }

  void submitApplicant({
    required String fullName,
    required String position,
    required CompanyRelationship relationship,
  }) {
    _advance(
      (current) => current.copyWith(
        data: current.data.copyWith(
          applicantFullName: fullName.trim(),
          applicantPosition: position.trim(),
          applicantRelationship: relationship,
        ),
        step: CompanyStep.notifications,
      ),
    );
  }

  Future<void> submitNotificationPrefs(List<NotificationChannelPrefs> prefs) =>
      _run((current) async {
        await ref.read(notificationPrefsRepositoryProvider).save(prefs);
        return current.copyWith(
          prefs: prefs,
          submitting: false,
          step: CompanyStep.summary,
        );
      });

  /// Empresa + owner + solicitante nacen en UNA transacción; reintentar o
  /// tocar dos veces no duplica nada (RPC idempotente + bloqueo local).
  Future<void> finish() => _run((current) async {
    await ref
        .read(onboardingRepositoryProvider)
        .completeCompanyOnboarding(current.data);
    await ref.read(onboardingResolutionProvider.notifier).reload();
    return current.copyWith(submitting: false);
  });

  void goBack() {
    final current = state.value;
    if (current == null || current.submitting) {
      return;
    }
    final index = CompanyStep.values.indexOf(current.step);
    if (index == 0) {
      return;
    }
    state = AsyncValue.data(
      current.copyWith(
        step: CompanyStep.values[index - 1],
        failure: () => null,
      ),
    );
  }

  void _advance(CompanyWizardState Function(CompanyWizardState) transform) {
    final current = state.value;
    if (current == null || current.submitting) {
      return;
    }
    state = AsyncValue.data(transform(current).copyWith(failure: () => null));
  }

  Future<void> _run(
    Future<CompanyWizardState> Function(CompanyWizardState current) action,
  ) async {
    final current = state.value;
    if (current == null || current.submitting) {
      return; // doble submit bloqueado
    }
    state = AsyncValue.data(
      current.copyWith(submitting: true, failure: () => null),
    );
    try {
      state = AsyncValue.data(await action(current));
    } catch (error) {
      state = AsyncValue.data(
        current.copyWith(
          submitting: false,
          failure: () => DataFailure.from(error),
        ),
      );
    }
  }
}

final companyOnboardingControllerProvider =
    AsyncNotifierProvider<CompanyOnboardingController, CompanyWizardState>(
      CompanyOnboardingController.new,
    );
