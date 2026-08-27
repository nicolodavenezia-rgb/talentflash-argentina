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
        AuthFailureCode.unknown => l10n.authFailureUnknown,
      };

  /// Cualquier error que llegue a la UI se muestra traducido: si no es un
  /// [AuthFailure] conocido, se degrada al mensaje genérico.
  static String error(AppLocalizations l10n, Object error) =>
      failure(l10n, AuthFailure.from(error));
}
