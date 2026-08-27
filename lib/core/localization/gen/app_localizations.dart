import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('es')];

  /// Nombre de la aplicación (pestaña del navegador, task switcher)
  ///
  /// In es, this message translates to:
  /// **'TalentFlash'**
  String get appTitle;

  /// Título de la pantalla de bienvenida
  ///
  /// In es, this message translates to:
  /// **'Bienvenido a TalentFlash'**
  String get welcomeHeadline;

  /// Bajada de la pantalla de bienvenida; recuerda que el video es opcional (SPEC §5)
  ///
  /// In es, this message translates to:
  /// **'Trabajo en gastronomía y hotelería de CABA y GBA, con presentaciones en video de 20 a 30 segundos. El video siempre es opcional.'**
  String get welcomeSubtitle;

  /// Pregunta de selección de rol en el onboarding
  ///
  /// In es, this message translates to:
  /// **'¿Cómo querés usar TalentFlash?'**
  String get roleQuestion;

  /// No description provided for @roleCandidateTitle.
  ///
  /// In es, this message translates to:
  /// **'Soy candidato'**
  String get roleCandidateTitle;

  /// No description provided for @roleCandidateSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Quiero conseguir trabajo'**
  String get roleCandidateSubtitle;

  /// Etiqueta para lectores de pantalla del botón candidato (WCAG AA)
  ///
  /// In es, this message translates to:
  /// **'Crear una cuenta de candidato para buscar trabajo'**
  String get roleCandidateSemantics;

  /// No description provided for @roleCompanyTitle.
  ///
  /// In es, this message translates to:
  /// **'Soy empresa'**
  String get roleCompanyTitle;

  /// No description provided for @roleCompanySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Quiero contratar personal'**
  String get roleCompanySubtitle;

  /// Etiqueta para lectores de pantalla del botón empresa (WCAG AA)
  ///
  /// In es, this message translates to:
  /// **'Crear una cuenta de empresa para publicar ofertas y descubrir candidatos'**
  String get roleCompanySemantics;

  /// Enlace de la bienvenida hacia el login
  ///
  /// In es, this message translates to:
  /// **'Ya tengo cuenta: iniciar sesión'**
  String get welcomeHaveAccount;

  /// No description provided for @candidateHomeTitle.
  ///
  /// In es, this message translates to:
  /// **'Inicio — Candidato'**
  String get candidateHomeTitle;

  /// No description provided for @candidateHomePlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Acá va a estar tu feed de ofertas con salario siempre visible (Bloque G del ROADMAP). Por ahora este es el punto de entrada del candidato.'**
  String get candidateHomePlaceholder;

  /// No description provided for @companyHomeTitle.
  ///
  /// In es, this message translates to:
  /// **'Inicio — Empresa'**
  String get companyHomeTitle;

  /// No description provided for @companyHomePlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Acá van a estar tus búsquedas, ofertas y candidatos (Bloque G del ROADMAP). Por ahora este es el punto de entrada de la empresa.'**
  String get companyHomePlaceholder;

  /// No description provided for @adminHomeTitle.
  ///
  /// In es, this message translates to:
  /// **'Inicio — Administración'**
  String get adminHomeTitle;

  /// No description provided for @adminHomePlaceholder.
  ///
  /// In es, this message translates to:
  /// **'El panel de moderación y administración llega en el Bloque P del ROADMAP. Tu cuenta tiene rol de administración, así que no te llevamos a un shell de candidato ni de empresa.'**
  String get adminHomePlaceholder;

  /// Identidad de la sesión activa en las pantallas de inicio
  ///
  /// In es, this message translates to:
  /// **'Sesión iniciada como {email}'**
  String signedInAs(String email);

  /// Pantalla de arranque mientras se restaura la sesión
  ///
  /// In es, this message translates to:
  /// **'Cargando tu sesión…'**
  String get authLoadingSession;

  /// No description provided for @authLoginTitle.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get authLoginTitle;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Entrá con el correo y la contraseña de tu cuenta.'**
  String get authLoginSubtitle;

  /// No description provided for @authLoginSubtitleCandidate.
  ///
  /// In es, this message translates to:
  /// **'Entrá para seguir tus postulaciones y descubrir ofertas.'**
  String get authLoginSubtitleCandidate;

  /// No description provided for @authLoginSubtitleCompany.
  ///
  /// In es, this message translates to:
  /// **'Entrá para gestionar tus búsquedas y tus candidatos.'**
  String get authLoginSubtitleCompany;

  /// No description provided for @authEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get authEmailLabel;

  /// No description provided for @authEmailHint.
  ///
  /// In es, this message translates to:
  /// **'nombre@ejemplo.com'**
  String get authEmailHint;

  /// No description provided for @authPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get authPasswordLabel;

  /// No description provided for @authPasswordConfirmLabel.
  ///
  /// In es, this message translates to:
  /// **'Repetir contraseña'**
  String get authPasswordConfirmLabel;

  /// Ayuda del campo contraseña; el mínimo lo fija SECURITY.md §2
  ///
  /// In es, this message translates to:
  /// **'Mínimo {min} caracteres.'**
  String authPasswordHelp(int min);

  /// No description provided for @authPasswordShow.
  ///
  /// In es, this message translates to:
  /// **'Mostrar contraseña'**
  String get authPasswordShow;

  /// No description provided for @authPasswordHide.
  ///
  /// In es, this message translates to:
  /// **'Ocultar contraseña'**
  String get authPasswordHide;

  /// No description provided for @authSubmitLogin.
  ///
  /// In es, this message translates to:
  /// **'Entrar'**
  String get authSubmitLogin;

  /// No description provided for @authSubmitSignUp.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get authSubmitSignUp;

  /// No description provided for @authSubmitRecovery.
  ///
  /// In es, this message translates to:
  /// **'Enviar instrucciones'**
  String get authSubmitRecovery;

  /// No description provided for @authForgotPassword.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get authForgotPassword;

  /// No description provided for @authGoToSignUp.
  ///
  /// In es, this message translates to:
  /// **'¿No tenés cuenta? Registrate'**
  String get authGoToSignUp;

  /// No description provided for @authGoToSignUpCandidate.
  ///
  /// In es, this message translates to:
  /// **'¿No tenés cuenta? Registrate como candidato'**
  String get authGoToSignUpCandidate;

  /// No description provided for @authGoToSignUpCompany.
  ///
  /// In es, this message translates to:
  /// **'¿No tenés cuenta? Registrá tu empresa'**
  String get authGoToSignUpCompany;

  /// No description provided for @authGoToLogin.
  ///
  /// In es, this message translates to:
  /// **'¿Ya tenés cuenta? Iniciá sesión'**
  String get authGoToLogin;

  /// No description provided for @authAccountTypeTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Qué tipo de cuenta querés crear?'**
  String get authAccountTypeTitle;

  /// No description provided for @authAccountTypeSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Elegí el recorrido; después vas a poder completar tu perfil.'**
  String get authAccountTypeSubtitle;

  /// No description provided for @authSignUpCandidateTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta de candidato'**
  String get authSignUpCandidateTitle;

  /// No description provided for @authSignUpCandidateSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Con tu cuenta vas a poder postularte y seguir el estado de cada postulación.'**
  String get authSignUpCandidateSubtitle;

  /// No description provided for @authSignUpCompanyTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta de empresa'**
  String get authSignUpCompanyTitle;

  /// No description provided for @authSignUpCompanySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Creá primero tu usuario. Los datos de la empresa y la verificación de CUIT vienen en el paso siguiente.'**
  String get authSignUpCompanySubtitle;

  /// No description provided for @authSignUpConsentDataProcessing.
  ///
  /// In es, this message translates to:
  /// **'Acepto el tratamiento de mis datos personales para operar mi cuenta (Ley 25.326).'**
  String get authSignUpConsentDataProcessing;

  /// No description provided for @authSignUpConsentAge.
  ///
  /// In es, this message translates to:
  /// **'Declaro ser mayor de 18 años.'**
  String get authSignUpConsentAge;

  /// No description provided for @authSignUpConsentNote.
  ///
  /// In es, this message translates to:
  /// **'Los consentimientos opcionales (publicación del perfil, funciones de IA) se piden más adelante y se pueden revocar cuando quieras.'**
  String get authSignUpConsentNote;

  /// No description provided for @authSignUpEmailConfirmationSent.
  ///
  /// In es, this message translates to:
  /// **'Te enviamos un correo para confirmar tu cuenta. Abrí el enlace y volvé a iniciar sesión.'**
  String get authSignUpEmailConfirmationSent;

  /// No description provided for @authRecoveryTitle.
  ///
  /// In es, this message translates to:
  /// **'Recuperar contraseña'**
  String get authRecoveryTitle;

  /// No description provided for @authRecoverySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Escribí tu correo y te mandamos las instrucciones para restablecer la contraseña.'**
  String get authRecoverySubtitle;

  /// Respuesta neutra: nunca revela si la cuenta existe (SECURITY.md §2)
  ///
  /// In es, this message translates to:
  /// **'Si hay una cuenta con ese correo, te enviamos las instrucciones para restablecer la contraseña. Revisá tu bandeja de entrada y el correo no deseado.'**
  String get authRecoverySent;

  /// No description provided for @authRecoveryPendingStep.
  ///
  /// In es, this message translates to:
  /// **'El cambio de contraseña dentro de la app todavía no está disponible: falta definir el enlace profundo (T-013 del ROADMAP).'**
  String get authRecoveryPendingStep;

  /// No description provided for @authBackToLogin.
  ///
  /// In es, this message translates to:
  /// **'Volver al inicio de sesión'**
  String get authBackToLogin;

  /// No description provided for @authSignOut.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get authSignOut;

  /// No description provided for @authGoHome.
  ///
  /// In es, this message translates to:
  /// **'Ir a mi inicio'**
  String get authGoHome;

  /// Salida de la pantalla de estado seguro cuando no hay sesión
  ///
  /// In es, this message translates to:
  /// **'Volver al inicio'**
  String get authGoToStart;

  /// No description provided for @authErrorEmailRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresá tu correo electrónico.'**
  String get authErrorEmailRequired;

  /// No description provided for @authErrorEmailInvalid.
  ///
  /// In es, this message translates to:
  /// **'Ese correo no parece válido. Revisalo y probá de nuevo.'**
  String get authErrorEmailInvalid;

  /// No description provided for @authErrorPasswordRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresá tu contraseña.'**
  String get authErrorPasswordRequired;

  /// No description provided for @authErrorPasswordTooShort.
  ///
  /// In es, this message translates to:
  /// **'La contraseña necesita al menos {min} caracteres.'**
  String authErrorPasswordTooShort(int min);

  /// No description provided for @authErrorPasswordConfirmRequired.
  ///
  /// In es, this message translates to:
  /// **'Repetí la contraseña para confirmarla.'**
  String get authErrorPasswordConfirmRequired;

  /// No description provided for @authErrorPasswordMismatch.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden.'**
  String get authErrorPasswordMismatch;

  /// No description provided for @authErrorConsentRequired.
  ///
  /// In es, this message translates to:
  /// **'Necesitamos tu confirmación para poder crear la cuenta.'**
  String get authErrorConsentRequired;

  /// No description provided for @authFailureInvalidCredentials.
  ///
  /// In es, this message translates to:
  /// **'El correo o la contraseña no coinciden. Probá de nuevo.'**
  String get authFailureInvalidCredentials;

  /// No description provided for @authFailureEmailAlreadyRegistered.
  ///
  /// In es, this message translates to:
  /// **'Ya existe una cuenta con ese correo. Iniciá sesión o recuperá tu contraseña.'**
  String get authFailureEmailAlreadyRegistered;

  /// No description provided for @authFailureWeakPassword.
  ///
  /// In es, this message translates to:
  /// **'Esa contraseña es demasiado débil. Elegí una más larga.'**
  String get authFailureWeakPassword;

  /// No description provided for @authFailureEmailNotConfirmed.
  ///
  /// In es, this message translates to:
  /// **'Confirmá tu correo con el enlace que te enviamos y volvé a entrar.'**
  String get authFailureEmailNotConfirmed;

  /// No description provided for @authFailureRateLimited.
  ///
  /// In es, this message translates to:
  /// **'Hiciste muchos intentos seguidos. Esperá unos minutos y volvé a probar.'**
  String get authFailureRateLimited;

  /// No description provided for @authFailureNetwork.
  ///
  /// In es, this message translates to:
  /// **'No pudimos conectarnos. Revisá tu conexión y reintentá.'**
  String get authFailureNetwork;

  /// No description provided for @authFailureUnknown.
  ///
  /// In es, this message translates to:
  /// **'No pudimos completar la acción. Reintentá en unos minutos.'**
  String get authFailureUnknown;

  /// Encabezado del cartel de error de los formularios de autenticación
  ///
  /// In es, this message translates to:
  /// **'No pudimos continuar'**
  String get authErrorTitle;

  /// No description provided for @authSessionIssueClaimTitle.
  ///
  /// In es, this message translates to:
  /// **'No pudimos verificar tu tipo de cuenta'**
  String get authSessionIssueClaimTitle;

  /// No description provided for @authSessionIssueClaimBody.
  ///
  /// In es, this message translates to:
  /// **'Tu sesión no trae un tipo de cuenta válido, así que por seguridad no te damos acceso. Cerrá sesión y volvé a entrar; si el problema sigue, escribinos.'**
  String get authSessionIssueClaimBody;

  /// No description provided for @authSessionIssueNotAllowedTitle.
  ///
  /// In es, this message translates to:
  /// **'No tenés permiso para esta sección'**
  String get authSessionIssueNotAllowedTitle;

  /// No description provided for @authSessionIssueNotAllowedBody.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta no habilita esta parte de TalentFlash. Volvé a tu inicio para seguir trabajando.'**
  String get authSessionIssueNotAllowedBody;

  /// No description provided for @authSessionIssueNotFoundTitle.
  ///
  /// In es, this message translates to:
  /// **'No encontramos esa pantalla'**
  String get authSessionIssueNotFoundTitle;

  /// No description provided for @authSessionIssueNotFoundBody.
  ///
  /// In es, this message translates to:
  /// **'El enlace puede estar viejo o mal escrito. Volvé al inicio y buscá desde ahí.'**
  String get authSessionIssueNotFoundBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
