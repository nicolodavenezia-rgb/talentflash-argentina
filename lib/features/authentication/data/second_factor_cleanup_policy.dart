import 'dart:convert';

/// Qué factores puede dar de baja **la app sola**, sin que una persona lo pida.
///
/// ## Por qué hace falta una política y no alcanza una comprobación
///
/// GoTrue no ofrece una baja condicional: no existe «borrá este factor **solo
/// si** sigue sin verificar». Y comprobar antes no sirve, porque la
/// comprobación y el borrado son dos pedidos distintos: entre el `GET /user`
/// que contesta «pendiente» y el `DELETE` puede entrar la verificación.
///
/// Por eso ninguna de estas cosas cierra la carrera, y no hay que volver a
/// proponerlas: agregar el nivel a la identidad de sesión, refrescar o
/// consultar justo antes del `DELETE`, guardar una marca solo en el controller
/// (que es `autoDispose` y muere con la pantalla), o esperar un rato.
///
/// ## Qué decide hoy: no mandar ninguna baja automática
///
/// **No alcanza con tener el secreto.** Una versión anterior de este archivo
/// decía que la app conserva el único ejemplar porque GoTrue lo entrega una
/// sola vez. Es falso: el secreto se **muestra** en pantalla, como QR y como
/// clave manual, para que la persona lo copie. Esa afirmación está retirada.
///
/// **Y tampoco alcanza el rechazo del servidor.** Parecía que sí: con la
/// sesión en `aal1`, un `DELETE` sobre un factor verificado responde
/// `422 insufficient_aal` y el factor sobrevive (medido, y fijado en
/// `npm run mfa:test`). Pero ese rechazo **no es una baja condicional**: por
/// lectura del código de `v2.195.0` se ve que el chequeo corre fuera de la
/// transacción que borra, sobre un factor leído antes, y que adentro nadie
/// relee ni bloquea la fila. Ver [automaticUnenrollEnabled].
///
/// Sin una baja condicional del lado del servidor, **ninguna evidencia que la
/// app pueda juntar autoriza una baja automática**: siempre queda la ventana
/// entre decidir y borrar. Así que no se manda. Es la única forma de cerrar
/// «la app no destruye un factor verificado» sin condiciones ni supuestos
/// sobre versiones.
///
/// ## Qué queda vivo, y por qué
///
/// El registro de intentos ([beginVerifyAttempt] / [rejectVerifyAttempt],
/// alimentado por `SecondFactorAttemptRecorder` desde el transporte) se
/// conserva y se sigue probando. No es adorno: es la **precondición** que
/// habría que cumplir el día que exista un endpoint de baja usable, y es lo
/// que impide que alguien vuelva a encender las bajas sin reintroducir D1.
///
/// Está cableado en [canAutoUnenroll], pero **hoy no se llega a evaluar**:
/// el `&&` cortocircuita en [automaticUnenrollEnabled] y las condiciones por
/// factor no se consultan. Lo que las mantiene honestas mientras tanto son
/// sus tests propios, que las ejercitan directamente en vez de a través de
/// [canAutoUnenroll].
///
/// ## Lo que esto NO resuelve
///
/// Las configuraciones incompletas se acumulan contra el tope de la cuenta.
/// Es un problema distinto —disponibilidad, no destrucción— y se trata
/// aparte. El servidor tiene dos limpiezas, y cada una alcanza a un grupo
/// distinto: la que corre dentro del handler del alta recolecta solo los
/// pendientes **sin ningún desafío** (por eso el desafío se pide recién al
/// mandar el código), y una **verificación TOTP exitosa** borra, en su misma
/// transacción, los demás factores TOTP sin verificar de la cuenta —también
/// los que ya tienen desafío— (`DeleteUnverifiedFactors`, leído en
/// `v2.195.0` y medido: tres abandonados con desafío desaparecieron al
/// verificar un cuarto). Lo que queda sin salida es acumular el tope de
/// pendientes **con** desafío sin que ninguna verificación llegue a
/// completarse nunca. Ver SECURITY.md §2.
class SecondFactorCleanupPolicy {
  /// **La app no manda bajas automáticas. Está en `false` a propósito.**
  ///
  /// `DELETE /auth/v1/factors/{id}` es **incondicional**: no existe «borralo
  /// solo si sigue sin verificar». Y el chequeo que parecía suplirlo no es
  /// atómico. En GoTrue `v2.195.0`, `UnenrollFactor`
  /// (`internal/api/mfa.go`) hace:
  ///
  /// ```go
  /// if factor.IsVerified() && !session.IsAAL2() { return insufficient_aal }
  /// err = db.Transaction(func(tx) error {
  ///   tx.Destroy(factor)            // por clave primaria, sin predicado
  ///   ...
  ///   factor.DowngradeSessionsToAAL1(tx)
  /// })
  /// ```
  ///
  /// El chequeo corre **antes** de la transacción, sobre un factor que se
  /// cargó todavía antes; adentro no se relee ni se bloquea la fila, y
  /// `Destroy` borra por clave primaria sin mirar el estado ni comprobar
  /// cuántas filas tocó.
  ///
  /// El orden en el tiempo es lo que importa, y conviene decirlo despacio
  /// porque a primera vista parece chocar con lo que el servidor sí rechaza.
  /// Cuando el `DELETE` llega, el factor **todavía figura pendiente** y la
  /// sesión **todavía está en `aal1`**: el chequeo mira
  /// `factor.IsVerified()`, que es `false`, y lo deja pasar sin siquiera
  /// evaluar el nivel. Recién **después** entra la verificación, que deja el
  /// factor `verified` y la sesión en `aal2`. Para cuando corre el
  /// `tx.Destroy`, lo que se está borrando ya es el segundo factor de la
  /// cuenta. No hay contradicción con el rechazo medido: ahí el factor ya
  /// estaba verificado **antes** de que llegara el pedido, así que el chequeo
  /// tenía algo que rechazar. Acá no lo tiene, y por eso no protege.
  ///
  /// **Esa carrera está señalada por lectura del código, no reproducida**;
  /// alcanza igual para no poder justificar la baja.
  ///
  /// Como no se puede justificar, no se manda. El costo está medido y
  /// documentado en SECURITY.md §2: las configuraciones incompletas que
  /// llegaron a pedir un desafío ya no las limpia la app en la misma corrida
  /// —antes sí—, y del lado del servidor solo las barre una **verificación
  /// exitosa**, que las borra todas juntas. Las que nunca pidieron desafío
  /// las recolecta el servidor solo, y por eso el desafío se pide recién al
  /// mandar el código.
  ///
  /// Para volver a encenderlo hace falta un endpoint que borre **condicional
  /// y atómicamente**; hasta entonces, cambiar esta constante reintroduce D1.
  static const bool automaticUnenrollEnabled = false;

