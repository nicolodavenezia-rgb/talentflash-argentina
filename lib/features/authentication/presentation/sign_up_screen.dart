import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../data/auth_repository.dart';
import '../domain/auth_validation.dart';
import '../providers/auth_controller.dart';
import 'auth_copy.dart';
import 'widgets/auth_form_widgets.dart';

/// Alta de cuenta para candidato o empresa.
///
/// El rol es un [SignUpRole] fijado por la ruta: no hay parámetro libre, así
/// que la UI no puede pedir `admin`. El servidor igual sanea el valor
/// (migración 0004, `SECURITY.md` §3).
///
/// El alta **no** crea `company_profiles`: la empresa nace en el onboarding
/// mediante `create_company_with_owner(...)`, que crea empresa y owner en una
/// sola transacción (Bloque C, T-017).
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({required this.role, super.key});

  final SignUpRole role;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmationFocus = FocusNode();

  bool _acceptsDataProcessing = false;
  bool _declaresLegalAge = false;
  bool _showConsentError = false;

  bool get _consentsGiven => _acceptsDataProcessing && _declaresLegalAge;

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
    _passwordController.dispose();
    _confirmationController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmationFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final formIsValid = _formKey.currentState?.validate() ?? false;
    setState(() => _showConsentError = !_consentsGiven);
    if (!formIsValid) {
      _focusFirstInvalidField();
      return;
    }
    if (!_consentsGiven) {
      return;
    }
    FocusScope.of(context).unfocus();
    ref
        .read(authControllerProvider.notifier)
        .signUp(
          email: _emailController.text,
          password: _passwordController.text,
          role: widget.role,
        );
  }

  void _focusFirstInvalidField() {
    if (AuthValidation.validateEmail(_emailController.text) != null) {
      _emailFocus.requestFocus();
      return;
    }
    if (AuthValidation.validatePassword(_passwordController.text) != null) {
      _passwordFocus.requestFocus();
      return;
    }
    final confirmationIssue = AuthValidation.validatePasswordConfirmation(
      _passwordController.text,
      _confirmationController.text,
    );
    if (confirmationIssue != null) {
      _confirmationFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controllerState = ref.watch(authControllerProvider);
    final isLoading = controllerState.isLoading;
    final error = controllerState.error;
    final needsEmailConfirmation =
        controllerState.value == AuthActionOutcome.signUpNeedsEmailConfirmation;
    final isCandidate = widget.role == SignUpRole.candidate;

    return AuthScreenLayout(
      title: isCandidate
          ? l10n.authSignUpCandidateTitle
          : l10n.authSignUpCompanyTitle,
      subtitle: isCandidate
          ? l10n.authSignUpCandidateSubtitle
          : l10n.authSignUpCompanySubtitle,
      children: [
        if (error != null)
          AuthMessageBanner.error(
            title: l10n.authErrorTitle,
            message: AuthCopy.error(l10n, error),
          ),
        if (needsEmailConfirmation)
          AuthMessageBanner.info(message: l10n.authSignUpEmailConfirmationSent),
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
                  helperText: l10n.authPasswordHelp(
                    AuthValidation.minPasswordLength,
                  ),
                  enabled: !isLoading,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) {
                    final issue = AuthValidation.validatePassword(value);
                    return issue == null
                        ? null
                        : AuthCopy.passwordIssue(l10n, issue);
                  },
                  onSubmitted: _confirmationFocus.requestFocus,
                ),
                const SizedBox(height: 16),
                AuthPasswordField(
                  controller: _confirmationController,
                  focusNode: _confirmationFocus,
                  label: l10n.authPasswordConfirmLabel,
                  enabled: !isLoading,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) {
                    final issue = AuthValidation.validatePasswordConfirmation(
                      _passwordController.text,
                      value,
                    );
                    return issue == null
                        ? null
                        : AuthCopy.passwordConfirmationIssue(l10n, issue);
                  },
                  onSubmitted: _submit,
                ),
                const SizedBox(height: 16),
                // Consentimientos obligatorios de PRIVACY.md §3 y §4, separados
                // y sin premarcar. El registro versionado en `consents` llega
                // con T-018 (Bloque C).
                AuthConsentCheckbox(
                  value: _acceptsDataProcessing,
                  label: l10n.authSignUpConsentDataProcessing,
                  enabled: !isLoading,
                  showError: _showConsentError && !_acceptsDataProcessing,
                  errorText: l10n.authErrorConsentRequired,
                  onChanged: (value) =>
                      setState(() => _acceptsDataProcessing = value),
                ),
                AuthConsentCheckbox(
                  value: _declaresLegalAge,
                  label: l10n.authSignUpConsentAge,
                  enabled: !isLoading,
                  showError: _showConsentError && !_declaresLegalAge,
                  errorText: l10n.authErrorConsentRequired,
                  onChanged: (value) =>
                      setState(() => _declaresLegalAge = value),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.authSignUpConsentNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                AuthSubmitButton(
                  label: l10n.authSubmitSignUp,
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
              : () => context.goNamed(AppRoute.login.name),
          child: Text(l10n.authGoToLogin),
        ),
      ],
    );
  }
}
