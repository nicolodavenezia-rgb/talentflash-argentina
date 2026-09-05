import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/data_failure.dart';
import 'company_access_repository.dart';

/// Lectura del estado de verificación propio a través de
/// `public.my_company_verification()` (migración `0028`).
///
/// POR QUÉ LA RPC Y NO UN SELECT: la versión anterior consultaba
/// `company_members` con `.eq('profile_id', uid).limit(1).maybeSingle()`. Con
/// una cuenta que hubiera quedado en más de una empresa, ese `limit(1)` elegía
/// UNA en silencio —la que devolviera el planner, sin orden estable— y la
/// pantalla podía mostrar "Empresa verificada" leyendo la empresa equivocada.
/// Un estado de autorización nunca se decide por un desempate arbitrario.
///
/// La RPC resuelve la empresa con `private.caller_company()`, que es la misma
/// función que usan todas las RPC del bloque, y distingue los tres casos con
/// sqlstates distintos (`0031`): ninguna empresa (`TFEMP`) y más de una
/// (`TFMUL`). Acá el segundo se convierte en un fallo tipado, no en un valor.
class SupabaseCompanyAccessRepository implements CompanyAccessRepository {
  SupabaseCompanyAccessRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CompanyVerificationStatus?> fetchOwnVerificationStatus() async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) {
        throw const DataFailure(DataFailureCode.notAllowed);
      }

      final result = await _client.rpc<dynamic>('my_company_verification');

      // La RPC devuelve una tabla: PostgREST la serializa como lista de filas.
      if (result is! List || result.isEmpty) {
        // Sin filas no hay empresa que informar. No se infiere ningún estado.
        return null;
      }
      final row = result.first;
      if (row is! Map) {
        return null;
      }

      // `fromWire` devuelve null ante un valor desconocido y la UI trata ese
      // null como "sin estado": un enum nuevo en la base no se muestra como
      // verificado por accidente.
      return CompanyVerificationStatus.fromWire(row['company_status']);
    } on PostgrestException catch (error) {
      // Todavía no integra ninguna empresa: es el estado normal de una cuenta
      // recién creada, no un error que haya que mostrar.
      if (error.code == 'TFEMP') {
        return null;
      }
      // Más de una empresa: estado partido que el cliente NO puede resolver
      // eligiendo una. Falla cerrado y tipado.
      throw DataFailure.from(error);
    } catch (error) {
      if (error is DataFailure) {
        rethrow;
      }
      throw DataFailure.from(error);
    }
  }
}
