import 'package:flutter/material.dart';

/// Sección del formulario o del detalle de una oferta, con encabezado
/// semántico: la oferta se recorre por encabezados con el lector de pantalla
/// (UX_FLOWS §20, "vista previa navegable por encabezados").
class JobSection extends StatelessWidget {
  const JobSection({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

/// Dato del detalle: rótulo arriba y valor abajo, leídos juntos por el
/// lector ("Jornada, Jornada parcial") en vez de como dos textos sueltos.
class JobDetailRow extends StatelessWidget {
  const JobDetailRow({
    required this.label,
    required this.value,
    required this.emptyLabel,
    super.key,
  });

  final String label;
  final String? value;

  /// Texto neutro cuando falta el dato (solo puede pasar en la vista previa
  /// o con un valor que este cliente no conoce).
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = value;
    final hasValue = text != null && text.trim().isNotEmpty;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              hasValue ? text : emptyLabel,
              style: hasValue
                  ? theme.textTheme.bodyLarge
                  : theme.textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
