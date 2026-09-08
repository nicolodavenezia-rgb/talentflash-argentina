/// Tipos de dominio del segundo factor TOTP, desacoplados del SDK.
///
/// Solo entran acá los datos que el flujo necesita. El secreto y la URI del
/// alta viven **únicamente en memoria** mientras dura la pantalla: no se
/// persisten, no se loguean y no viajan por URL (por eso `toString` los
/// omite a propósito).
library;

/// Un factor TOTP **ya verificado** de la cuenta, tal como lo lista el
/// servidor. Sirve para elegir contra cuál desafiar cuando hay varios.
class SecondFactor {
  const SecondFactor({required this.id, this.friendlyName, this.createdAt});

  final String id;

  /// Etiqueta que se dio al factor al crearlo; puede faltar.
  final String? friendlyName;

  final DateTime? createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecondFactor &&
          other.id == id &&
          other.friendlyName == friendlyName &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, friendlyName, createdAt);

  @override
  String toString() => 'SecondFactor(id: $id, friendlyName: $friendlyName)';
}

/// Alta TOTP en curso: un factor **pendiente** (no verificado) con el secreto
/// que hay que cargar en la app de autenticación.
///
/// Crear este objeto no configura nada: el factor recién cuenta cuando el
/// servidor acepta un código. Si la persona se va antes, se descarta.
class TotpEnrollment {
  const TotpEnrollment({
    required this.factorId,
    required this.friendlyName,
    required this.secret,
    required this.uri,
  });

  final String factorId;
  final String friendlyName;

  /// Clave base32 para la carga manual. **Sensible.**
  final String secret;

  /// URI `otpauth://totp/...` que codifica el QR. **Sensible.**
  final String uri;

  /// La clave en bloques de cuatro para que se pueda leer y tipear.
  String get secretGrouped {
    final buffer = StringBuffer();
    for (var i = 0; i < secret.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(secret[i]);
    }
    return buffer.toString();
  }

  /// La clave carácter por carácter, para que el lector de pantalla la
  /// deletree en vez de intentar pronunciarla.
  String get secretSpelled => secret.split('').join(' ');

  /// Sin secreto ni URI a propósito: este objeto puede terminar en un log.
  @override
  String toString() => 'TotpEnrollment(factorId: $factorId)';
}

/// Desafío emitido por el servidor para un factor. Vence solo: pasado
/// [expiresAt] hay que pedir otro antes de mandar un código.
class SecondFactorChallenge {
  const SecondFactorChallenge({
    required this.id,
    required this.factorId,
    required this.expiresAt,
  });

  final String id;
  final String factorId;
  final DateTime expiresAt;

  /// Margen para no mandar un código contra un desafío que vence en el
  /// viaje: mejor pedir uno nuevo que recibir `mfa_challenge_expired`.
  static const expiryMargin = Duration(seconds: 10);

  bool isExpiredAt(DateTime now) => !now.add(expiryMargin).isBefore(expiresAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecondFactorChallenge &&
          other.id == id &&
          other.factorId == factorId &&
          other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(id, factorId, expiresAt);

  @override
  String toString() =>
      'SecondFactorChallenge(id: $id, factorId: $factorId, '
      'expiresAt: $expiresAt)';
}
