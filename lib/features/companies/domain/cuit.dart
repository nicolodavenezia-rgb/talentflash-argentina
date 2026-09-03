/// CUIT argentino como value object (T-027).
///
/// Misma semántica que `private.cuit_is_valid` / `private.cuit_format` en la
/// base (migración `0025`): mismos pesos, los mismos dos resultados especiales
/// del módulo 11 y la misma forma canónica. Acá sirve solo para UX — el
/// servidor vuelve a validar en la RPC y en el trigger de tabla, así que
/// saltearse el cliente no habilita nada (`SECURITY.md` §3).
///
/// No consulta ARCA, no infiere titularidad y no deduce si el CUIT existe de
/// verdad: eso es revisión humana (T-028).
library;

/// Motivo por el que un CUIT no se acepta. Se informa el primero que aparece,
/// del problema más grosero al más fino.
enum CuitIssue {
  /// No hay ningún dígito.
  empty,

  /// Trae letras o símbolos que no son separadores admitidos.
  invalidCharacters,

  /// Hay dígitos, pero no son exactamente 11.
  wrongLength,

  /// Son 11 dígitos pero el verificador no cierra por módulo 11.
  checkDigit,
}

/// Un CUIT ya validado. No existe forma de construir uno inválido: [parse] es
/// la única puerta y devuelve `null` cuando el valor no pasa.
final class Cuit {
  const Cuit._(this.digits);

  /// Los 11 dígitos sin separadores, con los ceros iniciales conservados: se
  /// guarda texto, nunca un entero.
  final String digits;

  /// Pesos del módulo 11, en el orden de los 10 primeros dígitos.
  static const List<int> _weights = <int>[5, 4, 3, 2, 7, 6, 5, 4, 3, 2];

  /// Caracteres admitidos: dígitos y los separadores ` ` y `-`.
  static final RegExp _allowedCharacters = RegExp(r'^[0-9\s-]*$');

  /// Las tres escrituras aceptadas, con el separador SOLO donde corresponde:
  /// `30712345671`, `30-71234567-1` y `30 71234567 1`. Un separador corrido
  /// (`30-7123456-71`) se rechaza aunque haya once dígitos — casi siempre es
  /// un dígito mal tipeado, y aceptarlo convertiría el error en el CUIT válido
  /// de otra empresa. Misma regla que `private.cuit_digits` en `0025`.
  static final RegExp _shape = RegExp(r'^[0-9]{2}[ -]?[0-9]{8}[ -]?[0-9]$');

  static final RegExp _separators = RegExp('[ -]');
  static final RegExp _elevenDigits = RegExp(r'^[0-9]{11}$');

  /// Forma canónica `XX-XXXXXXXX-X`, la misma que persiste la base.
  String get formatted =>
      '${digits.substring(0, 2)}-${digits.substring(2, 10)}'
      '-${digits.substring(10)}';

  /// Los dos primeros dígitos. Se expone porque la UI los agrupa, no porque se
  /// infiera nada de ellos.
  String get prefix => digits.substring(0, 2);

  /// Dígito verificador de los 10 primeros dígitos, o `null` si no recibe
  /// exactamente 10 dígitos.
  ///
  /// Aritmética entera de punta a punta: el CUIT completo nunca se convierte a
  /// `double`, que en JavaScript (Flutter Web) dejaría de ser exacto más allá
  /// de 2^53. Contempla los dos resultados especiales del algoritmo: 11 se
  /// informa como 0 y 10 como 9.
  static int? checkDigitOf(String tenDigits) {
    if (tenDigits.length != 10 || !RegExp(r'^[0-9]{10}$').hasMatch(tenDigits)) {
      return null;
    }
    var total = 0;
    for (var i = 0; i < 10; i++) {
      total += int.parse(tenDigits[i]) * _weights[i];
    }
    final candidate = 11 - (total % 11);
    if (candidate == 11) {
      return 0;
    }
    if (candidate == 10) {
      return 9;
    }
    return candidate;
  }

  /// Motivo del rechazo, o `null` si [raw] es un CUIT válido.
  static CuitIssue? validate(String raw) {
    final trimmed = raw.trim();
    if (!_allowedCharacters.hasMatch(trimmed)) {
      return CuitIssue.invalidCharacters;
    }
    if (trimmed.replaceAll(_separators, '').isEmpty) {
      return CuitIssue.empty;
    }
    if (!_shape.hasMatch(trimmed)) {
      return CuitIssue.wrongLength;
    }
    final digits = trimmed.replaceAll(_separators, '');
    if (checkDigitOf(digits.substring(0, 10)) != int.parse(digits[10])) {
      return CuitIssue.checkDigit;
    }
    return null;
  }

  /// El CUIT validado, o `null`. Única forma de obtener un [Cuit].
  static Cuit? parse(String raw) {
    if (validate(raw) != null) {
      return null;
    }
    return Cuit._(raw.trim().replaceAll(_separators, ''));
  }

  static bool isValid(String raw) => validate(raw) == null;

  /// Formatea lo que haya para mostrarlo mientras se tipea: con 11 dígitos los
  /// agrupa aunque el verificador todavía no cierre, y si no, devuelve los
  /// dígitos tal cual. Nunca valida: es puro formateo de UI, y por eso descarta
  /// cualquier caracter que no sea dígito en vez de rechazar la entrada.
  static String formatPartial(String raw) {
    final digits = raw.replaceAll(RegExp('[^0-9]'), '');
    if (!_elevenDigits.hasMatch(digits)) {
      return digits;
    }
    return '${digits.substring(0, 2)}-${digits.substring(2, 10)}'
        '-${digits.substring(10)}';
  }

  @override
  bool operator ==(Object other) => other is Cuit && other.digits == digits;

  @override
  int get hashCode => digits.hashCode;

  @override
  String toString() => formatted;
}
