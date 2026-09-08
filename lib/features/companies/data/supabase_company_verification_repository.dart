import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/data_failure.dart';
import '../domain/company_verification.dart';
import 'company_access_repository.dart';
import 'company_verification_repository.dart';

/// Implementación sobre Supabase (RPCs de 0028 + bucket privado de 0029).
///
/// Recibe el `SupabaseClient` por constructor para ejercitarla en tests con un
/// cliente HTTP falso, sin proyecto remoto.
class SupabaseCompanyVerificationRepository
    implements CompanyVerificationRepository {
  SupabaseCompanyVerificationRepository(this._client);

  final SupabaseClient _client;

  static const _bucket = 'company-docs';

  /// Vida de la URL firmada de la constancia. Corta a propósito: la pantalla la
  /// renueva al volver a entrar, y un enlace filtrado deja de servir enseguida.
  static const _signedUrlSeconds = 300;

  @override
  Future<CompanyVerification> fetchMyVerification() {
    return _guard(() async {
      final raw = await _client.rpc<dynamic>('my_company_verification');
      final row = _firstRow(raw);
      if (row == null) {
        throw const DataFailure(
          DataFailureCode.notAllowed,
          debugDetail: 'my_company_verification: sin filas',
        );
      }
      return CompanyVerification.fromJson(row);
    });
  }

  @override
  Future<String> uploadConstancia(PickedConstancia document) {
    return _guard(() async {
      final format = document.format;
      if (format == null) {
        throw const DataFailure(
          DataFailureCode.invalidData,
          debugDetail: 'constancia: extensión no admitida',
        );
      }
      if (document.isTooLarge) {
        throw const DataFailure(
          DataFailureCode.invalidData,
          debugDetail: 'constancia: supera el límite del bucket',
        );
      }
      // El path lo decide el servidor a partir de la sesión: acá se pide, no se
      // arma. La policy del bucket vuelve a comprobar lo mismo.
      final path = await _client.rpc<dynamic>(
        'company_document_upload_path',
        params: {'p_extension': format.wireName},
      );
      if (path is! String || path.isEmpty) {
        throw const DataFailure(
          DataFailureCode.unknown,
          debugDetail: 'company_document_upload_path: respuesta vacía',
        );
      }
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            path,
            document.bytes,
            fileOptions: FileOptions(
              contentType: format.contentType,
              // Reemplazar la constancia sobreescribe el mismo objeto: el
              // nombre es canónico y no quedan huérfanos.
              upsert: true,
            ),
          );
      return path;
    });
  }

  @override
  Future<String> requestVerification({
    required String cuit,
    ConstanciaFormat? format,
  }) {
    return _guard(() async {
      final id = await _client.rpc<dynamic>(
        'request_company_verification',
        params: {'p_cuit': cuit, 'p_document_extension': format?.wireName},
      );
      if (id is! String || id.isEmpty) {
        throw const DataFailure(
          DataFailureCode.unknown,
          debugDetail: 'request_company_verification: respuesta vacía',
        );
      }
      return id;
    });
  }

  @override
  Future<String> createConstanciaSignedUrl(String path) {
    return _guard(
      () => _client.storage
          .from(_bucket)
          .createSignedUrl(path, _signedUrlSeconds),
    );
  }

  @override
  Future<List<CompanyVerificationRequest>> fetchVerificationQueue(
    CompanyVerificationStatus status,
  ) {
    return _guard(() async {
      final raw = await _client.rpc<dynamic>(
        'admin_list_company_verifications',
        params: {'p_status': status.wireName},
      );
      if (raw is! List) {
        throw const DataFailure(
          DataFailureCode.unknown,
          debugDetail:
              'admin_list_company_verifications: respuesta no es lista',
        );
      }
      return [
        for (final row in raw)
          if (row is Map<String, dynamic>)
            CompanyVerificationRequest.fromJson(row),
      ];
    });
  }

  @override
  Future<void> reviewVerification({
    required String requestId,
    required bool approve,
    VerificationRejectionReason? reason,
  }) {
    return _guard(() async {
      await _client.rpc<dynamic>(
        'admin_review_company_verification',
        params: {
          'p_request_id': requestId,
          'p_decision': approve ? 'approved' : 'rejected',
          'p_reason': approve ? null : reason?.wireName,
        },
      );
    });
  }

  /// Primera fila de una RPC que devuelve `returns table (...)`: PostgREST la
  /// entrega siempre como lista, incluso cuando hay a lo sumo una.
  Map<String, dynamic>? _firstRow(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is List) {
      for (final row in raw) {
        if (row is Map<String, dynamic>) {
          return row;
        }
      }
    }
    return null;
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
