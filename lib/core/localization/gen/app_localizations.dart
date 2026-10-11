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
  /// **'Desde acá entrás a las ofertas publicadas, siempre con el sueldo a la vista, y a tu perfil. El orden por zona y compatibilidad llega en el Bloque G del ROADMAP.'**
  String get candidateHomePlaceholder;

  /// No description provided for @companyHomeTitle.
  ///
  /// In es, this message translates to:
  /// **'Inicio — Empresa'**
  String get companyHomeTitle;

  /// No description provided for @companyHomePlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Desde acá gestionás tus ofertas y la verificación de tu empresa. Los candidatos llegan en el Bloque G y las postulaciones en el Bloque H del ROADMAP.'**
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

  /// No description provided for @authFailureSessionMissing.
  ///
  /// In es, this message translates to:
  /// **'Tu sesión terminó. Volvé a iniciar sesión.'**
  String get authFailureSessionMissing;

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

  /// No description provided for @retryLabel.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retryLabel;

  /// No description provided for @sessionLoadFailedBody.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar los datos de tu cuenta. Revisá tu conexión y reintentá.'**
  String get sessionLoadFailedBody;

  /// No description provided for @dataFailureNotAllowed.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta no puede hacer esta acción.'**
  String get dataFailureNotAllowed;

  /// No description provided for @dataFailureInvalidData.
  ///
  /// In es, this message translates to:
  /// **'Hay datos incompletos o inválidos. Revisá los pasos y probá de nuevo.'**
  String get dataFailureInvalidData;

  /// No description provided for @dataFailureStaleConsent.
  ///
  /// In es, this message translates to:
  /// **'Los textos legales cambiaron mientras completabas el formulario. Volvé al paso de consentimientos y aceptá la versión nueva.'**
  String get dataFailureStaleConsent;

  /// No description provided for @dataFailureDuplicate.
  ///
  /// In es, this message translates to:
  /// **'Ese CUIT ya está registrado en TalentFlash. Si es tu empresa, escribinos.'**
  String get dataFailureDuplicate;

  /// No description provided for @dataFailureNetwork.
  ///
  /// In es, this message translates to:
  /// **'No pudimos conectarnos. Revisá tu conexión y reintentá.'**
  String get dataFailureNetwork;

  /// No description provided for @dataFailureUnknown.
  ///
  /// In es, this message translates to:
  /// **'No pudimos completar la acción. Reintentá en unos minutos.'**
  String get dataFailureUnknown;

  /// No description provided for @onboardingErrorTitle.
  ///
  /// In es, this message translates to:
  /// **'No pudimos guardar'**
  String get onboardingErrorTitle;

  /// Progreso del wizard, anunciado por el lector de pantalla (UX_FLOWS §20)
  ///
  /// In es, this message translates to:
  /// **'Paso {current} de {total}'**
  String onboardingStepLabel(int current, int total);

  /// No description provided for @onboardingContinue.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get onboardingContinue;

  /// No description provided for @onboardingBack.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get onboardingBack;

  /// No description provided for @onboardingFinish.
  ///
  /// In es, this message translates to:
  /// **'Terminar'**
  String get onboardingFinish;

  /// No description provided for @onboardingConsentsTitle.
  ///
  /// In es, this message translates to:
  /// **'Tus consentimientos'**
  String get onboardingConsentsTitle;

  /// No description provided for @onboardingConsentsIntro.
  ///
  /// In es, this message translates to:
  /// **'Para registrar tu aceptación de forma válida necesitamos que la confirmes acá, con tu sesión iniciada. Cada punto es una decisión separada y nada viene marcado.'**
  String get onboardingConsentsIntro;

  /// No description provided for @consentTermsLabel.
  ///
  /// In es, this message translates to:
  /// **'Leí y acepto los Términos y condiciones.'**
  String get consentTermsLabel;

  /// No description provided for @consentAlreadyAccepted.
  ///
  /// In es, this message translates to:
  /// **'Ya lo aceptaste; queda registrado con fecha y versión.'**
  String get consentAlreadyAccepted;

  /// No description provided for @consentReadTerms.
  ///
  /// In es, this message translates to:
  /// **'Leer los términos y condiciones'**
  String get consentReadTerms;

  /// No description provided for @consentReadPrivacy.
  ///
  /// In es, this message translates to:
  /// **'Leer la política de privacidad'**
  String get consentReadPrivacy;

  /// No description provided for @candidateOnboardingTitle.
  ///
  /// In es, this message translates to:
  /// **'Completá tu perfil'**
  String get candidateOnboardingTitle;

  /// No description provided for @candidateStepIdentityTitle.
  ///
  /// In es, this message translates to:
  /// **'Sobre vos'**
  String get candidateStepIdentityTitle;

  /// No description provided for @candidateStepPlaceTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Dónde buscás trabajo?'**
  String get candidateStepPlaceTitle;

  /// No description provided for @candidateStepPreferencesTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu búsqueda'**
  String get candidateStepPreferencesTitle;

  /// No description provided for @candidateStepPrivacyTitle.
  ///
  /// In es, this message translates to:
  /// **'Privacidad de tu perfil'**
  String get candidateStepPrivacyTitle;

  /// No description provided for @onboardingNotificationsTitle.
  ///
  /// In es, this message translates to:
  /// **'Avisos'**
  String get onboardingNotificationsTitle;

  /// No description provided for @onboardingSummaryTitle.
  ///
  /// In es, this message translates to:
  /// **'Revisá y confirmá'**
  String get onboardingSummaryTitle;

  /// No description provided for @fullNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre y apellido'**
  String get fullNameLabel;

  /// No description provided for @fullNameError.
  ///
  /// In es, this message translates to:
  /// **'Ingresá tu nombre y apellido.'**
  String get fullNameError;

  /// No description provided for @birthDateLabel.
  ///
  /// In es, this message translates to:
  /// **'Fecha de nacimiento'**
  String get birthDateLabel;

  /// No description provided for @birthDateHint.
  ///
  /// In es, this message translates to:
  /// **'DD/MM/AAAA'**
  String get birthDateHint;

  /// No description provided for @birthDateHelp.
  ///
  /// In es, this message translates to:
  /// **'La usamos solo para confirmar que sos mayor de 18 años.'**
  String get birthDateHelp;

  /// No description provided for @birthDateErrorRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresá tu fecha de nacimiento.'**
  String get birthDateErrorRequired;

  /// No description provided for @birthDateErrorInvalid.
  ///
  /// In es, this message translates to:
  /// **'Esa fecha no parece válida. Usá el formato DD/MM/AAAA.'**
  String get birthDateErrorInvalid;

  /// No description provided for @birthDateErrorFuture.
  ///
  /// In es, this message translates to:
  /// **'La fecha no puede estar en el futuro.'**
  String get birthDateErrorFuture;

  /// No description provided for @underageTitle.
  ///
  /// In es, this message translates to:
  /// **'TalentFlash es solo para mayores de 18'**
  String get underageTitle;

  /// No description provided for @underageBody.
  ///
  /// In es, this message translates to:
  /// **'Por la fecha que ingresaste todavía no cumpliste los 18 años, así que no podemos crearte el perfil. No guardamos ningún dato de este formulario. Te esperamos cuando los cumplas.'**
  String get underageBody;

  /// No description provided for @provinceLabel.
  ///
  /// In es, this message translates to:
  /// **'Provincia'**
  String get provinceLabel;

  /// No description provided for @localityLabel.
  ///
  /// In es, this message translates to:
  /// **'Localidad'**
  String get localityLabel;

  /// No description provided for @neighborhoodLabel.
  ///
  /// In es, this message translates to:
  /// **'Barrio'**
  String get neighborhoodLabel;

  /// No description provided for @selectOptionError.
  ///
  /// In es, this message translates to:
  /// **'Elegí una opción.'**
  String get selectOptionError;

  /// No description provided for @sectorLabel.
  ///
  /// In es, this message translates to:
  /// **'Sector o rubro'**
  String get sectorLabel;

  /// No description provided for @availabilityLabel.
  ///
  /// In es, this message translates to:
  /// **'Disponibilidad'**
  String get availabilityLabel;

  /// No description provided for @availabilityImmediate.
  ///
  /// In es, this message translates to:
  /// **'Inmediata'**
  String get availabilityImmediate;

  /// No description provided for @availabilityOneWeek.
  ///
  /// In es, this message translates to:
  /// **'En 1 semana'**
  String get availabilityOneWeek;

  /// No description provided for @availabilityTwoWeeks.
  ///
  /// In es, this message translates to:
  /// **'En 2 semanas'**
  String get availabilityTwoWeeks;

  /// No description provided for @availabilityOneMonth.
  ///
  /// In es, this message translates to:
  /// **'En 1 mes'**
  String get availabilityOneMonth;

  /// No description provided for @availabilityToAgree.
  ///
  /// In es, this message translates to:
  /// **'A convenir'**
  String get availabilityToAgree;

  /// No description provided for @workModesLabel.
  ///
  /// In es, this message translates to:
  /// **'Modalidad preferida'**
  String get workModesLabel;

  /// No description provided for @workModesError.
  ///
  /// In es, this message translates to:
  /// **'Elegí al menos una modalidad.'**
  String get workModesError;

  /// No description provided for @workModeOnSite.
  ///
  /// In es, this message translates to:
  /// **'Presencial'**
  String get workModeOnSite;

  /// No description provided for @workModeHybrid.
  ///
  /// In es, this message translates to:
  /// **'Híbrido'**
  String get workModeHybrid;

  /// No description provided for @workModeRemote.
  ///
  /// In es, this message translates to:
  /// **'Remoto'**
  String get workModeRemote;

  /// No description provided for @privacyIntro.
  ///
  /// In es, this message translates to:
  /// **'Estas dos opciones son tuyas: nada viene marcado, no cambian lo que podés hacer en la app y las revocás cuando quieras.'**
  String get privacyIntro;

  /// No description provided for @consentVideoLabel.
  ///
  /// In es, this message translates to:
  /// **'Quiero que las empresas descubran mi perfil (publicación de perfil y video).'**
  String get consentVideoLabel;

  /// No description provided for @consentVideoHelp.
  ///
  /// In es, this message translates to:
  /// **'Si no lo activás, igual vas a poder ver ofertas y postularte; solo no aparecés en las búsquedas de las empresas.'**
  String get consentVideoHelp;

  /// No description provided for @consentAiLabel.
  ///
  /// In es, this message translates to:
  /// **'Quiero usar las funciones de inteligencia artificial sobre mis datos.'**
  String get consentAiLabel;

  /// No description provided for @consentAiHelp.
  ///
  /// In es, this message translates to:
  /// **'Sin esto, todo funciona en modo manual. Nunca usamos tus datos para entrenar modelos.'**
  String get consentAiHelp;

  /// No description provided for @notifPrefsIntro.
  ///
  /// In es, this message translates to:
  /// **'Elegí qué avisos querés recibir por cada canal. Nada viene activado de fábrica: si no marcás nada, solo vas a ver avisos dentro de la app.'**
  String get notifPrefsIntro;

  /// No description provided for @notifChannelPush.
  ///
  /// In es, this message translates to:
  /// **'Push'**
  String get notifChannelPush;

  /// No description provided for @notifChannelEmail.
  ///
  /// In es, this message translates to:
  /// **'Correo'**
  String get notifChannelEmail;

  /// No description provided for @notifCategoryApplicationUpdate.
  ///
  /// In es, this message translates to:
  /// **'Tus postulaciones'**
  String get notifCategoryApplicationUpdate;

  /// No description provided for @notifCategoryNewApplication.
  ///
  /// In es, this message translates to:
  /// **'Nuevas postulaciones'**
  String get notifCategoryNewApplication;

  /// No description provided for @notifCategoryInvitation.
  ///
  /// In es, this message translates to:
  /// **'Invitaciones'**
  String get notifCategoryInvitation;

  /// No description provided for @notifCategoryMessage.
  ///
  /// In es, this message translates to:
  /// **'Mensajes'**
  String get notifCategoryMessage;

  /// No description provided for @notifCategoryVerificationUpdate.
  ///
  /// In es, this message translates to:
  /// **'Verificación de tu empresa'**
  String get notifCategoryVerificationUpdate;

  /// No description provided for @notifCategorySystem.
  ///
  /// In es, this message translates to:
  /// **'Cuenta y seguridad'**
  String get notifCategorySystem;

  /// No description provided for @notifSystemLockedNote.
  ///
  /// In es, this message translates to:
  /// **'Los avisos de cuenta y seguridad llegan siempre dentro de la app y por correo; no se pueden desactivar.'**
  String get notifSystemLockedNote;

  /// Etiqueta accesible del switch de push por categoría
  ///
  /// In es, this message translates to:
  /// **'Push para {category}'**
  String notifPushSwitchLabel(String category);

  /// Etiqueta accesible del switch de correo por categoría
  ///
  /// In es, this message translates to:
  /// **'Correo para {category}'**
  String notifEmailSwitchLabel(String category);

  /// No description provided for @summaryIntro.
  ///
  /// In es, this message translates to:
  /// **'Revisá que esté todo bien antes de terminar. Podés volver a cualquier paso.'**
  String get summaryIntro;

  /// No description provided for @summaryVisibleYes.
  ///
  /// In es, this message translates to:
  /// **'Tu perfil va a ser visible para las empresas verificadas.'**
  String get summaryVisibleYes;

  /// No description provided for @summaryVisibleNo.
  ///
  /// In es, this message translates to:
  /// **'Tu perfil NO va a ser visible para las empresas: no activaste la publicación. Podés cambiarlo cuando quieras.'**
  String get summaryVisibleNo;

  /// No description provided for @summaryMissingValue.
  ///
  /// In es, this message translates to:
  /// **'Sin completar'**
  String get summaryMissingValue;

  /// No description provided for @companyOnboardingTitle.
  ///
  /// In es, this message translates to:
  /// **'Registrá tu empresa'**
  String get companyOnboardingTitle;

  /// No description provided for @companyStepDataTitle.
  ///
  /// In es, this message translates to:
  /// **'Datos de la empresa'**
  String get companyStepDataTitle;

  /// No description provided for @companyStepPlaceTitle.
  ///
  /// In es, this message translates to:
  /// **'Ubicación y web'**
  String get companyStepPlaceTitle;

  /// No description provided for @companyStepApplicantTitle.
  ///
  /// In es, this message translates to:
  /// **'Sobre vos'**
  String get companyStepApplicantTitle;

  /// No description provided for @legalNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Razón social'**
  String get legalNameLabel;

  /// No description provided for @legalNameError.
  ///
  /// In es, this message translates to:
  /// **'Ingresá la razón social.'**
  String get legalNameError;

  /// No description provided for @tradeNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre de fantasía'**
  String get tradeNameLabel;

  /// No description provided for @tradeNameError.
  ///
  /// In es, this message translates to:
  /// **'Ingresá el nombre de fantasía.'**
  String get tradeNameError;

  /// No description provided for @cuitLabel.
  ///
  /// In es, this message translates to:
  /// **'CUIT'**
  String get cuitLabel;

  /// No description provided for @cuitHint.
  ///
  /// In es, this message translates to:
  /// **'30-12345678-1'**
  String get cuitHint;

  /// No description provided for @cuitHelp.
  ///
  /// In es, this message translates to:
  /// **'Once números. Comprobamos el dígito verificador; que la empresa sea tuya lo revisa una persona después.'**
  String get cuitHelp;

  /// No description provided for @cuitErrorRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresá el CUIT de la empresa.'**
  String get cuitErrorRequired;

  /// No description provided for @cuitErrorLength.
  ///
  /// In es, this message translates to:
  /// **'El CUIT debe tener 11 números.'**
  String get cuitErrorLength;

  /// No description provided for @cuitErrorCharacters.
  ///
  /// In es, this message translates to:
  /// **'El CUIT solo lleva números, guiones y espacios.'**
  String get cuitErrorCharacters;

  /// No description provided for @cuitErrorCheckDigit.
  ///
  /// In es, this message translates to:
  /// **'Ese CUIT no existe: el último número no se corresponde con los anteriores. Revisalo.'**
  String get cuitErrorCheckDigit;

  /// No description provided for @companySizeLabel.
  ///
  /// In es, this message translates to:
  /// **'Tamaño de la empresa'**
  String get companySizeLabel;

  /// No description provided for @companySize1to10.
  ///
  /// In es, this message translates to:
  /// **'1 a 10 personas'**
  String get companySize1to10;

  /// No description provided for @companySize11to50.
  ///
  /// In es, this message translates to:
  /// **'11 a 50 personas'**
  String get companySize11to50;

  /// No description provided for @companySize51to200.
  ///
  /// In es, this message translates to:
  /// **'51 a 200 personas'**
  String get companySize51to200;

  /// No description provided for @companySize201to500.
  ///
  /// In es, this message translates to:
  /// **'201 a 500 personas'**
  String get companySize201to500;

  /// No description provided for @companySizeMoreThan500.
  ///
  /// In es, this message translates to:
  /// **'Más de 500 personas'**
  String get companySizeMoreThan500;

  /// No description provided for @websiteLabel.
  ///
  /// In es, this message translates to:
  /// **'Sitio web (opcional)'**
  String get websiteLabel;

  /// No description provided for @websiteError.
  ///
  /// In es, this message translates to:
  /// **'Esa dirección no parece una URL válida.'**
  String get websiteError;

  /// No description provided for @positionLabel.
  ///
  /// In es, this message translates to:
  /// **'Tu cargo'**
  String get positionLabel;

  /// No description provided for @positionError.
  ///
  /// In es, this message translates to:
  /// **'Ingresá tu cargo.'**
  String get positionError;

  /// No description provided for @relationshipLabel.
  ///
  /// In es, this message translates to:
  /// **'Tu relación con la empresa'**
  String get relationshipLabel;

  /// No description provided for @relationshipOwner.
  ///
  /// In es, this message translates to:
  /// **'Dueño/a'**
  String get relationshipOwner;

  /// No description provided for @relationshipPartner.
  ///
  /// In es, this message translates to:
  /// **'Socio/a'**
  String get relationshipPartner;

  /// No description provided for @relationshipManager.
  ///
  /// In es, this message translates to:
  /// **'Gerente o encargado/a'**
  String get relationshipManager;

  /// No description provided for @relationshipHr.
  ///
  /// In es, this message translates to:
  /// **'Recursos Humanos'**
  String get relationshipHr;

  /// No description provided for @relationshipOther.
  ///
  /// In es, this message translates to:
  /// **'Otra'**
  String get relationshipOther;

  /// No description provided for @companyPendingNote.
  ///
  /// In es, this message translates to:
  /// **'La empresa se crea en estado \"no verificada\": hasta que verifiquemos el CUIT vas a poder preparar todo, pero no publicar búsquedas.'**
  String get companyPendingNote;

  /// No description provided for @reconsentTitle.
  ///
  /// In es, this message translates to:
  /// **'Necesitamos tu aceptación de nuevo'**
  String get reconsentTitle;

  /// No description provided for @reconsentBody.
  ///
  /// In es, this message translates to:
  /// **'Actualizamos textos que ya habías aceptado. Leélos y confirmá cada punto para seguir usando tu cuenta; nada viene marcado.'**
  String get reconsentBody;

  /// No description provided for @reconsentAccept.
  ///
  /// In es, this message translates to:
  /// **'Aceptar y continuar'**
  String get reconsentAccept;

  /// No description provided for @legalVersionLabel.
  ///
  /// In es, this message translates to:
  /// **'Versión vigente: {version}'**
  String legalVersionLabel(String version);

  /// No description provided for @legalTermsFallbackTitle.
  ///
  /// In es, this message translates to:
  /// **'Términos y condiciones'**
  String get legalTermsFallbackTitle;

  /// No description provided for @legalPrivacyFallbackTitle.
  ///
  /// In es, this message translates to:
  /// **'Política de privacidad'**
  String get legalPrivacyFallbackTitle;

  /// No description provided for @legalLoadError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar el documento. Revisá tu conexión y reintentá.'**
  String get legalLoadError;

  /// Titulo de la pantalla del perfil propio y del boton de entrada desde el home
  ///
  /// In es, this message translates to:
  /// **'Mi perfil'**
  String get profileTitle;

  /// No description provided for @profileEditAction.
  ///
  /// In es, this message translates to:
  /// **'Editar perfil'**
  String get profileEditAction;

  /// No description provided for @profileLoadError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar tu perfil. Revisá tu conexión y reintentá.'**
  String get profileLoadError;

  /// No description provided for @profilePublishedBadge.
  ///
  /// In es, this message translates to:
  /// **'Visible para empresas verificadas'**
  String get profilePublishedBadge;

  /// No description provided for @profileNotPublishedBadge.
  ///
  /// In es, this message translates to:
  /// **'No visible para empresas'**
  String get profileNotPublishedBadge;

  /// No description provided for @profileReadyBadge.
  ///
  /// In es, this message translates to:
  /// **'Tenés los datos mínimos para postularte'**
  String get profileReadyBadge;

  /// No description provided for @profileNotReadyBadge.
  ///
  /// In es, this message translates to:
  /// **'Te faltan datos mínimos para postularte'**
  String get profileNotReadyBadge;

  /// No description provided for @profileSectionIdentity.
  ///
  /// In es, this message translates to:
  /// **'Sobre vos'**
  String get profileSectionIdentity;

  /// No description provided for @profileSectionLocation.
  ///
  /// In es, this message translates to:
  /// **'Dónde buscás trabajo'**
  String get profileSectionLocation;

  /// No description provided for @profileSectionPreferences.
  ///
  /// In es, this message translates to:
  /// **'Tu búsqueda'**
  String get profileSectionPreferences;

  /// No description provided for @profileSectionSchedule.
  ///
  /// In es, this message translates to:
  /// **'Disponibilidad horaria'**
  String get profileSectionSchedule;

  /// No description provided for @profileSectionSalary.
  ///
  /// In es, this message translates to:
  /// **'Expectativa salarial'**
  String get profileSectionSalary;

  /// No description provided for @profileSectionSkills.
  ///
  /// In es, this message translates to:
  /// **'Habilidades'**
  String get profileSectionSkills;

  /// No description provided for @profileSectionLanguages.
  ///
  /// In es, this message translates to:
  /// **'Idiomas'**
  String get profileSectionLanguages;

  /// No description provided for @profileSectionExperience.
  ///
  /// In es, this message translates to:
  /// **'Experiencia laboral'**
  String get profileSectionExperience;

  /// No description provided for @profileSectionEducation.
  ///
  /// In es, this message translates to:
  /// **'Educación'**
  String get profileSectionEducation;

  /// No description provided for @profileEmptyValue.
  ///
  /// In es, this message translates to:
  /// **'Sin completar'**
  String get profileEmptyValue;

  /// No description provided for @profileOptionalEmptyValue.
  ///
  /// In es, this message translates to:
  /// **'Sin especificar (es opcional)'**
  String get profileOptionalEmptyValue;

  /// No description provided for @profileSalaryRange.
  ///
  /// In es, this message translates to:
  /// **'ARS {min} a {max} por mes'**
  String profileSalaryRange(String min, String max);

  /// No description provided for @profileExperiencePeriod.
  ///
  /// In es, this message translates to:
  /// **'{from} a {to}'**
  String profileExperiencePeriod(String from, String to);

  /// No description provided for @profileExperienceCurrent.
  ///
  /// In es, this message translates to:
  /// **'{from} a la actualidad'**
  String profileExperienceCurrent(String from);

  /// No description provided for @profileScheduleNextDay.
  ///
  /// In es, this message translates to:
  /// **'{day} de {start} a {end} (termina el día siguiente)'**
  String profileScheduleNextDay(String day, String start, String end);

  /// No description provided for @profileScheduleSameDay.
  ///
  /// In es, this message translates to:
  /// **'{day} de {start} a {end}'**
  String profileScheduleSameDay(String day, String start, String end);

  /// No description provided for @profileCompletenessTitle.
  ///
  /// In es, this message translates to:
  /// **'Completitud del perfil'**
  String get profileCompletenessTitle;

  /// No description provided for @profileCompletenessValue.
  ///
  /// In es, this message translates to:
  /// **'{score} % completo'**
  String profileCompletenessValue(int score);

  /// No description provided for @profileCompletenessHint.
  ///
  /// In es, this message translates to:
  /// **'Es una guía solo para vos: las empresas no la ven y no cambia ningún orden de resultados.'**
  String get profileCompletenessHint;

  /// No description provided for @profileCompletenessPendingTitle.
  ///
  /// In es, this message translates to:
  /// **'Si querés, podés sumar:'**
  String get profileCompletenessPendingTitle;

  /// No description provided for @profileCompletenessItemBase.
  ///
  /// In es, this message translates to:
  /// **'Los datos básicos del onboarding'**
  String get profileCompletenessItemBase;

  /// No description provided for @profileCompletenessItemHeadline.
  ///
  /// In es, this message translates to:
  /// **'Un titular que te presente'**
  String get profileCompletenessItemHeadline;

  /// No description provided for @profileCompletenessItemBio.
  ///
  /// In es, this message translates to:
  /// **'Una breve biografía'**
  String get profileCompletenessItemBio;

  /// No description provided for @profileCompletenessItemExperience.
  ///
  /// In es, this message translates to:
  /// **'Al menos una experiencia laboral'**
  String get profileCompletenessItemExperience;

  /// No description provided for @profileCompletenessItemSkills.
  ///
  /// In es, this message translates to:
  /// **'Tres habilidades o más'**
  String get profileCompletenessItemSkills;

  /// No description provided for @profileCompletenessItemLanguages.
  ///
  /// In es, this message translates to:
  /// **'Al menos un idioma'**
  String get profileCompletenessItemLanguages;

  /// No description provided for @profileCompletenessItemSchedule.
  ///
  /// In es, this message translates to:
  /// **'Tu disponibilidad horaria'**
  String get profileCompletenessItemSchedule;

  /// No description provided for @profileCompletenessItemEducation.
  ///
  /// In es, this message translates to:
  /// **'Tu educación (opcional)'**
  String get profileCompletenessItemEducation;

  /// No description provided for @profileCompletenessItemAvatar.
  ///
  /// In es, this message translates to:
  /// **'Una foto de perfil (opcional)'**
  String get profileCompletenessItemAvatar;

  /// No description provided for @profileCompletenessItemPresentation.
  ///
  /// In es, this message translates to:
  /// **'Una presentación (opcional)'**
  String get profileCompletenessItemPresentation;

  /// No description provided for @profilePresentationNone.
  ///
  /// In es, this message translates to:
  /// **'Todavía no tenés una presentación cargada.'**
  String get profilePresentationNone;

  /// No description provided for @profilePresentationProcessing.
  ///
  /// In es, this message translates to:
  /// **'Tu video de presentación se está procesando.'**
  String get profilePresentationProcessing;

  /// No description provided for @profilePresentationReady.
  ///
  /// In es, this message translates to:
  /// **'Tu presentación en video está lista.'**
  String get profilePresentationReady;

  /// No description provided for @profilePresentationFailed.
  ///
  /// In es, this message translates to:
  /// **'El procesamiento de tu video falló.'**
  String get profilePresentationFailed;

  /// No description provided for @profilePresentationExpired.
  ///
  /// In es, this message translates to:
  /// **'Tu video de presentación venció.'**
  String get profilePresentationExpired;

  /// Banner informativo sin CTA (T-023): honesto sobre lo que falta, sin botones que no funcionen
  ///
  /// In es, this message translates to:
  /// **'La presentación es opcional y nunca es requisito para postularte. La grabación en video, audio o texto —con igual jerarquía— llega en una etapa posterior del desarrollo.'**
  String get profilePresentationOptionalNote;

  /// No description provided for @profileAvatarLabel.
  ///
  /// In es, this message translates to:
  /// **'Foto de perfil'**
  String get profileAvatarLabel;

  /// No description provided for @profileAvatarAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar foto'**
  String get profileAvatarAdd;

  /// No description provided for @profileAvatarReplace.
  ///
  /// In es, this message translates to:
  /// **'Cambiar foto'**
  String get profileAvatarReplace;

  /// No description provided for @profileAvatarDelete.
  ///
  /// In es, this message translates to:
  /// **'Quitar foto'**
  String get profileAvatarDelete;

  /// No description provided for @profileAvatarOptionalNote.
  ///
  /// In es, this message translates to:
  /// **'La foto es opcional: no tenerla no te resta en nada.'**
  String get profileAvatarOptionalNote;

  /// No description provided for @profileAvatarUploaded.
  ///
  /// In es, this message translates to:
  /// **'Foto de perfil actualizada.'**
  String get profileAvatarUploaded;

  /// No description provided for @profileAvatarDeleted.
  ///
  /// In es, this message translates to:
  /// **'Foto de perfil eliminada.'**
  String get profileAvatarDeleted;

  /// No description provided for @avatarErrorTooLarge.
  ///
  /// In es, this message translates to:
  /// **'La imagen supera los 2 MB. Elegí una más liviana.'**
  String get avatarErrorTooLarge;

  /// No description provided for @avatarErrorInvalid.
  ///
  /// In es, this message translates to:
  /// **'El archivo no parece una imagen JPEG o PNG válida.'**
  String get avatarErrorInvalid;

  /// No description provided for @avatarErrorUnsupported.
  ///
  /// In es, this message translates to:
  /// **'Por ahora aceptamos JPEG o PNG; el soporte de WebP llega más adelante.'**
  String get avatarErrorUnsupported;

  /// No description provided for @avatarErrorNotAllowed.
  ///
  /// In es, this message translates to:
  /// **'No pudimos actualizar tu foto con esta sesión. Volvé a entrar y reintentá.'**
  String get avatarErrorNotAllowed;

  /// No description provided for @avatarErrorNetwork.
  ///
  /// In es, this message translates to:
  /// **'No pudimos conectarnos para subir la foto. Revisá tu conexión.'**
  String get avatarErrorNetwork;

  /// No description provided for @avatarErrorUnknown.
  ///
  /// In es, this message translates to:
  /// **'No pudimos procesar la foto. Reintentá en unos minutos.'**
  String get avatarErrorUnknown;

  /// No description provided for @profileEditTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar perfil'**
  String get profileEditTitle;

  /// No description provided for @profileSaveAction.
  ///
  /// In es, this message translates to:
  /// **'Guardar cambios'**
  String get profileSaveAction;

  /// No description provided for @profileSavedMessage.
  ///
  /// In es, this message translates to:
  /// **'Cambios guardados.'**
  String get profileSavedMessage;

  /// No description provided for @profileDiscardTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Salir sin guardar?'**
  String get profileDiscardTitle;

  /// No description provided for @profileDiscardBody.
  ///
  /// In es, this message translates to:
  /// **'Tenés cambios sin guardar. Si salís ahora, se pierden.'**
  String get profileDiscardBody;

  /// No description provided for @profileDiscardConfirm.
  ///
  /// In es, this message translates to:
  /// **'Salir sin guardar'**
  String get profileDiscardConfirm;

  /// No description provided for @profileDiscardCancel.
  ///
  /// In es, this message translates to:
  /// **'Seguir editando'**
  String get profileDiscardCancel;

  /// No description provided for @headlineLabel.
  ///
  /// In es, this message translates to:
  /// **'Titular'**
  String get headlineLabel;

  /// No description provided for @headlineHelp.
  ///
  /// In es, this message translates to:
  /// **'Una línea que te presente (hasta 120 caracteres).'**
  String get headlineHelp;

  /// No description provided for @bioLabel.
  ///
  /// In es, this message translates to:
  /// **'Biografía'**
  String get bioLabel;

  /// No description provided for @bioHelp.
  ///
  /// In es, this message translates to:
  /// **'Contá tu experiencia y qué buscás (hasta 2000 caracteres).'**
  String get bioHelp;

  /// No description provided for @experienceLevelLabel.
  ///
  /// In es, this message translates to:
  /// **'Nivel de experiencia'**
  String get experienceLevelLabel;

  /// No description provided for @salaryMinLabel.
  ///
  /// In es, this message translates to:
  /// **'Mínimo (ARS por mes)'**
  String get salaryMinLabel;

  /// No description provided for @salaryMaxLabel.
  ///
  /// In es, this message translates to:
  /// **'Máximo (ARS por mes)'**
  String get salaryMaxLabel;

  /// No description provided for @salaryOptionalNote.
  ///
  /// In es, this message translates to:
  /// **'La expectativa salarial es opcional; podés dejarla vacía.'**
  String get salaryOptionalNote;

  /// No description provided for @skillsAddLabel.
  ///
  /// In es, this message translates to:
  /// **'Agregar habilidad'**
  String get skillsAddLabel;

  /// No description provided for @languagesAddLabel.
  ///
  /// In es, this message translates to:
  /// **'Agregar idioma'**
  String get languagesAddLabel;

  /// No description provided for @chipAddAction.
  ///
  /// In es, this message translates to:
  /// **'Agregar'**
  String get chipAddAction;

  /// No description provided for @chipRemoveLabel.
  ///
  /// In es, this message translates to:
  /// **'Quitar {value}'**
  String chipRemoveLabel(String value);

  /// No description provided for @profileErrorNameRequired.
  ///
  /// In es, this message translates to:
  /// **'El nombre necesita entre 2 y 80 caracteres.'**
  String get profileErrorNameRequired;

  /// No description provided for @profileErrorHeadlineTooLong.
  ///
  /// In es, this message translates to:
  /// **'El titular admite hasta 120 caracteres.'**
  String get profileErrorHeadlineTooLong;

  /// No description provided for @profileErrorBioTooLong.
  ///
  /// In es, this message translates to:
  /// **'La biografía admite hasta 2000 caracteres.'**
  String get profileErrorBioTooLong;

  /// No description provided for @profileErrorSalaryInvalid.
  ///
  /// In es, this message translates to:
  /// **'Revisá el rango: el mínimo no puede superar al máximo.'**
  String get profileErrorSalaryInvalid;

  /// No description provided for @profileErrorSalaryFormat.
  ///
  /// In es, this message translates to:
  /// **'Ingresá solo números, sin puntos ni comas.'**
  String get profileErrorSalaryFormat;

  /// No description provided for @profileErrorChipEmpty.
  ///
  /// In es, this message translates to:
  /// **'Escribí un valor antes de agregar.'**
  String get profileErrorChipEmpty;

  /// No description provided for @profileErrorChipDuplicate.
  ///
  /// In es, this message translates to:
  /// **'Ese valor ya está en la lista.'**
  String get profileErrorChipDuplicate;

  /// No description provided for @profileErrorChipTooLong.
  ///
  /// In es, this message translates to:
  /// **'Ese valor es demasiado largo.'**
  String get profileErrorChipTooLong;

  /// No description provided for @profileErrorTooManyChips.
  ///
  /// In es, this message translates to:
  /// **'Llegaste al máximo de esta lista.'**
  String get profileErrorTooManyChips;

  /// No description provided for @experienceAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar experiencia'**
  String get experienceAdd;

  /// No description provided for @experienceEditAction.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get experienceEditAction;

  /// No description provided for @experienceDeleteAction.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get experienceDeleteAction;

  /// No description provided for @experienceMoveUp.
  ///
  /// In es, this message translates to:
  /// **'Subir en la lista'**
  String get experienceMoveUp;

  /// No description provided for @experienceMoveDown.
  ///
  /// In es, this message translates to:
  /// **'Bajar en la lista'**
  String get experienceMoveDown;

  /// No description provided for @experienceCompanyLabel.
  ///
  /// In es, this message translates to:
  /// **'Empresa o lugar'**
  String get experienceCompanyLabel;

  /// No description provided for @experiencePositionLabel.
  ///
  /// In es, this message translates to:
  /// **'Puesto'**
  String get experiencePositionLabel;

  /// No description provided for @experienceFromLabel.
  ///
  /// In es, this message translates to:
  /// **'Desde (MM/AAAA)'**
  String get experienceFromLabel;

  /// No description provided for @experienceToLabel.
  ///
  /// In es, this message translates to:
  /// **'Hasta (MM/AAAA)'**
  String get experienceToLabel;

  /// No description provided for @experienceCurrentLabel.
  ///
  /// In es, this message translates to:
  /// **'Trabajo acá actualmente'**
  String get experienceCurrentLabel;

  /// No description provided for @experienceDescriptionLabel.
  ///
  /// In es, this message translates to:
  /// **'Descripción (opcional)'**
  String get experienceDescriptionLabel;

  /// No description provided for @experienceErrorRequired.
  ///
  /// In es, this message translates to:
  /// **'Completá empresa, puesto y fecha de inicio.'**
  String get experienceErrorRequired;

  /// No description provided for @experienceErrorDates.
  ///
  /// In es, this message translates to:
  /// **'Revisá las fechas: formato MM/AAAA y el fin no puede ser anterior al inicio.'**
  String get experienceErrorDates;

  /// No description provided for @experienceDialogSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar experiencia'**
  String get experienceDialogSave;

  /// No description provided for @educationAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar educación'**
  String get educationAdd;

  /// No description provided for @educationLevelLabel.
  ///
  /// In es, this message translates to:
  /// **'Nivel'**
  String get educationLevelLabel;

  /// No description provided for @educationInstitutionLabel.
  ///
  /// In es, this message translates to:
  /// **'Institución'**
  String get educationInstitutionLabel;

  /// No description provided for @educationDegreeLabel.
  ///
  /// In es, this message translates to:
  /// **'Título (opcional)'**
  String get educationDegreeLabel;

  /// No description provided for @educationOptionalNote.
  ///
  /// In es, this message translates to:
  /// **'La educación es opcional: no es requisito para postularte.'**
  String get educationOptionalNote;

  /// No description provided for @educationErrorRequired.
  ///
  /// In es, this message translates to:
  /// **'Completá nivel e institución.'**
  String get educationErrorRequired;

  /// No description provided for @educationDialogSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar educación'**
  String get educationDialogSave;

  /// No description provided for @educationLevelPrimario.
  ///
  /// In es, this message translates to:
  /// **'Primario'**
  String get educationLevelPrimario;

  /// No description provided for @educationLevelSecundario.
  ///
  /// In es, this message translates to:
  /// **'Secundario'**
  String get educationLevelSecundario;

  /// No description provided for @educationLevelTerciario.
  ///
  /// In es, this message translates to:
  /// **'Terciario'**
  String get educationLevelTerciario;

  /// No description provided for @educationLevelUniversitario.
  ///
  /// In es, this message translates to:
  /// **'Universitario'**
  String get educationLevelUniversitario;

  /// No description provided for @educationLevelPosgrado.
  ///
  /// In es, this message translates to:
  /// **'Posgrado'**
  String get educationLevelPosgrado;

  /// No description provided for @educationLevelCurso.
  ///
  /// In es, this message translates to:
  /// **'Curso o capacitación'**
  String get educationLevelCurso;

  /// No description provided for @scheduleAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar franja'**
  String get scheduleAdd;

  /// No description provided for @scheduleDayLabel.
  ///
  /// In es, this message translates to:
  /// **'Día'**
  String get scheduleDayLabel;

  /// No description provided for @scheduleStartLabel.
  ///
  /// In es, this message translates to:
  /// **'Desde (HH:MM)'**
  String get scheduleStartLabel;

  /// No description provided for @scheduleEndLabel.
  ///
  /// In es, this message translates to:
  /// **'Hasta (HH:MM)'**
  String get scheduleEndLabel;

  /// No description provided for @scheduleCrossesNote.
  ///
  /// In es, this message translates to:
  /// **'Si el fin es menor que el inicio, el turno termina el día siguiente (por ejemplo, 22:00 a 02:00).'**
  String get scheduleCrossesNote;

  /// No description provided for @scheduleErrorFormat.
  ///
  /// In es, this message translates to:
  /// **'Usá el formato HH:MM, por ejemplo 18:30.'**
  String get scheduleErrorFormat;

  /// No description provided for @scheduleErrorOverlap.
  ///
  /// In es, this message translates to:
  /// **'Esa franja se superpone con otra que ya cargaste.'**
  String get scheduleErrorOverlap;

  /// No description provided for @scheduleErrorTooMany.
  ///
  /// In es, this message translates to:
  /// **'Podés cargar hasta 21 franjas, con un máximo de 3 por día.'**
  String get scheduleErrorTooMany;

  /// No description provided for @scheduleErrorZeroLength.
  ///
  /// In es, this message translates to:
  /// **'El inicio y el fin no pueden ser iguales.'**
  String get scheduleErrorZeroLength;

  /// No description provided for @scheduleDeleteLabel.
  ///
  /// In es, this message translates to:
  /// **'Quitar la franja de {day}'**
  String scheduleDeleteLabel(String day);

  /// No description provided for @scheduleDialogSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar franja'**
  String get scheduleDialogSave;

  /// No description provided for @dayLun.
  ///
  /// In es, this message translates to:
  /// **'Lunes'**
  String get dayLun;

  /// No description provided for @dayMar.
  ///
  /// In es, this message translates to:
  /// **'Martes'**
  String get dayMar;

  /// No description provided for @dayMie.
  ///
  /// In es, this message translates to:
  /// **'Miércoles'**
  String get dayMie;

  /// No description provided for @dayJue.
  ///
  /// In es, this message translates to:
  /// **'Jueves'**
  String get dayJue;

  /// No description provided for @dayVie.
  ///
  /// In es, this message translates to:
  /// **'Viernes'**
  String get dayVie;

  /// No description provided for @daySab.
  ///
  /// In es, this message translates to:
  /// **'Sábado'**
  String get daySab;

  /// No description provided for @dayDom.
  ///
  /// In es, this message translates to:
  /// **'Domingo'**
  String get dayDom;

  /// No description provided for @experienceLevelSinExperiencia.
  ///
  /// In es, this message translates to:
  /// **'Sin experiencia'**
  String get experienceLevelSinExperiencia;

  /// No description provided for @experienceLevelHasta1Anio.
  ///
  /// In es, this message translates to:
  /// **'Hasta 1 año'**
  String get experienceLevelHasta1Anio;

  /// No description provided for @experienceLevel1a3.
  ///
  /// In es, this message translates to:
  /// **'1 a 3 años'**
  String get experienceLevel1a3;

  /// No description provided for @experienceLevel3a5.
  ///
  /// In es, this message translates to:
  /// **'3 a 5 años'**
  String get experienceLevel3a5;

  /// No description provided for @experienceLevelMas5.
  ///
  /// In es, this message translates to:
  /// **'Más de 5 años'**
  String get experienceLevelMas5;

  /// No description provided for @companyCandidateTitle.
  ///
  /// In es, this message translates to:
  /// **'Perfil de candidato'**
  String get companyCandidateTitle;

  /// No description provided for @companyCandidateBack.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get companyCandidateBack;

  /// No description provided for @companyCandidateNotAvailableTitle.
  ///
  /// In es, this message translates to:
  /// **'Candidato no disponible'**
  String get companyCandidateNotAvailableTitle;

  /// Mensaje fail-closed: identico exista o no el candidato (T-024)
  ///
  /// In es, this message translates to:
  /// **'Este perfil no está disponible. Puede haber dejado de estar publicado o el enlace ya no es válido.'**
  String get companyCandidateNotAvailableBody;

  /// No description provided for @companyCandidatePendingTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu empresa está en verificación'**
  String get companyCandidatePendingTitle;

  /// No description provided for @companyCandidatePendingBody.
  ///
  /// In es, this message translates to:
  /// **'Hasta que se apruebe la verificación de tu empresa no podés ver perfiles de candidatos. Te avisamos apenas esté lista.'**
  String get companyCandidatePendingBody;

  /// No description provided for @companyCandidateRejectedTitle.
  ///
  /// In es, this message translates to:
  /// **'La verificación de tu empresa fue rechazada'**
  String get companyCandidateRejectedTitle;

  /// No description provided for @companyCandidateRejectedBody.
  ///
  /// In es, this message translates to:
  /// **'Mientras la verificación no esté aprobada no es posible ver candidatos. Corregí los datos y volvé a enviarla.'**
  String get companyCandidateRejectedBody;

  /// No description provided for @companyCandidateLoadError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar el perfil. Revisá tu conexión y reintentá.'**
  String get companyCandidateLoadError;

  /// No description provided for @companyCandidatePresentationReady.
  ///
  /// In es, this message translates to:
  /// **'Tiene una presentación lista para ver (la reproducción llega en una etapa posterior).'**
  String get companyCandidatePresentationReady;

  /// No description provided for @companyCandidateNoPresentation.
  ///
  /// In es, this message translates to:
  /// **'Todavía no cargó una presentación (es opcional y no dice nada de su candidatura).'**
  String get companyCandidateNoPresentation;

  /// No description provided for @dataFailureInvalidCuit.
  ///
  /// In es, this message translates to:
  /// **'Ese CUIT no es válido: revisá el dígito verificador.'**
  String get dataFailureInvalidCuit;

  /// No description provided for @dataFailureSecondFactor.
  ///
  /// In es, this message translates to:
  /// **'Esta acción necesita que inicies sesión con segundo factor.'**
  String get dataFailureSecondFactor;

  /// TFMUL (0031): la cuenta integra más de una empresa y la lectura falla cerrada en vez de elegir una
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta figura en más de una empresa. Escribinos para que lo resolvamos: no podemos elegir una por vos.'**
  String get dataFailureAmbiguousCompany;

  /// TFJOB (0032): transición de estado de oferta no permitida (otra persona del equipo la cambió, venció o fue descartada). Solo lo muestran Mis ofertas y el formulario de oferta, que ya recargan la oferta solos: por eso no pide actualizar
  ///
  /// In es, this message translates to:
  /// **'La oferta cambió de estado mientras la tenías abierta. Ya te mostramos cómo quedó: revisala y volvé a intentarlo.'**
  String get dataFailureJobStateConflict;

  /// Texto del distintivo de empresa verificada (T-029)
  ///
  /// In es, this message translates to:
  /// **'Empresa verificada'**
  String get companyVerifiedBadgeLabel;

  /// No description provided for @companyVerifiedBadgeTooltip.
  ///
  /// In es, this message translates to:
  /// **'Verificamos el CUIT de esta empresa con su constancia de ARCA.'**
  String get companyVerifiedBadgeTooltip;

  /// Etiqueta del distintivo para el lector de pantalla; el ícono es decorativo y no se anuncia aparte
  ///
  /// In es, this message translates to:
  /// **'Empresa verificada: verificamos su CUIT con la constancia de ARCA.'**
  String get companyVerifiedBadgeSemantics;

  /// No description provided for @companyVerificationTitle.
  ///
  /// In es, this message translates to:
  /// **'Verificación de la empresa'**
  String get companyVerificationTitle;

  /// No description provided for @companyVerificationErrorTitle.
  ///
  /// In es, this message translates to:
  /// **'No pudimos completar la acción'**
  String get companyVerificationErrorTitle;

  /// No description provided for @companyVerificationFormTitle.
  ///
  /// In es, this message translates to:
  /// **'Pedir la verificación'**
  String get companyVerificationFormTitle;

  /// No description provided for @companyVerificationFormHelp.
  ///
  /// In es, this message translates to:
  /// **'Confirmá el CUIT con el que registraste la empresa y adjuntá tu constancia de ARCA. La revisa una persona del equipo: no consultamos el padrón automáticamente.'**
  String get companyVerificationFormHelp;

  /// No description provided for @companyVerificationAttach.
  ///
  /// In es, this message translates to:
  /// **'Adjuntar constancia de ARCA'**
  String get companyVerificationAttach;

  /// Confirmación de que la constancia se subió al bucket privado
  ///
  /// In es, this message translates to:
  /// **'Constancia adjuntada ({formato}).'**
  String companyVerificationAttached(String formato);

  /// No description provided for @companyVerificationAttachedEarlier.
  ///
  /// In es, this message translates to:
  /// **'Ya hay una constancia adjunta de un envío anterior. Si no adjuntás otra, se usa esa.'**
  String get companyVerificationAttachedEarlier;

  /// No description provided for @companyVerificationSubmit.
  ///
  /// In es, this message translates to:
  /// **'Enviar solicitud'**
  String get companyVerificationSubmit;

  /// No description provided for @companyVerificationSubmitted.
  ///
  /// In es, this message translates to:
  /// **'Recibimos tu solicitud. Te avisamos apenas la revisemos.'**
  String get companyVerificationSubmitted;

  /// No description provided for @companyVerificationNotOwner.
  ///
  /// In es, this message translates to:
  /// **'Solo quien creó la empresa puede pedir la verificación.'**
  String get companyVerificationNotOwner;

  /// No description provided for @companyVerificationPendingTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu empresa todavía no está verificada'**
  String get companyVerificationPendingTitle;

  /// No description provided for @companyVerificationPendingBody.
  ///
  /// In es, this message translates to:
  /// **'Hasta que verifiquemos el CUIT vas a poder preparar todo, pero no publicar búsquedas.'**
  String get companyVerificationPendingBody;

  /// No description provided for @companyVerificationInReviewTitle.
  ///
  /// In es, this message translates to:
  /// **'Estamos revisando tu solicitud'**
  String get companyVerificationInReviewTitle;

  /// No description provided for @companyVerificationInReviewBody.
  ///
  /// In es, this message translates to:
  /// **'Ya recibimos el CUIT y la constancia. Te avisamos apenas haya respuesta; mientras tanto no hace falta que envíes nada más.'**
  String get companyVerificationInReviewBody;

  /// No description provided for @companyVerificationApprovedTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu empresa está verificada'**
  String get companyVerificationApprovedTitle;

  /// No description provided for @companyVerificationApprovedBody.
  ///
  /// In es, this message translates to:
  /// **'Verificamos el CUIT con tu constancia de ARCA.'**
  String get companyVerificationApprovedBody;

  /// No description provided for @companyVerificationRejectedTitle.
  ///
  /// In es, this message translates to:
  /// **'La verificación fue rechazada'**
  String get companyVerificationRejectedTitle;

  /// Explicación del rechazo con el motivo de la lista cerrada
  ///
  /// In es, this message translates to:
  /// **'Motivo: {motivo} Podés corregirlo y volver a enviarla.'**
  String companyVerificationRejectedBody(String motivo);

  /// No description provided for @rejectionCuitMismatch.
  ///
  /// In es, this message translates to:
  /// **'el CUIT no coincide con el de la constancia.'**
  String get rejectionCuitMismatch;

  /// No description provided for @rejectionUnreadableDocument.
  ///
  /// In es, this message translates to:
  /// **'la constancia no se lee bien.'**
  String get rejectionUnreadableDocument;

  /// No description provided for @rejectionExpiredDocument.
  ///
  /// In es, this message translates to:
  /// **'la constancia está vencida.'**
  String get rejectionExpiredDocument;

  /// No description provided for @rejectionMissingData.
  ///
  /// In es, this message translates to:
  /// **'faltan datos de la empresa.'**
  String get rejectionMissingData;

  /// No description provided for @rejectionCompanyNotOperating.
  ///
  /// In es, this message translates to:
  /// **'la empresa figura como no operativa.'**
  String get rejectionCompanyNotOperating;

  /// No description provided for @rejectionOther.
  ///
  /// In es, this message translates to:
  /// **'hace falta revisar la documentación.'**
  String get rejectionOther;

  /// No description provided for @verificationStatusPending.
  ///
  /// In es, this message translates to:
  /// **'Pendientes'**
  String get verificationStatusPending;

  /// No description provided for @verificationStatusInReview.
  ///
  /// In es, this message translates to:
  /// **'En revisión'**
  String get verificationStatusInReview;

  /// No description provided for @verificationStatusApproved.
  ///
  /// In es, this message translates to:
  /// **'Aprobadas'**
  String get verificationStatusApproved;

  /// No description provided for @verificationStatusRejected.
  ///
  /// In es, this message translates to:
  /// **'Rechazadas'**
  String get verificationStatusRejected;

  /// No description provided for @adminVerificationsTitle.
  ///
  /// In es, this message translates to:
  /// **'Verificaciones de empresa'**
  String get adminVerificationsTitle;

  /// No description provided for @adminVerificationsMfaTitle.
  ///
  /// In es, this message translates to:
  /// **'Necesitás segundo factor'**
  String get adminVerificationsMfaTitle;

  /// No description provided for @adminVerificationsMfaBody.
  ///
  /// In es, this message translates to:
  /// **'Para revisar verificaciones tenés que confirmar tu segundo factor en esta sesión. Si todavía no lo configuraste, lo hacés en el mismo paso, sin cerrar sesión.'**
  String get adminVerificationsMfaBody;

  /// Botón de la cola admin que lleva al alta o verificación TOTP
  ///
  /// In es, this message translates to:
  /// **'Verificar segundo factor'**
  String get adminVerificationsMfaAction;

  /// No description provided for @mfaTitle.
  ///
  /// In es, this message translates to:
  /// **'Segundo factor'**
  String get mfaTitle;

  /// No description provided for @mfaPreparing.
  ///
  /// In es, this message translates to:
  /// **'Preparando el segundo factor…'**
  String get mfaPreparing;

  /// No description provided for @mfaEnrollTitle.
  ///
  /// In es, this message translates to:
  /// **'Configurá tu autenticador'**
  String get mfaEnrollTitle;

  /// No description provided for @mfaEnrollIntro.
  ///
  /// In es, this message translates to:
  /// **'Escaneá el código QR con una app de autenticación (por ejemplo Google Authenticator, Microsoft Authenticator o Aegis). Si no podés escanearlo, cargá la clave manual que sigue.'**
  String get mfaEnrollIntro;

  /// No description provided for @mfaEnrollPendingNote.
  ///
  /// In es, this message translates to:
  /// **'El segundo factor queda activo recién cuando ingresás un código válido. Si salís antes, no queda configurado.'**
  String get mfaEnrollPendingNote;

  /// No description provided for @mfaEnrollRestartedTitle.
  ///
  /// In es, this message translates to:
  /// **'La configuración anterior venció'**
  String get mfaEnrollRestartedTitle;

  /// No description provided for @mfaEnrollRestarted.
  ///
  /// In es, this message translates to:
  /// **'Pasó demasiado tiempo y la configuración anterior venció. Este código QR es NUEVO: borrá la entrada anterior de tu app de autenticación y escaneá este. El código que tenías ya no sirve.'**
  String get mfaEnrollRestarted;

  /// No description provided for @mfaLimitsNote.
  ///
  /// In es, this message translates to:
  /// **'Guardá bien el acceso a tu app de autenticación: esta versión no permite recuperar, dar de baja ni reemplazar el autenticador desde la app.'**
  String get mfaLimitsNote;

  /// No description provided for @mfaQrSemantics.
  ///
  /// In es, this message translates to:
  /// **'Código QR para registrar TalentFlash en tu app de autenticación. Si no podés escanearlo, usá la clave manual que sigue.'**
  String get mfaQrSemantics;

  /// No description provided for @mfaManualKeyLabel.
  ///
  /// In es, this message translates to:
  /// **'Clave manual'**
  String get mfaManualKeyLabel;

  /// No description provided for @mfaManualKeyHelp.
  ///
  /// In es, this message translates to:
  /// **'Cargala en tu app como clave de tiempo (TOTP), sin espacios.'**
  String get mfaManualKeyHelp;

  /// Etiqueta para lectores de pantalla de la clave TOTP, deletreada
  ///
  /// In es, this message translates to:
  /// **'Clave manual, carácter por carácter: {clave}'**
  String mfaManualKeySemantics(String clave);

  /// No description provided for @mfaCodeLabel.
  ///
  /// In es, this message translates to:
  /// **'Código de 6 dígitos'**
  String get mfaCodeLabel;

  /// No description provided for @mfaCodeHelp.
  ///
  /// In es, this message translates to:
  /// **'Es el código que muestra tu app ahora; cambia cada 30 segundos.'**
  String get mfaCodeHelp;

  /// No description provided for @mfaCodeRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresá el código de tu app.'**
  String get mfaCodeRequired;

  /// No description provided for @mfaCodeFormat.
  ///
  /// In es, this message translates to:
  /// **'El código tiene 6 dígitos.'**
  String get mfaCodeFormat;

  /// No description provided for @mfaSubmitEnroll.
  ///
  /// In es, this message translates to:
  /// **'Activar segundo factor'**
  String get mfaSubmitEnroll;

  /// No description provided for @mfaSubmitVerify.
  ///
  /// In es, this message translates to:
  /// **'Verificar'**
  String get mfaSubmitVerify;

  /// No description provided for @mfaCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar y volver'**
  String get mfaCancel;

  /// No description provided for @mfaBackToQueue.
  ///
  /// In es, this message translates to:
  /// **'Volver a la cola'**
  String get mfaBackToQueue;

  /// No description provided for @mfaChallengeTitle.
  ///
  /// In es, this message translates to:
  /// **'Confirmá tu segundo factor'**
  String get mfaChallengeTitle;

  /// Bajada del desafío sobre un factor ya verificado
  ///
  /// In es, this message translates to:
  /// **'Ingresá el código que muestra tu app de autenticación para {nombre}.'**
  String mfaChallengeIntro(String nombre);

  /// No description provided for @mfaChooseTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Qué autenticador vas a usar?'**
  String get mfaChooseTitle;

  /// No description provided for @mfaChooseIntro.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta tiene más de un autenticador registrado. Elegí con cuál vas a verificar esta sesión.'**
  String get mfaChooseIntro;

  /// No description provided for @mfaChooseAnother.
  ///
  /// In es, this message translates to:
  /// **'Usar otro autenticador'**
  String get mfaChooseAnother;

  /// No description provided for @mfaFactorUnnamed.
  ///
  /// In es, this message translates to:
  /// **'Autenticador sin nombre'**
  String get mfaFactorUnnamed;

  /// Rótulo de un factor sin etiqueta en la lista para elegir; la fecha lo distingue
  ///
  /// In es, this message translates to:
  /// **'Autenticador sin nombre, registrado el {fecha}'**
  String mfaFactorUnnamedCreated(String fecha);

  /// Etiqueta con la que se guarda un factor nuevo; única por la fecha, hora y segundos
  ///
  /// In es, this message translates to:
  /// **'TalentFlash · {fecha}'**
  String mfaFriendlyName(String fecha);

  /// No description provided for @mfaVerified.
  ///
  /// In es, this message translates to:
  /// **'Segundo factor verificado. Ya podés revisar la cola.'**
  String get mfaVerified;

  /// No description provided for @mfaAlreadyVerified.
  ///
  /// In es, this message translates to:
  /// **'Tu sesión ya tiene el segundo factor verificado.'**
  String get mfaAlreadyVerified;

  /// No description provided for @mfaErrorTitle.
  ///
  /// In es, this message translates to:
  /// **'No pudimos verificar el código'**
  String get mfaErrorTitle;

  /// No description provided for @mfaUnavailableTitle.
  ///
  /// In es, this message translates to:
  /// **'No pudimos preparar el segundo factor'**
  String get mfaUnavailableTitle;

  /// No description provided for @mfaFailureInvalidCode.
  ///
  /// In es, this message translates to:
  /// **'El código no es válido. Fijate que sea el actual de tu app y probá de nuevo.'**
  String get mfaFailureInvalidCode;

  /// No description provided for @mfaFailureChallengeExpired.
  ///
  /// In es, this message translates to:
  /// **'Se venció el tiempo para ingresar el código. Probá de nuevo con el código actual de tu app.'**
  String get mfaFailureChallengeExpired;

  /// No description provided for @mfaFailureFactorNotFound.
  ///
  /// In es, this message translates to:
  /// **'No encontramos ese autenticador. Volvé a la cola y empezá de nuevo.'**
  String get mfaFailureFactorNotFound;

  /// No description provided for @mfaFailureNameConflict.
  ///
  /// In es, this message translates to:
  /// **'Quedó un alta anterior sin terminar con ese nombre. Reintentá para generar una nueva.'**
  String get mfaFailureNameConflict;

  /// No description provided for @mfaFailureTooManyFactors.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta llegó al máximo de autenticadores registrados.'**
  String get mfaFailureTooManyFactors;

  /// No description provided for @mfaFailureInsufficientAssurance.
  ///
  /// In es, this message translates to:
  /// **'Para hacer esto primero tenés que verificar el autenticador que ya tenés.'**
  String get mfaFailureInsufficientAssurance;

  /// No description provided for @mfaFailureNotEnabled.
  ///
  /// In es, this message translates to:
  /// **'El segundo factor no está habilitado en este entorno.'**
  String get mfaFailureNotEnabled;

  /// No description provided for @mfaFailureRejected.
  ///
  /// In es, this message translates to:
  /// **'La verificación fue rechazada. Probá de nuevo con el código actual de tu app.'**
  String get mfaFailureRejected;

  /// No description provided for @mfaFailureStaleSession.
  ///
  /// In es, this message translates to:
  /// **'La sesión cambió mientras preparábamos el segundo factor. Reintentá para empezar de nuevo.'**
  String get mfaFailureStaleSession;

  /// No description provided for @adminVerificationsEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay solicitudes en este estado.'**
  String get adminVerificationsEmpty;

  /// No description provided for @adminVerificationsErrorTitle.
  ///
  /// In es, this message translates to:
  /// **'No pudimos completar la acción'**
  String get adminVerificationsErrorTitle;

  /// No description provided for @adminVerificationsResolved.
  ///
  /// In es, this message translates to:
  /// **'Solicitud resuelta.'**
  String get adminVerificationsResolved;

  /// CUIT que envió la empresa en la solicitud
  ///
  /// In es, this message translates to:
  /// **'CUIT declarado: {cuit}'**
  String adminVerificationsCuit(String cuit);

  /// No description provided for @adminVerificationsWithDocument.
  ///
  /// In es, this message translates to:
  /// **'Adjuntó constancia de ARCA.'**
  String get adminVerificationsWithDocument;

  /// No description provided for @adminVerificationsNoDocument.
  ///
  /// In es, this message translates to:
  /// **'Sin constancia adjunta.'**
  String get adminVerificationsNoDocument;

  /// Motivo con el que se rechazó una solicitud ya resuelta
  ///
  /// In es, this message translates to:
  /// **'Motivo del rechazo: {motivo}'**
  String adminVerificationsReason(String motivo);

  /// No description provided for @adminVerificationsReasonTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Por qué se rechaza?'**
  String get adminVerificationsReasonTitle;

  /// No description provided for @adminVerificationsApprove.
  ///
  /// In es, this message translates to:
  /// **'Aprobar'**
  String get adminVerificationsApprove;

  /// No description provided for @adminVerificationsReject.
  ///
  /// In es, this message translates to:
  /// **'Rechazar'**
  String get adminVerificationsReject;

  /// No description provided for @adminVerificationsOpenDocument.
  ///
  /// In es, this message translates to:
  /// **'Ver la constancia'**
  String get adminVerificationsOpenDocument;

  /// No description provided for @adminVerificationsDocumentTitle.
  ///
  /// In es, this message translates to:
  /// **'Constancia de ARCA'**
  String get adminVerificationsDocumentTitle;

  /// No description provided for @adminVerificationsDocumentHelp.
  ///
  /// In es, this message translates to:
  /// **'Copiá este enlace y abrilo en el navegador. Vence en 5 minutos: si expira, volvé a pedirlo desde acá.'**
  String get adminVerificationsDocumentHelp;

  /// No description provided for @adminVerificationsDocumentError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos generar el enlace a la constancia. Reintentá en unos minutos.'**
  String get adminVerificationsDocumentError;

  /// No description provided for @adminVerificationsDocumentClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get adminVerificationsDocumentClose;

  /// Título de la lista de ofertas de la empresa (T-030) y del acceso desde su inicio
  ///
  /// In es, this message translates to:
  /// **'Mis ofertas'**
  String get jobsCompanyTitle;

  /// Título del feed de ofertas del candidato (T-030) y del acceso desde su inicio
  ///
  /// In es, this message translates to:
  /// **'Ofertas de trabajo'**
  String get jobsFeedTitle;

  /// No description provided for @jobsNewOffer.
  ///
  /// In es, this message translates to:
  /// **'Nueva oferta'**
  String get jobsNewOffer;

  /// No description provided for @jobsEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Todavía no creaste ofertas'**
  String get jobsEmptyTitle;

  /// No description provided for @jobsEmptyBody.
  ///
  /// In es, this message translates to:
  /// **'Cuando crees una, la vas a ver acá con su estado.'**
  String get jobsEmptyBody;

  /// No description provided for @jobsEmptyReadOnlyBody.
  ///
  /// In es, this message translates to:
  /// **'Cuando tu empresa cree ofertas, las vas a ver acá.'**
  String get jobsEmptyReadOnlyBody;

  /// No description provided for @jobsEmptyAction.
  ///
  /// In es, this message translates to:
  /// **'Crear mi primera oferta'**
  String get jobsEmptyAction;

  /// No description provided for @jobsLoadErrorTitle.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar tus ofertas'**
  String get jobsLoadErrorTitle;

  /// Aviso de Mis ofertas cuando falla una recarga con la lista ya cargada. Si la recarga la pidió la persona (botón Actualizar), va en un SnackBar sin acción; si fue automática (tras una acción, un guardado del formulario o al volver a la pantalla), solo se anuncia al lector de pantalla, para no tapar el resultado que está a la vista. Se reintenta con el botón Actualizar de la barra superior
  ///
  /// In es, this message translates to:
  /// **'La lista no se actualizó y puede no estar al día: tocá \"Actualizar\" arriba para reintentar.'**
  String get jobsListStale;

  /// Rótulo (tooltip) del botón de la barra de Mis ofertas que vuelve a pedir la lista; siempre disponible
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get jobsCompanyRefresh;

  /// Rótulo del botón Actualizar de Mis ofertas cuando la última recarga falló con la lista ya cargada (el ícono pasa a uno de advertencia)
  ///
  /// In es, this message translates to:
  /// **'Actualizar: la lista puede no estar al día'**
  String get jobsCompanyRefreshStale;

  /// Rótulo del botón Actualizar de Mis ofertas mientras la recarga está en vuelo
  ///
  /// In es, this message translates to:
  /// **'Actualizando tus ofertas'**
  String get jobsCompanyRefreshing;

  /// No description provided for @jobsErrorTitle.
  ///
  /// In es, this message translates to:
  /// **'No pudimos completar la acción'**
  String get jobsErrorTitle;

  /// No description provided for @jobsUnverifiedBanner.
  ///
  /// In es, this message translates to:
  /// **'Tu empresa todavía no está verificada. Podés preparar ofertas y guardarlas como borrador; vas a poder publicarlas cuando la verifiquemos.'**
  String get jobsUnverifiedBanner;

  /// No description provided for @jobsGoToVerification.
  ///
  /// In es, this message translates to:
  /// **'Ir a la verificación'**
  String get jobsGoToVerification;

  /// Rol viewer (D3 de T-030): ve las ofertas de su empresa pero no las escribe
  ///
  /// In es, this message translates to:
  /// **'Tu rol en la empresa te deja ver las ofertas, pero no crearlas ni modificarlas. Si lo necesitás, pedíselo a quien administra la cuenta de la empresa.'**
  String get jobsReadOnlyBanner;

  /// No description provided for @jobsPermissionsError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos comprobar si tu cuenta puede gestionar ofertas, así que por ahora no te mostramos esas acciones.'**
  String get jobsPermissionsError;

  /// No description provided for @jobsFailureNotAllowed.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta no puede hacer esta acción. Para publicar, tu empresa tiene que estar verificada y tu rol tiene que permitir gestionar ofertas.'**
  String get jobsFailureNotAllowed;

  /// No description provided for @jobsFailureInvalidData.
  ///
  /// In es, this message translates to:
  /// **'No pudimos guardar: hay datos que no cumplen las reglas de la oferta. Revisá los campos y probá de nuevo.'**
  String get jobsFailureInvalidData;

  /// No description provided for @jobsFailurePublishRules.
  ///
  /// In es, this message translates to:
  /// **'Para publicarla, el sueldo mínimo tiene que ser mayor que 0, el vencimiento tiene que estar dentro de los próximos 60 días y, si la localidad tiene barrios, hay que elegir uno. Editala para corregirlo.'**
  String get jobsFailurePublishRules;

  /// No description provided for @jobsPublishNeedsVerification.
  ///
  /// In es, this message translates to:
  /// **'Para publicar, tu empresa tiene que estar verificada.'**
  String get jobsPublishNeedsVerification;

  /// No description provided for @jobStatusDraft.
  ///
  /// In es, this message translates to:
  /// **'Borrador'**
  String get jobStatusDraft;

  /// No description provided for @jobStatusActive.
  ///
  /// In es, this message translates to:
  /// **'Activa'**
  String get jobStatusActive;

  /// No description provided for @jobStatusPaused.
  ///
  /// In es, this message translates to:
  /// **'Pausada'**
  String get jobStatusPaused;

  /// No description provided for @jobStatusExpired.
  ///
  /// In es, this message translates to:
  /// **'Vencida'**
  String get jobStatusExpired;

  /// No description provided for @jobStatusClosed.
  ///
  /// In es, this message translates to:
  /// **'Cerrada'**
  String get jobStatusClosed;

  /// No description provided for @jobStatusUnknown.
  ///
  /// In es, this message translates to:
  /// **'Estado desconocido'**
  String get jobStatusUnknown;

  /// Etiqueta para el lector de pantalla del estado de una oferta: el estado nunca se comunica solo con color
  ///
  /// In es, this message translates to:
  /// **'Estado: {status}'**
  String jobStatusSemantics(String status);

  /// No description provided for @jobExpiresOn.
  ///
  /// In es, this message translates to:
  /// **'Vence el {date}'**
  String jobExpiresOn(String date);

  /// Oferta todavía activa cuyo vencimiento ya pasó (el cron de T-033 todavía no la marcó vencida)
  ///
  /// In es, this message translates to:
  /// **'Venció el {date}: ya no se muestra a los candidatos.'**
  String jobExpiredOn(String date);

  /// No description provided for @jobExpiredOnShort.
  ///
  /// In es, this message translates to:
  /// **'Venció el {date}'**
  String jobExpiredOnShort(String date);

  /// No description provided for @jobPlaceUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar el nombre de la ubicación.'**
  String get jobPlaceUnavailable;

  /// No description provided for @jobPublishBlockedUnverified.
  ///
  /// In es, this message translates to:
  /// **'Vas a poder publicar cuando verifiquemos tu empresa. Mientras tanto, guardá la oferta como borrador.'**
  String get jobPublishBlockedUnverified;

  /// No description provided for @jobActionEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get jobActionEdit;

  /// No description provided for @jobActionPublish.
  ///
  /// In es, this message translates to:
  /// **'Publicar'**
  String get jobActionPublish;

  /// No description provided for @jobActionPause.
  ///
  /// In es, this message translates to:
  /// **'Pausar'**
  String get jobActionPause;

  /// No description provided for @jobActionResume.
  ///
  /// In es, this message translates to:
  /// **'Reanudar'**
  String get jobActionResume;

  /// No description provided for @jobActionClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get jobActionClose;

  /// No description provided for @jobActionDiscard.
  ///
  /// In es, this message translates to:
  /// **'Descartar borrador'**
  String get jobActionDiscard;

  /// No description provided for @jobActionDuplicate.
  ///
  /// In es, this message translates to:
  /// **'Duplicar'**
  String get jobActionDuplicate;

  /// Etiqueta accesible de cada acción de la lista, para que el lector diga sobre qué oferta actúa
  ///
  /// In es, this message translates to:
  /// **'{action}: {title}'**
  String jobActionSemantics(String action, String title);

  /// No description provided for @jobDialogCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get jobDialogCancel;

  /// No description provided for @jobCloseDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Cerrar la oferta?'**
  String get jobCloseDialogTitle;

  /// No description provided for @jobCloseDialogBody.
  ///
  /// In es, this message translates to:
  /// **'La oferta deja de verse para los candidatos y no se puede volver a abrir. Si más adelante necesitás publicarla de nuevo, podés duplicarla.'**
  String get jobCloseDialogBody;

  /// No description provided for @jobCloseDialogConfirm.
  ///
  /// In es, this message translates to:
  /// **'Cerrar oferta'**
  String get jobCloseDialogConfirm;

  /// No description provided for @jobDiscardDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Descartar el borrador?'**
  String get jobDiscardDialogTitle;

  /// No description provided for @jobDiscardDialogBody.
  ///
  /// In es, this message translates to:
  /// **'El borrador se quita de tu lista y no se puede recuperar.'**
  String get jobDiscardDialogBody;

  /// No description provided for @jobDiscardDialogConfirm.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get jobDiscardDialogConfirm;

  /// No description provided for @jobOutcomePublished.
  ///
  /// In es, this message translates to:
  /// **'Oferta publicada.'**
  String get jobOutcomePublished;

  /// No description provided for @jobOutcomePaused.
  ///
  /// In es, this message translates to:
  /// **'Oferta pausada: los candidatos ya no la ven.'**
  String get jobOutcomePaused;

  /// No description provided for @jobOutcomeResumed.
  ///
  /// In es, this message translates to:
  /// **'Oferta reanudada.'**
  String get jobOutcomeResumed;

  /// No description provided for @jobOutcomeClosed.
  ///
  /// In es, this message translates to:
  /// **'Oferta cerrada.'**
  String get jobOutcomeClosed;

  /// No description provided for @jobOutcomeDiscarded.
  ///
  /// In es, this message translates to:
  /// **'Borrador descartado.'**
  String get jobOutcomeDiscarded;

  /// No description provided for @jobOutcomeDraftSaved.
  ///
  /// In es, this message translates to:
  /// **'Borrador guardado.'**
  String get jobOutcomeDraftSaved;

  /// No description provided for @jobOutcomeChangesSaved.
  ///
  /// In es, this message translates to:
  /// **'Cambios guardados.'**
  String get jobOutcomeChangesSaved;

  /// No description provided for @jobFormNewTitle.
  ///
  /// In es, this message translates to:
  /// **'Nueva oferta'**
  String get jobFormNewTitle;

  /// No description provided for @jobFormEditTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar oferta'**
  String get jobFormEditTitle;

  /// No description provided for @jobFormIntro.
  ///
  /// In es, this message translates to:
  /// **'Todos los campos son obligatorios salvo los que dicen \"opcional\", también para guardar un borrador. Para publicar, además, el sueldo mínimo tiene que ser mayor que 0, el vencimiento tiene que estar dentro de los próximos 60 días y, si la localidad tiene barrios, hay que elegir uno.'**
  String get jobFormIntro;

  /// No description provided for @jobFormDuplicateNote.
  ///
  /// In es, this message translates to:
  /// **'Copiamos el contenido de \"{title}\". Elegí una fecha de vencimiento nueva antes de guardar.'**
  String jobFormDuplicateNote(String title);

  /// No description provided for @jobFormErrorsTitle.
  ///
  /// In es, this message translates to:
  /// **'Revisá los campos marcados'**
  String get jobFormErrorsTitle;

  /// No description provided for @jobFormErrorsBody.
  ///
  /// In es, this message translates to:
  /// **'Hay datos que faltan o que no son válidos. Cada campo explica qué corregir.'**
  String get jobFormErrorsBody;

  /// No description provided for @jobSectionPosition.
  ///
  /// In es, this message translates to:
  /// **'Puesto y descripción'**
  String get jobSectionPosition;

  /// No description provided for @jobSectionSalary.
  ///
  /// In es, this message translates to:
  /// **'Sueldo'**
  String get jobSectionSalary;

  /// No description provided for @jobSectionContract.
  ///
  /// In es, this message translates to:
  /// **'Contrato y jornada'**
  String get jobSectionContract;

  /// No description provided for @jobSectionSchedule.
  ///
  /// In es, this message translates to:
  /// **'Días y horario'**
  String get jobSectionSchedule;

  /// No description provided for @jobSectionWorkMode.
  ///
  /// In es, this message translates to:
  /// **'Modalidad'**
  String get jobSectionWorkMode;

  /// No description provided for @jobSectionLocation.
  ///
  /// In es, this message translates to:
  /// **'Ubicación'**
  String get jobSectionLocation;

  /// No description provided for @jobSectionSector.
  ///
  /// In es, this message translates to:
  /// **'Sector'**
  String get jobSectionSector;

  /// No description provided for @jobSectionExperience.
  ///
  /// In es, this message translates to:
  /// **'Experiencia'**
  String get jobSectionExperience;

  /// No description provided for @jobSectionAvailability.
  ///
  /// In es, this message translates to:
  /// **'Disponibilidad'**
  String get jobSectionAvailability;

  /// No description provided for @jobSectionBenefits.
  ///
  /// In es, this message translates to:
  /// **'Beneficios'**
  String get jobSectionBenefits;

  /// No description provided for @jobSectionVacancies.
  ///
  /// In es, this message translates to:
  /// **'Vacantes'**
  String get jobSectionVacancies;

  /// No description provided for @jobSectionExpiry.
  ///
  /// In es, this message translates to:
  /// **'Vencimiento'**
  String get jobSectionExpiry;

  /// No description provided for @jobSectionDescription.
  ///
  /// In es, this message translates to:
  /// **'Descripción y requisitos'**
  String get jobSectionDescription;

  /// No description provided for @jobSectionMore.
  ///
  /// In es, this message translates to:
  /// **'Más datos'**
  String get jobSectionMore;

  /// No description provided for @jobTitleLabel.
  ///
  /// In es, this message translates to:
  /// **'Puesto'**
  String get jobTitleLabel;

  /// No description provided for @jobTitleHint.
  ///
  /// In es, this message translates to:
  /// **'Por ejemplo: Mozo/a de salón'**
  String get jobTitleHint;

  /// No description provided for @jobDescriptionLabel.
  ///
  /// In es, this message translates to:
  /// **'Descripción y requisitos'**
  String get jobDescriptionLabel;

  /// No description provided for @jobDescriptionHelp.
  ///
  /// In es, this message translates to:
  /// **'Contá las tareas y todo lo que pedís para el puesto: experiencia, conocimientos, documentación u otros requisitos.'**
  String get jobDescriptionHelp;

  /// No description provided for @jobSalaryMinLabel.
  ///
  /// In es, this message translates to:
  /// **'Sueldo mínimo'**
  String get jobSalaryMinLabel;

  /// No description provided for @jobSalaryMaxLabel.
  ///
  /// In es, this message translates to:
  /// **'Sueldo máximo'**
  String get jobSalaryMaxLabel;

  /// No description provided for @jobSalaryHelp.
  ///
  /// In es, this message translates to:
  /// **'En pesos argentinos y sin centavos. Para un sueldo fijo, poné el mismo monto en los dos campos. El sueldo siempre se muestra en la oferta.'**
  String get jobSalaryHelp;

  /// No description provided for @jobSalaryPeriodLabel.
  ///
  /// In es, this message translates to:
  /// **'Período del sueldo'**
  String get jobSalaryPeriodLabel;

  /// No description provided for @jobSalaryPeriodMonthly.
  ///
  /// In es, this message translates to:
  /// **'Mensual'**
  String get jobSalaryPeriodMonthly;

  /// No description provided for @jobSalaryPeriodYearly.
  ///
  /// In es, this message translates to:
  /// **'Anual'**
  String get jobSalaryPeriodYearly;

  /// No description provided for @jobSalaryPeriodHourly.
  ///
  /// In es, this message translates to:
  /// **'Por hora'**
  String get jobSalaryPeriodHourly;

  /// No description provided for @jobSalaryPerMonth.
  ///
  /// In es, this message translates to:
  /// **'por mes'**
  String get jobSalaryPerMonth;

  /// No description provided for @jobSalaryPerYear.
  ///
  /// In es, this message translates to:
  /// **'por año'**
  String get jobSalaryPerYear;

  /// No description provided for @jobSalaryPerHour.
  ///
  /// In es, this message translates to:
  /// **'por hora'**
  String get jobSalaryPerHour;

  /// No description provided for @jobSalaryRange.
  ///
  /// In es, this message translates to:
  /// **'ARS {min} a {max}'**
  String jobSalaryRange(String min, String max);

  /// No description provided for @jobSalarySingle.
  ///
  /// In es, this message translates to:
  /// **'ARS {amount}'**
  String jobSalarySingle(String amount);

  /// No description provided for @jobSalaryWithPeriod.
  ///
  /// In es, this message translates to:
  /// **'{amount} {period}'**
  String jobSalaryWithPeriod(String amount, String period);

  /// No description provided for @jobContractTypeLabel.
  ///
  /// In es, this message translates to:
  /// **'Modalidad de contratación'**
  String get jobContractTypeLabel;

  /// No description provided for @jobContractRelacionDependencia.
  ///
  /// In es, this message translates to:
  /// **'Relación de dependencia'**
  String get jobContractRelacionDependencia;

  /// No description provided for @jobContractMonotributo.
  ///
  /// In es, this message translates to:
  /// **'Monotributo'**
  String get jobContractMonotributo;

  /// No description provided for @jobContractPlazoFijo.
  ///
  /// In es, this message translates to:
  /// **'Plazo fijo'**
  String get jobContractPlazoFijo;

  /// No description provided for @jobContractTemporal.
  ///
  /// In es, this message translates to:
  /// **'Temporal'**
  String get jobContractTemporal;

  /// No description provided for @jobContractPasantia.
  ///
  /// In es, this message translates to:
  /// **'Pasantía'**
  String get jobContractPasantia;

  /// No description provided for @jobContractFreelance.
  ///
  /// In es, this message translates to:
  /// **'Freelance'**
  String get jobContractFreelance;

  /// No description provided for @jobJornadaLabel.
  ///
  /// In es, this message translates to:
  /// **'Jornada'**
  String get jobJornadaLabel;

  /// No description provided for @jobJornadaFullTime.
  ///
  /// In es, this message translates to:
  /// **'Jornada completa'**
  String get jobJornadaFullTime;

  /// No description provided for @jobJornadaPartTime.
  ///
  /// In es, this message translates to:
  /// **'Jornada parcial'**
  String get jobJornadaPartTime;

  /// No description provided for @jobJornadaPorTurnos.
  ///
  /// In es, this message translates to:
  /// **'Por turnos'**
  String get jobJornadaPorTurnos;

  /// No description provided for @jobJornadaFinDeSemana.
  ///
  /// In es, this message translates to:
  /// **'Fines de semana'**
  String get jobJornadaFinDeSemana;

  /// No description provided for @jobJornadaPorHoras.
  ///
  /// In es, this message translates to:
  /// **'Por horas'**
  String get jobJornadaPorHoras;

  /// No description provided for @jobScheduleDaysLabel.
  ///
  /// In es, this message translates to:
  /// **'Días de trabajo'**
  String get jobScheduleDaysLabel;

  /// No description provided for @jobScheduleDetailLabel.
  ///
  /// In es, this message translates to:
  /// **'Horario'**
  String get jobScheduleDetailLabel;

  /// No description provided for @jobScheduleDetailHint.
  ///
  /// In es, this message translates to:
  /// **'Por ejemplo: 9 a 18 hs, viernes hasta las 15'**
  String get jobScheduleDetailHint;

  /// No description provided for @jobWorkModeLabel.
  ///
  /// In es, this message translates to:
  /// **'Modalidad de trabajo'**
  String get jobWorkModeLabel;

  /// No description provided for @jobNeighborhoodHelp.
  ///
  /// In es, this message translates to:
  /// **'Obligatorio para publicar en esta localidad.'**
  String get jobNeighborhoodHelp;

  /// No description provided for @jobSectorLabel.
  ///
  /// In es, this message translates to:
  /// **'Sector o rubro (opcional)'**
  String get jobSectorLabel;

  /// No description provided for @jobSectorNone.
  ///
  /// In es, this message translates to:
  /// **'Sin especificar'**
  String get jobSectorNone;

  /// La oferta (editada o duplicada) tenía un sector que ya no está activo: el formulario lo quita para que lo que se ve sea lo que se guarda
  ///
  /// In es, this message translates to:
  /// **'El sector que tenía la oferta ya no está disponible. Elegí otro o dejalo sin especificar.'**
  String get jobSectorUnavailable;

  /// No description provided for @jobExperienceLabel.
  ///
  /// In es, this message translates to:
  /// **'Experiencia requerida'**
  String get jobExperienceLabel;

  /// No description provided for @jobAvailabilityLabel.
  ///
  /// In es, this message translates to:
  /// **'Disponibilidad requerida'**
  String get jobAvailabilityLabel;

  /// No description provided for @jobBenefitAddLabel.
  ///
  /// In es, this message translates to:
  /// **'Agregar beneficio'**
  String get jobBenefitAddLabel;

  /// No description provided for @jobBenefitsHelp.
  ///
  /// In es, this message translates to:
  /// **'Opcional. Hasta {maxItems} beneficios de hasta {maxLength} caracteres cada uno; por ejemplo, comida incluida o propinas.'**
  String jobBenefitsHelp(int maxItems, int maxLength);

  /// No description provided for @jobBenefitsCount.
  ///
  /// In es, this message translates to:
  /// **'{count} de {max} beneficios'**
  String jobBenefitsCount(int count, int max);

  /// No description provided for @jobBenefitsNone.
  ///
  /// In es, this message translates to:
  /// **'No se informaron beneficios.'**
  String get jobBenefitsNone;

  /// No description provided for @jobVacanciesLabel.
  ///
  /// In es, this message translates to:
  /// **'Cantidad de vacantes'**
  String get jobVacanciesLabel;

  /// No description provided for @jobVacanciesHelp.
  ///
  /// In es, this message translates to:
  /// **'Entre {min} y {max}.'**
  String jobVacanciesHelp(int min, int max);

  /// No description provided for @jobVacanciesValue.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 vacante} other{{count} vacantes}}'**
  String jobVacanciesValue(int count);

  /// No description provided for @jobExpiryLabel.
  ///
  /// In es, this message translates to:
  /// **'Fecha de vencimiento'**
  String get jobExpiryLabel;

  /// No description provided for @jobExpiryHint.
  ///
  /// In es, this message translates to:
  /// **'Elegí una fecha'**
  String get jobExpiryHint;

  /// No description provided for @jobExpiryHelp.
  ///
  /// In es, this message translates to:
  /// **'Para publicar, hasta {days} días desde hoy. Ese día la oferta deja de mostrarse.'**
  String jobExpiryHelp(int days);

  /// No description provided for @jobExpiryPick.
  ///
  /// In es, this message translates to:
  /// **'Elegir la fecha de vencimiento'**
  String get jobExpiryPick;

  /// No description provided for @jobSaveDraft.
  ///
  /// In es, this message translates to:
  /// **'Guardar borrador'**
  String get jobSaveDraft;

  /// No description provided for @jobPublish.
  ///
  /// In es, this message translates to:
  /// **'Publicar'**
  String get jobPublish;

  /// No description provided for @jobSaveChanges.
  ///
  /// In es, this message translates to:
  /// **'Guardar cambios'**
  String get jobSaveChanges;

  /// No description provided for @jobPreview.
  ///
  /// In es, this message translates to:
  /// **'Vista previa'**
  String get jobPreview;

  /// No description provided for @jobPreviewNote.
  ///
  /// In es, this message translates to:
  /// **'Así va a ver la oferta un candidato.'**
  String get jobPreviewNote;

  /// Nombre provisorio de la empresa en la vista previa de una oferta nueva, solo si no se pudo leer el nombre real de la empresa (company_profiles)
  ///
  /// In es, this message translates to:
  /// **'Tu empresa'**
  String get jobPreviewCompanyName;

  /// No description provided for @jobEditActiveNeedsVerification.
  ///
  /// In es, this message translates to:
  /// **'Para modificar una oferta publicada, tu empresa tiene que estar verificada. Desde Mis ofertas podés pausarla o cerrarla.'**
  String get jobEditActiveNeedsVerification;

  /// No description provided for @jobLeaveTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Salir sin guardar?'**
  String get jobLeaveTitle;

  /// No description provided for @jobLeaveBody.
  ///
  /// In es, this message translates to:
  /// **'Tenés cambios sin guardar en la oferta. Si salís ahora, se pierden.'**
  String get jobLeaveBody;

  /// No description provided for @jobLeaveConfirm.
  ///
  /// In es, this message translates to:
  /// **'Salir sin guardar'**
  String get jobLeaveConfirm;

  /// No description provided for @jobLeaveCancel.
  ///
  /// In es, this message translates to:
  /// **'Seguir editando'**
  String get jobLeaveCancel;

  /// No description provided for @jobNotFoundTitle.
  ///
  /// In es, this message translates to:
  /// **'No encontramos esa oferta'**
  String get jobNotFoundTitle;

  /// No description provided for @jobNotFoundBody.
  ///
  /// In es, this message translates to:
  /// **'Puede haber sido descartada o el enlace ya no es válido.'**
  String get jobNotFoundBody;

  /// No description provided for @jobLoadError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar la oferta. Revisá tu conexión y reintentá.'**
  String get jobLoadError;

  /// No description provided for @jobBackToList.
  ///
  /// In es, this message translates to:
  /// **'Volver a Mis ofertas'**
  String get jobBackToList;

  /// No description provided for @jobNotEditableTitle.
  ///
  /// In es, this message translates to:
  /// **'Esta oferta ya no se puede editar'**
  String get jobNotEditableTitle;

  /// No description provided for @jobNotEditableBody.
  ///
  /// In es, this message translates to:
  /// **'Una oferta vencida o cerrada queda como historial. Si querés volver a publicarla, duplicala y elegí una fecha nueva.'**
  String get jobNotEditableBody;

  /// No description provided for @jobErrorTextEmpty.
  ///
  /// In es, this message translates to:
  /// **'Completá este campo.'**
  String get jobErrorTextEmpty;

  /// No description provided for @jobErrorTextTooLong.
  ///
  /// In es, this message translates to:
  /// **'Admite hasta {max} caracteres.'**
  String jobErrorTextTooLong(int max);

  /// No description provided for @jobErrorDaysEmpty.
  ///
  /// In es, this message translates to:
  /// **'Elegí al menos un día.'**
  String get jobErrorDaysEmpty;

  /// No description provided for @jobErrorDaysDuplicated.
  ///
  /// In es, this message translates to:
  /// **'Hay días repetidos.'**
  String get jobErrorDaysDuplicated;

  /// No description provided for @jobErrorSalaryMissing.
  ///
  /// In es, this message translates to:
  /// **'Ingresá el monto.'**
  String get jobErrorSalaryMissing;

  /// No description provided for @jobErrorSalaryFormat.
  ///
  /// In es, this message translates to:
  /// **'Ingresá solo números, en pesos y sin centavos (por ejemplo, 350000 o 350.000).'**
  String get jobErrorSalaryFormat;

  /// No description provided for @jobErrorSalaryNegative.
  ///
  /// In es, this message translates to:
  /// **'El monto no puede ser negativo.'**
  String get jobErrorSalaryNegative;

  /// No description provided for @jobErrorSalaryTooHigh.
  ///
  /// In es, this message translates to:
  /// **'El monto no puede superar {max}.'**
  String jobErrorSalaryTooHigh(String max);

  /// No description provided for @jobErrorSalaryNotPositive.
  ///
  /// In es, this message translates to:
  /// **'Para publicar, el sueldo mínimo tiene que ser mayor que 0.'**
  String get jobErrorSalaryNotPositive;

  /// No description provided for @jobErrorSalaryBelowMin.
  ///
  /// In es, this message translates to:
  /// **'El máximo no puede ser menor que el mínimo.'**
  String get jobErrorSalaryBelowMin;

  /// No description provided for @jobErrorBenefitEmpty.
  ///
  /// In es, this message translates to:
  /// **'Escribí el beneficio antes de agregarlo.'**
  String get jobErrorBenefitEmpty;

  /// No description provided for @jobErrorBenefitTooLong.
  ///
  /// In es, this message translates to:
  /// **'Cada beneficio admite hasta {max} caracteres.'**
  String jobErrorBenefitTooLong(int max);

  /// No description provided for @jobErrorBenefitDuplicated.
  ///
  /// In es, this message translates to:
  /// **'Ese beneficio ya está en la lista.'**
  String get jobErrorBenefitDuplicated;

  /// No description provided for @jobErrorBenefitTooMany.
  ///
  /// In es, this message translates to:
  /// **'Podés cargar hasta {max} beneficios.'**
  String jobErrorBenefitTooMany(int max);

  /// No description provided for @jobErrorVacanciesMissing.
  ///
  /// In es, this message translates to:
  /// **'Ingresá la cantidad de vacantes.'**
  String get jobErrorVacanciesMissing;

  /// No description provided for @jobErrorVacanciesOutOfRange.
  ///
  /// In es, this message translates to:
  /// **'Tiene que ser un número entero entre {min} y {max}.'**
  String jobErrorVacanciesOutOfRange(int min, int max);

  /// No description provided for @jobErrorExpiryMissing.
  ///
  /// In es, this message translates to:
  /// **'Elegí la fecha de vencimiento.'**
  String get jobErrorExpiryMissing;

  /// No description provided for @jobErrorExpiryNotInFuture.
  ///
  /// In es, this message translates to:
  /// **'Para publicar, el vencimiento tiene que ser posterior a hoy.'**
  String get jobErrorExpiryNotInFuture;

  /// No description provided for @jobErrorExpiryBeyondWindow.
  ///
  /// In es, this message translates to:
  /// **'Para publicar, el vencimiento puede estar como máximo a {days} días de hoy.'**
  String jobErrorExpiryBeyondWindow(int days);

  /// No description provided for @jobErrorNeighborhoodRequired.
  ///
  /// In es, this message translates to:
  /// **'Elegí el barrio: es obligatorio para publicar en esta localidad.'**
  String get jobErrorNeighborhoodRequired;

  /// No description provided for @jobValueMissing.
  ///
  /// In es, this message translates to:
  /// **'Sin completar'**
  String get jobValueMissing;

  /// No description provided for @jobCompanyUnknown.
  ///
  /// In es, this message translates to:
  /// **'Empresa sin nombre disponible'**
  String get jobCompanyUnknown;

  /// No description provided for @jobsFeedEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay ofertas publicadas.'**
  String get jobsFeedEmpty;

  /// No description provided for @jobsFeedEmptyHint.
  ///
  /// In es, this message translates to:
  /// **'Volvé a mirar en un rato: las ofertas nuevas aparecen primero.'**
  String get jobsFeedEmptyHint;

  /// No description provided for @jobsFeedRefresh.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get jobsFeedRefresh;

  /// Rótulo del botón Actualizar del feed mientras la recarga está en vuelo
  ///
  /// In es, this message translates to:
  /// **'Actualizando ofertas'**
  String get jobsFeedRefreshing;

  /// SnackBar del feed cuando falla una recarga (botón Actualizar o deslizar) y se siguen viendo las ofertas de antes
  ///
  /// In es, this message translates to:
  /// **'Las ofertas no se actualizaron. {motivo}'**
  String jobsFeedRefreshFailed(String motivo);

  /// SnackBar corto del feed cuando una recarga sale bien después de una que había fallado: reemplaza el aviso del fallo, que ya no es cierto
  ///
  /// In es, this message translates to:
  /// **'Las ofertas ya están al día.'**
  String get jobsFeedUpToDate;

  /// No description provided for @jobsFeedLoadErrorTitle.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar las ofertas'**
  String get jobsFeedLoadErrorTitle;

  /// No description provided for @jobsFeedLoadMore.
  ///
  /// In es, this message translates to:
  /// **'Cargar más ofertas'**
  String get jobsFeedLoadMore;

  /// No description provided for @jobsFeedLoadingMore.
  ///
  /// In es, this message translates to:
  /// **'Cargando más ofertas'**
  String get jobsFeedLoadingMore;

  /// No description provided for @jobsFeedEnd.
  ///
  /// In es, this message translates to:
  /// **'No hay más ofertas por ahora.'**
  String get jobsFeedEnd;

  /// Cantidad de ofertas cargadas, anunciada por el lector al cambiar (UX_FLOWS §20)
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Mostrando 1 oferta} other{Mostrando {count} ofertas}}'**
  String jobsFeedCount(int count);

  /// Pista del lector de pantalla para la acción de tocar una tarjeta de oferta
  ///
  /// In es, this message translates to:
  /// **'ver el detalle de la oferta'**
  String get jobCardOpenHint;

  /// No description provided for @jobDetailTitle.
  ///
  /// In es, this message translates to:
  /// **'Detalle de la oferta'**
  String get jobDetailTitle;

  /// No description provided for @jobNotAvailableTitle.
  ///
  /// In es, this message translates to:
  /// **'Esta oferta no está disponible'**
  String get jobNotAvailableTitle;

  /// No description provided for @jobNotAvailableBody.
  ///
  /// In es, this message translates to:
  /// **'Puede haber vencido, estar pausada o el enlace ya no es válido.'**
  String get jobNotAvailableBody;

  /// No description provided for @jobBackToFeed.
  ///
  /// In es, this message translates to:
  /// **'Volver a las ofertas'**
  String get jobBackToFeed;

  /// Aviso honesto en el detalle de la oferta: no hay botón Postularme hasta T-040
  ///
  /// In es, this message translates to:
  /// **'Todavía no podés postularte desde la app: esa función llega en una próxima etapa.'**
  String get jobApplyComingSoon;
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
