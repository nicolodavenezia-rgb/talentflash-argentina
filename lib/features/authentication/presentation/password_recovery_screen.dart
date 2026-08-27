import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../providers/auth_controller.dart';
import 'auth_copy.dart';
import 'widgets/auth_form_widgets.dart';

/// Primera etapa de la recuperación de contraseña: pide el correo de
/// restablecimiento.
///
/// La respuesta visual es **siempre la misma** exista o no la cuenta
/// (`SECURITY.md` §2 — no revelar si el correo está registrado).
///
/// La segunda etapa (cambiar la contraseña dentro de la app) depende del enlace
/// profundo de T-013, todavía sin definir: por eso no se dibuja un formulario
/// de nueva contraseña que no podría funcionar.
class PasswordRecoveryScreen extends ConsumerStatefulWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  ConsumerState<PasswordRecoveryScreen> createState() =>
      _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState
    extends ConsumerState<PasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(authControllerProvider.notifier).reset();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _emailFocus.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    ref
        .read(authControllerProvider.notifier)
        .sendPasswordRecoveryEmail(_emailController.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controllerState = ref.watch(authControllerProvider);
    final isLoading = controllerState.isLoading;
    final error = controllerState.error;
    final wasSent =
        controllerState.value == AuthActionOutcome.recoveryEmailSent;

    return AuthScreenLayout(
      title: l10n.authRecoveryTitle,
      subtitle: l10n.authRecoverySubtitle,
      children: [
        if (error != null)
          AuthMessageBanner.error(
            title: l10n.authErrorTitle,
            message: AuthCopy.error(l10n, error),
          ),
        if (wasSent) AuthMessageBanner.info(message: l10n.authRecoverySent),
        Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthEmailField(
                controller: _emailController,
                focusNode: _emailFocus,
                enabled: !isLoading,
                onSubmitted: _submit,
              ),
              const SizedBox(height: 24),
              AuthSubmitButton(
                label: l10n.authSubmitRecovery,
                isLoading: isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.authRecoveryPendingStep,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: isLoading
              ? null
              : () => context.goNamed(AppRoute.login.name),
          child: Text(l10n.authBackToLogin),
        ),
      ],
    );
  }
}
