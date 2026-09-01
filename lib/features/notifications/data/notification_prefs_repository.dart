import '../domain/notification_prefs.dart';

/// Frontera con la tabla `notification_prefs` (T-019).
abstract interface class NotificationPrefsRepository {
  /// Preferencias guardadas del usuario actual (solo las filas existentes).
  Future<List<NotificationChannelPrefs>> fetchOwn();

  /// Upsert idempotente por `(profile_id, category)`: guardar dos veces lo
  /// mismo no duplica filas ni cambia el resultado.
  Future<void> save(List<NotificationChannelPrefs> prefs);
}
