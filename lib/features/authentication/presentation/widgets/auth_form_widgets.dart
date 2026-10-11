import 'package:flutter/material.dart';

import '../../../../core/localization/gen/app_localizations.dart';
import '../../domain/auth_validation.dart';
import '../auth_copy.dart';

/// Estructura común de las pantallas de autenticación.
///
/// Ancho acotado para que en Web la línea de lectura no se estire, scroll
/// propio para que el teclado nunca tape un campo, y encabezado marcado como
/// `header` para lectores de pantalla (UX_FLOWS.md §20).
class AuthScreenLayout extends StatelessWidget {
  const AuthScreenLayout({
    required this.title,
    required this.children,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(title, style: theme.textTheme.headlineSmall),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(subtitle!, style: theme.textTheme.bodyLarge),
                  ],
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de correo con label visible, teclado de email y autocompletado del SO.
class AuthEmailField extends StatelessWidget {
  const AuthEmailField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      autofillHints: const [AutofillHints.username, AutofillHints.email],
      decoration: InputDecoration(
        labelText: l10n.authEmailLabel,
        hintText: l10n.authEmailHint,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final issue = AuthValidation.validateEmail(value ?? '');
        return issue == null ? null : AuthCopy.emailIssue(l10n, issue);
      },
      onFieldSubmitted: (_) => onSubmitted(),
    );
  }
}

/// Campo de contraseña con alternancia mostrar/ocultar accesible.
class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.validator,
    required this.textInputAction,
    required this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
    this.helperText,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String? Function(String value) validator;
  final TextInputAction textInputAction;
  final VoidCallback onSubmitted;
  final List<String> autofillHints;
  final String? helperText;
  final bool enabled;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final toggleLabel = _obscured
        ? l10n.authPasswordShow
        : l10n.authPasswordHide;
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        helperMaxLines: 2,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          // 48 dp de área táctil (UX_FLOWS.md §20) y estado anunciado por
          // tooltip + semantics, no solo por el ícono.
          icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
          tooltip: toggleLabel,
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
      validator: (value) => widget.validator(value ?? ''),
      onFieldSubmitted: (_) => widget.onSubmitted(),
    );
  }
}

/// Cartel de error o de confirmación.
///
/// `liveRegion` hace que el lector de pantalla lo anuncie al aparecer, y el
/// ícono acompaña al color para no depender solo de él (UX_FLOWS.md §19.2/§20).
class AuthMessageBanner extends StatelessWidget {
  const AuthMessageBanner.error({
    required this.message,
    required this.title,
    super.key,
  }) : isError = true;

  const AuthMessageBanner.info({required this.message, super.key})
    : isError = false,
      title = null;

  final String message;
  final String? title;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = isError
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final foreground = isError
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: foreground,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: foreground,
                      ),
                    ),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón principal de los formularios: muestra progreso y se deshabilita
/// mientras la acción está en curso (bloqueo de doble submit).
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              // El botón conserva su nombre accesible mientras carga: sin
              // esto el lector lo anuncia como "botón deshabilitado" a secas.
              child: CircularProgressIndicator(
                strokeWidth: 2,
                semanticsLabel: label,
              ),
            )
          : Text(label),
    );
  }
}

/// Casilla de consentimiento obligatoria del registro.
///
/// Control nativo (`CheckboxListTile`) para que el estado lo anuncie el lector
/// de pantalla, nunca premarcada (PRIVACY.md §4).
class AuthConsentCheckbox extends StatelessWidget {
  const AuthConsentCheckbox({
    required this.value,
    required this.label,
    required this.onChanged,
    required this.showError,
    required this.errorText,
    this.enabled = true,
    super.key,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  final bool showError;
  final String errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          value: value,
          onChanged: enabled ? (checked) => onChanged(checked ?? false) : null,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: theme.textTheme.bodyMedium),
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              errorText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
