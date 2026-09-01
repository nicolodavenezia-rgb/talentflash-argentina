import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/data_failure.dart';
import '../domain/notification_prefs.dart';
import 'notification_prefs_repository.dart';

/// Implementación sobre PostgREST; RLS (`nprefs_own`) garantiza que solo se
/// leen y escriben filas propias.
class SupabaseNotificationPrefsRepository
    implements NotificationPrefsRepository {
  SupabaseNotificationPrefsRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const DataFailure(
        DataFailureCode.notAllowed,
        debugDetail: 'sin sesión',
      );
    }
    return user.id;
  }

  @override
  Future<List<NotificationChannelPrefs>> fetchOwn() => _guard(() async {
    final rows = await _client
        .from('notification_prefs')
        .select('category, push_enabled, email_enabled, in_app_enabled')
        .eq('profile_id', _uid);
    return [
      for (final row in rows)
        if (NotificationCategory.fromWire(row['category']) case final category?)
          NotificationChannelPrefs(
            category: category,
            pushEnabled: row['push_enabled'] as bool,
            emailEnabled: row['email_enabled'] as bool,
            inAppEnabled: row['in_app_enabled'] as bool,
          ),
    ];
  });

  @override
  Future<void> save(List<NotificationChannelPrefs> prefs) => _guard(() async {
    if (prefs.isEmpty) {
      return;
    }
    await _client.from('notification_prefs').upsert([
      for (final pref in prefs)
        {
          'profile_id': _uid,
          'category': pref.category.wireName,
          'push_enabled': pref.pushEnabled,
          'email_enabled': pref.emailEnabled,
          'in_app_enabled': pref.inAppEnabled,
        },
    ], onConflict: 'profile_id,category');
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw DataFailure.from(error);
    }
  }
}
