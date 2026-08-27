/// Validaciones de formulario, puras y testeables sin Flutter.
///
/// Los textos viven en el ARB; acá solo se decide **qué** falla.
library;

/// Problemas posibles del campo correo.
enum EmailIssue { required, invalidFormat }

/// Problemas posibles del campo contraseña.
enum PasswordIssue { required, tooShort }

/// Problemas posibles de la confirmación de contraseña.
enum PasswordConfirmationIssue { required, mismatch }

/// Reglas de credenciales alineadas con `SECURITY.md` §2 y con
/// `supabase/config.toml` (`auth.minimum_password_length = 10`).
abstract final class AuthValidation {
  /// Mínimo de caracteres exigido por Supabase Auth y por SECURITY.md §2.
  /// Sin reglas de composición arbitrarias (misma decisión del documento).
  static const int minPasswordLength = 10;

  /// Deliberadamente permisiva: valida forma, no existencia. Rechazar correos
  /// válidos raros es peor que dejar pasar uno inexistente, que el backend
  /// resuelve igual.
  static final RegExp _emailPattern = RegExp(
    r'^[^@\s]+@[^@\s.]+(\.[^@\s.]+)+$',
  );

  /// Normaliza antes de enviar: sin espacios al borde y en minúsculas.
  /// Supabase guarda el correo en minúsculas; normalizar evita duplicados
  /// aparentes y fallos de login por mayúsculas.
  static String normalizeEmail(String raw) => raw.trim().toLowerCase();

  static EmailIssue? validateEmail(String raw) {
    final value = normalizeEmail(raw);
    if (value.isEmpty) {
      return EmailIssue.required;
    }
    if (!_emailPattern.hasMatch(value)) {
      return EmailIssue.invalidFormat;
    }
    return null;
  }

  /// La contraseña no se recorta: los espacios son caracteres válidos.
  static PasswordIssue? validatePassword(String raw) {
    if (raw.isEmpty) {
      return PasswordIssue.required;
    }
    if (raw.length < minPasswordLength) {
      return PasswordIssue.tooShort;
    }
    return null;
  }

  static PasswordConfirmationIssue? validatePasswordConfirmation(
    String password,
    String confirmation,
  ) {
    if (confirmation.isEmpty) {
      return PasswordConfirmationIssue.required;
    }
    if (confirmation != password) {
      return PasswordConfirmationIssue.mismatch;
    }
    return null;
  }
}
