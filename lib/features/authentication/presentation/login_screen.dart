import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../domain/auth_validation.dart';
import '../providers/auth_controller.dart';
import 'auth_copy.dart';
import 'widgets/auth_form_widgets.dart';

/// Inicio de sesión con correo y contraseña.
///
/// [roleHint] llega por query param `rol` cuando el binario es el de candidato
/// o el de empresa: solo adapta el copy y el enlace de registro. Los permisos
/// no dependen nunca de este valor.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({this.roleHint, super.key});

  final String? roleHint;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Un error de una pantalla anterior no debe aparecer acá.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(authControllerProvider.notifier).reset();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _focusFirstInvalidField();
      return;
    }
    FocusScope.of(context).unfocus();
    ref
        .read(authControllerProvider.notifier)
        .signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  /// El foco va al primer campo con error (UX_FLOWS.md §19.2).
  void _focusFirstInvalidField() {
    if (AuthValidation.validateEmail(_emailController.text) != null) {
      _emailFocus.requestFocus();
      return;
    }
    if (AuthValidation.validatePassword(_passwordController.text) != null) {
      _passwordFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controllerState = ref.watch(authControllerProvider);
    final isLoading = controllerState.isLoading;
    final error = controllerState.error;

    return AuthScreenLayout(
      title: l10n.authLoginTitle,
      subtitle: switch (widget.roleHint) {
        AuthQueryParams.candidateHint => l10n.authLoginSubtitleCandidate,
        AuthQueryParams.companyHint => l10n.authLoginSubtitleCompany,
        _ => l10n.authLoginSubtitle,
      },
      children: [
        if (error != null)
          AuthMessageBanner.error(
            title: l10n.authErrorTitle,
            message: AuthCopy.error(l10n, error),
          ),
        Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthEmailField(
                  controller: _emailController,
                  focusNode: _emailFocus,
                  enabled: !isLoading,
                  onSubmitted: _passwordFocus.requestFocus,
                ),
                const SizedBox(height: 16),
                AuthPasswordField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  label: l10n.authPasswordLabel,
                  enabled: !isLoading,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    final issue = AuthValidation.validatePassword(value);
                    return issue == null
                        ? null
                        : AuthCopy.passwordIssue(l10n, issue);
                  },
                  onSubmitted: _submit,
                ),
                const SizedBox(height: 24),
                AuthSubmitButton(
                  label: l10n.authSubmitLogin,
                  isLoading: isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: isLoading
              ? null
              : () => context.goNamed(AppRoute.passwordRecovery.name),
          child: Text(l10n.authForgotPassword),
        ),
        TextButton(
          onPressed: isLoading ? null : () => _goToSignUp(context),
          child: Text(switch (widget.roleHint) {
            AuthQueryParams.candidateHint => l10n.authGoToSignUpCandidate,
            AuthQueryParams.companyHint => l10n.authGoToSignUpCompany,
            _ => l10n.authGoToSignUp,
          }),
        ),
      ],
    );
  }

  void _goToSignUp(BuildContext context) {
    final route = switch (widget.roleHint) {
      AuthQueryParams.candidateHint => AppRoute.signupCandidate,
      AuthQueryParams.companyHint => AppRoute.signupCompany,
      _ => AppRoute.signupChooser,
    };
    context.goNamed(route.name);
  }
}
