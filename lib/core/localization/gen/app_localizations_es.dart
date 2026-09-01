// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'TalentFlash';

  @override
  String get welcomeHeadline => 'Bienvenido a TalentFlash';

  @override
  String get welcomeSubtitle =>
      'Trabajo en gastronomía y hotelería de CABA y GBA, con presentaciones en video de 20 a 30 segundos. El video siempre es opcional.';

  @override
  String get roleQuestion => '¿Cómo querés usar TalentFlash?';

  @override
  String get roleCandidateTitle => 'Soy candidato';

  @override
  String get roleCandidateSubtitle => 'Quiero conseguir trabajo';

  @override
  String get roleCandidateSemantics =>
      'Crear una cuenta de candidato para buscar trabajo';

  @override
  String get roleCompanyTitle => 'Soy empresa';

  @override
  String get roleCompanySubtitle => 'Quiero contratar personal';

  @override
  String get roleCompanySemantics =>
      'Crear una cuenta de empresa para publicar ofertas y descubrir candidatos';

  @override
  String get welcomeHaveAccount => 'Ya tengo cuenta: iniciar sesión';

  @override
  String get candidateHomeTitle => 'Inicio — Candidato';

  @override
  String get candidateHomePlaceholder =>
      'Acá va a estar tu feed de ofertas con salario siempre visible (Bloque G del ROADMAP). Por ahora este es el punto de entrada del candidato.';

  @override
  String get companyHomeTitle => 'Inicio — Empresa';

  @override
  String get companyHomePlaceholder =>
      'Acá van a estar tus búsquedas, ofertas y candidatos (Bloque G del ROADMAP). Por ahora este es el punto de entrada de la empresa.';

  @override
  String get adminHomeTitle => 'Inicio — Administración';

  @override
  String get adminHomePlaceholder =>
      'El panel de moderación y administración llega en el Bloque P del ROADMAP. Tu cuenta tiene rol de administración, así que no te llevamos a un shell de candidato ni de empresa.';

  @override
  String signedInAs(String email) {
    return 'Sesión iniciada como $email';
  }

  @override
  String get authLoadingSession => 'Cargando tu sesión…';

  @override
  String get authLoginTitle => 'Iniciar sesión';

  @override
  String get authLoginSubtitle =>
      'Entrá con el correo y la contraseña de tu cuenta.';

  @override
  String get authLoginSubtitleCandidate =>
      'Entrá para seguir tus postulaciones y descubrir ofertas.';

  @override
  String get authLoginSubtitleCompany =>
      'Entrá para gestionar tus búsquedas y tus candidatos.';

  @override
  String get authEmailLabel => 'Correo electrónico';

  @override
  String get authEmailHint => 'nombre@ejemplo.com';

  @override
  String get authPasswordLabel => 'Contraseña';

  @override
  String get authPasswordConfirmLabel => 'Repetir contraseña';

  @override
  String authPasswordHelp(int min) {
    return 'Mínimo $min caracteres.';
  }

  @override
  String get authPasswordShow => 'Mostrar contraseña';

  @override
  String get authPasswordHide => 'Ocultar contraseña';

  @override
  String get authSubmitLogin => 'Entrar';

  @override
  String get authSubmitSignUp => 'Crear cuenta';

  @override
  String get authSubmitRecovery => 'Enviar instrucciones';

  @override
  String get authForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get authGoToSignUp => '¿No tenés cuenta? Registrate';

  @override
  String get authGoToSignUpCandidate =>
      '¿No tenés cuenta? Registrate como candidato';

  @override
  String get authGoToSignUpCompany => '¿No tenés cuenta? Registrá tu empresa';

  @override
  String get authGoToLogin => '¿Ya tenés cuenta? Iniciá sesión';

  @override
  String get authAccountTypeTitle => '¿Qué tipo de cuenta querés crear?';

  @override
  String get authAccountTypeSubtitle =>
      'Elegí el recorrido; después vas a poder completar tu perfil.';

  @override
  String get authSignUpCandidateTitle => 'Crear cuenta de candidato';

  @override
  String get authSignUpCandidateSubtitle =>
      'Con tu cuenta vas a poder postularte y seguir el estado de cada postulación.';

  @override
  String get authSignUpCompanyTitle => 'Crear cuenta de empresa';

  @override
  String get authSignUpCompanySubtitle =>
      'Creá primero tu usuario. Los datos de la empresa y la verificación de CUIT vienen en el paso siguiente.';

  @override
  String get authSignUpConsentDataProcessing =>
      'Acepto el tratamiento de mis datos personales para operar mi cuenta (Ley 25.326).';

  @override
  String get authSignUpConsentAge => 'Declaro ser mayor de 18 años.';

  @override
  String get authSignUpConsentNote =>
      'Los consentimientos opcionales (publicación del perfil, funciones de IA) se piden más adelante y se pueden revocar cuando quieras.';

  @override
  String get authSignUpEmailConfirmationSent =>
      'Te enviamos un correo para confirmar tu cuenta. Abrí el enlace y volvé a iniciar sesión.';

  @override
  String get authRecoveryTitle => 'Recuperar contraseña';

  @override
  String get authRecoverySubtitle =>
      'Escribí tu correo y te mandamos las instrucciones para restablecer la contraseña.';

  @override
  String get authRecoverySent =>
      'Si hay una cuenta con ese correo, te enviamos las instrucciones para restablecer la contraseña. Revisá tu bandeja de entrada y el correo no deseado.';

  @override
  String get authRecoveryPendingStep =>
      'El cambio de contraseña dentro de la app todavía no está disponible: falta definir el enlace profundo (T-013 del ROADMAP).';

  @override
  String get authBackToLogin => 'Volver al inicio de sesión';

  @override
  String get authSignOut => 'Cerrar sesión';

  @override
  String get authGoHome => 'Ir a mi inicio';

  @override
  String get authGoToStart => 'Volver al inicio';

  @override
  String get authErrorEmailRequired => 'Ingresá tu correo electrónico.';

  @override
  String get authErrorEmailInvalid =>
      'Ese correo no parece válido. Revisalo y probá de nuevo.';

  @override
  String get authErrorPasswordRequired => 'Ingresá tu contraseña.';

  @override
  String authErrorPasswordTooShort(int min) {
    return 'La contraseña necesita al menos $min caracteres.';
  }

  @override
  String get authErrorPasswordConfirmRequired =>
      'Repetí la contraseña para confirmarla.';

  @override
  String get authErrorPasswordMismatch => 'Las contraseñas no coinciden.';

  @override
  String get authErrorConsentRequired =>
      'Necesitamos tu confirmación para poder crear la cuenta.';

  @override
  String get authFailureInvalidCredentials =>
      'El correo o la contraseña no coinciden. Probá de nuevo.';

  @override
  String get authFailureEmailAlreadyRegistered =>
      'Ya existe una cuenta con ese correo. Iniciá sesión o recuperá tu contraseña.';

  @override
  String get authFailureWeakPassword =>
      'Esa contraseña es demasiado débil. Elegí una más larga.';

  @override
  String get authFailureEmailNotConfirmed =>
      'Confirmá tu correo con el enlace que te enviamos y volvé a entrar.';

  @override
  String get authFailureRateLimited =>
      'Hiciste muchos intentos seguidos. Esperá unos minutos y volvé a probar.';

  @override
  String get authFailureNetwork =>
      'No pudimos conectarnos. Revisá tu conexión y reintentá.';

  @override
  String get authFailureUnknown =>
      'No pudimos completar la acción. Reintentá en unos minutos.';

  @override
  String get authErrorTitle => 'No pudimos continuar';

  @override
  String get authSessionIssueClaimTitle =>
      'No pudimos verificar tu tipo de cuenta';

  @override
  String get authSessionIssueClaimBody =>
      'Tu sesión no trae un tipo de cuenta válido, así que por seguridad no te damos acceso. Cerrá sesión y volvé a entrar; si el problema sigue, escribinos.';

  @override
  String get authSessionIssueNotAllowedTitle =>
      'No tenés permiso para esta sección';

  @override
  String get authSessionIssueNotAllowedBody =>
      'Tu cuenta no habilita esta parte de TalentFlash. Volvé a tu inicio para seguir trabajando.';

  @override
  String get authSessionIssueNotFoundTitle => 'No encontramos esa pantalla';

  @override
  String get authSessionIssueNotFoundBody =>
      'El enlace puede estar viejo o mal escrito. Volvé al inicio y buscá desde ahí.';

  @override
  String get retryLabel => 'Reintentar';

  @override
  String get sessionLoadFailedBody =>
      'No pudimos cargar los datos de tu cuenta. Revisá tu conexión y reintentá.';

  @override
  String get dataFailureNotAllowed => 'Tu cuenta no puede hacer esta acción.';

  @override
  String get dataFailureInvalidData =>
      'Hay datos incompletos o inválidos. Revisá los pasos y probá de nuevo.';

  @override
  String get dataFailureStaleConsent =>
      'Los textos legales cambiaron mientras completabas el formulario. Volvé al paso de consentimientos y aceptá la versión nueva.';

  @override
  String get dataFailureDuplicate =>
      'Ese CUIT ya está registrado en TalentFlash. Si es tu empresa, escribinos.';

  @override
  String get dataFailureNetwork =>
      'No pudimos conectarnos. Revisá tu conexión y reintentá.';

  @override
  String get dataFailureUnknown =>
      'No pudimos completar la acción. Reintentá en unos minutos.';

  @override
  String get onboardingErrorTitle => 'No pudimos guardar';

  @override
  String onboardingStepLabel(int current, int total) {
    return 'Paso $current de $total';
  }

  @override
  String get onboardingContinue => 'Continuar';

  @override
  String get onboardingBack => 'Volver';

  @override
  String get onboardingFinish => 'Terminar';

  @override
  String get onboardingConsentsTitle => 'Tus consentimientos';

  @override
  String get onboardingConsentsIntro =>
      'Para registrar tu aceptación de forma válida necesitamos que la confirmes acá, con tu sesión iniciada. Cada punto es una decisión separada y nada viene marcado.';

  @override
  String get consentTermsLabel => 'Leí y acepto los Términos y condiciones.';

  @override
  String get consentAlreadyAccepted =>
      'Ya lo aceptaste; queda registrado con fecha y versión.';

  @override
  String get consentReadTerms => 'Leer los términos y condiciones';

  @override
  String get consentReadPrivacy => 'Leer la política de privacidad';

  @override
  String get candidateOnboardingTitle => 'Completá tu perfil';

  @override
  String get candidateStepIdentityTitle => 'Sobre vos';

  @override
  String get candidateStepPlaceTitle => '¿Dónde buscás trabajo?';

  @override
  String get candidateStepPreferencesTitle => 'Tu búsqueda';

  @override
  String get candidateStepPrivacyTitle => 'Privacidad de tu perfil';

  @override
  String get onboardingNotificationsTitle => 'Avisos';

  @override
  String get onboardingSummaryTitle => 'Revisá y confirmá';

  @override
  String get fullNameLabel => 'Nombre y apellido';

  @override
  String get fullNameError => 'Ingresá tu nombre y apellido.';

  @override
  String get birthDateLabel => 'Fecha de nacimiento';

  @override
  String get birthDateHint => 'DD/MM/AAAA';

  @override
  String get birthDateHelp =>
      'La usamos solo para confirmar que sos mayor de 18 años.';

  @override
  String get birthDateErrorRequired => 'Ingresá tu fecha de nacimiento.';

  @override
  String get birthDateErrorInvalid =>
      'Esa fecha no parece válida. Usá el formato DD/MM/AAAA.';

  @override
  String get birthDateErrorFuture => 'La fecha no puede estar en el futuro.';

  @override
  String get underageTitle => 'TalentFlash es solo para mayores de 18';

  @override
  String get underageBody =>
      'Por la fecha que ingresaste todavía no cumpliste los 18 años, así que no podemos crearte el perfil. No guardamos ningún dato de este formulario. Te esperamos cuando los cumplas.';

  @override
  String get provinceLabel => 'Provincia';

  @override
  String get localityLabel => 'Localidad';

  @override
  String get neighborhoodLabel => 'Barrio';

  @override
  String get selectOptionError => 'Elegí una opción.';

  @override
  String get sectorLabel => 'Sector o rubro';

  @override
  String get availabilityLabel => 'Disponibilidad';

  @override
  String get availabilityImmediate => 'Inmediata';

  @override
  String get availabilityOneWeek => 'En 1 semana';

  @override
  String get availabilityTwoWeeks => 'En 2 semanas';

  @override
  String get availabilityOneMonth => 'En 1 mes';

  @override
  String get availabilityToAgree => 'A convenir';

  @override
  String get workModesLabel => 'Modalidad preferida';

  @override
  String get workModesError => 'Elegí al menos una modalidad.';

  @override
  String get workModeOnSite => 'Presencial';

  @override
  String get workModeHybrid => 'Híbrido';

  @override
  String get workModeRemote => 'Remoto';

  @override
  String get privacyIntro =>
      'Estas dos opciones son tuyas: nada viene marcado, no cambian lo que podés hacer en la app y las revocás cuando quieras.';

  @override
  String get consentVideoLabel =>
      'Quiero que las empresas descubran mi perfil (publicación de perfil y video).';

  @override
  String get consentVideoHelp =>
      'Si no lo activás, igual vas a poder ver ofertas y postularte; solo no aparecés en las búsquedas de las empresas.';

  @override
  String get consentAiLabel =>
      'Quiero usar las funciones de inteligencia artificial sobre mis datos.';

  @override
  String get consentAiHelp =>
      'Sin esto, todo funciona en modo manual. Nunca usamos tus datos para entrenar modelos.';

  @override
  String get notifPrefsIntro =>
      'Elegí qué avisos querés recibir por cada canal. Nada viene activado de fábrica: si no marcás nada, solo vas a ver avisos dentro de la app.';

  @override
  String get notifChannelPush => 'Push';

  @override
  String get notifChannelEmail => 'Correo';

  @override
  String get notifCategoryApplicationUpdate => 'Tus postulaciones';

  @override
  String get notifCategoryNewApplication => 'Nuevas postulaciones';

  @override
  String get notifCategoryInvitation => 'Invitaciones';

  @override
  String get notifCategoryMessage => 'Mensajes';

  @override
  String get notifCategoryVerificationUpdate => 'Verificación de tu empresa';

  @override
  String get notifCategorySystem => 'Cuenta y seguridad';

  @override
  String get notifSystemLockedNote =>
      'Los avisos de cuenta y seguridad llegan siempre dentro de la app y por correo; no se pueden desactivar.';

  @override
  String notifPushSwitchLabel(String category) {
    return 'Push para $category';
  }

  @override
  String notifEmailSwitchLabel(String category) {
    return 'Correo para $category';
  }

  @override
  String get summaryIntro =>
      'Revisá que esté todo bien antes de terminar. Podés volver a cualquier paso.';

  @override
  String get summaryVisibleYes =>
      'Tu perfil va a ser visible para las empresas verificadas.';

  @override
  String get summaryVisibleNo =>
      'Tu perfil NO va a ser visible para las empresas: no activaste la publicación. Podés cambiarlo cuando quieras.';

  @override
  String get summaryMissingValue => 'Sin completar';

  @override
  String get companyOnboardingTitle => 'Registrá tu empresa';

  @override
  String get companyStepDataTitle => 'Datos de la empresa';

  @override
  String get companyStepPlaceTitle => 'Ubicación y web';

  @override
  String get companyStepApplicantTitle => 'Sobre vos';

  @override
  String get legalNameLabel => 'Razón social';

  @override
  String get legalNameError => 'Ingresá la razón social.';

  @override
  String get tradeNameLabel => 'Nombre de fantasía';

  @override
  String get tradeNameError => 'Ingresá el nombre de fantasía.';

  @override
  String get cuitLabel => 'CUIT';

  @override
  String get cuitHint => '30-12345678-9';

  @override
  String get cuitHelp =>
      'Once números. La verificación de la empresa se hace después, con revisión humana.';

  @override
  String get cuitErrorRequired => 'Ingresá el CUIT de la empresa.';

  @override
  String get cuitErrorLength => 'El CUIT debe tener 11 números.';

  @override
  String get companySizeLabel => 'Tamaño de la empresa';

  @override
  String get companySize1to10 => '1 a 10 personas';

  @override
  String get companySize11to50 => '11 a 50 personas';

  @override
  String get companySize51to200 => '51 a 200 personas';

  @override
  String get companySize201to500 => '201 a 500 personas';

  @override
  String get companySizeMoreThan500 => 'Más de 500 personas';

  @override
  String get websiteLabel => 'Sitio web (opcional)';

  @override
  String get websiteError => 'Esa dirección no parece una URL válida.';

  @override
  String get positionLabel => 'Tu cargo';

  @override
  String get positionError => 'Ingresá tu cargo.';

  @override
  String get relationshipLabel => 'Tu relación con la empresa';

  @override
  String get relationshipOwner => 'Dueño/a';

  @override
  String get relationshipPartner => 'Socio/a';

  @override
  String get relationshipManager => 'Gerente o encargado/a';

  @override
  String get relationshipHr => 'Recursos Humanos';

  @override
  String get relationshipOther => 'Otra';

  @override
  String get companyPendingNote =>
      'La empresa se crea en estado \"no verificada\": hasta que verifiquemos el CUIT vas a poder preparar todo, pero no publicar búsquedas.';

  @override
  String get reconsentTitle => 'Necesitamos tu aceptación de nuevo';

  @override
  String get reconsentBody =>
      'Actualizamos textos que ya habías aceptado. Leélos y confirmá cada punto para seguir usando tu cuenta; nada viene marcado.';

  @override
  String get reconsentAccept => 'Aceptar y continuar';

  @override
  String legalVersionLabel(String version) {
    return 'Versión vigente: $version';
  }

  @override
  String get legalTermsFallbackTitle => 'Términos y condiciones';

  @override
  String get legalPrivacyFallbackTitle => 'Política de privacidad';

  @override
  String get legalLoadError =>
      'No pudimos cargar el documento. Revisá tu conexión y reintentá.';
}
