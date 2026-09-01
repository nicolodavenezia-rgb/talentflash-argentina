import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/data_failure.dart';
import '../../authentication/domain/business_role.dart';
import '../../consents/domain/consent_snapshot.dart';
import '../../consents/domain/consent_type.dart';
import '../../consents/providers/consents_providers.dart';
import '../../notifications/domain/notification_prefs.dart';
import '../../notifications/providers/notification_prefs_providers.dart';
import '../domain/candidate_onboarding_data.dart';
import '../domain/onboarding_validation.dart';
import 'onboarding_providers.dart';

/// Pasos del wizard de candidato (T-016), en orden.
enum CandidateStep {
  consents,
  identity,
  place,
  preferences,
  privacy,
  notifications,
  summary,
}

class CandidateWizardState {
  const CandidateWizardState({
    required this.step,
    required this.data,
    required this.consents,
    required this.prefs,
    this.submitting = false,
    this.failure,
    this.underage = false,
  });

  final CandidateStep step;
  final CandidateOnboardingData data;
  final ConsentSnapshot consents;
  final List<NotificationChannelPrefs> prefs;

  /// Bloqueo de doble submit: mientras es `true` se ignoran nuevas acciones.
  final bool submitting;
  final DataFailure? failure;

  /// Persona menor de 18 detectada: el wizard queda bloqueado con explicación
  /// y sin persistir ningún dato adicional (PRIVACY.md §3).
  final bool underage;

  int get stepNumber => CandidateStep.values.indexOf(step) + 1;

  int get stepCount => CandidateStep.values.length;

  bool get mandatoryConsentsCurrent => consents.pendingMandatory.isEmpty;

  CandidateWizardState copyWith({
    CandidateStep? step,
    CandidateOnboardingData? data,
    ConsentSnapshot? consents,
    List<NotificationChannelPrefs>? prefs,
    bool? submitting,
    DataFailure? Function()? failure,
    bool? underage,
  }) {
    return CandidateWizardState(
      step: step ?? this.step,
      data: data ?? this.data,
      consents: consents ?? this.consents,
      prefs: prefs ?? this.prefs,
      submitting: submitting ?? this.submitting,
      failure: failure == null ? this.failure : failure(),
      underage: underage ?? this.underage,
    );
  }
}

