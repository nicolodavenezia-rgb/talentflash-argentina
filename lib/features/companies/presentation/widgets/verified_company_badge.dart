import 'package:flutter/material.dart';

import '../../../../core/localization/gen/app_localizations.dart';
import '../../data/company_access_repository.dart';

/// Distintivo "empresa verificada" (T-029).
///
/// Regla única, y a propósito estricta: se dibuja SOLO con
/// [CompanyVerificationStatus.approved] exacto. `pending`, `inReview`,
/// `rejected`, `null` (que es lo que devuelve `fromWire` ante un estado que
/// esta versión del cliente no conoce) y cualquier estado futuro devuelven un
/// widget vacío. El default de un `switch` sobre el enum sería lo contrario de
/// lo que hace falta acá: ante la duda, no hay insignia.
///
/// Deliberadamente NO recibe un booleano: si recibiera `isVerified` la decisión
/// quedaría repartida por las pantallas que lo usan, y alcanzaría con que una
/// se equivocara para mostrar una insignia falsa. Recibe el estado y decide él.
///
/// Accesibilidad: el ícono es decorativo (`excludeSemantics`) y el chip expone
/// una sola etiqueta con el significado completo, no "tilde". El tooltip
/// explica qué implica estar verificada.
class VerifiedCompanyBadge extends StatelessWidget {
  const VerifiedCompanyBadge({
    required this.status,
    this.compact = false,
    super.key,
  });

  /// Estado de verificación de la empresa. Null cuando todavía no se sabe o
  /// cuando el servidor devolvió algo desconocido.
  final CompanyVerificationStatus? status;

  /// En modo compacto se dibuja más chico, para listas y tarjetas.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (status != CompanyVerificationStatus.approved) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textStyle = compact
        ? Theme.of(context).textTheme.labelSmall
        : Theme.of(context).textTheme.labelLarge;

    return Tooltip(
      message: l10n.companyVerifiedBadgeTooltip,
      child: Semantics(
        label: l10n.companyVerifiedBadgeSemantics,
        container: true,
        child: ExcludeSemantics(
          child: Chip(
            avatar: Icon(
              Icons.verified_outlined,
              size: compact ? 16 : 18,
              color: scheme.primary,
            ),
            label: Text(l10n.companyVerifiedBadgeLabel, style: textStyle),
            visualDensity: compact ? VisualDensity.compact : null,
            materialTapTargetSize: compact
                ? MaterialTapTargetSize.shrinkWrap
                : null,
          ),
        ),
      ),
    );
  }
}
