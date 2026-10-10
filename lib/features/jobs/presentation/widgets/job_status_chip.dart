import 'package:flutter/material.dart';

import '../../../../core/localization/gen/app_localizations.dart';
import '../../domain/job_offer_enums.dart';
import '../jobs_copy.dart';

/// Estado de una oferta en la lista de la empresa. Ícono y texto, nunca solo
/// color (UX_FLOWS §20), y una sola etiqueta para el lector ("Estado:
/// Pausada") en vez del ícono suelto.
class JobStatusChip extends StatelessWidget {
  const JobStatusChip({required this.status, super.key});

  /// Null = estado que este cliente no conoce: se dice así, sin adivinar.
  final JobStatus? status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = JobsCopy.status(l10n, status);
    final icon = switch (status) {
      JobStatus.draft => Icons.edit_note,
      JobStatus.active => Icons.check_circle_outline,
      JobStatus.paused => Icons.pause_circle_outline,
      JobStatus.expired => Icons.event_busy_outlined,
      JobStatus.closed => Icons.lock_outline,
      null => Icons.help_outline,
    };
    return Semantics(
      container: true,
      label: l10n.jobStatusSemantics(label),
      child: ExcludeSemantics(
        child: Chip(avatar: Icon(icon, size: 18), label: Text(label)),
      ),
    );
  }
}
