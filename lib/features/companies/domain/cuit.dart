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
///
/// ---------------------------------------------------------------------------
/// ADVERTENCIA PARA QUIEN VENGA A "ARREGLAR" ESTE ALGORITMO
/// ---------------------------------------------------------------------------
///
/// **No existe documentación oficial de ARCA/AFIP del dígito verificador.** Se
/// buscó en afip.gob.ar, arca.gob.ar, argentina.gob.ar, el Boletín Oficial e
/// InfoLEG. Lo único oficial que se encontró dice que la validez depende del
/// prefijo Y del dígito verificador, sin publicar el cálculo. Todo lo que
/// sostiene este validador es (a) aritmética verificada contra CUIT reales de
/// fuente oficial, (b) código de terceros que **se contradice entre sí**.
///
/// Lo que SÍ tiene consenso, y no hay que tocar:
///   * pesos `5,4,3,2,7,6,5,4,3,2` sobre los primeros 10 dígitos;
///   * `candidato = 11 - (suma mod 11)`;
///   * `candidato == 11` ⇒ dígito `0`.
///
/// Lo que NO tiene consenso: qué hacer con `candidato == 10`.
///   * Este código informa `9` (regla PERMISIVA). Es lo que hace `python-stdnum`,
///     cuya única fuente citada es Wikipedia en español, que a su vez no tiene
///     referencia bibliográfica en esa sección.
///   * `lalloni/afip` (Go) implementa la regla ESTRICTA y documenta que un
///     candidato `10` significa que ese CUIT no puede existir.
///
/// Por qué se mantiene la permisiva, como DECISIÓN EXPLÍCITA y no por descuido:
/// la tabla de "cambio de prefijo" (20→23, 27→23, 30→33…) es una regla de
/// EMISIÓN, no de validación — el CUIT que ARCA efectivamente emite satisface
/// siempre el algoritmo plano. Endurecer a la regla estricta rechazaría un
/// ~9,09% adicional de números (1 de cada 11 cuerpos por prefijo) que casi con
/// seguridad no existen, pero cuyo fundamento último es una inferencia y no una
/// norma. Ejemplo concreto: `20-10000005-9` lo acepta la regla permisiva y no
/// la estricta; el emitible de verdad para ese cuerpo es `23-10000005-9`.
/// Cambiar esto es una decisión del fundador sobre tolerancia al falso
/// negativo en el signup, no una corrección de bug. El test
/// `test/features/companies/domain/cuit_test.dart` fija el comportamiento
/// actual en ese caso, apareado con `supabase/tests/database/014_…`.
///
/// LO QUE ESTE VALIDADOR **NO** DECIDE, y es también decisión del fundador:
/// qué prefijos acepta la plataforma como "empresa empleadora". Hoy acepta
/// TODOS. Restringir a `30/33/34` excluiría por diseño a empleadores legalmente
/// válidos (monotributistas y autónomos emplean con su CUIT personal 20/23/24/27,
/// asignado de forma aleatoria y no binaria desde la RG Conjunta AFIP-ANSES
/// 5007/2021). Aceptar todo deja entrar los CUIT genéricos de país (50/51/55),
/// que no identifican una entidad. Cualquiera de las dos puede ser correcta;
/// ninguna se hereda de una suposición del código.
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
