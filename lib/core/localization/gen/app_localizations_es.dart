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
}