  /// Factores que **esta** instancia dio de alta.
  ///
  /// Condición conservadora que se conserva junto con el registro de
  /// intentos: la app no tocaría lo que no creó. Hoy no cambia nada, porque
  /// no se manda ninguna baja; queda como parte de la precondición.
  final Set<String> _propios = <String>{};

  /// Intentos de verificación en vuelo o de desenlace desconocido, por factor.
  /// Cada intento tiene **identidad propia**: un rechazo resuelve el suyo y
  /// solo el suyo.
  final Map<String, Set<int>> _sinResolver = <String, Set<int>>{};

  /// A qué factor pertenece cada intento. Sacar la entrada es lo que hace que
  /// un resultado se procese **una sola vez**.
  final Map<int, String> _factorDelIntento = <int, String>{};

  int _ultimoIntento = 0;

  /// Persona de la sesión vigente, para descartar todo al cambiar de cuenta.
  String? _usuario;

  /// El alta creó [factorId].
  void recordEnrolled(String factorId) => _propios.add(factorId);

  /// Un pedido de verificación **está por salir hacia el servidor**. Devuelve
  /// el identificador de ese intento.
  ///
  /// Lo llama el transporte ([SecondFactorAttemptRecorder]), no el
  /// repositorio, y ahí está la diferencia: el repositorio cuenta
  /// *invocaciones*, y un cliente que reintente convierte una invocación en
  /// varios pedidos. El transporte cuenta *pedidos*, que es lo que el servidor
  /// puede llegar a procesar.
  int beginVerifyAttempt(String factorId) {
    final intento = ++_ultimoIntento;
    (_sinResolver[factorId] ??= <int>{}).add(intento);
    _factorDelIntento[intento] = factorId;
    return intento;
  }

