import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/supabase_client_provider.dart';
import '../data/notification_prefs_repository.dart';
import '../data/supabase_notification_prefs_repository.dart';

/// Repositorio de preferencias de notificaciones. Se sobreescribe en tests.
final notificationPrefsRepositoryProvider =
    Provider<NotificationPrefsRepository>((ref) {
      return SupabaseNotificationPrefsRepository(
        ref.watch(supabaseClientProvider),
      );
    });
