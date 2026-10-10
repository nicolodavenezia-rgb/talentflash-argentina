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
      'Desde acá entrás a las ofertas publicadas, siempre con el sueldo a la vista, y a tu perfil. El orden por zona y compatibilidad llega en el Bloque G del ROADMAP.';

  @override
  String get companyHomeTitle => 'Inicio — Empresa';

  @override
  String get companyHomePlaceholder =>
      'Desde acá gestionás tus ofertas y la verificación de tu empresa. Los candidatos llegan en el Bloque G y las postulaciones en el Bloque H del ROADMAP.';

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
  String get dataFailureJobStateConflict =>
      'La oferta cambió de estado mientras la tenías abierta. Ya te mostramos cómo quedó: revisala y volvé a intentarlo.';

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
      'Para revisar verificaciones hay que iniciar sesión con segundo factor. Cerrá sesión, activá el segundo factor y volvé a entrar.';

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

  @override
  String get jobsCompanyTitle => 'Mis ofertas';

  @override
  String get jobsFeedTitle => 'Ofertas de trabajo';

  @override
  String get jobsNewOffer => 'Nueva oferta';

  @override
  String get jobsEmptyTitle => 'Todavía no creaste ofertas';

  @override
  String get jobsEmptyBody =>
      'Cuando crees una, la vas a ver acá con su estado.';

  @override
  String get jobsEmptyReadOnlyBody =>
      'Cuando tu empresa cree ofertas, las vas a ver acá.';

  @override
  String get jobsEmptyAction => 'Crear mi primera oferta';

  @override
  String get jobsLoadErrorTitle => 'No pudimos cargar tus ofertas';

  @override
  String get jobsListStale =>
      'La lista no se actualizó y puede no estar al día: tocá \"Actualizar\" arriba para reintentar.';

  @override
  String get jobsCompanyRefresh => 'Actualizar';

  @override
  String get jobsCompanyRefreshStale =>
      'Actualizar: la lista puede no estar al día';

  @override
  String get jobsCompanyRefreshing => 'Actualizando tus ofertas';

  @override
  String get jobsErrorTitle => 'No pudimos completar la acción';

  @override
  String get jobsUnverifiedBanner =>
      'Tu empresa todavía no está verificada. Podés preparar ofertas y guardarlas como borrador; vas a poder publicarlas cuando la verifiquemos.';

  @override
  String get jobsGoToVerification => 'Ir a la verificación';

  @override
  String get jobsReadOnlyBanner =>
      'Tu rol en la empresa te deja ver las ofertas, pero no crearlas ni modificarlas. Si lo necesitás, pedíselo a quien administra la cuenta de la empresa.';

  @override
  String get jobsPermissionsError =>
      'No pudimos comprobar si tu cuenta puede gestionar ofertas, así que por ahora no te mostramos esas acciones.';

  @override
  String get jobsFailureNotAllowed =>
      'Tu cuenta no puede hacer esta acción. Para publicar, tu empresa tiene que estar verificada y tu rol tiene que permitir gestionar ofertas.';

  @override
  String get jobsFailureInvalidData =>
      'No pudimos guardar: hay datos que no cumplen las reglas de la oferta. Revisá los campos y probá de nuevo.';

  @override
  String get jobsFailurePublishRules =>
      'Para publicarla, el sueldo mínimo tiene que ser mayor que 0, el vencimiento tiene que estar dentro de los próximos 60 días y, si la localidad tiene barrios, hay que elegir uno. Editala para corregirlo.';

  @override
  String get jobsPublishNeedsVerification =>
      'Para publicar, tu empresa tiene que estar verificada.';

  @override
  String get jobStatusDraft => 'Borrador';

  @override
  String get jobStatusActive => 'Activa';

  @override
  String get jobStatusPaused => 'Pausada';

  @override
  String get jobStatusExpired => 'Vencida';

  @override
  String get jobStatusClosed => 'Cerrada';

  @override
  String get jobStatusUnknown => 'Estado desconocido';

  @override
  String jobStatusSemantics(String status) {
    return 'Estado: $status';
  }

  @override
  String jobExpiresOn(String date) {
    return 'Vence el $date';
  }

  @override
  String jobExpiredOn(String date) {
    return 'Venció el $date: ya no se muestra a los candidatos.';
  }

  @override
  String jobExpiredOnShort(String date) {
    return 'Venció el $date';
  }

  @override
  String get jobPlaceUnavailable =>
      'No pudimos cargar el nombre de la ubicación.';

  @override
  String get jobPublishBlockedUnverified =>
      'Vas a poder publicar cuando verifiquemos tu empresa. Mientras tanto, guardá la oferta como borrador.';

  @override
  String get jobActionEdit => 'Editar';

  @override
  String get jobActionPublish => 'Publicar';

  @override
  String get jobActionPause => 'Pausar';

  @override
  String get jobActionResume => 'Reanudar';

  @override
  String get jobActionClose => 'Cerrar';

  @override
  String get jobActionDiscard => 'Descartar borrador';

  @override
  String get jobActionDuplicate => 'Duplicar';

  @override
  String jobActionSemantics(String action, String title) {
    return '$action: $title';
  }

  @override
  String get jobDialogCancel => 'Cancelar';

  @override
  String get jobCloseDialogTitle => '¿Cerrar la oferta?';

  @override
  String get jobCloseDialogBody =>
      'La oferta deja de verse para los candidatos y no se puede volver a abrir. Si más adelante necesitás publicarla de nuevo, podés duplicarla.';

  @override
  String get jobCloseDialogConfirm => 'Cerrar oferta';

  @override
  String get jobDiscardDialogTitle => '¿Descartar el borrador?';

  @override
  String get jobDiscardDialogBody =>
      'El borrador se quita de tu lista y no se puede recuperar.';

  @override
  String get jobDiscardDialogConfirm => 'Descartar';

  @override
  String get jobOutcomePublished => 'Oferta publicada.';

  @override
  String get jobOutcomePaused => 'Oferta pausada: los candidatos ya no la ven.';

  @override
  String get jobOutcomeResumed => 'Oferta reanudada.';

  @override
  String get jobOutcomeClosed => 'Oferta cerrada.';

  @override
  String get jobOutcomeDiscarded => 'Borrador descartado.';

  @override
  String get jobOutcomeDraftSaved => 'Borrador guardado.';

  @override
  String get jobOutcomeChangesSaved => 'Cambios guardados.';

  @override
  String get jobFormNewTitle => 'Nueva oferta';

  @override
  String get jobFormEditTitle => 'Editar oferta';

  @override
  String get jobFormIntro =>
      'Todos los campos son obligatorios salvo los que dicen \"opcional\", también para guardar un borrador. Para publicar, además, el sueldo mínimo tiene que ser mayor que 0, el vencimiento tiene que estar dentro de los próximos 60 días y, si la localidad tiene barrios, hay que elegir uno.';

  @override
  String jobFormDuplicateNote(String title) {
    return 'Copiamos el contenido de \"$title\". Elegí una fecha de vencimiento nueva antes de guardar.';
  }

  @override
  String get jobFormErrorsTitle => 'Revisá los campos marcados';

  @override
  String get jobFormErrorsBody =>
      'Hay datos que faltan o que no son válidos. Cada campo explica qué corregir.';

  @override
  String get jobSectionPosition => 'Puesto y descripción';

  @override
  String get jobSectionSalary => 'Sueldo';

  @override
  String get jobSectionContract => 'Contrato y jornada';

  @override
  String get jobSectionSchedule => 'Días y horario';

  @override
  String get jobSectionWorkMode => 'Modalidad';

  @override
  String get jobSectionLocation => 'Ubicación';

  @override
  String get jobSectionSector => 'Sector';

  @override
  String get jobSectionExperience => 'Experiencia';

  @override
  String get jobSectionAvailability => 'Disponibilidad';

  @override
  String get jobSectionBenefits => 'Beneficios';

  @override
  String get jobSectionVacancies => 'Vacantes';

  @override
  String get jobSectionExpiry => 'Vencimiento';

  @override
  String get jobSectionDescription => 'Descripción y requisitos';

  @override
  String get jobSectionMore => 'Más datos';

  @override
  String get jobTitleLabel => 'Puesto';

  @override
  String get jobTitleHint => 'Por ejemplo: Mozo/a de salón';

  @override
  String get jobDescriptionLabel => 'Descripción y requisitos';

  @override
  String get jobDescriptionHelp =>
      'Contá las tareas y todo lo que pedís para el puesto: experiencia, conocimientos, documentación u otros requisitos.';

  @override
  String get jobSalaryMinLabel => 'Sueldo mínimo';

  @override
  String get jobSalaryMaxLabel => 'Sueldo máximo';

  @override
  String get jobSalaryHelp =>
      'En pesos argentinos y sin centavos. Para un sueldo fijo, poné el mismo monto en los dos campos. El sueldo siempre se muestra en la oferta.';

  @override
  String get jobSalaryPeriodLabel => 'Período del sueldo';

  @override
  String get jobSalaryPeriodMonthly => 'Mensual';

  @override
  String get jobSalaryPeriodYearly => 'Anual';

  @override
  String get jobSalaryPeriodHourly => 'Por hora';

  @override
  String get jobSalaryPerMonth => 'por mes';

  @override
  String get jobSalaryPerYear => 'por año';

  @override
  String get jobSalaryPerHour => 'por hora';

  @override
  String jobSalaryRange(String min, String max) {
    return 'ARS $min a $max';
  }

  @override
  String jobSalarySingle(String amount) {
    return 'ARS $amount';
  }

  @override
  String jobSalaryWithPeriod(String amount, String period) {
    return '$amount $period';
  }

  @override
  String get jobContractTypeLabel => 'Modalidad de contratación';

  @override
  String get jobContractRelacionDependencia => 'Relación de dependencia';

  @override
  String get jobContractMonotributo => 'Monotributo';

  @override
  String get jobContractPlazoFijo => 'Plazo fijo';

  @override
  String get jobContractTemporal => 'Temporal';

  @override
  String get jobContractPasantia => 'Pasantía';

  @override
  String get jobContractFreelance => 'Freelance';

  @override
  String get jobJornadaLabel => 'Jornada';

  @override
  String get jobJornadaFullTime => 'Jornada completa';

  @override
  String get jobJornadaPartTime => 'Jornada parcial';

  @override
  String get jobJornadaPorTurnos => 'Por turnos';

  @override
  String get jobJornadaFinDeSemana => 'Fines de semana';

  @override
  String get jobJornadaPorHoras => 'Por horas';

  @override
  String get jobScheduleDaysLabel => 'Días de trabajo';

  @override
  String get jobScheduleDetailLabel => 'Horario';

  @override
  String get jobScheduleDetailHint =>
      'Por ejemplo: 9 a 18 hs, viernes hasta las 15';

  @override
  String get jobWorkModeLabel => 'Modalidad de trabajo';

  @override
  String get jobNeighborhoodHelp =>
      'Obligatorio para publicar en esta localidad.';

  @override
  String get jobSectorLabel => 'Sector o rubro (opcional)';

  @override
  String get jobSectorNone => 'Sin especificar';

  @override
  String get jobSectorUnavailable =>
      'El sector que tenía la oferta ya no está disponible. Elegí otro o dejalo sin especificar.';

  @override
  String get jobExperienceLabel => 'Experiencia requerida';

  @override
  String get jobAvailabilityLabel => 'Disponibilidad requerida';

  @override
  String get jobBenefitAddLabel => 'Agregar beneficio';

  @override
  String jobBenefitsHelp(int maxItems, int maxLength) {
    return 'Opcional. Hasta $maxItems beneficios de hasta $maxLength caracteres cada uno; por ejemplo, comida incluida o propinas.';
  }

  @override
  String jobBenefitsCount(int count, int max) {
    return '$count de $max beneficios';
  }

  @override
  String get jobBenefitsNone => 'No se informaron beneficios.';

  @override
  String get jobVacanciesLabel => 'Cantidad de vacantes';

  @override
  String jobVacanciesHelp(int min, int max) {
    return 'Entre $min y $max.';
  }

  @override
  String jobVacanciesValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vacantes',
      one: '1 vacante',
    );
    return '$_temp0';
  }

  @override
  String get jobExpiryLabel => 'Fecha de vencimiento';

  @override
  String get jobExpiryHint => 'Elegí una fecha';

  @override
  String jobExpiryHelp(int days) {
    return 'Para publicar, hasta $days días desde hoy. Ese día la oferta deja de mostrarse.';
  }

  @override
  String get jobExpiryPick => 'Elegir la fecha de vencimiento';

  @override
  String get jobSaveDraft => 'Guardar borrador';

  @override
  String get jobPublish => 'Publicar';

  @override
  String get jobSaveChanges => 'Guardar cambios';

  @override
  String get jobPreview => 'Vista previa';

  @override
  String get jobPreviewNote => 'Así va a ver la oferta un candidato.';

  @override
  String get jobPreviewCompanyName => 'Tu empresa';

  @override
  String get jobEditActiveNeedsVerification =>
      'Para modificar una oferta publicada, tu empresa tiene que estar verificada. Desde Mis ofertas podés pausarla o cerrarla.';

  @override
  String get jobLeaveTitle => '¿Salir sin guardar?';

  @override
  String get jobLeaveBody =>
      'Tenés cambios sin guardar en la oferta. Si salís ahora, se pierden.';

  @override
  String get jobLeaveConfirm => 'Salir sin guardar';

  @override
  String get jobLeaveCancel => 'Seguir editando';

  @override
  String get jobNotFoundTitle => 'No encontramos esa oferta';

  @override
  String get jobNotFoundBody =>
      'Puede haber sido descartada o el enlace ya no es válido.';

  @override
  String get jobLoadError =>
      'No pudimos cargar la oferta. Revisá tu conexión y reintentá.';

  @override
  String get jobBackToList => 'Volver a Mis ofertas';

  @override
  String get jobNotEditableTitle => 'Esta oferta ya no se puede editar';

  @override
  String get jobNotEditableBody =>
      'Una oferta vencida o cerrada queda como historial. Si querés volver a publicarla, duplicala y elegí una fecha nueva.';

  @override
  String get jobErrorTextEmpty => 'Completá este campo.';

  @override
  String jobErrorTextTooLong(int max) {
    return 'Admite hasta $max caracteres.';
  }

  @override
  String get jobErrorDaysEmpty => 'Elegí al menos un día.';

  @override
  String get jobErrorDaysDuplicated => 'Hay días repetidos.';

  @override
  String get jobErrorSalaryMissing => 'Ingresá el monto.';

  @override
  String get jobErrorSalaryFormat =>
      'Ingresá solo números, en pesos y sin centavos (por ejemplo, 350000 o 350.000).';

  @override
  String get jobErrorSalaryNegative => 'El monto no puede ser negativo.';

  @override
  String jobErrorSalaryTooHigh(String max) {
    return 'El monto no puede superar $max.';
  }

  @override
  String get jobErrorSalaryNotPositive =>
      'Para publicar, el sueldo mínimo tiene que ser mayor que 0.';

  @override
  String get jobErrorSalaryBelowMin =>
      'El máximo no puede ser menor que el mínimo.';

  @override
  String get jobErrorBenefitEmpty => 'Escribí el beneficio antes de agregarlo.';

  @override
  String jobErrorBenefitTooLong(int max) {
    return 'Cada beneficio admite hasta $max caracteres.';
  }

  @override
  String get jobErrorBenefitDuplicated => 'Ese beneficio ya está en la lista.';

  @override
  String jobErrorBenefitTooMany(int max) {
    return 'Podés cargar hasta $max beneficios.';
  }

  @override
  String get jobErrorVacanciesMissing => 'Ingresá la cantidad de vacantes.';

  @override
  String jobErrorVacanciesOutOfRange(int min, int max) {
    return 'Tiene que ser un número entero entre $min y $max.';
  }

  @override
  String get jobErrorExpiryMissing => 'Elegí la fecha de vencimiento.';

  @override
  String get jobErrorExpiryNotInFuture =>
      'Para publicar, el vencimiento tiene que ser posterior a hoy.';

  @override
  String jobErrorExpiryBeyondWindow(int days) {
    return 'Para publicar, el vencimiento puede estar como máximo a $days días de hoy.';
  }

  @override
  String get jobErrorNeighborhoodRequired =>
      'Elegí el barrio: es obligatorio para publicar en esta localidad.';

  @override
  String get jobValueMissing => 'Sin completar';

  @override
  String get jobCompanyUnknown => 'Empresa sin nombre disponible';

  @override
  String get jobsFeedEmpty => 'Todavía no hay ofertas publicadas.';

  @override
  String get jobsFeedEmptyHint =>
      'Volvé a mirar en un rato: las ofertas nuevas aparecen primero.';

  @override
  String get jobsFeedRefresh => 'Actualizar';

  @override
  String get jobsFeedRefreshing => 'Actualizando ofertas';

  @override
  String jobsFeedRefreshFailed(String motivo) {
    return 'Las ofertas no se actualizaron. $motivo';
  }

  @override
  String get jobsFeedUpToDate => 'Las ofertas ya están al día.';

  @override
  String get jobsFeedLoadErrorTitle => 'No pudimos cargar las ofertas';

  @override
  String get jobsFeedLoadMore => 'Cargar más ofertas';

  @override
  String get jobsFeedLoadingMore => 'Cargando más ofertas';

  @override
  String get jobsFeedEnd => 'No hay más ofertas por ahora.';

  @override
  String jobsFeedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrando $count ofertas',
      one: 'Mostrando 1 oferta',
    );
    return '$_temp0';
  }

  @override
  String get jobCardOpenHint => 'ver el detalle de la oferta';

  @override
  String get jobDetailTitle => 'Detalle de la oferta';

  @override
  String get jobNotAvailableTitle => 'Esta oferta no está disponible';

  @override
  String get jobNotAvailableBody =>
      'Puede haber vencido, estar pausada o el enlace ya no es válido.';

  @override
  String get jobBackToFeed => 'Volver a las ofertas';

  @override
  String get jobApplyComingSoon =>
      'Todavía no podés postularte desde la app: esa función llega en una próxima etapa.';
}
