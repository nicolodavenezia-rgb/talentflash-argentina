import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/data_failure.dart';
import '../domain/avatar.dart';
import '../domain/candidate_profile.dart';
import '../domain/candidate_profile_patch.dart';
import '../domain/candidate_public_profile.dart';
import 'profile_repository.dart';

/// Implementación sobre Supabase (PostgREST + Storage + Edge Function).
///
/// Recibe el `SupabaseClient` por constructor para ejercitarla en tests con
/// un cliente HTTP falso, sin proyecto remoto.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  static const _avatarBucket = 'avatars';
  static const _avatarFunction = 'avatar';

  @override
  Future<CandidateProfile> fetchMyProfile() {
    return _guard(() async {
      final raw = await _client.rpc<dynamic>('get_my_candidate_profile');
      if (raw is! Map<String, dynamic>) {
        throw const DataFailure(
          DataFailureCode.unknown,
          debugDetail: 'get_my_candidate_profile: respuesta no es objeto',
        );
      }
      return CandidateProfile.fromJson(raw);
    });
  }

  @override
  Future<void> updateMyProfile(CandidateProfilePatch patch) {
    return _guard(() async {
      if (patch.isEmpty) {
        return;
      }
      await _client.rpc<dynamic>(
        'update_my_candidate_profile',
        params: {'p_patch': patch.toJson()},
      );
    });
  }

  @override
  Future<CandidatePublicProfile?> fetchCandidatePublicProfile(
    String candidateProfileId,
  ) {
    return _guard(() async {
      final raw = await _client.rpc<dynamic>(
        'get_candidate_public_profile',
        params: {'p_candidate_profile_id': candidateProfileId},
      );
      if (raw is! Map<String, dynamic>) {
        // null del RPC = no disponible, indistinguible de inexistente.
        return null;
      }
      return CandidatePublicProfile.fromJson(raw);
    });
  }

  @override
  Future<String> createAvatarSignedUrl(
    String path, {
    int expiresInSeconds = 300,
  }) {
    return _guard(
      () => _client.storage
          .from(_avatarBucket)
          .createSignedUrl(path, expiresInSeconds),
    );
  }

  @override
  Future<AvatarPaths> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      final response = await _client.functions.invoke(
        _avatarFunction,
        body: {'data': base64Encode(bytes), 'content_type': contentType},
      );
      final data = response.data;
      if (data is Map<String, dynamic> &&
          data['avatar_path'] is String &&
          data['thumb_path'] is String) {
        return AvatarPaths(
          avatarPath: data['avatar_path'] as String,
          thumbPath: data['thumb_path'] as String,
        );
      }
      throw const AvatarFailure(
        AvatarFailureCode.unknown,
        debugDetail: 'avatar: respuesta sin paths',
      );
    } catch (error) {
      throw _asAvatarFailure(error);
    }
  }

  @override
  Future<void> deleteAvatar() async {
    try {
      await _client.functions.invoke(
        _avatarFunction,
        method: HttpMethod.delete,
      );
    } catch (error) {
      throw _asAvatarFailure(error);
    }
  }

  /// Traduce los errores de la Edge Function a fallos tipados; el detalle
  /// interno queda para logs, jamás para la pantalla.
  AvatarFailure _asAvatarFailure(Object error) {
    if (error is AvatarFailure) {
      return error;
    }
    if (error is FunctionException) {
      final details = error.details;
      final code = details is Map<String, dynamic> ? details['code'] : null;
      return AvatarFailure.fromFunctionCode(code, status: error.status);
    }
    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('Connection')) {
      return const AvatarFailure(AvatarFailureCode.network);
    }
    return AvatarFailure(AvatarFailureCode.unknown, debugDetail: text);
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      if (error is DataFailure) {
        rethrow;
      }
      throw DataFailure.from(error);
    }
  }
}
