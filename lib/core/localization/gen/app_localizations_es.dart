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
  String get authFailureSessionMissing =>
      'Tu sesión terminó. Volvé a iniciar sesión.';

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
  String get cuitHint => '30-12345678-1';

  @override
  String get cuitHelp =>
      'Once números. Comprobamos el dígito verificador; que la empresa sea tuya lo revisa una persona después.';

  @override
  String get cuitErrorRequired => 'Ingresá el CUIT de la empresa.';

  @override
  String get cuitErrorLength => 'El CUIT debe tener 11 números.';

  @override
  String get cuitErrorCharacters =>
      'El CUIT solo lleva números, guiones y espacios.';

  @override
  String get cuitErrorCheckDigit =>
      'Ese CUIT no existe: el último número no se corresponde con los anteriores. Revisalo.';

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

  @override
  String get profileTitle => 'Mi perfil';

  @override
  String get profileEditAction => 'Editar perfil';

  @override
  String get profileLoadError =>
      'No pudimos cargar tu perfil. Revisá tu conexión y reintentá.';

  @override
  String get profilePublishedBadge => 'Visible para empresas verificadas';

  @override
  String get profileNotPublishedBadge => 'No visible para empresas';

  @override
  String get profileReadyBadge => 'Tenés los datos mínimos para postularte';

  @override
  String get profileNotReadyBadge => 'Te faltan datos mínimos para postularte';

  @override
  String get profileSectionIdentity => 'Sobre vos';

  @override
  String get profileSectionLocation => 'Dónde buscás trabajo';

  @override
  String get profileSectionPreferences => 'Tu búsqueda';

  @override
  String get profileSectionSchedule => 'Disponibilidad horaria';

  @override
  String get profileSectionSalary => 'Expectativa salarial';

  @override
  String get profileSectionSkills => 'Habilidades';

  @override
  String get profileSectionLanguages => 'Idiomas';

  @override
  String get profileSectionExperience => 'Experiencia laboral';

  @override
  String get profileSectionEducation => 'Educación';

  @override
  String get profileEmptyValue => 'Sin completar';

  @override
  String get profileOptionalEmptyValue => 'Sin especificar (es opcional)';

  @override
  String profileSalaryRange(String min, String max) {
    return 'ARS $min a $max por mes';
  }

  @override
  String profileExperiencePeriod(String from, String to) {
    return '$from a $to';
  }

  @override
  String profileExperienceCurrent(String from) {
    return '$from a la actualidad';
  }

  @override
  String profileScheduleNextDay(String day, String start, String end) {
    return '$day de $start a $end (termina el día siguiente)';
  }

  @override
  String profileScheduleSameDay(String day, String start, String end) {
    return '$day de $start a $end';
  }

  @override
  String get profileCompletenessTitle => 'Completitud del perfil';

  @override
  String profileCompletenessValue(int score) {
    return '$score % completo';
  }

  @override
  String get profileCompletenessHint =>
      'Es una guía solo para vos: las empresas no la ven y no cambia ningún orden de resultados.';

  @override
  String get profileCompletenessPendingTitle => 'Si querés, podés sumar:';

  @override
  String get profileCompletenessItemBase => 'Los datos básicos del onboarding';

  @override
  String get profileCompletenessItemHeadline => 'Un titular que te presente';

  @override
  String get profileCompletenessItemBio => 'Una breve biografía';

  @override
  String get profileCompletenessItemExperience =>
      'Al menos una experiencia laboral';

  @override
  String get profileCompletenessItemSkills => 'Tres habilidades o más';

  @override
  String get profileCompletenessItemLanguages => 'Al menos un idioma';

  @override
  String get profileCompletenessItemSchedule => 'Tu disponibilidad horaria';

  @override
  String get profileCompletenessItemEducation => 'Tu educación (opcional)';

  @override
  String get profileCompletenessItemAvatar => 'Una foto de perfil (opcional)';

  @override
  String get profileCompletenessItemPresentation =>
      'Una presentación (opcional)';

  @override
  String get profilePresentationNone =>
      'Todavía no tenés una presentación cargada.';

  @override
  String get profilePresentationProcessing =>
      'Tu video de presentación se está procesando.';

  @override
  String get profilePresentationReady => 'Tu presentación en video está lista.';

  @override
  String get profilePresentationFailed => 'El procesamiento de tu video falló.';

  @override
  String get profilePresentationExpired => 'Tu video de presentación venció.';

  @override
  String get profilePresentationOptionalNote =>
      'La presentación es opcional y nunca es requisito para postularte. La grabación en video, audio o texto —con igual jerarquía— llega en una etapa posterior del desarrollo.';

  @override
  String get profileAvatarLabel => 'Foto de perfil';

  @override
  String get profileAvatarAdd => 'Agregar foto';

  @override
  String get profileAvatarReplace => 'Cambiar foto';

  @override
  String get profileAvatarDelete => 'Quitar foto';

  @override
  String get profileAvatarOptionalNote =>
      'La foto es opcional: no tenerla no te resta en nada.';

  @override
  String get profileAvatarUploaded => 'Foto de perfil actualizada.';

  @override
  String get profileAvatarDeleted => 'Foto de perfil eliminada.';

  @override
  String get avatarErrorTooLarge =>
      'La imagen supera los 2 MB. Elegí una más liviana.';

  @override
  String get avatarErrorInvalid =>
      'El archivo no parece una imagen JPEG o PNG válida.';

  @override
  String get avatarErrorUnsupported =>
      'Por ahora aceptamos JPEG o PNG; el soporte de WebP llega más adelante.';

  @override
  String get avatarErrorNotAllowed =>
      'No pudimos actualizar tu foto con esta sesión. Volvé a entrar y reintentá.';

  @override
  String get avatarErrorNetwork =>
      'No pudimos conectarnos para subir la foto. Revisá tu conexión.';

  @override
  String get avatarErrorUnknown =>
      'No pudimos procesar la foto. Reintentá en unos minutos.';

  @override
  String get profileEditTitle => 'Editar perfil';

  @override
  String get profileSaveAction => 'Guardar cambios';

  @override
  String get profileSavedMessage => 'Cambios guardados.';

  @override
  String get profileDiscardTitle => '¿Salir sin guardar?';

  @override
  String get profileDiscardBody =>
      'Tenés cambios sin guardar. Si salís ahora, se pierden.';

  @override
  String get profileDiscardConfirm => 'Salir sin guardar';

  @override
  String get profileDiscardCancel => 'Seguir editando';

  @override
  String get headlineLabel => 'Titular';

  @override
  String get headlineHelp =>
      'Una línea que te presente (hasta 120 caracteres).';

  @override
  String get bioLabel => 'Biografía';

  @override
  String get bioHelp =>
      'Contá tu experiencia y qué buscás (hasta 2000 caracteres).';

  @override
  String get experienceLevelLabel => 'Nivel de experiencia';

  @override
  String get salaryMinLabel => 'Mínimo (ARS por mes)';

  @override
  String get salaryMaxLabel => 'Máximo (ARS por mes)';

  @override
  String get salaryOptionalNote =>
      'La expectativa salarial es opcional; podés dejarla vacía.';

  @override
  String get skillsAddLabel => 'Agregar habilidad';

  @override
  String get languagesAddLabel => 'Agregar idioma';

  @override
  String get chipAddAction => 'Agregar';

  @override
  String chipRemoveLabel(String value) {
    return 'Quitar $value';
  }

  @override
  String get profileErrorNameRequired =>
      'El nombre necesita entre 2 y 80 caracteres.';

  @override
  String get profileErrorHeadlineTooLong =>
      'El titular admite hasta 120 caracteres.';

  @override
  String get profileErrorBioTooLong =>
      'La biografía admite hasta 2000 caracteres.';

  @override
  String get profileErrorSalaryInvalid =>
      'Revisá el rango: el mínimo no puede superar al máximo.';

  @override
  String get profileErrorSalaryFormat =>
      'Ingresá solo números, sin puntos ni comas.';

  @override
  String get profileErrorChipEmpty => 'Escribí un valor antes de agregar.';

  @override
  String get profileErrorChipDuplicate => 'Ese valor ya está en la lista.';

  @override
  String get profileErrorChipTooLong => 'Ese valor es demasiado largo.';

  @override
  String get profileErrorTooManyChips => 'Llegaste al máximo de esta lista.';

  @override
  String get experienceAdd => 'Agregar experiencia';

  @override
  String get experienceEditAction => 'Editar';

  @override
  String get experienceDeleteAction => 'Eliminar';

  @override
  String get experienceMoveUp => 'Subir en la lista';

  @override
  String get experienceMoveDown => 'Bajar en la lista';

  @override
  String get experienceCompanyLabel => 'Empresa o lugar';

  @override
  String get experiencePositionLabel => 'Puesto';

  @override
  String get experienceFromLabel => 'Desde (MM/AAAA)';

  @override
  String get experienceToLabel => 'Hasta (MM/AAAA)';

  @override
  String get experienceCurrentLabel => 'Trabajo acá actualmente';

  @override
  String get experienceDescriptionLabel => 'Descripción (opcional)';

  @override
  String get experienceErrorRequired =>
      'Completá empresa, puesto y fecha de inicio.';

  @override
  String get experienceErrorDates =>
      'Revisá las fechas: formato MM/AAAA y el fin no puede ser anterior al inicio.';

  @override
  String get experienceDialogSave => 'Guardar experiencia';

  @override
  String get educationAdd => 'Agregar educación';

  @override
  String get educationLevelLabel => 'Nivel';

  @override
  String get educationInstitutionLabel => 'Institución';

  @override
  String get educationDegreeLabel => 'Título (opcional)';

  @override
  String get educationOptionalNote =>
      'La educación es opcional: no es requisito para postularte.';

  @override
  String get educationErrorRequired => 'Completá nivel e institución.';

  @override
  String get educationDialogSave => 'Guardar educación';

  @override
  String get educationLevelPrimario => 'Primario';

  @override
  String get educationLevelSecundario => 'Secundario';

  @override
  String get educationLevelTerciario => 'Terciario';

  @override
  String get educationLevelUniversitario => 'Universitario';

  @override
  String get educationLevelPosgrado => 'Posgrado';

  @override
  String get educationLevelCurso => 'Curso o capacitación';

  @override
  String get scheduleAdd => 'Agregar franja';

  @override
  String get scheduleDayLabel => 'Día';

  @override
  String get scheduleStartLabel => 'Desde (HH:MM)';

  @override
  String get scheduleEndLabel => 'Hasta (HH:MM)';

  @override
  String get scheduleCrossesNote =>
      'Si el fin es menor que el inicio, el turno termina el día siguiente (por ejemplo, 22:00 a 02:00).';

  @override
  String get scheduleErrorFormat => 'Usá el formato HH:MM, por ejemplo 18:30.';

  @override
  String get scheduleErrorOverlap =>
      'Esa franja se superpone con otra que ya cargaste.';

  @override
  String get scheduleErrorTooMany =>
      'Podés cargar hasta 21 franjas, con un máximo de 3 por día.';

  @override
  String get scheduleErrorZeroLength =>
      'El inicio y el fin no pueden ser iguales.';

  @override
  String scheduleDeleteLabel(String day) {
    return 'Quitar la franja de $day';
  }

  @override
  String get scheduleDialogSave => 'Guardar franja';

  @override
  String get dayLun => 'Lunes';

  @override
  String get dayMar => 'Martes';

  @override
  String get dayMie => 'Miércoles';

  @override
  String get dayJue => 'Jueves';

  @override
  String get dayVie => 'Viernes';

  @override
  String get daySab => 'Sábado';

  @override
  String get dayDom => 'Domingo';

  @override
  String get experienceLevelSinExperiencia => 'Sin experiencia';

  @override
  String get experienceLevelHasta1Anio => 'Hasta 1 año';

  @override
  String get experienceLevel1a3 => '1 a 3 años';

  @override
  String get experienceLevel3a5 => '3 a 5 años';

  @override
  String get experienceLevelMas5 => 'Más de 5 años';

  @override
  String get companyCandidateTitle => 'Perfil de candidato';

  @override
  String get companyCandidateBack => 'Volver';

  @override
  String get companyCandidateNotAvailableTitle => 'Candidato no disponible';

  @override
  String get companyCandidateNotAvailableBody =>
      'Este perfil no está disponible. Puede haber dejado de estar publicado o el enlace ya no es válido.';

  @override
  String get companyCandidatePendingTitle => 'Tu empresa está en verificación';

  @override
  String get companyCandidatePendingBody =>
      'Hasta que se apruebe la verificación de tu empresa no podés ver perfiles de candidatos. Te avisamos apenas esté lista.';

  @override
  String get companyCandidateRejectedTitle =>
      'La verificación de tu empresa fue rechazada';

  @override
  String get companyCandidateRejectedBody =>
      'Mientras la verificación no esté aprobada no es posible ver candidatos. Corregí los datos y volvé a enviarla.';

  @override
  String get companyCandidateLoadError =>
      'No pudimos cargar el perfil. Revisá tu conexión y reintentá.';

  @override
  String get companyCandidatePresentationReady =>
      'Tiene una presentación lista para ver (la reproducción llega en una etapa posterior).';

  @override
  String get companyCandidateNoPresentation =>
      'Todavía no cargó una presentación (es opcional y no dice nada de su candidatura).';

  @override
  String get dataFailureInvalidCuit =>
      'Ese CUIT no es válido: revisá el dígito verificador.';

  @override
  String get dataFailureSecondFactor =>
      'Esta acción necesita que inicies sesión con segundo factor.';

  @override
  String get dataFailureAmbiguousCompany =>
      'Tu cuenta figura en más de una empresa. Escribinos para que lo resolvamos: no podemos elegir una por vos.';

  @override
  String get companyVerifiedBadgeLabel => 'Empresa verificada';

  @override
  String get companyVerifiedBadgeTooltip =>
      'Verificamos el CUIT de esta empresa con su constancia de ARCA.';

  @override
  String get companyVerifiedBadgeSemantics =>
      'Empresa verificada: verificamos su CUIT con la constancia de ARCA.';

  @override
  String get companyVerificationTitle => 'Verificación de la empresa';

  @override
  String get companyVerificationErrorTitle => 'No pudimos completar la acción';

  @override
  String get companyVerificationFormTitle => 'Pedir la verificación';

  @override
  String get companyVerificationFormHelp =>
      'Confirmá el CUIT con el que registraste la empresa y adjuntá tu constancia de ARCA. La revisa una persona del equipo: no consultamos el padrón automáticamente.';

  @override
  String get companyVerificationAttach => 'Adjuntar constancia de ARCA';

  @override
  String companyVerificationAttached(String formato) {
    return 'Constancia adjuntada ($formato).';
  }

  @override
  String get companyVerificationAttachedEarlier =>
      'Ya hay una constancia adjunta de un envío anterior. Si no adjuntás otra, se usa esa.';

  @override
  String get companyVerificationSubmit => 'Enviar solicitud';

  @override
  String get companyVerificationSubmitted =>
      'Recibimos tu solicitud. Te avisamos apenas la revisemos.';

  @override
  String get companyVerificationNotOwner =>
      'Solo quien creó la empresa puede pedir la verificación.';

  @override
  String get companyVerificationPendingTitle =>
      'Tu empresa todavía no está verificada';

  @override
  String get companyVerificationPendingBody =>
      'Hasta que verifiquemos el CUIT vas a poder preparar todo, pero no publicar búsquedas.';

  @override
  String get companyVerificationInReviewTitle =>
      'Estamos revisando tu solicitud';

  @override
  String get companyVerificationInReviewBody =>
      'Ya recibimos el CUIT y la constancia. Te avisamos apenas haya respuesta; mientras tanto no hace falta que envíes nada más.';

  @override
  String get companyVerificationApprovedTitle => 'Tu empresa está verificada';

  @override
  String get companyVerificationApprovedBody =>
      'Verificamos el CUIT con tu constancia de ARCA.';

  @override
  String get companyVerificationRejectedTitle =>
      'La verificación fue rechazada';

  @override
  String companyVerificationRejectedBody(String motivo) {
    return 'Motivo: $motivo Podés corregirlo y volver a enviarla.';
  }

  @override
  String get rejectionCuitMismatch =>
      'el CUIT no coincide con el de la constancia.';

  @override
  String get rejectionUnreadableDocument => 'la constancia no se lee bien.';

  @override
  String get rejectionExpiredDocument => 'la constancia está vencida.';

  @override
  String get rejectionMissingData => 'faltan datos de la empresa.';

  @override
  String get rejectionCompanyNotOperating =>
      'la empresa figura como no operativa.';

  @override
  String get rejectionOther => 'hace falta revisar la documentación.';

  @override
  String get verificationStatusPending => 'Pendientes';

  @override
  String get verificationStatusInReview => 'En revisión';

  @override
  String get verificationStatusApproved => 'Aprobadas';

  @override
  String get verificationStatusRejected => 'Rechazadas';

  @override
  String get adminVerificationsTitle => 'Verificaciones de empresa';

  @override
  String get adminVerificationsMfaTitle => 'Necesitás segundo factor';

  @override
  String get adminVerificationsMfaBody =>
      'Para revisar verificaciones tenés que confirmar tu segundo factor en esta sesión. Si todavía no lo configuraste, lo hacés en el mismo paso, sin cerrar sesión.';

  @override
  String get adminVerificationsMfaAction => 'Verificar segundo factor';

  @override
  String get mfaTitle => 'Segundo factor';

  @override
  String get mfaPreparing => 'Preparando el segundo factor…';

  @override
  String get mfaEnrollTitle => 'Configurá tu autenticador';

  @override
  String get mfaEnrollIntro =>
      'Escaneá el código QR con una app de autenticación (por ejemplo Google Authenticator, Microsoft Authenticator o Aegis). Si no podés escanearlo, cargá la clave manual que sigue.';

  @override
  String get mfaEnrollPendingNote =>
      'El segundo factor queda activo recién cuando ingresás un código válido. Si salís antes, no queda configurado.';

  @override
  String get mfaLimitsNote =>
      'Guardá bien el acceso a tu app de autenticación: esta versión no permite recuperar, dar de baja ni reemplazar el autenticador desde la app.';

  @override
  String get mfaQrSemantics =>
      'Código QR para registrar TalentFlash en tu app de autenticación. Si no podés escanearlo, usá la clave manual que sigue.';

  @override
  String get mfaManualKeyLabel => 'Clave manual';

  @override
  String get mfaManualKeyHelp =>
      'Cargala en tu app como clave de tiempo (TOTP), sin espacios.';

  @override
  String mfaManualKeySemantics(String clave) {
    return 'Clave manual, carácter por carácter: $clave';
  }

  @override
  String get mfaCodeLabel => 'Código de 6 dígitos';

  @override
  String get mfaCodeHelp =>
      'Es el código que muestra tu app ahora; cambia cada 30 segundos.';

  @override
  String get mfaCodeRequired => 'Ingresá el código de tu app.';

  @override
  String get mfaCodeFormat => 'El código tiene 6 dígitos.';

  @override
  String get mfaSubmitEnroll => 'Activar segundo factor';

  @override
  String get mfaSubmitVerify => 'Verificar';

  @override
  String get mfaCancel => 'Cancelar y volver';

  @override
  String get mfaBackToQueue => 'Volver a la cola';

  @override
  String get mfaChallengeTitle => 'Confirmá tu segundo factor';

  @override
  String mfaChallengeIntro(String nombre) {
    return 'Ingresá el código que muestra tu app de autenticación para $nombre.';
  }

  @override
  String get mfaChooseTitle => '¿Qué autenticador vas a usar?';

  @override
  String get mfaChooseIntro =>
      'Tu cuenta tiene más de un autenticador registrado. Elegí con cuál vas a verificar esta sesión.';

  @override
  String get mfaChooseAnother => 'Usar otro autenticador';

  @override
  String get mfaFactorUnnamed => 'Autenticador sin nombre';

  @override
  String mfaFactorUnnamedCreated(String fecha) {
    return 'Autenticador sin nombre, registrado el $fecha';
  }

  @override
  String mfaFriendlyName(String fecha) {
    return 'TalentFlash · $fecha';
  }

  @override
  String get mfaVerified =>
      'Segundo factor verificado. Ya podés revisar la cola.';

  @override
  String get mfaAlreadyVerified =>
      'Tu sesión ya tiene el segundo factor verificado.';

  @override
  String get mfaErrorTitle => 'No pudimos verificar el código';

  @override
  String get mfaUnavailableTitle => 'No pudimos preparar el segundo factor';

  @override
  String get mfaFailureInvalidCode =>
      'El código no es válido. Fijate que sea el actual de tu app y probá de nuevo.';

  @override
  String get mfaFailureChallengeExpired =>
      'Se venció el tiempo para ingresar el código. Probá de nuevo con el código actual de tu app.';

  @override
  String get mfaFailureFactorNotFound =>
      'No encontramos ese autenticador. Volvé a la cola y empezá de nuevo.';

  @override
  String get mfaFailureNameConflict =>
      'Quedó un alta anterior sin terminar con ese nombre. Reintentá para generar una nueva.';

  @override
  String get mfaFailureTooManyFactors =>
      'Tu cuenta llegó al máximo de autenticadores registrados.';

  @override
  String get mfaFailureInsufficientAssurance =>
      'Para hacer esto primero tenés que verificar el autenticador que ya tenés.';

  @override
  String get mfaFailureNotEnabled =>
      'El segundo factor no está habilitado en este entorno.';

  @override
  String get mfaFailureRejected =>
      'La verificación fue rechazada. Probá de nuevo con el código actual de tu app.';

  @override
  String get adminVerificationsEmpty => 'No hay solicitudes en este estado.';

  @override
  String get adminVerificationsErrorTitle => 'No pudimos completar la acción';

  @override
  String get adminVerificationsResolved => 'Solicitud resuelta.';

  @override
  String adminVerificationsCuit(String cuit) {
    return 'CUIT declarado: $cuit';
  }

  @override
  String get adminVerificationsWithDocument => 'Adjuntó constancia de ARCA.';

  @override
  String get adminVerificationsNoDocument => 'Sin constancia adjunta.';

  @override
  String adminVerificationsReason(String motivo) {
    return 'Motivo del rechazo: $motivo';
  }

  @override
  String get adminVerificationsReasonTitle => '¿Por qué se rechaza?';

  @override
  String get adminVerificationsApprove => 'Aprobar';

  @override
  String get adminVerificationsReject => 'Rechazar';

  @override
  String get adminVerificationsOpenDocument => 'Ver la constancia';

  @override
  String get adminVerificationsDocumentTitle => 'Constancia de ARCA';

  @override
  String get adminVerificationsDocumentHelp =>
      'Copiá este enlace y abrilo en el navegador. Vence en 5 minutos: si expira, volvé a pedirlo desde acá.';

  @override
  String get adminVerificationsDocumentError =>
      'No pudimos generar el enlace a la constancia. Reintentá en unos minutos.';

  @override
  String get adminVerificationsDocumentClose => 'Cerrar';
}