/// Orquesta el wizard: carga el avance persistido, guarda cada paso y
/// finaliza vía RPC. Todas las acciones bloquean el doble submit.
class CandidateOnboardingController
    extends AsyncNotifier<CandidateWizardState> {
  @override
  Future<CandidateWizardState> build() async {
    final data = await ref
        .read(onboardingRepositoryProvider)
        .fetchCandidateDraft();
    final consents = await ref.read(consentsRepositoryProvider).loadSnapshot();
    final stored = await ref
        .read(notificationPrefsRepositoryProvider)
        .fetchOwn();

    return CandidateWizardState(
      step: _firstPendingStep(data, consents),
      data: data,
      consents: consents,
      prefs: _mergePrefs(stored),
    );
  }

  /// Retomar donde quedó (T-016): el primer paso cuyo dato falta.
  static CandidateStep _firstPendingStep(
    CandidateOnboardingData data,
    ConsentSnapshot consents,
  ) {
    if (consents.pendingMandatory.isNotEmpty) {
      return CandidateStep.consents;
    }
    if (!data.hasIdentity) {
      return CandidateStep.identity;
    }
    if (!data.hasPlace) {
      return CandidateStep.place;
    }
    if (!data.hasPreferences) {
      return CandidateStep.preferences;
    }
    return CandidateStep.summary;
  }

  static List<NotificationChannelPrefs> _mergePrefs(
    List<NotificationChannelPrefs> stored,
  ) {
    final byCategory = {for (final pref in stored) pref.category: pref};
    return [
      for (final category in NotificationCategory.forRole(
        BusinessRole.candidate,
      ))
        byCategory[category] ?? NotificationChannelPrefs.defaultsFor(category),
    ];
  }

  /// Registra los consentimientos obligatorios que faltan (la UI solo llega
  /// acá con las casillas marcadas; nada viene premarcado).
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
      step: CandidateStep.identity,
    );
  });

  Future<void> submitIdentity({
    required String fullName,
    required DateTime birthDate,
  }) async {
    final current = state.value;
    if (current == null || current.submitting) {
      return;
    }
    if (!OnboardingValidation.isAdult(birthDate)) {
      // Bloqueo inmediato SIN persistir nada: los datos de una persona menor
      // no se guardan (PRIVACY.md §3). El servidor aplica la misma regla.
      state = AsyncValue.data(current.copyWith(underage: true));
      return;
    }
    await _run((current) async {
      final data = current.data.copyWith(
        fullName: fullName.trim(),
        birthDate: birthDate,
      );
      await ref.read(onboardingRepositoryProvider).saveCandidateData(data);
      return current.copyWith(
        data: data,
        submitting: false,
        step: CandidateStep.place,
      );
    });
  }

  Future<void> submitPlace({
    required String provinceId,
    required String localityId,
    String? neighborhoodId,
  }) => _run((current) async {
    final data = current.data.copyWith(
      provinceId: provinceId,
      localityId: localityId,
      neighborhoodId: () => neighborhoodId,
    );
    await ref.read(onboardingRepositoryProvider).saveCandidateData(data);
    return current.copyWith(
      data: data,
      submitting: false,
      step: CandidateStep.preferences,
    );
  });

  Future<void> submitPreferences({
    required String sectorId,
    required CandidateAvailability availability,
    required Set<CandidateWorkMode> workModes,
  }) => _run((current) async {
    final data = current.data.copyWith(
      sectorId: sectorId,
      availability: availability,
      workModes: workModes,
    );
    await ref.read(onboardingRepositoryProvider).saveCandidateData(data);
    return current.copyWith(
      data: data,
      submitting: false,
      step: CandidateStep.privacy,
    );
  });

  /// Consentimientos opcionales (B y C de UX_FLOWS.md §2.3): otorga lo que se
  /// activó y revoca lo que se desactivó. `ai_training` no existe acá.
  Future<void> submitPrivacy({
    required bool publishProfile,
    required bool aiFeatures,
  }) => _run((current) async {
    final consentsRepository = ref.read(consentsRepositoryProvider);
    final choices = {
      ConsentType.videoProfilePublication: publishProfile,
      ConsentType.aiFeatures: aiFeatures,
    };
    for (final entry in choices.entries) {
      final requirement = current.consents.requirementFor(entry.key);
      if (requirement == null) {
        continue;
      }
      final currentlyGranted = current.consents.isCurrentlyGranted(entry.key);
      if (entry.value && !currentlyGranted) {
        await consentsRepository.grant(entry.key, version: requirement.version);
      } else if (!entry.value && currentlyGranted) {
        await consentsRepository.revoke(
          entry.key,
          version: requirement.version,
        );
      }
    }
    final snapshot = await consentsRepository.loadSnapshot();
    return current.copyWith(
      consents: snapshot,
      submitting: false,
      step: CandidateStep.notifications,
    );
  });

  Future<void> submitNotificationPrefs(List<NotificationChannelPrefs> prefs) =>
      _run((current) async {
        await ref.read(notificationPrefsRepositoryProvider).save(prefs);
        return current.copyWith(
          prefs: prefs,
          submitting: false,
          step: CandidateStep.summary,
        );
      });

  /// Finalización server-side (RPC valida datos + consentimientos y falla
  /// cerrada). Al confirmarse, el router saca a la persona del wizard.
  Future<void> finish() => _run((current) async {
    await ref.read(onboardingRepositoryProvider).completeCandidateOnboarding();
    await ref.read(onboardingResolutionProvider.notifier).reload();
    return current.copyWith(submitting: false);
  });

  void goBack() {
    final current = state.value;
    if (current == null || current.submitting) {
      return;
    }
    final index = CandidateStep.values.indexOf(current.step);
    if (index == 0) {
      return;
    }
    state = AsyncValue.data(
      current.copyWith(
        step: CandidateStep.values[index - 1],
        failure: () => null,
      ),
    );
  }

  Future<void> _run(
    Future<CandidateWizardState> Function(CandidateWizardState current) action,
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
      final failure = DataFailure.from(error);
      if (failure.code == DataFailureCode.underage) {
        state = AsyncValue.data(
          current.copyWith(submitting: false, underage: true),
        );
        return;
      }
      state = AsyncValue.data(
        current.copyWith(submitting: false, failure: () => failure),
      );
    }
  }
}

final candidateOnboardingControllerProvider =
    AsyncNotifierProvider<CandidateOnboardingController, CandidateWizardState>(
      CandidateOnboardingController.new,
    );