  /// El servidor contestó, sin ambigüedad, que **no** verificó el factor en
  /// **ese** intento. Resuelve únicamente a [attemptId].
  ///
  /// Un segundo llamado con el mismo id no hace nada: el resultado de un
  /// pedido se procesa una sola vez. Y el rechazo de un reintento nunca puede
  /// resolver el intento anterior, que es exactamente el defecto que tenía la
  /// versión con un bit por factor.
  void rejectVerifyAttempt(int attemptId) {
    final factorId = _factorDelIntento.remove(attemptId);
    if (factorId == null) return;
    _sinResolver[factorId]?.remove(attemptId);
  }

  /// El factor ya no existe en el servidor.
  void recordGone(String factorId) {
    _propios.remove(factorId);
    final intentos = _sinResolver.remove(factorId);
    if (intentos != null) {
      for (final intento in intentos) {
        _factorDelIntento.remove(intento);
      }
    }
  }

  /// Cambió la persona de la sesión (o no hay ninguna). Se descarta todo.
  ///
  /// Olvidar solo hace que la app se **abstenga más**: un factor que ya no es
  /// «propio» no se toca. Así, cerrar sesión o entrar con otra cuenta nunca
  /// puede habilitar una baja que antes no estaba habilitada.
  void onSessionUser(String? userId) {
    if (userId == _usuario) return;
    _usuario = userId;
    reset();
  }

  /// Descarta todo lo aprendido. Siempre es la dirección segura.
  void reset() {
    _propios.clear();
    _sinResolver.clear();
    _factorDelIntento.clear();
  }

  /// Intentos de verificación de los que **no** se conoce el desenlace.
  int unresolvedVerifications(String factorId) =>
      _sinResolver[factorId]?.length ?? 0;

  /// **Hoy la app no manda ninguna baja automática, y por eso esto siempre
  /// devuelve `false`.** El motivo está en [automaticUnenrollEnabled].
  ///
  /// El resto de las condiciones se conserva y se sigue probando: son la
  /// precondición que habría que cumplir el día que exista un endpoint de
  /// baja que sí se pueda usar sin carrera. Volver a encender esto sin ellas
  /// reintroduce D1.
  bool canAutoUnenroll(String factorId) =>
      automaticUnenrollEnabled &&
      _propios.contains(factorId) &&
      unresolvedVerifications(factorId) == 0;

  /// Por qué no se puede, para el detalle de diagnóstico. Nunca se muestra.
  ///
  /// Se lee de arriba hacia abajo igual que [canAutoUnenroll]: primero el
  /// interruptor, después las condiciones por factor. Mientras
  /// [automaticUnenrollEnabled] esté en `false` **no existe el caso «la baja
  /// está permitida»**, y por eso la última rama no dice eso: decirlo sería
  /// describir una autorización que no se da, y el diagnóstico quedaría
  /// contradiciendo a la única línea que decide.
  String reasonToSkip(String factorId) {
    if (!automaticUnenrollEnabled) {
      return 'la app no manda bajas automáticas '
          '(automaticUnenrollEnabled=false)';
    }
    if (!_propios.contains(factorId)) {
      return 'el factor no lo dio de alta esta instancia';
    }
    final sinResolver = unresolvedVerifications(factorId);
    if (sinResolver > 0) {
      return 'quedan $sinResolver verificaciones de desenlace desconocido '
          'para el factor';
    }
    return 'las condiciones por factor se cumplen';
  }
}

