import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Códigos de fallo de la capa de datos (PostgREST/RPC/Storage), alineados con
/// el contrato de errores de las migraciones:
/// `42501` → [notAllowed] · `TF018` → [underage] · `TFDAT` → [invalidData] ·
/// `TFCNS` → [staleConsent] · `23505` → [duplicate] · `TFCUI` → [invalidCuit] ·
/// `TFMFA` → [secondFactorRequired] · `TFMUL` → [ambiguousCompany] ·
/// `TFJOB` → [jobStateConflict].
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

  /// El CUIT no pasa el dígito verificador (`TFCUI`, migración 0025). Antes
  /// caía en [unknown] y la pantalla mostraba un error genérico para el caso
  /// más frecuente del formulario de empresa.
  invalidCuit,

  /// La cuenta integra más de una empresa (`TFMUL`, migración 0031). No se
  /// resuelve eligiendo una: la lectura falla cerrada y la UI lo explica.
  ambiguousCompany,

  /// La acción exige una sesión con segundo factor (`TFMFA`, migración 0028).
  /// Es distinto de [notAllowed]: la cuenta tiene el permiso, le falta el
  /// nivel de autenticación.
  secondFactorRequired,

  /// La oferta no admite esa acción en el estado en que está AHORA (`TFJOB`,
  /// migración 0032): otra persona del equipo la pausó o la cerró, venció, o
  /// fue descartada. No es falta de permiso ni un dato inválido: la acción
  /// tenía sentido con lo que la pantalla mostraba y dejó de tenerlo, así que
  /// la UI recarga la oferta y lo explica.
  jobStateConflict,

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
        'TFCUI' => DataFailureCode.invalidCuit,
        'TFMFA' => DataFailureCode.secondFactorRequired,
        'TFMUL' => DataFailureCode.ambiguousCompany,
        'TFJOB' => DataFailureCode.jobStateConflict,
        '23505' => DataFailureCode.duplicate,
        // FKs y checks violados equivalen a datos inválidos del cliente.
        '23503' || '23514' || '23502' => DataFailureCode.invalidData,
        _ => DataFailureCode.unknown,
      };
      return DataFailure(code, debugDetail: 'postgrest:${error.code}');
    }
    // Las policies del bucket privado rechazan con 4xx de Storage, no con un
    // SQLSTATE: sin esto, "no podés tocar esa carpeta" llegaba como `unknown`.
    if (error is StorageException) {
      final status = int.tryParse('${error.statusCode}');
      final code = switch (status) {
        400 || 401 || 403 => DataFailureCode.notAllowed,
        413 || 415 || 422 => DataFailureCode.invalidData,
        408 || 429 || 502 || 503 || 504 => DataFailureCode.network,
        _ => DataFailureCode.unknown,
      };
      return DataFailure(code, debugDetail: 'storage:${error.statusCode}');
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
