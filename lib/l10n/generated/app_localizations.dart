import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en', 'GB'),
    Locale('it', 'IT'),
    Locale('en'),
    Locale('it'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'LibreSlip'**
  String get appName;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @compose.
  ///
  /// In en, this message translates to:
  /// **'Compose'**
  String get compose;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get items;

  /// No description provided for @tickets.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get tickets;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @onThisPhone.
  ///
  /// In en, this message translates to:
  /// **'On this phone'**
  String get onThisPhone;

  /// No description provided for @yourWorkspace.
  ///
  /// In en, this message translates to:
  /// **'YOUR WORKSPACE'**
  String get yourWorkspace;

  /// No description provided for @defaultHeading.
  ///
  /// In en, this message translates to:
  /// **'Your workspace'**
  String get defaultHeading;

  /// No description provided for @overviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A little order for your working day.'**
  String get overviewSubtitle;

  /// No description provided for @heroEyebrow.
  ///
  /// In en, this message translates to:
  /// **'A LITTLE SLIP. A CLEARER DAY.'**
  String get heroEyebrow;

  /// No description provided for @heroTitle.
  ///
  /// In en, this message translates to:
  /// **'Every order.\nClearly on paper.'**
  String get heroTitle;

  /// No description provided for @heroBody.
  ///
  /// In en, this message translates to:
  /// **'A quiet space for your orders, right here on your phone. Make it feel like yours.'**
  String get heroBody;

  /// No description provided for @personaliseWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Personalise your workspace'**
  String get personaliseWorkspace;

  /// No description provided for @workspaceTitle.
  ///
  /// In en, this message translates to:
  /// **'From a thought to a ticket'**
  String get workspaceTitle;

  /// No description provided for @workspaceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A place for each step of your order.'**
  String get workspaceSubtitle;

  /// No description provided for @composeCardBody.
  ///
  /// In en, this message translates to:
  /// **'Items, quantities and the little details.'**
  String get composeCardBody;

  /// No description provided for @itemsCardBody.
  ///
  /// In en, this message translates to:
  /// **'Your frequently used items, together.'**
  String get itemsCardBody;

  /// No description provided for @ticketsCardBody.
  ///
  /// In en, this message translates to:
  /// **'Your orders, neatly kept in one place.'**
  String get ticketsCardBody;

  /// No description provided for @previewLabel.
  ///
  /// In en, this message translates to:
  /// **'Workspace preview'**
  String get previewLabel;

  /// No description provided for @localTitle.
  ///
  /// In en, this message translates to:
  /// **'Yours stays yours.'**
  String get localTitle;

  /// No description provided for @localBody.
  ///
  /// In en, this message translates to:
  /// **'Your preferences stay on this phone. No account. No cloud. No fuss.'**
  String get localBody;

  /// No description provided for @ticketHeader.
  ///
  /// In en, this message translates to:
  /// **'Ticket heading'**
  String get ticketHeader;

  /// No description provided for @ticketHeaderBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a name to make your workspace yours.'**
  String get ticketHeaderBody;

  /// No description provided for @heading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get heading;

  /// No description provided for @headingHint.
  ///
  /// In en, this message translates to:
  /// **'For example, Corner & Co.'**
  String get headingHint;

  /// No description provided for @editHeading.
  ///
  /// In en, this message translates to:
  /// **'Edit ticket heading'**
  String get editHeading;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a heading.'**
  String get nameRequired;

  /// No description provided for @nameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use 60 characters or fewer.'**
  String get nameTooLong;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Small details. A space that feels yours.'**
  String get settingsSubtitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageBody.
  ///
  /// In en, this message translates to:
  /// **'Choose the language you feel at home in.'**
  String get languageBody;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English (UK)'**
  String get english;

  /// No description provided for @italian.
  ///
  /// In en, this message translates to:
  /// **'Italiano'**
  String get italian;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @appearanceBody.
  ///
  /// In en, this message translates to:
  /// **'Set the mood, or follow your phone.'**
  String get appearanceBody;

  /// No description provided for @systemTheme.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemTheme;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// No description provided for @savedLocally.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone'**
  String get savedLocally;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving your preferences...'**
  String get saving;

  /// No description provided for @saveError.
  ///
  /// In en, this message translates to:
  /// **'Your changes could not be saved. Your previous preferences are still in place. Please try again.'**
  String get saveError;

  /// No description provided for @loadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Your workspace needs a moment'**
  String get loadErrorTitle;

  /// No description provided for @loadErrorBody.
  ///
  /// In en, this message translates to:
  /// **'We could not read your preferences. Nothing has been overwritten. Try opening your workspace again.'**
  String get loadErrorBody;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Opening your workspace'**
  String get loading;

  /// No description provided for @composeTitle.
  ///
  /// In en, this message translates to:
  /// **'A place for every detail.'**
  String get composeTitle;

  /// No description provided for @composeBody.
  ///
  /// In en, this message translates to:
  /// **'Build orders with items, quantities and notes. Ticket creation and printing will be available in a future update.'**
  String get composeBody;

  /// No description provided for @itemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your favourites, close to hand.'**
  String get itemsTitle;

  /// No description provided for @itemsBody.
  ///
  /// In en, this message translates to:
  /// **'Keep reusable items ready for your next order. Adding items, categories and photos will be available in a future update.'**
  String get itemsBody;

  /// No description provided for @ticketsTitle.
  ///
  /// In en, this message translates to:
  /// **'Every order has a story.'**
  String get ticketsTitle;

  /// No description provided for @ticketsBody.
  ///
  /// In en, this message translates to:
  /// **'Your saved tickets will live here. Order history, duplicates and reprints will be available in a future update.'**
  String get ticketsBody;

  /// No description provided for @backOverview.
  ///
  /// In en, this message translates to:
  /// **'Back to overview'**
  String get backOverview;

  /// No description provided for @localOnly.
  ///
  /// In en, this message translates to:
  /// **'LOCAL BY DEFAULT'**
  String get localOnly;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'No sign-in. Just your workspace.'**
  String get privacyTitle;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'These settings work without an internet connection. Automatic cloud backup is switched off.'**
  String get privacyBody;
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
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'en':
      {
        switch (locale.countryCode) {
          case 'GB':
            return AppLocalizationsEnGb();
        }
        break;
      }
    case 'it':
      {
        switch (locale.countryCode) {
          case 'IT':
            return AppLocalizationsItIt();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
