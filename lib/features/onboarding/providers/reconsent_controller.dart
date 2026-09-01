import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/data_failure.dart';
import '../../consents/domain/consent_snapshot.dart';
import '../../consents/providers/consents_providers.dart';
import 'onboarding_providers.dart';

class ReconsentState {
  const ReconsentState({
    required this.snapshot,
    this.submitting = false,
    this.failure,
  });

  final ConsentSnapshot snapshot;
  final bool submitting;
  final DataFailure? failure;

  List<ConsentRequirement> get pending => snapshot.pendingMandatory;

  ReconsentState copyWith({
    ConsentSnapshot? snapshot,
    bool? submitting,
    DataFailure? Function()? failure,
  }) => ReconsentState(
    snapshot: snapshot ?? this.snapshot,
    submitting: submitting ?? this.submitting,
    failure: failure == null ? this.failure : failure(),
  );
}

/// Reconsentimiento (T-018): un texto obligatorio subió de versión y hay que
/// volver a pedir la aceptación, aunque el onboarding esté completo.
class ReconsentController extends AsyncNotifier<ReconsentState> {
  @override
  Future<ReconsentState> build() async {
    final snapshot = await ref.read(consentsRepositoryProvider).loadSnapshot();
    return ReconsentState(snapshot: snapshot);
  }

  /// Registra la aceptación de todos los pendientes (la UI llega acá con las
  /// casillas marcadas una por una; nada viene premarcado) y refresca el
  /// estado de onboarding para que el router devuelva al shell.
  Future<void> acceptPending() async {
    final current = state.value;
    if (current == null || current.submitting) {
      return; // doble submit bloqueado
    }
    state = AsyncValue.data(
      current.copyWith(submitting: true, failure: () => null),
    );
    try {
      final consentsRepository = ref.read(consentsRepositoryProvider);
      for (final requirement in current.pending) {
        await consentsRepository.grant(
          requirement.type,
          version: requirement.version,
        );
      }
      final snapshot = await consentsRepository.loadSnapshot();
      await ref.read(onboardingResolutionProvider.notifier).reload();
      state = AsyncValue.data(
        current.copyWith(snapshot: snapshot, submitting: false),
      );
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

final reconsentControllerProvider =
    AsyncNotifierProvider<ReconsentController, ReconsentState>(
      ReconsentController.new,
    );
