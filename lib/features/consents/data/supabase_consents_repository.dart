import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/data_failure.dart';
import '../domain/consent_snapshot.dart';
import '../domain/consent_type.dart';
import 'consents_repository.dart';

/// Implementación sobre PostgREST. Recibe el [SupabaseClient] por constructor
/// para poder ejercitarla en tests contra un cliente HTTP falso.
class SupabaseConsentsRepository implements ConsentsRepository {
  SupabaseConsentsRepository(this._client);

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
  Future<ConsentSnapshot> loadSnapshot() => _guard(() async {
    final versionRows = await _client
        .from('consent_versions')
        .select('consent_type, version, document_slug, is_mandatory');

    final requirements = <ConsentRequirement>[
      for (final row in versionRows)
        // Un tipo desconocido para esta versión de la app (p. ej. uno nuevo
        // agregado por migración) se ignora acá: fail-closed lo maneja el
        // servidor, que sí lo exigirá al completar el onboarding.
        if (ConsentType.fromWire(row['consent_type']) case final type?)
          ConsentRequirement(
            type: type,
            version: row['version'] as String,
            documentSlug: row['document_slug'] as String,
            isMandatory: row['is_mandatory'] as bool,
          ),
    ];

    final consentRows = await _client
        .from('consents')
        .select('consent_type, granted, version, seq')
        .eq('profile_id', _uid)
        .order('seq', ascending: false);

    final latest = <ConsentType, ConsentDecision>{};
    for (final row in consentRows) {
      final type = ConsentType.fromWire(row['consent_type']);
      if (type == null || latest.containsKey(type)) {
        continue; // filas ordenadas por seq desc: la primera es la vigente
      }
      latest[type] = ConsentDecision(
        type: type,
        granted: row['granted'] as bool,
        version: row['version'] as String,
      );
    }

    return ConsentSnapshot(requirements: requirements, latestByType: latest);
  });

  @override
  Future<void> grant(ConsentType type, {required String version}) =>
      _insert(type: type, granted: true, version: version);

  @override
  Future<void> revoke(ConsentType type, {required String version}) =>
      _insert(type: type, granted: false, version: version);

  Future<void> _insert({
    required ConsentType type,
    required bool granted,
    required String version,
  }) => _guard(() async {
    await _client.from('consents').insert({
      'profile_id': _uid,
      'consent_type': type.wireName,
      'granted': granted,
      'version': version,
      // Canal de la aceptación (PRIVACY.md §4): plataforma desde la que se
      // registró, sin datos del dispositivo.
      'user_agent': _channel,
    });
  });

  static String get _channel {
    if (kIsWeb) {
      return 'app_web';
    }
    return 'app_${defaultTargetPlatform.name.toLowerCase()}';
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw DataFailure.from(error);
    }
  }
}
