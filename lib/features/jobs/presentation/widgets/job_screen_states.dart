import 'package:flutter/material.dart';

final _jobIdPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// ¿El `:id` de la ruta tiene forma de UUID? Un id malformado ni siquiera
/// viaja al servidor: la pantalla muestra directamente "no disponible".
bool isWellFormedJobId(String id) => _jobIdPattern.hasMatch(id);

/// Mensaje centrado de las pantallas de ofertas (no encontrada, no editable,
/// sin permiso, error de carga). El título es encabezado y región viva: el
/// lector lo anuncia al aparecer, igual que en la vista de candidato (T-024).
class JobCenteredMessage extends StatelessWidget {
  const JobCenteredMessage({
    required this.title,
    this.body,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String? body;

  /// Salidas reales de la pantalla (reintentar, volver, duplicar).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
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
                liveRegion: true,
                child: Text(title, style: theme.textTheme.headlineSmall),
              ),
              if (body != null) ...[
                const SizedBox(height: 12),
                Text(body!, style: theme.textTheme.bodyLarge),
              ],
              for (final action in actions) ...[
                const SizedBox(height: 16),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
