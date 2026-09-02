import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/data_failure.dart';
import '../domain/avatar.dart';
import '../domain/candidate_profile_patch.dart';
import 'profile_providers.dart';

/// Qué terminó de pasar tras la última acción de edición.
enum ProfileActionOutcome { saved, avatarUploaded, avatarDeleted }

/// Acciones de edición del perfil con estado de carga y errores tipados.
///
/// `AsyncValue<ProfileActionOutcome?>`: `loading` bloquea el doble submit; el
/// error es siempre un [DataFailure] o un [AvatarFailure], nunca un mensaje
/// interno de Postgres o de la Edge Function.
class ProfileEditController extends AsyncNotifier<ProfileActionOutcome?> {
  @override
  FutureOr<ProfileActionOutcome?> build() => null;

  Future<void> save(CandidateProfilePatch patch) {
    return _run(() async {
      await ref.read(profileRepositoryProvider).updateMyProfile(patch);
      await ref.read(myProfileProvider.notifier).refresh();
      return ProfileActionOutcome.saved;
    });
  }

  Future<void> uploadAvatar(PickedAvatarImage image) {
    return _run(() async {
      // Pre-chequeo local (tamaño + magic bytes) para no subir de más; la
      // autoridad sigue siendo la Edge Function.
      final issue = AvatarValidation.validate(image.bytes);
      if (issue != null) {
        throw AvatarFailure(switch (issue) {
          AvatarIssue.tooLarge => AvatarFailureCode.tooLarge,
          AvatarIssue.invalidFormat => AvatarFailureCode.invalidImage,
          AvatarIssue.unsupportedFormat => AvatarFailureCode.unsupportedFormat,
        });
      }
      final format = AvatarValidation.detectFormat(image.bytes)!;
      await ref
          .read(profileRepositoryProvider)
          .uploadAvatar(
            bytes: image.bytes,
            contentType: AvatarValidation.contentTypeFor(format),
          );
      await ref.read(myProfileProvider.notifier).refresh();
      return ProfileActionOutcome.avatarUploaded;
    });
  }

  Future<void> deleteAvatar() {
    return _run(() async {
      await ref.read(profileRepositoryProvider).deleteAvatar();
      await ref.read(myProfileProvider.notifier).refresh();
      return ProfileActionOutcome.avatarDeleted;
    });
  }

  /// Limpia el resultado anterior al entrar a la pantalla o reintentar.
  void reset() {
    if (state.isLoading) {
      return;
    }
    state = const AsyncValue<ProfileActionOutcome?>.data(null);
  }

  Future<void> _run(Future<ProfileActionOutcome> Function() action) async {
    if (state.isLoading) {
      // Segundo tap sobre el mismo botón: se ignora en vez de duplicar.
      return;
    }
    state = const AsyncValue<ProfileActionOutcome?>.loading();
    try {
      final outcome = await action();
      state = AsyncValue<ProfileActionOutcome?>.data(outcome);
    } on AvatarFailure catch (failure, stackTrace) {
      state = AsyncValue<ProfileActionOutcome?>.error(failure, stackTrace);
    } catch (error, stackTrace) {
      state = AsyncValue<ProfileActionOutcome?>.error(
        error is DataFailure ? error : DataFailure.from(error),
        stackTrace,
      );
    }
  }
}

final profileEditControllerProvider =
    AsyncNotifierProvider<ProfileEditController, ProfileActionOutcome?>(
      ProfileEditController.new,
    );
