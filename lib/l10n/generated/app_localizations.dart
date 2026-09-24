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

  /// No description provided for @addItems.
  ///
  /// In en, this message translates to:
  /// **'Add items'**
  String get addItems;

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

  /// No description provided for @printerOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Printer'**
  String get printerOverviewTitle;

  /// No description provided for @printerOverviewBody.
  ///
  /// In en, this message translates to:
  /// **'Current LibreSlip Bluetooth connection.'**
  String get printerOverviewBody;

  /// No description provided for @printerConnectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get printerConnectedStatus;

  /// No description provided for @printerDisconnectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get printerDisconnectedStatus;

  /// No description provided for @printerPermissionStatus.
  ///
  /// In en, this message translates to:
  /// **'Permission required'**
  String get printerPermissionStatus;

  /// No description provided for @printerBluetoothOffStatus.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is off'**
  String get printerBluetoothOffStatus;

  /// No description provided for @printerUnavailableStatus.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get printerUnavailableStatus;

  /// No description provided for @printerConnectedDevice.
  ///
  /// In en, this message translates to:
  /// **'Connected to {name}'**
  String printerConnectedDevice(String name);

  /// No description provided for @printerBattery.
  ///
  /// In en, this message translates to:
  /// **'Printer battery'**
  String get printerBattery;

  /// No description provided for @printerBatteryPercentage.
  ///
  /// In en, this message translates to:
  /// **'{percentage}%'**
  String printerBatteryPercentage(int percentage);

  /// No description provided for @printerBatteryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not reported by this printer. Check its battery indicator.'**
  String get printerBatteryUnavailable;

  /// No description provided for @managePrinter.
  ///
  /// In en, this message translates to:
  /// **'Manage printer'**
  String get managePrinter;

  /// No description provided for @refreshPrinterStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get refreshPrinterStatus;

  /// No description provided for @statisticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Ticket activity'**
  String get statisticsTitle;

  /// No description provided for @statisticsBody.
  ///
  /// In en, this message translates to:
  /// **'Counts saved tickets by creation date. No prices or sales are recorded.'**
  String get statisticsBody;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get endDate;

  /// No description provided for @noDateLimit.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get noDateLimit;

  /// No description provided for @clearDateFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear dates'**
  String get clearDateFilters;

  /// No description provided for @savedTicketsStat.
  ///
  /// In en, this message translates to:
  /// **'Saved tickets'**
  String get savedTicketsStat;

  /// No description provided for @ticketItemsStat.
  ///
  /// In en, this message translates to:
  /// **'Items on tickets'**
  String get ticketItemsStat;

  /// No description provided for @averageItemsStat.
  ///
  /// In en, this message translates to:
  /// **'Items per ticket'**
  String get averageItemsStat;

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
  /// **'Your reusable items, close to hand.'**
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
  /// **'Saved tickets and explicit print attempts stay together in your local history.'**
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

  /// No description provided for @composeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Build an order and keep every detail safe as you work.'**
  String get composeSubtitle;

  /// No description provided for @itemsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reusable items for faster ticket composition.'**
  String get itemsSubtitle;

  /// No description provided for @ticketsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Saved order snapshots, kept separately from printing.'**
  String get ticketsSubtitle;

  /// No description provided for @newDraft.
  ///
  /// In en, this message translates to:
  /// **'New draft'**
  String get newDraft;

  /// No description provided for @draft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draft;

  /// No description provided for @drafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get drafts;

  /// No description provided for @deleteDraft.
  ///
  /// In en, this message translates to:
  /// **'Delete draft'**
  String get deleteDraft;

  /// No description provided for @deleteDraftQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this draft?'**
  String get deleteDraftQuestion;

  /// No description provided for @deleteDraftBody.
  ///
  /// In en, this message translates to:
  /// **'Its items and notes will be removed from this phone.'**
  String get deleteDraftBody;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @searchItems.
  ///
  /// In en, this message translates to:
  /// **'Search items'**
  String get searchItems;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get allCategories;

  /// No description provided for @favourites.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get favourites;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get addItem;

  /// No description provided for @editItem.
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get editItem;

  /// No description provided for @itemName.
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get itemName;

  /// No description provided for @itemNameHint.
  ///
  /// In en, this message translates to:
  /// **'For example, Mushroom toastie'**
  String get itemNameHint;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @categoryHint.
  ///
  /// In en, this message translates to:
  /// **'For example, Kitchen'**
  String get categoryHint;

  /// No description provided for @favouriteItem.
  ///
  /// In en, this message translates to:
  /// **'Keep in favourites'**
  String get favouriteItem;

  /// No description provided for @favouriteItemBody.
  ///
  /// In en, this message translates to:
  /// **'Favourite items appear first when composing.'**
  String get favouriteItemBody;

  /// No description provided for @chooseImage.
  ///
  /// In en, this message translates to:
  /// **'Choose image'**
  String get chooseImage;

  /// No description provided for @changeImage.
  ///
  /// In en, this message translates to:
  /// **'Change image'**
  String get changeImage;

  /// No description provided for @removeImage.
  ///
  /// In en, this message translates to:
  /// **'Remove image'**
  String get removeImage;

  /// No description provided for @imagePickerError.
  ///
  /// In en, this message translates to:
  /// **'The image could not be added. Try another image.'**
  String get imagePickerError;

  /// No description provided for @itemRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an item name.'**
  String get itemRequired;

  /// No description provided for @itemNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use 80 characters or fewer.'**
  String get itemNameTooLong;

  /// No description provided for @categoryTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use 60 characters or fewer.'**
  String get categoryTooLong;

  /// No description provided for @duplicateItemError.
  ///
  /// In en, this message translates to:
  /// **'An active item already uses that name.'**
  String get duplicateItemError;

  /// No description provided for @emptyItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your item shelf is ready.'**
  String get emptyItemsTitle;

  /// No description provided for @emptyItemsBody.
  ///
  /// In en, this message translates to:
  /// **'Add reusable items to find them quickly while composing a ticket.'**
  String get emptyItemsBody;

  /// No description provided for @noItemsFound.
  ///
  /// In en, this message translates to:
  /// **'No items match this search.'**
  String get noItemsFound;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @removeItem.
  ///
  /// In en, this message translates to:
  /// **'Remove item'**
  String get removeItem;

  /// No description provided for @removeItemQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removeItemQuestion(String name);

  /// No description provided for @removeItemBody.
  ///
  /// In en, this message translates to:
  /// **'Saved tickets keep their original snapshot. This item will disappear from new searches.'**
  String get removeItemBody;

  /// No description provided for @addToDraft.
  ///
  /// In en, this message translates to:
  /// **'Add to draft'**
  String get addToDraft;

  /// No description provided for @adHocItem.
  ///
  /// In en, this message translates to:
  /// **'One-off item'**
  String get adHocItem;

  /// No description provided for @adHocItemBody.
  ///
  /// In en, this message translates to:
  /// **'Add an item to this draft without saving it to your reusable shelf.'**
  String get adHocItemBody;

  /// No description provided for @orderReference.
  ///
  /// In en, this message translates to:
  /// **'Table or order reference'**
  String get orderReference;

  /// No description provided for @orderReferenceHint.
  ///
  /// In en, this message translates to:
  /// **'Optional, for example Table 4'**
  String get orderReferenceHint;

  /// No description provided for @orderNotes.
  ///
  /// In en, this message translates to:
  /// **'Order notes'**
  String get orderNotes;

  /// No description provided for @orderFields.
  ///
  /// In en, this message translates to:
  /// **'Order fields'**
  String get orderFields;

  /// No description provided for @orderFieldsBody.
  ///
  /// In en, this message translates to:
  /// **'Choose which optional fields appear while composing a ticket.'**
  String get orderFieldsBody;

  /// No description provided for @preparationNotes.
  ///
  /// In en, this message translates to:
  /// **'Preparation notes'**
  String get preparationNotes;

  /// No description provided for @orderNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Optional notes for the whole order'**
  String get orderNotesHint;

  /// No description provided for @draftEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Start with an item.'**
  String get draftEmptyTitle;

  /// No description provided for @draftEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a reusable item. Your work is saved on this phone as you compose the ticket.'**
  String get draftEmptyBody;

  /// No description provided for @decreaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Decrease quantity'**
  String get decreaseQuantity;

  /// No description provided for @increaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Increase quantity'**
  String get increaseQuantity;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @preparationNote.
  ///
  /// In en, this message translates to:
  /// **'Preparation note'**
  String get preparationNote;

  /// No description provided for @preparationNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Optional, for example no onion'**
  String get preparationNoteHint;

  /// No description provided for @removeLine.
  ///
  /// In en, this message translates to:
  /// **'Remove line'**
  String get removeLine;

  /// No description provided for @saveTicket.
  ///
  /// In en, this message translates to:
  /// **'Print ticket'**
  String get saveTicket;

  /// No description provided for @ticketSaved.
  ///
  /// In en, this message translates to:
  /// **'Ticket saved to history.'**
  String get ticketSaved;

  /// No description provided for @ticketNeedsItem.
  ///
  /// In en, this message translates to:
  /// **'Add at least one item before printing.'**
  String get ticketNeedsItem;

  /// No description provided for @draftSaveError.
  ///
  /// In en, this message translates to:
  /// **'This draft could not be saved. Your latest details remain on screen. Try again.'**
  String get draftSaveError;

  /// No description provided for @storageErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Your order workspace needs a moment'**
  String get storageErrorTitle;

  /// No description provided for @storageErrorBody.
  ///
  /// In en, this message translates to:
  /// **'LibreSlip could not open its local order database. Nothing has been reset or overwritten.'**
  String get storageErrorBody;

  /// No description provided for @emptyTicketsTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved tickets yet.'**
  String get emptyTicketsTitle;

  /// No description provided for @emptyTicketsBody.
  ///
  /// In en, this message translates to:
  /// **'When you print a composed order, it is saved here before the print attempt begins.'**
  String get emptyTicketsBody;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @resetOrderNumberQuestion.
  ///
  /// In en, this message translates to:
  /// **'Reset order number?'**
  String get resetOrderNumberQuestion;

  /// No description provided for @resetOrderNumberBody.
  ///
  /// In en, this message translates to:
  /// **'The next order will use number 1. Saved tickets and their print attempts will not be changed.'**
  String get resetOrderNumberBody;

  /// No description provided for @orderNumberReset.
  ///
  /// In en, this message translates to:
  /// **'Order numbering restarted at 1.'**
  String get orderNumberReset;

  /// No description provided for @orderNumberResetFailed.
  ///
  /// In en, this message translates to:
  /// **'The order number could not be reset. Try again.'**
  String get orderNumberResetFailed;

  /// No description provided for @orderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order {number}'**
  String orderNumber(int number);

  /// No description provided for @ticketNumber.
  ///
  /// In en, this message translates to:
  /// **'Ticket {number}'**
  String ticketNumber(int number);

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items} =1{1 item} other{{count} items}}'**
  String itemCount(int count);

  /// No description provided for @viewTicket.
  ///
  /// In en, this message translates to:
  /// **'View ticket'**
  String get viewTicket;

  /// No description provided for @duplicateTicket.
  ///
  /// In en, this message translates to:
  /// **'Duplicate as draft'**
  String get duplicateTicket;

  /// No description provided for @duplicatedTicket.
  ///
  /// In en, this message translates to:
  /// **'A new editable draft was created from this snapshot.'**
  String get duplicatedTicket;

  /// No description provided for @ticketDetails.
  ///
  /// In en, this message translates to:
  /// **'Ticket details'**
  String get ticketDetails;

  /// No description provided for @savedHeading.
  ///
  /// In en, this message translates to:
  /// **'Saved heading'**
  String get savedHeading;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @savedSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Saved snapshot'**
  String get savedSnapshot;

  /// No description provided for @savedSnapshotBody.
  ///
  /// In en, this message translates to:
  /// **'Catalogue edits do not change this ticket.'**
  String get savedSnapshotBody;

  /// No description provided for @oneOff.
  ///
  /// In en, this message translates to:
  /// **'One-off'**
  String get oneOff;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @savingOrders.
  ///
  /// In en, this message translates to:
  /// **'Saving locally…'**
  String get savingOrders;

  /// No description provided for @referenceTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use 80 characters or fewer.'**
  String get referenceTooLong;

  /// No description provided for @noteTooLong.
  ///
  /// In en, this message translates to:
  /// **'This note is too long.'**
  String get noteTooLong;

  /// No description provided for @searchTickets.
  ///
  /// In en, this message translates to:
  /// **'Search tickets'**
  String get searchTickets;

  /// No description provided for @printerSetup.
  ///
  /// In en, this message translates to:
  /// **'Printer connection'**
  String get printerSetup;

  /// No description provided for @printerSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Connect a paired Bluetooth Classic printer. LibreSlip will never reconnect or resend by itself.'**
  String get printerSetupBody;

  /// No description provided for @bluetoothUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is not available on this phone.'**
  String get bluetoothUnsupported;

  /// No description provided for @bluetoothPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow nearby-device access'**
  String get bluetoothPermissionTitle;

  /// No description provided for @bluetoothPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Android requires this permission to see and connect to printers you have already paired.'**
  String get bluetoothPermissionBody;

  /// No description provided for @allowBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Allow access'**
  String get allowBluetooth;

  /// No description provided for @bluetoothOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is switched off'**
  String get bluetoothOffTitle;

  /// No description provided for @bluetoothOffBody.
  ///
  /// In en, this message translates to:
  /// **'Switch Bluetooth on, then return here and refresh the paired-device list.'**
  String get bluetoothOffBody;

  /// No description provided for @openBluetoothSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Bluetooth settings'**
  String get openBluetoothSettings;

  /// No description provided for @refreshPrinters.
  ///
  /// In en, this message translates to:
  /// **'Refresh printers'**
  String get refreshPrinters;

  /// No description provided for @pairedDevices.
  ///
  /// In en, this message translates to:
  /// **'Paired devices'**
  String get pairedDevices;

  /// No description provided for @noPairedPrinters.
  ///
  /// In en, this message translates to:
  /// **'No paired Bluetooth devices were found.'**
  String get noPairedPrinters;

  /// No description provided for @pairPrinterBody.
  ///
  /// In en, this message translates to:
  /// **'Pair the NETUM NT-1809DD in Android settings first. LibreSlip does not scan for nearby devices.'**
  String get pairPrinterBody;

  /// No description provided for @connectPrinter.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectPrinter;

  /// No description provided for @connectingPrinter.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connectingPrinter;

  /// No description provided for @connectedPrinter.
  ///
  /// In en, this message translates to:
  /// **'Connected to {name}'**
  String connectedPrinter(String name);

  /// No description provided for @disconnectPrinter.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnectPrinter;

  /// No description provided for @testTicket.
  ///
  /// In en, this message translates to:
  /// **'Print connection test'**
  String get testTicket;

  /// No description provided for @sendingTestTicket.
  ///
  /// In en, this message translates to:
  /// **'Sending test ticket…'**
  String get sendingTestTicket;

  /// No description provided for @testTicketSent.
  ///
  /// In en, this message translates to:
  /// **'Test bytes sent'**
  String get testTicketSent;

  /// No description provided for @testTicketSentBody.
  ///
  /// In en, this message translates to:
  /// **'Check the paper. Bluetooth transmission succeeded, but LibreSlip cannot confirm that the printer physically printed it.'**
  String get testTicketSentBody;

  /// No description provided for @testTicketFailed.
  ///
  /// In en, this message translates to:
  /// **'Nothing was sent. Check that the printer is on and nearby, then reconnect.'**
  String get testTicketFailed;

  /// No description provided for @testTicketUncertain.
  ///
  /// In en, this message translates to:
  /// **'The connection failed after some bytes were sent. The printer may have printed part or all of the test. Check the paper before trying again.'**
  String get testTicketUncertain;

  /// No description provided for @printerConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to this paired device. Check that the printer is on, nearby and not connected to another phone.'**
  String get printerConnectionFailed;

  /// No description provided for @printerOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'The printer operation failed. Refresh the list and try again.'**
  String get printerOperationFailed;

  /// No description provided for @testTicketSafety.
  ///
  /// In en, this message translates to:
  /// **'The test uses ESC/POS, feeds paper and never sends a cutter or cash-drawer command.'**
  String get testTicketSafety;

  /// No description provided for @ticketTemplate.
  ///
  /// In en, this message translates to:
  /// **'Printed ticket'**
  String get ticketTemplate;

  /// No description provided for @ticketTemplateBody.
  ///
  /// In en, this message translates to:
  /// **'Configure the saved heading, logo, footer and printed text sizes.'**
  String get ticketTemplateBody;

  /// No description provided for @ticketTextSizes.
  ///
  /// In en, this message translates to:
  /// **'Printed text sizes'**
  String get ticketTextSizes;

  /// No description provided for @ticketTextSizesBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a bounded size for each type of ticket content.'**
  String get ticketTextSizesBody;

  /// No description provided for @ticketHeadingSize.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get ticketHeadingSize;

  /// No description provided for @orderDetailsSize.
  ///
  /// In en, this message translates to:
  /// **'Order details'**
  String get orderDetailsSize;

  /// No description provided for @itemLinesSize.
  ///
  /// In en, this message translates to:
  /// **'Item lines'**
  String get itemLinesSize;

  /// No description provided for @notesSize.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesSize;

  /// No description provided for @footerSize.
  ///
  /// In en, this message translates to:
  /// **'Footer'**
  String get footerSize;

  /// No description provided for @ticketFooter.
  ///
  /// In en, this message translates to:
  /// **'Ticket footer'**
  String get ticketFooter;

  /// No description provided for @ticketFooterHint.
  ///
  /// In en, this message translates to:
  /// **'Optional, for example Prepared with care'**
  String get ticketFooterHint;

  /// No description provided for @editFooter.
  ///
  /// In en, this message translates to:
  /// **'Edit ticket footer'**
  String get editFooter;

  /// No description provided for @footerTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use 120 characters or fewer.'**
  String get footerTooLong;

  /// No description provided for @ticketLogo.
  ///
  /// In en, this message translates to:
  /// **'Ticket logo'**
  String get ticketLogo;

  /// No description provided for @ticketLogoBody.
  ///
  /// In en, this message translates to:
  /// **'Stored privately on this phone and printed in monochrome.'**
  String get ticketLogoBody;

  /// No description provided for @chooseLogo.
  ///
  /// In en, this message translates to:
  /// **'Choose logo'**
  String get chooseLogo;

  /// No description provided for @changeLogo.
  ///
  /// In en, this message translates to:
  /// **'Change logo'**
  String get changeLogo;

  /// No description provided for @removeLogo.
  ///
  /// In en, this message translates to:
  /// **'Remove logo'**
  String get removeLogo;

  /// No description provided for @logoPickerError.
  ///
  /// In en, this message translates to:
  /// **'The logo could not be saved. Try another image.'**
  String get logoPickerError;

  /// No description provided for @ticketLabel.
  ///
  /// In en, this message translates to:
  /// **'ORDER TICKET'**
  String get ticketLabel;

  /// No description provided for @lineNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get lineNoteLabel;

  /// No description provided for @printTicket.
  ///
  /// In en, this message translates to:
  /// **'Print ticket'**
  String get printTicket;

  /// No description provided for @reprintTicket.
  ///
  /// In en, this message translates to:
  /// **'Print again'**
  String get reprintTicket;

  /// No description provided for @sendQueuedTicket.
  ///
  /// In en, this message translates to:
  /// **'Send queued ticket'**
  String get sendQueuedTicket;

  /// No description provided for @shareTicketPdf.
  ///
  /// In en, this message translates to:
  /// **'Share PDF'**
  String get shareTicketPdf;

  /// No description provided for @preparingTicket.
  ///
  /// In en, this message translates to:
  /// **'Preparing ticket…'**
  String get preparingTicket;

  /// No description provided for @connectBeforePrinting.
  ///
  /// In en, this message translates to:
  /// **'Connect a printer in Settings before printing.'**
  String get connectBeforePrinting;

  /// No description provided for @printQueued.
  ///
  /// In en, this message translates to:
  /// **'Ticket queued'**
  String get printQueued;

  /// No description provided for @printQueuedBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been sent. Connect the printer, then use Send queued ticket.'**
  String get printQueuedBody;

  /// No description provided for @printTransmitted.
  ///
  /// In en, this message translates to:
  /// **'Ticket bytes sent'**
  String get printTransmitted;

  /// No description provided for @printTransmittedBody.
  ///
  /// In en, this message translates to:
  /// **'Check the paper. LibreSlip cannot confirm physical output, so it will not resend automatically.'**
  String get printTransmittedBody;

  /// No description provided for @printFailed.
  ///
  /// In en, this message translates to:
  /// **'Nothing was sent'**
  String get printFailed;

  /// No description provided for @printFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Reconnect the printer and start a new explicit print attempt.'**
  String get printFailedBody;

  /// No description provided for @printUncertain.
  ///
  /// In en, this message translates to:
  /// **'Printing outcome uncertain'**
  String get printUncertain;

  /// No description provided for @printUncertainBody.
  ///
  /// In en, this message translates to:
  /// **'Some data may have reached the printer. Check the paper before choosing Print again.'**
  String get printUncertainBody;

  /// No description provided for @printAttempts.
  ///
  /// In en, this message translates to:
  /// **'Print attempts'**
  String get printAttempts;

  /// No description provided for @noPrintAttempts.
  ///
  /// In en, this message translates to:
  /// **'This saved ticket has not been sent to a printer.'**
  String get noPrintAttempts;

  /// No description provided for @printStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get printStatusQueued;

  /// No description provided for @printStatusSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get printStatusSending;

  /// No description provided for @printStatusTransmitted.
  ///
  /// In en, this message translates to:
  /// **'Sent, check paper'**
  String get printStatusTransmitted;

  /// No description provided for @printStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed before transmission'**
  String get printStatusFailed;

  /// No description provided for @printStatusUncertain.
  ///
  /// In en, this message translates to:
  /// **'Uncertain, check paper'**
  String get printStatusUncertain;

  /// No description provided for @pdfShareFailed.
  ///
  /// In en, this message translates to:
  /// **'The PDF could not be opened in the system share sheet.'**
  String get pdfShareFailed;

  /// No description provided for @ticketPdfSubject.
  ///
  /// In en, this message translates to:
  /// **'LibreSlip ticket {number}'**
  String ticketPdfSubject(int number);

  /// No description provided for @hardwareTested.
  ///
  /// In en, this message translates to:
  /// **'NETUM NT-1809DD connection test printed successfully on the user’s physical printer.'**
  String get hardwareTested;

  /// No description provided for @printStorageError.
  ///
  /// In en, this message translates to:
  /// **'The print attempt could not be saved safely, so LibreSlip did not continue automatically.'**
  String get printStorageError;

  /// No description provided for @deleteTicket.
  ///
  /// In en, this message translates to:
  /// **'Delete ticket'**
  String get deleteTicket;

  /// No description provided for @deleteTicketQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete ticket {number}?'**
  String deleteTicketQuestion(int number);

  /// No description provided for @deleteTicketBody.
  ///
  /// In en, this message translates to:
  /// **'This saved ticket and its print-attempt history will be removed. The current order number will not change.'**
  String get deleteTicketBody;

  /// No description provided for @deleteAllTickets.
  ///
  /// In en, this message translates to:
  /// **'Delete all previous tickets'**
  String get deleteAllTickets;

  /// No description provided for @deleteAllTicketsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete all previous tickets?'**
  String get deleteAllTicketsQuestion;

  /// No description provided for @deleteAllTicketsBody.
  ///
  /// In en, this message translates to:
  /// **'All saved tickets and print-attempt history will be removed. The current draft and order number will not change.'**
  String get deleteAllTicketsBody;

  /// No description provided for @ticketDeleted.
  ///
  /// In en, this message translates to:
  /// **'Ticket deleted'**
  String get ticketDeleted;

  /// No description provided for @allTicketsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Previous tickets deleted'**
  String get allTicketsDeleted;

  /// No description provided for @portability.
  ///
  /// In en, this message translates to:
  /// **'Import and export'**
  String get portability;

  /// No description provided for @portabilityBody.
  ///
  /// In en, this message translates to:
  /// **'Move settings or make a complete local backup without an account or cloud service.'**
  String get portabilityBody;

  /// No description provided for @exportConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Export configuration'**
  String get exportConfiguration;

  /// No description provided for @exportConfigurationBody.
  ///
  /// In en, this message translates to:
  /// **'Includes language, appearance, printed ticket settings, order fields and logo.'**
  String get exportConfigurationBody;

  /// No description provided for @exportFullBackup.
  ///
  /// In en, this message translates to:
  /// **'Export full backup'**
  String get exportFullBackup;

  /// No description provided for @exportFullBackupBody.
  ///
  /// In en, this message translates to:
  /// **'Also includes reusable items, drafts, saved tickets, print attempts and referenced images.'**
  String get exportFullBackupBody;

  /// No description provided for @importArchive.
  ///
  /// In en, this message translates to:
  /// **'Import ZIP'**
  String get importArchive;

  /// No description provided for @archivePrivacyWarning.
  ///
  /// In en, this message translates to:
  /// **'Exported ZIP files can contain private ticket notes and history. Store and share them carefully.'**
  String get archivePrivacyWarning;

  /// No description provided for @archivePairingWarning.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth pairing is never included. Pair and reconnect the printer after restoring on another phone.'**
  String get archivePairingWarning;

  /// No description provided for @archivePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing archive…'**
  String get archivePreparing;

  /// No description provided for @archiveExportOpened.
  ///
  /// In en, this message translates to:
  /// **'Archive ready in the system share sheet'**
  String get archiveExportOpened;

  /// No description provided for @archiveImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Review import'**
  String get archiveImportTitle;

  /// No description provided for @configurationArchive.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get configurationArchive;

  /// No description provided for @fullBackupArchive.
  ///
  /// In en, this message translates to:
  /// **'Full backup'**
  String get fullBackupArchive;

  /// No description provided for @archiveCreated.
  ///
  /// In en, this message translates to:
  /// **'Created {date}'**
  String archiveCreated(String date);

  /// No description provided for @archiveContents.
  ///
  /// In en, this message translates to:
  /// **'{items} items, {drafts} drafts, {tickets} tickets and {attempts} print attempts'**
  String archiveContents(int items, int drafts, int tickets, int attempts);

  /// No description provided for @configurationReplaceWarning.
  ///
  /// In en, this message translates to:
  /// **'This replaces the current settings and order-field options. Items and ticket history stay unchanged.'**
  String get configurationReplaceWarning;

  /// No description provided for @backupReplaceWarning.
  ///
  /// In en, this message translates to:
  /// **'This replaces all settings, reusable items, drafts, ticket history and print attempts with the archive contents.'**
  String get backupReplaceWarning;

  /// No description provided for @restoreArchive.
  ///
  /// In en, this message translates to:
  /// **'Replace and restore'**
  String get restoreArchive;

  /// No description provided for @archiveRestored.
  ///
  /// In en, this message translates to:
  /// **'Archive restored'**
  String get archiveRestored;

  /// No description provided for @archiveInvalid.
  ///
  /// In en, this message translates to:
  /// **'This ZIP is invalid, unsafe, damaged or from an unsupported LibreSlip version. Nothing was changed.'**
  String get archiveInvalid;

  /// No description provided for @archiveOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'The archive operation could not be completed. Existing data remains available.'**
  String get archiveOperationFailed;

  /// No description provided for @archiveRollbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore could not be completed safely. Restart LibreSlip and check the existing data before trying again.'**
  String get archiveRollbackFailed;

  /// No description provided for @itemBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Items in this period'**
  String get itemBreakdownTitle;

  /// No description provided for @itemBreakdownBody.
  ///
  /// In en, this message translates to:
  /// **'Quantities from saved ticket snapshots.'**
  String get itemBreakdownBody;

  /// No description provided for @noItemsInPeriod.
  ///
  /// In en, this message translates to:
  /// **'No items were added to saved tickets in this period.'**
  String get noItemsInPeriod;

  /// No description provided for @itemQuantitySummary.
  ///
  /// In en, this message translates to:
  /// **'{name}: {quantity}'**
  String itemQuantitySummary(String name, int quantity);

  /// No description provided for @showAllItemStatistics.
  ///
  /// In en, this message translates to:
  /// **'Show full list ({count})'**
  String showAllItemStatistics(int count);

  /// No description provided for @showFewerItemStatistics.
  ///
  /// In en, this message translates to:
  /// **'Show fewer'**
  String get showFewerItemStatistics;

  /// No description provided for @appMode.
  ///
  /// In en, this message translates to:
  /// **'App mode'**
  String get appMode;

  /// No description provided for @appModeBody.
  ///
  /// In en, this message translates to:
  /// **'Choose whether this device creates or receives orders.'**
  String get appModeBody;

  /// No description provided for @clientMode.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get clientMode;

  /// No description provided for @clientModeBody.
  ///
  /// In en, this message translates to:
  /// **'Create, print and keep tickets locally. A server connection will always be optional.'**
  String get clientModeBody;

  /// No description provided for @serverMode.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverMode;

  /// No description provided for @serverModeBody.
  ///
  /// In en, this message translates to:
  /// **'Receive orders on this device and mark them Done. The listener runs only while LibreSlip is open.'**
  String get serverModeBody;

  /// No description provided for @switchToServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to Server mode?'**
  String get switchToServerTitle;

  /// No description provided for @switchToServerBody.
  ///
  /// In en, this message translates to:
  /// **'Your client items, drafts and ticket history stay on this phone. Server mode receives immutable orders on your local network while LibreSlip is open.'**
  String get switchToServerBody;

  /// No description provided for @switchToClientTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to Client mode?'**
  String get switchToClientTitle;

  /// No description provided for @switchToClientBody.
  ///
  /// In en, this message translates to:
  /// **'Received orders stay on this phone. Client mode restores the catalogue, composition, local printing and history workspace.'**
  String get switchToClientBody;

  /// No description provided for @switchMode.
  ///
  /// In en, this message translates to:
  /// **'Switch mode'**
  String get switchMode;

  /// No description provided for @modeSaveError.
  ///
  /// In en, this message translates to:
  /// **'The app mode could not be saved. Nothing was switched.'**
  String get modeSaveError;

  /// No description provided for @serverInboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Server orders'**
  String get serverInboxTitle;

  /// No description provided for @serverInboxSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive immutable orders from paired LibreSlip clients and mark them Done.'**
  String get serverInboxSubtitle;

  /// No description provided for @serverStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting local receiver…'**
  String get serverStarting;

  /// No description provided for @serverListening.
  ///
  /// In en, this message translates to:
  /// **'Ready to receive'**
  String get serverListening;

  /// No description provided for @serverNotListening.
  ///
  /// In en, this message translates to:
  /// **'Receiver unavailable'**
  String get serverNotListening;

  /// No description provided for @serverForegroundOnly.
  ///
  /// In en, this message translates to:
  /// **'Local HTTPS only. Receiving stops whenever LibreSlip is not open in Server mode.'**
  String get serverForegroundOnly;

  /// No description provided for @serverAddresses.
  ///
  /// In en, this message translates to:
  /// **'Connection addresses'**
  String get serverAddresses;

  /// No description provided for @noLocalAddress.
  ///
  /// In en, this message translates to:
  /// **'No local network address is available. Connect this device to the same Wi-Fi network as the client.'**
  String get noLocalAddress;

  /// No description provided for @serverFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Server certificate fingerprint'**
  String get serverFingerprint;

  /// No description provided for @serverRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh server orders'**
  String get serverRefresh;

  /// No description provided for @clientPairing.
  ///
  /// In en, this message translates to:
  /// **'Client pairing'**
  String get clientPairing;

  /// No description provided for @clientPairingBody.
  ///
  /// In en, this message translates to:
  /// **'Open a five-minute pairing window only when you are ready to add a client. Compare this server’s fingerprint on both devices.'**
  String get clientPairingBody;

  /// No description provided for @allowPairing.
  ///
  /// In en, this message translates to:
  /// **'Allow client pairing'**
  String get allowPairing;

  /// No description provided for @pairingCode.
  ///
  /// In en, this message translates to:
  /// **'One-time pairing code'**
  String get pairingCode;

  /// No description provided for @pairingExpires.
  ///
  /// In en, this message translates to:
  /// **'Valid until {time}'**
  String pairingExpires(String time);

  /// No description provided for @stopPairing.
  ///
  /// In en, this message translates to:
  /// **'Stop pairing'**
  String get stopPairing;

  /// No description provided for @receivedOrders.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get receivedOrders;

  /// No description provided for @completedOrders.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedOrders;

  /// No description provided for @noReceivedOrders.
  ///
  /// In en, this message translates to:
  /// **'No received orders yet'**
  String get noReceivedOrders;

  /// No description provided for @noReceivedOrdersBody.
  ///
  /// In en, this message translates to:
  /// **'Paired clients can send orders while this screen says Ready to receive.'**
  String get noReceivedOrdersBody;

  /// No description provided for @noCompletedOrders.
  ///
  /// In en, this message translates to:
  /// **'No completed orders yet'**
  String get noCompletedOrders;

  /// No description provided for @noCompletedOrdersBody.
  ///
  /// In en, this message translates to:
  /// **'Orders you mark Done will stay here.'**
  String get noCompletedOrdersBody;

  /// No description provided for @sourceDevice.
  ///
  /// In en, this message translates to:
  /// **'Source device'**
  String get sourceDevice;

  /// No description provided for @receivedAt.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get receivedAt;

  /// No description provided for @createdAt.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get createdAt;

  /// No description provided for @markDone.
  ///
  /// In en, this message translates to:
  /// **'Mark Done'**
  String get markDone;

  /// No description provided for @markingDone.
  ///
  /// In en, this message translates to:
  /// **'Marking Done…'**
  String get markingDone;

  /// No description provided for @markDoneFailed.
  ///
  /// In en, this message translates to:
  /// **'The order could not be marked Done. It remains in Received.'**
  String get markDoneFailed;
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
