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
  String get addItems => 'Add items';

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
  String get printerOverviewTitle => 'Printer';

  @override
  String get printerOverviewBody => 'Current LibreSlip Bluetooth connection.';

  @override
  String get printerConnectedStatus => 'Connected';

  @override
  String get printerDisconnectedStatus => 'Not connected';

  @override
  String get printerPermissionStatus => 'Permission required';

  @override
  String get printerBluetoothOffStatus => 'Bluetooth is off';

  @override
  String get printerUnavailableStatus => 'Unavailable';

  @override
  String printerConnectedDevice(String name) {
    return 'Connected to $name';
  }

  @override
  String get printerBattery => 'Printer battery';

  @override
  String printerBatteryPercentage(int percentage) {
    return '$percentage%';
  }

  @override
  String get printerBatteryUnavailable =>
      'Not reported by this printer. Check its battery indicator.';

  @override
  String get managePrinter => 'Manage printer';

  @override
  String get refreshPrinterStatus => 'Refresh status';

  @override
  String get statisticsTitle => 'Ticket activity';

  @override
  String get statisticsBody =>
      'Counts saved tickets by creation date. No prices or sales are recorded.';

  @override
  String get startDate => 'Start date';

  @override
  String get endDate => 'End date';

  @override
  String get noDateLimit => 'No limit';

  @override
  String get clearDateFilters => 'Clear dates';

  @override
  String get savedTicketsStat => 'Saved tickets';

  @override
  String get ticketItemsStat => 'Items on tickets';

  @override
  String get averageItemsStat => 'Items per ticket';

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
  String get itemsTitle => 'Your reusable items, close to hand.';

  @override
  String get itemsBody =>
      'Keep reusable items ready for your next order. Adding items, categories and photos will be available in a future update.';

  @override
  String get ticketsTitle => 'Every order has a story.';

  @override
  String get ticketsBody =>
      'Saved tickets and explicit print attempts stay together in your local history.';

  @override
  String get backOverview => 'Back to overview';

  @override
  String get localOnly => 'LOCAL BY DEFAULT';

  @override
  String get privacyTitle => 'No sign-in. Just your workspace.';

  @override
  String get privacyBody =>
      'These settings work without an internet connection. Automatic cloud backup is switched off.';

  @override
  String get composeSubtitle =>
      'Build an order and keep every detail safe as you work.';

  @override
  String get itemsSubtitle => 'Reusable items for faster ticket composition.';

  @override
  String get ticketsSubtitle =>
      'Saved order snapshots, kept separately from printing.';

  @override
  String get newDraft => 'New draft';

  @override
  String get draft => 'Draft';

  @override
  String get drafts => 'Drafts';

  @override
  String get deleteDraft => 'Delete draft';

  @override
  String get deleteDraftQuestion => 'Delete this draft?';

  @override
  String get deleteDraftBody =>
      'Its items and notes will be removed from this phone.';

  @override
  String get delete => 'Delete';

  @override
  String get searchItems => 'Search items';

  @override
  String get allCategories => 'All categories';

  @override
  String get favourites => 'Favourites';

  @override
  String get addItem => 'Add item';

  @override
  String get editItem => 'Edit item';

  @override
  String get itemName => 'Item name';

  @override
  String get itemNameHint => 'For example, Mushroom toastie';

  @override
  String get category => 'Category';

  @override
  String get categoryHint => 'For example, Kitchen';

  @override
  String get favouriteItem => 'Keep in favourites';

  @override
  String get favouriteItemBody =>
      'Favourite items appear first when composing.';

  @override
  String get chooseImage => 'Choose image';

  @override
  String get changeImage => 'Change image';

  @override
  String get removeImage => 'Remove image';

  @override
  String get imagePickerError =>
      'The image could not be added. Try another image.';

  @override
  String get itemRequired => 'Enter an item name.';

  @override
  String get itemNameTooLong => 'Use 80 characters or fewer.';

  @override
  String get categoryTooLong => 'Use 60 characters or fewer.';

  @override
  String get duplicateItemError => 'An active item already uses that name.';

  @override
  String get emptyItemsTitle => 'Your item shelf is ready.';

  @override
  String get emptyItemsBody =>
      'Add reusable items to find them quickly while composing a ticket.';

  @override
  String get noItemsFound => 'No items match this search.';

  @override
  String get edit => 'Edit';

  @override
  String get removeItem => 'Remove item';

  @override
  String removeItemQuestion(String name) {
    return 'Remove $name?';
  }

  @override
  String get removeItemBody =>
      'Saved tickets keep their original snapshot. This item will disappear from new searches.';

  @override
  String get addToDraft => 'Add to draft';

  @override
  String get adHocItem => 'One-off item';

  @override
  String get adHocItemBody =>
      'Add an item to this draft without saving it to your reusable shelf.';

  @override
  String get orderReference => 'Table or order reference';

  @override
  String get orderReferenceHint => 'Optional, for example Table 4';

  @override
  String get orderNotes => 'Order notes';

  @override
  String get orderFields => 'Order fields';

  @override
  String get orderFieldsBody =>
      'Choose which optional fields appear while composing a ticket.';

  @override
  String get preparationNotes => 'Preparation notes';

  @override
  String get orderNotesHint => 'Optional notes for the whole order';

  @override
  String get draftEmptyTitle => 'Start with an item.';

  @override
  String get draftEmptyBody =>
      'Choose a reusable item. Your work is saved on this phone as you compose the ticket.';

  @override
  String get decreaseQuantity => 'Decrease quantity';

  @override
  String get increaseQuantity => 'Increase quantity';

  @override
  String get quantity => 'Quantity';

  @override
  String get preparationNote => 'Preparation note';

  @override
  String get preparationNoteHint => 'Optional, for example no onion';

  @override
  String get removeLine => 'Remove line';

  @override
  String get saveTicket => 'Print ticket';

  @override
  String get ticketSaved => 'Ticket saved to history.';

  @override
  String get ticketNeedsItem => 'Add at least one item before printing.';

  @override
  String get draftSaveError =>
      'This draft could not be saved. Your latest details remain on screen. Try again.';

  @override
  String get storageErrorTitle => 'Your order workspace needs a moment';

  @override
  String get storageErrorBody =>
      'LibreSlip could not open its local order database. Nothing has been reset or overwritten.';

  @override
  String get emptyTicketsTitle => 'No saved tickets yet.';

  @override
  String get emptyTicketsBody =>
      'When you print a composed order, it is saved here before the print attempt begins.';

  @override
  String get reset => 'Reset';

  @override
  String get resetOrderNumberQuestion => 'Reset order number?';

  @override
  String get resetOrderNumberBody =>
      'The next order will use number 1. Saved tickets and their print attempts will not be changed.';

  @override
  String get orderNumberReset => 'Order numbering restarted at 1.';

  @override
  String get orderNumberResetFailed =>
      'The order number could not be reset. Try again.';

  @override
  String orderNumber(int number) {
    return 'Order $number';
  }

  @override
  String ticketNumber(int number) {
    return 'Ticket $number';
  }

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get viewTicket => 'View ticket';

  @override
  String get duplicateTicket => 'Duplicate as draft';

  @override
  String get duplicatedTicket =>
      'A new editable draft was created from this snapshot.';

  @override
  String get ticketDetails => 'Ticket details';

  @override
  String get savedHeading => 'Saved heading';

  @override
  String get close => 'Close';

  @override
  String get savedSnapshot => 'Saved snapshot';

  @override
  String get savedSnapshotBody => 'Catalogue edits do not change this ticket.';

  @override
  String get oneOff => 'One-off';

  @override
  String get saved => 'Saved';

  @override
  String get savingOrders => 'Saving locally…';

  @override
  String get referenceTooLong => 'Use 80 characters or fewer.';

  @override
  String get noteTooLong => 'This note is too long.';

  @override
  String get searchTickets => 'Search tickets';

  @override
  String get printerSetup => 'Printer connection';

  @override
  String get printerSetupBody =>
      'Connect a paired Bluetooth Classic printer. LibreSlip will never reconnect or resend by itself.';

  @override
  String get bluetoothUnsupported =>
      'Bluetooth is not available on this phone.';

  @override
  String get bluetoothPermissionTitle => 'Allow nearby-device access';

  @override
  String get bluetoothPermissionBody =>
      'Android requires this permission to see and connect to printers you have already paired.';

  @override
  String get allowBluetooth => 'Allow access';

  @override
  String get bluetoothOffTitle => 'Bluetooth is switched off';

  @override
  String get bluetoothOffBody =>
      'Switch Bluetooth on, then return here and refresh the paired-device list.';

  @override
  String get openBluetoothSettings => 'Open Bluetooth settings';

  @override
  String get refreshPrinters => 'Refresh printers';

  @override
  String get pairedDevices => 'Paired devices';

  @override
  String get noPairedPrinters => 'No paired Bluetooth devices were found.';

  @override
  String get pairPrinterBody =>
      'Pair the NETUM NT-1809DD in Android settings first. LibreSlip does not scan for nearby devices.';

  @override
  String get connectPrinter => 'Connect';

  @override
  String get connectingPrinter => 'Connecting…';

  @override
  String connectedPrinter(String name) {
    return 'Connected to $name';
  }

  @override
  String get disconnectPrinter => 'Disconnect';

  @override
  String get testTicket => 'Print connection test';

  @override
  String get sendingTestTicket => 'Sending test ticket…';

  @override
  String get testTicketSent => 'Test bytes sent';

  @override
  String get testTicketSentBody =>
      'Check the paper. Bluetooth transmission succeeded, but LibreSlip cannot confirm that the printer physically printed it.';

  @override
  String get testTicketFailed =>
      'Nothing was sent. Check that the printer is on and nearby, then reconnect.';

  @override
  String get testTicketUncertain =>
      'The connection failed after some bytes were sent. The printer may have printed part or all of the test. Check the paper before trying again.';

  @override
  String get printerConnectionFailed =>
      'Could not connect to this paired device. Check that the printer is on, nearby and not connected to another phone.';

  @override
  String get printerOperationFailed =>
      'The printer operation failed. Refresh the list and try again.';

  @override
  String get testTicketSafety =>
      'The test uses ESC/POS, feeds paper and never sends a cutter or cash-drawer command.';

  @override
  String get ticketTemplate => 'Printed ticket';

  @override
  String get ticketTemplateBody =>
      'Configure the saved heading, logo, footer and printed text sizes.';

  @override
  String get ticketTextSizes => 'Printed text sizes';

  @override
  String get ticketTextSizesBody =>
      'Choose a bounded size for each type of ticket content.';

  @override
  String get ticketHeadingSize => 'Heading';

  @override
  String get orderDetailsSize => 'Order details';

  @override
  String get itemLinesSize => 'Item lines';

  @override
  String get notesSize => 'Notes';

  @override
  String get footerSize => 'Footer';

  @override
  String get ticketFooter => 'Ticket footer';

  @override
  String get ticketFooterHint => 'Optional, for example Prepared with care';

  @override
  String get editFooter => 'Edit ticket footer';

  @override
  String get footerTooLong => 'Use 120 characters or fewer.';

  @override
  String get ticketLogo => 'Ticket logo';

  @override
  String get ticketLogoBody =>
      'Stored privately on this phone and printed in monochrome.';

  @override
  String get chooseLogo => 'Choose logo';

  @override
  String get changeLogo => 'Change logo';

  @override
  String get removeLogo => 'Remove logo';

  @override
  String get logoPickerError =>
      'The logo could not be saved. Try another image.';

  @override
  String get ticketLabel => 'ORDER TICKET';

  @override
  String get lineNoteLabel => 'Note';

  @override
  String get printTicket => 'Print ticket';

  @override
  String get reprintTicket => 'Print again';

  @override
  String get sendQueuedTicket => 'Send queued ticket';

  @override
  String get shareTicketPdf => 'Share PDF';

  @override
  String get preparingTicket => 'Preparing ticket…';

  @override
  String get connectBeforePrinting =>
      'Connect a printer in Settings before printing.';

  @override
  String get printQueued => 'Ticket queued';

  @override
  String get printQueuedBody =>
      'Nothing has been sent. Connect the printer, then use Send queued ticket.';

  @override
  String get printTransmitted => 'Ticket bytes sent';

  @override
  String get printTransmittedBody =>
      'Check the paper. LibreSlip cannot confirm physical output, so it will not resend automatically.';

  @override
  String get printFailed => 'Nothing was sent';

  @override
  String get printFailedBody =>
      'Reconnect the printer and start a new explicit print attempt.';

  @override
  String get printUncertain => 'Printing outcome uncertain';

  @override
  String get printUncertainBody =>
      'Some data may have reached the printer. Check the paper before choosing Print again.';

  @override
  String get printAttempts => 'Print attempts';

  @override
  String get noPrintAttempts =>
      'This saved ticket has not been sent to a printer.';

  @override
  String get printStatusQueued => 'Queued';

  @override
  String get printStatusSending => 'Sending';

  @override
  String get printStatusTransmitted => 'Sent, check paper';

  @override
  String get printStatusFailed => 'Failed before transmission';

  @override
  String get printStatusUncertain => 'Uncertain, check paper';

  @override
  String get pdfShareFailed =>
      'The PDF could not be opened in the system share sheet.';

  @override
  String ticketPdfSubject(int number) {
    return 'LibreSlip ticket $number';
  }

  @override
  String get hardwareTested =>
      'Physical NETUM NT-1809DD connection and test printing are confirmed.';

  @override
  String get printStorageError =>
      'The print attempt could not be saved safely, so LibreSlip did not continue automatically.';

  @override
  String get deleteTicket => 'Delete ticket';

  @override
  String deleteTicketQuestion(int number) {
    return 'Delete ticket $number?';
  }

  @override
  String get deleteTicketBody =>
      'This saved ticket and its print-attempt history will be removed. The current order number will not change.';

  @override
  String get deleteAllTickets => 'Delete all previous tickets';

  @override
  String get deleteAllTicketsQuestion => 'Delete all previous tickets?';

  @override
  String get deleteAllTicketsBody =>
      'All saved tickets and print-attempt history will be removed. The current draft and order number will not change.';

  @override
  String get ticketDeleted => 'Ticket deleted';

  @override
  String get allTicketsDeleted => 'Previous tickets deleted';

  @override
  String get portability => 'Import and export';

  @override
  String get portabilityBody =>
      'Move settings or make a complete local backup without an account or cloud service.';

  @override
  String get exportConfiguration => 'Export configuration';

  @override
  String get exportConfigurationBody =>
      'Includes language, appearance, printed ticket settings, order fields and logo.';

  @override
  String get exportFullBackup => 'Export full backup';

  @override
  String get exportFullBackupBody =>
      'Also includes reusable items, drafts, saved tickets, print attempts and referenced images.';

  @override
  String get importArchive => 'Import ZIP';

  @override
  String get archivePrivacyWarning =>
      'Exported ZIP files can contain private ticket notes and history. Store and share them carefully.';

  @override
  String get archivePairingWarning =>
      'Bluetooth pairing is never included. Pair and reconnect the printer after restoring on another phone.';

  @override
  String get archivePreparing => 'Preparing archive…';

  @override
  String get archiveExportOpened => 'Archive ready in the system share sheet';

  @override
  String get archiveImportTitle => 'Review import';

  @override
  String get configurationArchive => 'Configuration';

  @override
  String get fullBackupArchive => 'Full backup';

  @override
  String archiveCreated(String date) {
    return 'Created $date';
  }

  @override
  String archiveContents(int items, int drafts, int tickets, int attempts) {
    return '$items items, $drafts drafts, $tickets tickets and $attempts print attempts';
  }

  @override
  String get configurationReplaceWarning =>
      'This replaces the current settings and order-field options. Items and ticket history stay unchanged.';

  @override
  String get backupReplaceWarning =>
      'This replaces all settings, reusable items, drafts, ticket history and print attempts with the archive contents.';

  @override
  String get restoreArchive => 'Replace and restore';

  @override
  String get archiveRestored => 'Archive restored';

  @override
  String get archiveInvalid =>
      'This ZIP is invalid, unsafe, damaged or from an unsupported LibreSlip version. Nothing was changed.';

  @override
  String get archiveOperationFailed =>
      'The archive operation could not be completed. Existing data remains available.';

  @override
  String get archiveRollbackFailed =>
      'Restore could not be completed safely. Restart LibreSlip and check the existing data before trying again.';

  @override
  String get itemBreakdownTitle => 'Item totals';

  @override
  String get viewItemTotals => 'View item totals';

  @override
  String get itemBreakdownBody =>
      'Total quantities from saved ticket snapshots for the selected dates.';

  @override
  String get noItemsInPeriod =>
      'No items were added to saved tickets in this period.';

  @override
  String itemQuantitySummary(String name, int quantity) {
    return '$name: $quantity';
  }

  @override
  String showAllItemStatistics(int count) {
    return 'Show full list ($count)';
  }

  @override
  String get showFewerItemStatistics => 'Show fewer';

  @override
  String get appMode => 'App mode';

  @override
  String get appModeBody =>
      'Choose whether this device creates or receives orders.';

  @override
  String get clientMode => 'Client';

  @override
  String get clientModeBody =>
      'Create, print and keep tickets locally. Pairing with a local Server is always optional.';

  @override
  String get serverMode => 'Server';

  @override
  String get serverModeBody =>
      'Receive orders on this device and mark them Done. The listener runs only while LibreSlip is open.';

  @override
  String get switchToServerTitle => 'Switch to Server mode?';

  @override
  String get switchToServerBody =>
      'Your client items, drafts and ticket history stay on this phone. Server mode receives immutable orders on your local network while LibreSlip is open.';

  @override
  String get switchToClientTitle => 'Switch to Client mode?';

  @override
  String get switchToClientBody =>
      'Received orders stay on this phone. Client mode restores the catalogue, composition, local printing and history workspace.';

  @override
  String get switchMode => 'Switch mode';

  @override
  String get modeSaveError =>
      'The app mode could not be saved. Nothing was switched.';

  @override
  String get serverInboxTitle => 'Server orders';

  @override
  String get serverInboxSubtitle =>
      'Receive immutable orders from paired LibreSlip clients and mark them Done.';

  @override
  String get serverStarting => 'Starting local receiver…';

  @override
  String get serverListening => 'Ready to receive';

  @override
  String get serverNotListening => 'Receiver unavailable';

  @override
  String get serverForegroundOnly =>
      'Local HTTPS only. Receiving stops whenever LibreSlip is not open in Server mode.';

  @override
  String get serverAddresses => 'Connection addresses';

  @override
  String get noLocalAddress =>
      'No local network address is available. Connect this device to the same Wi-Fi network as the client.';

  @override
  String get serverFingerprint => 'Server certificate fingerprint';

  @override
  String get serverRefresh => 'Refresh server orders';

  @override
  String get clientPairing => 'Client pairing';

  @override
  String get clientPairingBody =>
      'Open a five-minute pairing window only when you are ready to add a client. Compare this server’s fingerprint on both devices.';

  @override
  String get allowPairing => 'Allow client pairing';

  @override
  String get pairingCode => 'One-time pairing code';

  @override
  String pairingExpires(String time) {
    return 'Valid until $time';
  }

  @override
  String get stopPairing => 'Stop pairing';

  @override
  String get receivedOrders => 'Received';

  @override
  String get completedOrders => 'Completed';

  @override
  String get noReceivedOrders => 'No received orders yet';

  @override
  String get noReceivedOrdersBody =>
      'Paired clients can send orders while this screen says Ready to receive.';

  @override
  String get noCompletedOrders => 'No completed orders yet';

  @override
  String get noCompletedOrdersBody => 'Orders you mark Done will stay here.';

  @override
  String get sourceDevice => 'Source device';

  @override
  String get receivedAt => 'Received';

  @override
  String get createdAt => 'Created';

  @override
  String get markDone => 'Mark Done';

  @override
  String get markingDone => 'Marking Done…';

  @override
  String get markDoneFailed =>
      'The order could not be marked Done. It remains in Received.';

  @override
  String get clientServerTitle => 'Optional order server';

  @override
  String get clientServerBody =>
      'Pair a LibreSlip Server on this local network. Local printing and ticket history continue even when the server is unavailable.';

  @override
  String get noPairedServer => 'No server paired';

  @override
  String get pairServer => 'Pair server';

  @override
  String get pairedServer => 'Paired server';

  @override
  String get serverAddressInput => 'Server address';

  @override
  String get serverAddressHint => '192.168.1.25:5119';

  @override
  String get serverFingerprintInput => 'Certificate fingerprint';

  @override
  String get serverFingerprintHint =>
      'Copy the fingerprint shown on the Server device';

  @override
  String get clientDeviceName => 'This device name';

  @override
  String get clientDeviceNameHint => 'Front counter';

  @override
  String get pairServerTitle => 'Pair with Server';

  @override
  String get pairServerBody =>
      'On the Server device, open Client pairing. Enter its address, fingerprint and one-time code exactly as shown.';

  @override
  String get pair => 'Pair';

  @override
  String get pairingServer => 'Pairing…';

  @override
  String get serverPaired => 'Server paired';

  @override
  String get unpairServer => 'Unpair server';

  @override
  String get unpairServerTitle => 'Unpair this server?';

  @override
  String get unpairServerBody =>
      'New tickets will stop creating deliveries. Existing local tickets and delivery history stay on this phone.';

  @override
  String get serverUnpaired => 'Server unpaired';

  @override
  String get pairingInvalid =>
      'Check the local address, six-digit code, device name and certificate fingerprint.';

  @override
  String get pairingCertificateError =>
      'The Server certificate does not match this fingerprint. Nothing was paired.';

  @override
  String get pairingDenied =>
      'The one-time code was rejected or has expired. Open a new pairing window on the Server.';

  @override
  String get pairingUnreachable =>
      'The Server could not be reached. Keep both devices on the same local network and leave Server mode open.';

  @override
  String get pairingFailed =>
      'The Server response was not valid for this LibreSlip version.';

  @override
  String get pairingStorageFailed =>
      'Pairing succeeded remotely, but could not be saved securely on this phone. Pair again with a new code.';

  @override
  String get pendingDeliveries => 'Waiting';

  @override
  String get failedDeliveries => 'Needs attention';

  @override
  String get serverDelivery => 'Server delivery';

  @override
  String get deliveryPending => 'Pending';

  @override
  String get deliverySending => 'Sending';

  @override
  String get deliveryDelivered => 'Delivered';

  @override
  String get deliveryFailed => 'Needs attention';

  @override
  String get deliveryPendingBody =>
      'This ticket is saved locally and will be sent while LibreSlip is open and the paired Server is reachable.';

  @override
  String get deliveryDeliveredBody =>
      'The paired Server acknowledged this immutable order.';

  @override
  String get deliveryFailedBody =>
      'Local printing and history are unaffected. Check the Server and retry this same delivery safely.';

  @override
  String get retryDelivery => 'Retry delivery';

  @override
  String get retryingDelivery => 'Retrying…';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get defaultClientName => 'LibreSlip Client';

  @override
  String get includeInServerOrders => 'Include in Server orders';

  @override
  String get includeInServerOrdersBody =>
      'When off, this item stays on the printed local ticket but is omitted from the optional Server order.';

  @override
  String get localOnlyItem => 'Local only';

  @override
  String get serverOrdersTab => 'Orders';

  @override
  String get serverSettingsTab => 'Settings';

  @override
  String get serverSettingsTitle => 'Server settings';

  @override
  String get serverSettingsSubtitle =>
      'Manage this local receiver, pairing and app mode.';

  @override
  String get outstandingItems => 'Still to prepare';

  @override
  String get outstandingItemsBody =>
      'Item totals across all orders currently in Received.';

  @override
  String get noOutstandingItems => 'Nothing is waiting to be prepared.';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }
}

/// The translations for English, as used in the United Kingdom (`en_GB`).
class AppLocalizationsEnGb extends AppLocalizationsEn {
  AppLocalizationsEnGb() : super('en_GB');
}
