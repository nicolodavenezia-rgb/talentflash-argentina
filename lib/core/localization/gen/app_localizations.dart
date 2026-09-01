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
  /// **'30-12345678-9'**
  String get cuitHint;

  /// No description provided for @cuitHelp.
  ///
  /// In es, this message translates to:
  /// **'Once números. La verificación de la empresa se hace después, con revisión humana.'**
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
