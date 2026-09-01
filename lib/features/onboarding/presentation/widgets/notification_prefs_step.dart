import 'package:flutter/material.dart';

import '../../../../core/localization/gen/app_localizations.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../notifications/domain/notification_prefs.dart';
import '../onboarding_copy.dart';

/// Paso de preferencias de notificaciones (T-019): opt-in explícito por
/// categoría y canal. Ningún switch opcional viene premarcado; los avisos de
/// cuenta y seguridad se muestran bloqueados (siempre activos in-app y por
/// correo, regla server-side de 0021).
class NotificationPrefsStep extends StatefulWidget {
  const NotificationPrefsStep({
    required this.initialPrefs,
    required this.isLoading,
    required this.onSubmit,
    super.key,
  });

  final List<NotificationChannelPrefs> initialPrefs;
  final bool isLoading;
  final ValueChanged<List<NotificationChannelPrefs>> onSubmit;

  @override
  State<NotificationPrefsStep> createState() => _NotificationPrefsStepState();
}

class _NotificationPrefsStepState extends State<NotificationPrefsStep> {
  late List<NotificationChannelPrefs> _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = List.of(widget.initialPrefs);
  }

  void _update(int index, NotificationChannelPrefs updated) {
    setState(() => _prefs[index] = updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.notifPrefsIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        for (final (index, pref) in _prefs.indexed) ...[
          Text(
            OnboardingCopy.notificationCategory(l10n, pref.category),
            style: theme.textTheme.titleMedium,
          ),
          if (pref.isLocked)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                l10n.notifSystemLockedNote,
                style: theme.textTheme.bodySmall,
              ),
            )
          else ...[
            SwitchListTile(
              value: pref.pushEnabled,
              onChanged: widget.isLoading
                  ? null
                  : (value) =>
                        _update(index, pref.copyWith(pushEnabled: value)),
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.notifChannelPush,
                // El lector anuncia canal + categoría, no un "Push" suelto.
                semanticsLabel: l10n.notifPushSwitchLabel(
                  OnboardingCopy.notificationCategory(l10n, pref.category),
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            SwitchListTile(
              value: pref.emailEnabled,
              onChanged: widget.isLoading
                  ? null
                  : (value) =>
                        _update(index, pref.copyWith(emailEnabled: value)),
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.notifChannelEmail,
                semanticsLabel: l10n.notifEmailSwitchLabel(
                  OnboardingCopy.notificationCategory(l10n, pref.category),
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        ProgressButton(
          label: l10n.onboardingContinue,
          isLoading: widget.isLoading,
          onPressed: () => widget.onSubmit(_prefs),
        ),
      ],
    );
  }
}
