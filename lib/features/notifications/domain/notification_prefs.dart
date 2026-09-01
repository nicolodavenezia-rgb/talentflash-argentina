import '../../authentication/domain/business_role.dart';

/// Categorías de `notification_type` con preferencia configurable en el MVP.
enum NotificationCategory {
  /// Cambios de estado de las postulaciones propias (candidato).
  applicationUpdate('application_update'),

  /// Nuevas postulaciones recibidas (empresa).
  newApplication('new_application'),

  /// Invitaciones de empresas (candidato).
  invitation('invitation'),

  /// Mensajes de chat (ambos roles).
  message('message'),

  /// Resultado de la verificación de la empresa.
  verificationUpdate('verification_update'),

  /// Avisos de cuenta y seguridad: in-app y correo NO se pueden desactivar
  /// (regla server-side, migración 0021).
  system('system');

  const NotificationCategory(this.wireName);

  final String wireName;

  static NotificationCategory? fromWire(Object? raw) {
    for (final value in NotificationCategory.values) {
      if (raw == value.wireName) {
        return value;
      }
    }
    return null;
  }

  /// Categorías que el onboarding le ofrece a cada rol.
  static List<NotificationCategory> forRole(BusinessRole role) =>
      switch (role) {
        BusinessRole.candidate => const [
          NotificationCategory.applicationUpdate,
          NotificationCategory.invitation,
          NotificationCategory.message,
          NotificationCategory.system,
        ],
        BusinessRole.company => const [
          NotificationCategory.newApplication,
          NotificationCategory.message,
          NotificationCategory.verificationUpdate,
          NotificationCategory.system,
        ],
        BusinessRole.admin => const [NotificationCategory.system],
      };
}

/// Preferencia por categoría y canal (fila de `notification_prefs`).
///
/// Opt-in explícito (T-019): sin fila —o al crearla— push y correo arrancan
/// APAGADOS; solo lo in-app operativo queda activo. El backend de envío
/// (T-064) consulta estas filas tal cual, sin reinterpretar.
class NotificationChannelPrefs {
  const NotificationChannelPrefs({
    required this.category,
    this.pushEnabled = false,
    this.emailEnabled = false,
    this.inAppEnabled = true,
  });

  /// Estado por defecto de una categoría sin fila guardada.
  factory NotificationChannelPrefs.defaultsFor(NotificationCategory category) =>
      NotificationChannelPrefs(
        category: category,
        // Los avisos de cuenta llegan también por correo, siempre.
        emailEnabled: category == NotificationCategory.system,
      );

  final NotificationCategory category;
  final bool pushEnabled;
  final bool emailEnabled;
  final bool inAppEnabled;

  bool get isLocked => category == NotificationCategory.system;

  NotificationChannelPrefs copyWith({bool? pushEnabled, bool? emailEnabled}) =>
      NotificationChannelPrefs(
        category: category,
        pushEnabled: pushEnabled ?? this.pushEnabled,
        emailEnabled: emailEnabled ?? this.emailEnabled,
        inAppEnabled: inAppEnabled,
      );

  @override
  bool operator ==(Object other) =>
      other is NotificationChannelPrefs &&
      other.category == category &&
      other.pushEnabled == pushEnabled &&
      other.emailEnabled == emailEnabled &&
      other.inAppEnabled == inAppEnabled;

  @override
  int get hashCode =>
      Object.hash(category, pushEnabled, emailEnabled, inAppEnabled);
}
