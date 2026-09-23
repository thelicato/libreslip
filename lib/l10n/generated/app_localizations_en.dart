// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'LibreSlip';

  @override
  String get overview => 'Overview';

  @override
  String get compose => 'Compose';

  @override
  String get items => 'Items';

  @override
  String get tickets => 'Tickets';

  @override
  String get settings => 'Settings';

  @override
  String get onThisPhone => 'On this phone';

  @override
  String get yourWorkspace => 'YOUR WORKSPACE';

  @override
  String get defaultHeading => 'Your workspace';

  @override
  String get overviewSubtitle => 'A little order for your working day.';

  @override
  String get heroEyebrow => 'A LITTLE SLIP. A CLEARER DAY.';

  @override
  String get heroTitle => 'Every order.\nClearly on paper.';

  @override
  String get heroBody =>
      'A quiet space for your orders, right here on your phone. Make it feel like yours.';

  @override
  String get personaliseWorkspace => 'Personalise your workspace';

  @override
  String get workspaceTitle => 'From a thought to a ticket';

  @override
  String get workspaceSubtitle => 'A place for each step of your order.';

  @override
  String get composeCardBody => 'Items, quantities and the little details.';

  @override
  String get itemsCardBody => 'Your frequently used items, together.';

  @override
  String get ticketsCardBody => 'Your orders, neatly kept in one place.';

  @override
  String get previewLabel => 'Workspace preview';

  @override
  String get localTitle => 'Yours stays yours.';

  @override
  String get localBody =>
      'Your preferences stay on this phone. No account. No cloud. No fuss.';

  @override
  String get ticketHeader => 'Ticket heading';

  @override
  String get ticketHeaderBody => 'Choose a name to make your workspace yours.';

  @override
  String get heading => 'Heading';

  @override
  String get headingHint => 'For example, Corner & Co.';

  @override
  String get editHeading => 'Edit ticket heading';

  @override
  String get nameRequired => 'Enter a heading.';

  @override
  String get nameTooLong => 'Use 60 characters or fewer.';

  @override
  String get save => 'Save changes';

  @override
  String get cancel => 'Cancel';

  @override
  String get settingsSubtitle => 'Small details. A space that feels yours.';

  @override
  String get language => 'Language';

  @override
  String get languageBody => 'Choose the language you feel at home in.';

  @override
  String get english => 'English (UK)';

  @override
  String get italian => 'Italiano';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceBody => 'Set the mood, or follow your phone.';

  @override
  String get systemTheme => 'System';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get savedLocally => 'Saved on this phone';

  @override
  String get saving => 'Saving your preferences...';

  @override
  String get saveError =>
      'Your changes could not be saved. Your previous preferences are still in place. Please try again.';

  @override
  String get loadErrorTitle => 'Your workspace needs a moment';

  @override
  String get loadErrorBody =>
      'We could not read your preferences. Nothing has been overwritten. Try opening your workspace again.';

  @override
  String get retry => 'Try again';

  @override
  String get loading => 'Opening your workspace';

  @override
  String get composeTitle => 'A place for every detail.';

  @override
  String get composeBody =>
      'Build orders with items, quantities and notes. Ticket creation and printing will be available in a future update.';

  @override
  String get itemsTitle => 'Your favourites, close to hand.';

  @override
  String get itemsBody =>
      'Keep reusable items ready for your next order. Adding items, categories and photos will be available in a future update.';

  @override
  String get ticketsTitle => 'Every order has a story.';

  @override
  String get ticketsBody =>
      'Your saved tickets will live here. Order history, duplicates and reprints will be available in a future update.';

  @override
  String get backOverview => 'Back to overview';

  @override
  String get localOnly => 'LOCAL BY DEFAULT';

  @override
  String get privacyTitle => 'No sign-in. Just your workspace.';

  @override
  String get privacyBody =>
      'These settings work without an internet connection. Automatic cloud backup is switched off.';
}

/// The translations for English, as used in the United Kingdom (`en_GB`).
class AppLocalizationsEnGb extends AppLocalizationsEn {
  AppLocalizationsEnGb() : super('en_GB');
}
