import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Códigos de fallo de la capa de datos (PostgREST/RPC), alineados con el
/// contrato de errores de las migraciones del Bloque C (`0022`):
/// `42501` → [notAllowed] · `TF018` → [underage] · `TFDAT` → [invalidData] ·
/// `TFCNS` → [staleConsent] · `23505` → [duplicate].
enum DataFailureCode {
  /// Sin permiso: rol equivocado, sesión ausente o columna protegida.
  notAllowed,

  /// La persona no es mayor de 18 años (regla server-side, PRIVACY.md §3).
  underage,

  /// Datos incompletos o inválidos (geo incoherente, sector inactivo, etc.).
  invalidData,

  /// Falta un consentimiento obligatorio o la versión aceptada no es la
  /// vigente.
  staleConsent,

  /// Violación de unicidad (p. ej. CUIT ya registrado).
  duplicate,

  /// Problema de red o timeout.
  network,

  unknown,
}

/// Error tipado de la capa de datos.
///
/// La UI muestra SIEMPRE un texto del ARB elegido por [code]; el mensaje
/// interno de Postgres/PostgREST queda en [debugDetail] para diagnóstico y
/// nunca llega a la pantalla (`SECURITY.md` §2).
class DataFailure implements Exception {
  const DataFailure(this.code, {this.debugDetail = ''});

  factory DataFailure.from(Object error) {
    if (error is DataFailure) {
      return error;
    }
    if (error is PostgrestException) {
      final code = switch (error.code) {
        '42501' => DataFailureCode.notAllowed,
        'TF018' => DataFailureCode.underage,
        'TFDAT' => DataFailureCode.invalidData,
        'TFCNS' => DataFailureCode.staleConsent,
        '23505' => DataFailureCode.duplicate,
        // FKs y checks violados equivalen a datos inválidos del cliente.
        '23503' || '23514' || '23502' => DataFailureCode.invalidData,
        _ => DataFailureCode.unknown,
      };
      return DataFailure(code, debugDetail: 'postgrest:${error.code}');
    }
    if (error is AuthException) {
      return DataFailure(
        DataFailureCode.notAllowed,
        debugDetail: 'auth:${error.code ?? error.statusCode ?? 'desconocido'}',
      );
    }
    if (error is TimeoutException) {
      return const DataFailure(DataFailureCode.network, debugDetail: 'timeout');
    }
    // `ClientException` de package:http y errores de socket llegan con este
    // aspecto sin importar la plataforma; se evita dart:io por la Web.
    final description = error.toString();
    if (description.contains('SocketException') ||
        description.contains('ClientException') ||
        description.contains('Connection')) {
      return const DataFailure(DataFailureCode.network, debugDetail: 'red');
    }
    return DataFailure(
      DataFailureCode.unknown,
      debugDetail: error.runtimeType.toString(),
    );
  }

  final DataFailureCode code;

  /// Detalle interno para logs; jamás se muestra.
  final String debugDetail;

  @override
  String toString() => 'DataFailure($code, $debugDetail)';
}
