import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/auth_failure.dart';
import 'auth_providers.dart';

/// Qué terminó de pasar tras la última acción del usuario.
enum AuthActionOutcome {
  signedIn,
  signedUpAndSignedIn,
  signUpNeedsEmailConfirmation,
  recoveryEmailSent,
  signedOut,
}

/// Acciones de autenticación con estado de carga y error tipado.
///
/// El estado es `AsyncValue<AuthActionOutcome?>`: `loading` bloquea el doble
/// submit y el error siempre es un [AuthFailure], nunca el mensaje interno de
/// Supabase.
class AuthController extends AsyncNotifier<AuthActionOutcome?> {
  @override
  FutureOr<AuthActionOutcome?> build() => null;

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<void> signIn({required String email, required String password}) {
    return _run(() async {
      await _repository.signInWithEmail(email: email, password: password);
      return AuthActionOutcome.signedIn;
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    required SignUpRole role,
  }) {
    return _run(() async {
      final outcome = await _repository.signUpWithEmail(
        email: email,
        password: password,
        role: role,
      );
      return switch (outcome) {
        SignUpOutcome.signedIn => AuthActionOutcome.signedUpAndSignedIn,
        SignUpOutcome.emailConfirmationRequired =>
          AuthActionOutcome.signUpNeedsEmailConfirmation,
      };
    });
  }

  Future<void> sendPasswordRecoveryEmail(String email) {
    return _run(() async {
      await _repository.sendPasswordRecoveryEmail(email);
      return AuthActionOutcome.recoveryEmailSent;
    });
  }

  Future<void> signOut() {
    return _run(() async {
      await _repository.signOut();
      return AuthActionOutcome.signedOut;
    });
  }

  /// Limpia el resultado anterior al cambiar de pantalla o reintentar.
  void reset() {
    if (state.isLoading) {
      return;
    }
    state = const AsyncValue<AuthActionOutcome?>.data(null);
  }

  Future<void> _run(Future<AuthActionOutcome> Function() action) async {
    if (state.isLoading) {
      // Segundo tap sobre el mismo botón: se ignora en vez de duplicar la
      // llamada (y de gastar el rate limit del proyecto).
      return;
    }
    state = const AsyncValue<AuthActionOutcome?>.loading();
    try {
      final outcome = await action();
      state = AsyncValue<AuthActionOutcome?>.data(outcome);
    } catch (error, stackTrace) {
      state = AsyncValue<AuthActionOutcome?>.error(
        AuthFailure.from(error),
        stackTrace,
      );
    }
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthActionOutcome?>(
      AuthController.new,
    );
