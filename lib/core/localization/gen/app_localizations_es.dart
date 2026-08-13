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
      'Entrar como candidato: crear tu perfil y buscar trabajo';

  @override
  String get roleCompanyTitle => 'Soy empresa';

  @override
  String get roleCompanySubtitle => 'Quiero contratar personal';

  @override
  String get roleCompanySemantics =>
      'Entrar como empresa: publicar ofertas y descubrir candidatos';

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
  String get backToRoleSelection => 'Volver a elegir cómo usar TalentFlash';
}
