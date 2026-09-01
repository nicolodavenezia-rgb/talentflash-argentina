/// Reglas puras de validación del onboarding (T-016/T-017). Cada regla existe
/// también server-side (migración 0022): esto es UX temprana, no seguridad.
library;

enum FullNameIssue { empty, tooShort }

enum BirthDateIssue { empty, invalidFormat, inFuture, underage }

enum CuitIssue { empty, wrongLength }

enum WebsiteIssue { invalid }

abstract final class OnboardingValidation {
  static const int adultAge = 18;

  /// Fecha en la que la persona cumple 18, por calendario. Quien nació un 29
  /// de febrero los cumple el 1 de marzo de los años no bisiestos (mismo
  /// redondeo que `private.is_adult` en la base: ninguna capa es más
  /// permisiva que la otra).
  static DateTime majorityDate(DateTime birthDate) =>
      DateTime(birthDate.year + adultAge, birthDate.month, birthDate.day);

  static bool isAdult(DateTime birthDate, {DateTime? on}) {
    final today = _dateOnly(on ?? DateTime.now());
    return !majorityDate(_dateOnly(birthDate)).isAfter(today);
  }

  /// Interpreta `DD/MM/AAAA` de forma estricta (fechas de calendario reales).
  static DateTime? parseBirthDate(String raw) {
    final match = RegExp(r'^\s*([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})\s*$')
        .firstMatch(raw);
    if (match == null) {
      return null;
    }
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);
    // DateTime "arregla" fechas inexistentes (32/01 → 01/02): eso acá es un
    // error de tipeo, no una fecha.
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  static FullNameIssue? validateFullName(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return FullNameIssue.empty;
    }
    if (value.length < 2) {
      return FullNameIssue.tooShort;
    }
    return null;
  }

  static BirthDateIssue? validateBirthDate(String raw, {DateTime? today}) {
    if (raw.trim().isEmpty) {
      return BirthDateIssue.empty;
    }
    final parsed = parseBirthDate(raw);
    if (parsed == null) {
      return BirthDateIssue.invalidFormat;
    }
    final reference = _dateOnly(today ?? DateTime.now());
    if (parsed.isAfter(reference)) {
      return BirthDateIssue.inFuture;
    }
    if (!isAdult(parsed, on: reference)) {
      return BirthDateIssue.underage;
    }
    return null;
  }

  /// Deja solo dígitos y, si son 11, aplica el formato `XX-XXXXXXXX-X` que
  /// exige la base. La validación del dígito verificador es T-027 (Bloque E).
  static String normalizeCuit(String raw) {
    final digits = raw.replaceAll(RegExp('[^0-9]'), '');
    if (digits.length != 11) {
      return digits;
    }
    return '${digits.substring(0, 2)}-${digits.substring(2, 10)}'
        '-${digits.substring(10)}';
  }

  static CuitIssue? validateCuit(String raw) {
    final digits = raw.replaceAll(RegExp('[^0-9]'), '');
    if (digits.isEmpty) {
      return CuitIssue.empty;
    }
    if (digits.length != 11) {
      return CuitIssue.wrongLength;
    }
    return null;
  }

  /// El sitio web es opcional; si está, se completa el esquema y se valida.
  static String? normalizeWebsite(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return 'https://$value';
  }

  static WebsiteIssue? validateWebsite(String raw) {
    final normalized = normalizeWebsite(raw);
    if (normalized == null) {
      return null; // opcional
    }
    final valid = RegExp(r'^https?://[^\s]+\.[^\s]+$').hasMatch(normalized);
    return valid ? null : WebsiteIssue.invalid;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
