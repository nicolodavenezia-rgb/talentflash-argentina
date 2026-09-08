/// Nivel de garantía de autenticación de **la sesión** (claim `aal` del JWT).
///
/// Es una propiedad de la sesión y no de la cuenta: la misma persona puede
/// tener un factor verificado y aun así estar en `aal1` porque en este inicio
/// de sesión todavía no lo confirmó. Por eso vive en `AuthStatusSignedIn` y no
/// en `AuthenticatedUser`, y por eso el servidor (`private.caller_is_aal2()`,
/// migración 0028) lo lee del token y no de una tabla.
///
/// La comparación es exacta, igual que en SQL: `'AAL2'`, `'aal2 '` o `'aal3'`
/// no son el valor que emite GoTrue y se tratan como [unknown], que a todos
/// los efectos vale lo mismo que no tener segundo factor (fail-closed).
enum SessionAssurance {
  /// Un solo factor (contraseña, OTP por correo, etc.).
  aal1('aal1'),

  /// Contraseña más un segundo factor verificado en esta sesión.
  aal2('aal2'),

  /// El claim falta, no se pudo leer o trae un valor desconocido.
  unknown(null);

  const SessionAssurance(this.claim);

  /// Valor exacto del claim `aal`, o `null` para [unknown].
  final String? claim;

  /// Lo único que habilita a mostrar la cola administrativa. `nextLevel`
  /// (tener un factor verificado) NO cuenta: demuestra que la cuenta puede
  /// subir, no que esta sesión ya subió.
  bool get isSecondFactorVerified => this == SessionAssurance.aal2;

  /// Traduce el claim crudo. Cualquier cosa que no sea exactamente `aal1` o
  /// `aal2` cae en [unknown]; nunca se asume el nivel alto.
  static SessionAssurance fromClaim(Object? rawClaim) {
    if (rawClaim is! String) {
      return SessionAssurance.unknown;
    }
    for (final level in SessionAssurance.values) {
      if (level.claim != null && level.claim == rawClaim) {
        return level;
      }
    }
    return SessionAssurance.unknown;
  }
}