/// Códigos con los que GoTrue dice, sin ambigüedad, que **no verificó el
/// factor en ESE pedido**.
///
/// Leer bien el alcance: cada uno afirma algo del pedido que lo recibió y
/// **nada** de otro. Medido contra el GoTrue local: si una verificación se
/// aceptó y la respuesta se perdió, el reintento con el mismo desafío devuelve
/// `mfa_ip_address_mismatch` y el reintento con un desafío nuevo y código
/// incorrecto devuelve `mfa_verification_failed`, con el factor ya `verified`.
/// Por eso cada intento tiene identidad propia y un rechazo resuelve solo el
/// suyo.
///
/// Es una lista blanca a propósito. Cualquier otro desenlace —un error de
/// transporte, un 5xx, un `stale_session`, un código nuevo de una versión
/// futura de GoTrue— deja el intento sin resolver. Equivocarse hacia «sin
/// resolver» deja un factor pendiente de más; equivocarse hacia «rechazado»
/// borra el segundo factor de alguien.
const Set<String> _rechazosDefinitivos = {
  'mfa_verification_failed',
  'mfa_challenge_expired',
  'mfa_verification_rejected',
  'mfa_ip_address_mismatch',
};

/// `true` solo si la respuesta prueba que el servidor rechazó **este** pedido
/// de verificación.
///
/// Se decide sobre la respuesta cruda, que es lo que ve el transporte: un
/// cuerpo ilegible, un 5xx o un 2xx no son rechazos.
bool isDefinitiveRejectionResponse(int statusCode, List<int> body) {
  // **Solo el rango de error del cliente.** Que el cuerpo traiga uno de los
  // códigos conocidos no alcanza: hay que creerle al estado HTTP primero.
  //
  // - Un **2xx** no es un rechazo, por más que el cuerpo diga otra cosa.
  // - Un **3xx** es una redirección: el cuerpo no es el desenlace, y el
  //   cliente puede terminar mandando la solicitud a otro lado.
  // - Un **5xx** es exactamente incertidumbre: el servidor pudo haber
  //   verificado el factor y haberse caído después, o el error puede venir de
  //   un proxy que copió un cuerpo cualquiera. Tomarlo por rechazo resolvería
  //   un intento que nadie resolvió.
  //
  // Lo medido contra el GoTrue local es `422` para `mfa_verification_failed`
  // y para `mfa_ip_address_mismatch`; se acepta todo el rango 4xx porque es
  // el que significa «el servidor evaluó y se negó», no solo el valor exacto
  // que hoy devuelve. Cualquier otro rango deja el intento sin resolver, que
  // es el lado seguro.
  if (statusCode < 400 || statusCode >= 500) return false;
  try {
    final decodificado = jsonDecode(utf8.decode(body));
    if (decodificado is! Map) return false;
    // GoTrue tiene dos formas de cuerpo de error: la vieja trae el código en
    // `error_code` y `code` con el número HTTP; la nueva lo trae en `code`
    // como texto. Se aceptan las dos, y por eso se exige que sea `String`:
    // así un `"code": 422` de la forma vieja no se confunde con nada. Mirar
    // solo `error_code` dejaría de resolver intentos sin avisar el día que el
    // servidor cambie de forma —seguro, pero acumularía pendientes.
    final codigo = decodificado['error_code'] ?? decodificado['code'];
    return codigo is String && _rechazosDefinitivos.contains(codigo);
  } on Object {
    return false;
  }
}
