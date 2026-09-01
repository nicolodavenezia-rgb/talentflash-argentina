import 'package:flutter/material.dart';

/// Cartel de error o de aviso, anunciado por el lector de pantalla al
/// aparecer (`liveRegion`); el ícono acompaña al color para no depender solo
/// de él (UX_FLOWS.md §19.2/§20). Equivalente genérico del cartel de auth.
class MessageBanner extends StatelessWidget {
  const MessageBanner.error({
    required this.message,
    required this.title,
    super.key,
  }) : isError = true;

  const MessageBanner.info({required this.message, super.key})
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

/// Botón principal con progreso: se deshabilita mientras la acción está en
/// curso (bloqueo de doble submit en la capa visual, además del controller).
class ProgressButton extends StatelessWidget {
  const ProgressButton({
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
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

/// Casilla de consentimiento: control nativo con estado anunciado por el
/// lector, jamás premarcada (PRIVACY.md §4).
class ConsentCheckTile extends StatelessWidget {
  const ConsentCheckTile({
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
