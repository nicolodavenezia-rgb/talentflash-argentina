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
  /// **'Entrar como candidato: crear tu perfil y buscar trabajo'**
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
  /// **'Entrar como empresa: publicar ofertas y descubrir candidatos'**
  String get roleCompanySemantics;

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

  /// Tooltip/semántica del botón volver en las pantallas placeholder
  ///
  /// In es, this message translates to:
  /// **'Volver a elegir cómo usar TalentFlash'**
  String get backToRoleSelection;
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
