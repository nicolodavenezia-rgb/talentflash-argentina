/// Rol de negocio del usuario autenticado (`DATA_MODEL.md` §1.1 — enum
/// `user_role`; `SECURITY.md` §3).
///
/// **Fuente confiable única:** el claim `role` de `app_metadata` del JWT, que
/// escribe el trigger `handle_new_user` (migración 0004) a partir de un valor
/// saneado. `user_metadata` es input del cliente y **jamás** se usa para
/// autorizar: un signup puede pedir `admin` en `raw_user_meta_data` y el
/// trigger igual persiste `candidate`.
enum BusinessRole {
  candidate('candidate'),
  company('company'),
  admin('admin');

  const BusinessRole(this.claim);

  /// Valor exacto que viaja en `app_metadata.role`.
  final String claim;

  /// Traduce el claim confiable. Devuelve `null` ante cualquier valor que no
  /// sea exactamente uno de los tres esperados: sin claim válido no hay rol, y
  /// nunca se asume `admin` (fail-closed, `SECURITY.md` §3).
  ///
  /// La comparación es exacta a propósito (sin `trim`/`toLowerCase`): el
  /// trigger escribe el texto del enum de Postgres, así que cualquier
  /// desviación indica un token manipulado o un usuario provisionado fuera
  /// del flujo soportado, y ese caso debe tratarse como sesión inconsistente.
  static BusinessRole? fromClaim(Object? rawClaim) {
    if (rawClaim is! String) {
      return null;
    }
    for (final role in BusinessRole.values) {
      if (role.claim == rawClaim) {
        return role;
      }
    }
    return null;
  }
}
