import '../../../core/localization/gen/app_localizations.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_validation.dart';

/// Traducción de códigos de dominio a textos es-AR.
///
/// Concentrar el mapeo acá evita strings sueltos en los widgets y garantiza
/// que el mensaje interno de Supabase nunca llegue a la pantalla
/// (`SECURITY.md` §5).
abstract final class AuthCopy {
  static String emailIssue(AppLocalizations l10n, EmailIssue issue) =>
      switch (issue) {
        EmailIssue.required => l10n.authErrorEmailRequired,
        EmailIssue.invalidFormat => l10n.authErrorEmailInvalid,
      };

  static String passwordIssue(AppLocalizations l10n, PasswordIssue issue) =>
      switch (issue) {
        PasswordIssue.required => l10n.authErrorPasswordRequired,
        PasswordIssue.tooShort => l10n.authErrorPasswordTooShort(
          AuthValidation.minPasswordLength,
        ),
      };

  static String passwordConfirmationIssue(
    AppLocalizations l10n,
    PasswordConfirmationIssue issue,
  ) => switch (issue) {
    PasswordConfirmationIssue.required => l10n.authErrorPasswordConfirmRequired,
    PasswordConfirmationIssue.mismatch => l10n.authErrorPasswordMismatch,
  };

  static String failure(AppLocalizations l10n, AuthFailure failure) =>
      switch (failure.code) {
        AuthFailureCode.invalidCredentials =>
          l10n.authFailureInvalidCredentials,
        AuthFailureCode.emailAlreadyRegistered =>
          l10n.authFailureEmailAlreadyRegistered,
        AuthFailureCode.weakPassword => l10n.authFailureWeakPassword,
        AuthFailureCode.emailNotConfirmed => l10n.authFailureEmailNotConfirmed,
        AuthFailureCode.rateLimited => l10n.authFailureRateLimited,
        AuthFailureCode.network => l10n.authFailureNetwork,
        AuthFailureCode.sessionMissing => l10n.authFailureSessionMissing,
        // No es «tu sesión terminó»: la sesión vigente puede ser perfectamente
        // válida (la misma cuenta reingresando, u otra). Lo que caducó es la
        // operación, que pertenecía a la sesión anterior.
        AuthFailureCode.staleSession => l10n.mfaFailureStaleSession,
        AuthFailureCode.mfaInvalidCode => l10n.mfaFailureInvalidCode,
        AuthFailureCode.mfaChallengeExpired => l10n.mfaFailureChallengeExpired,
        AuthFailureCode.mfaFactorNotFound => l10n.mfaFailureFactorNotFound,
        AuthFailureCode.mfaFactorNameConflict => l10n.mfaFailureNameConflict,
        AuthFailureCode.mfaTooManyFactors => l10n.mfaFailureTooManyFactors,
        AuthFailureCode.mfaInsufficientAssurance =>
          l10n.mfaFailureInsufficientAssurance,
        AuthFailureCode.mfaNotEnabled => l10n.mfaFailureNotEnabled,
        AuthFailureCode.mfaRejected => l10n.mfaFailureRejected,
        AuthFailureCode.unknown => l10n.authFailureUnknown,
      };

  /// Cualquier error que llegue a la UI se muestra traducido: si no es un
  /// [AuthFailure] conocido, se degrada al mensaje genérico.
  static String error(AppLocalizations l10n, Object error) =>
      failure(l10n, AuthFailure.from(error));

  /// `dd/MM/yyyy`, sin depender de los datos de locale de `intl` (que en esta
  /// app no se inicializan): es el formato numérico habitual en Argentina.
  static String shortDate(DateTime date) =>
      '${_twoDigits(date.day)}/${_twoDigits(date.month)}/${date.year}';

  /// `dd/MM/yyyy HH:mm:ss`, para etiquetar un factor nuevo de forma única y
  /// legible. Con segundos: el servidor rechaza dos altas con el mismo nombre
  /// y un reintento dentro del mismo minuto tiene que generar uno distinto.
  static String shortDateTime(DateTime date) =>
      '${shortDate(date)} ${_twoDigits(date.hour)}:${_twoDigits(date.minute)}'
      ':${_twoDigits(date.second)}';

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
