// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appName => 'LibreSlip';

  @override
  String get overview => 'Panoramica';

  @override
  String get compose => 'Componi';

  @override
  String get addItems => 'Aggiungi articoli';

  @override
  String get items => 'Articoli';

  @override
  String get tickets => 'Comande';

  @override
  String get settings => 'Impostazioni';

  @override
  String get onThisPhone => 'Su questo telefono';

  @override
  String get yourWorkspace => 'IL TUO SPAZIO';

  @override
  String get defaultHeading => 'Il tuo spazio';

  @override
  String get heroEyebrow => 'UNA COMANDA. TUTTO PIÙ CHIARO.';

  @override
  String get heroTitle => 'Ogni ordine.\nChiaro, su carta.';

  @override
  String get heroBody =>
      'Uno spazio semplice per i tuoi ordini, qui sul telefono. Rendilo davvero tuo.';

  @override
  String get personaliseWorkspace => 'Personalizza il tuo spazio';

  @override
  String get workspaceTitle => 'Dall’idea alla comanda';

  @override
  String get workspaceSubtitle => 'Uno spazio per ogni fase del tuo ordine.';

  @override
  String get composeCardBody => 'Articoli, quantità e piccoli dettagli.';

  @override
  String get itemsCardBody => 'I tuoi articoli più usati, insieme.';

  @override
  String get ticketsCardBody => 'I tuoi ordini, raccolti in un unico posto.';

  @override
  String get printerOverviewTitle => 'Stampante';

  @override
  String get printerOverviewBody =>
      'Connessione Bluetooth attualmente usata da LibreSlip.';

  @override
  String get printerConnectedStatus => 'Connessa';

  @override
  String get printerDisconnectedStatus => 'Non connessa';

  @override
  String get printerPermissionStatus => 'Autorizzazione necessaria';

  @override
  String get printerBluetoothOffStatus => 'Bluetooth disattivato';

  @override
  String get printerUnavailableStatus => 'Non disponibile';

  @override
  String printerConnectedDevice(String name) {
    return 'Connessa a $name';
  }

  @override
  String get printerBattery => 'Batteria stampante';

  @override
  String printerBatteryPercentage(int percentage) {
    return '$percentage%';
  }

  @override
  String get printerBatteryUnavailable =>
      'Non comunicata dalla stampante. Controlla l’indicatore della batteria.';

  @override
  String get managePrinter => 'Gestisci stampante';

  @override
  String get refreshPrinterStatus => 'Aggiorna stato';

  @override
  String get statisticsTitle => 'Attività delle comande';

  @override
  String get statisticsBody =>
      'Conta le comande salvate in base alla data di creazione. Non registra prezzi o vendite.';

  @override
  String get startDate => 'Data iniziale';

  @override
  String get endDate => 'Data finale';

  @override
  String get noDateLimit => 'Nessun limite';

  @override
  String get clearDateFilters => 'Azzera date';

  @override
  String get savedTicketsStat => 'Comande salvate';

  @override
  String get ticketItemsStat => 'Articoli nelle comande';

  @override
  String get averageItemsStat => 'Articoli per comanda';

  @override
  String get previewLabel => 'Anteprima dello spazio';

  @override
  String get localTitle => 'Ciò che è tuo, resta tuo.';

  @override
  String get localBody =>
      'Le tue preferenze restano su questo telefono. Nessun account. Nessun cloud. Nessuna complicazione.';

  @override
  String get ticketHeader => 'Intestazione delle comande';

  @override
  String get ticketHeaderBody =>
      'Scegli un nome per personalizzare il tuo spazio.';

  @override
  String get heading => 'Intestazione';

  @override
  String get headingHint => 'Ad esempio, Bottega del Borgo';

  @override
  String get editHeading => 'Modifica intestazione';

  @override
  String get nameRequired => 'Inserisci un’intestazione.';

  @override
  String get nameTooLong => 'Usa al massimo 60 caratteri.';

  @override
  String get save => 'Salva modifiche';

  @override
  String get cancel => 'Annulla';

  @override
  String get language => 'Lingua';

  @override
  String get languageBody => 'Scegli la lingua in cui ti senti a casa.';

  @override
  String get english => 'English (UK)';

  @override
  String get italian => 'Italiano';

  @override
  String get appearance => 'Aspetto';

  @override
  String get appearanceBody => 'Scegli lo stile o segui quello del telefono.';

  @override
  String get appTextSize => 'Dimensione del testo';

  @override
  String get appTextSizeBody =>
      'Ingrandisci il testo in LibreSlip mantenendo le impostazioni di accessibilità di Android.';

  @override
  String get appTextSizeDefault => 'Predefinita';

  @override
  String get appTextSizeLarge => 'Grande';

  @override
  String get appTextSizeLargest => 'Molto grande';

  @override
  String get systemTheme => 'Sistema';

  @override
  String get lightTheme => 'Chiaro';

  @override
  String get darkTheme => 'Scuro';

  @override
  String get savedLocally => 'Salvato su questo telefono';

  @override
  String get saving => 'Salvataggio delle preferenze...';

  @override
  String get saveError =>
      'Impossibile salvare le modifiche. Le preferenze precedenti sono ancora attive. Riprova.';

  @override
  String get loadErrorTitle => 'Un momento per il tuo spazio';

  @override
  String get loadErrorBody =>
      'Non è stato possibile leggere le preferenze. Nulla è stato sovrascritto. Prova a riaprire il tuo spazio.';

  @override
  String get retry => 'Riprova';

  @override
  String get loading => 'Apertura del tuo spazio';

  @override
  String get composeTitle => 'Un posto per ogni dettaglio.';

  @override
  String get composeBody =>
      'Crea ordini con articoli, quantità e note. Creazione e stampa delle comande saranno disponibili in un prossimo aggiornamento.';

  @override
  String get itemsTitle => 'I tuoi articoli riutilizzabili, a portata di mano.';

  @override
  String get itemsBody =>
      'Tieni gli articoli pronti per il prossimo ordine. Articoli, categorie e foto saranno disponibili in un prossimo aggiornamento.';

  @override
  String get ticketsTitle => 'Ogni ordine ha una storia.';

  @override
  String get ticketsBody =>
      'Le comande salvate e i tentativi di stampa espliciti restano insieme nello storico locale.';

  @override
  String get backOverview => 'Torna alla panoramica';

  @override
  String get localOnly => 'LOCALE, PER NATURA';

  @override
  String get privacyTitle => 'Nessun accesso. Solo il tuo spazio.';

  @override
  String get privacyBody =>
      'Queste impostazioni funzionano senza connessione a Internet. Il backup automatico sul cloud è disattivato.';

  @override
  String get newDraft => 'Nuova bozza';

  @override
  String get draft => 'Bozza';

  @override
  String get drafts => 'Bozze';

  @override
  String get deleteDraft => 'Elimina bozza';

  @override
  String get deleteDraftQuestion => 'Eliminare questa bozza?';

  @override
  String get deleteDraftBody =>
      'Gli articoli e le note verranno rimossi da questo telefono.';

  @override
  String get delete => 'Elimina';

  @override
  String get searchItems => 'Cerca articoli';

  @override
  String get allCategories => 'Tutte le categorie';

  @override
  String get favourites => 'Preferiti';

  @override
  String get addItem => 'Aggiungi articolo';

  @override
  String get editItem => 'Modifica articolo';

  @override
  String get itemName => 'Nome articolo';

  @override
  String get itemNameHint => 'Ad esempio, Toast ai funghi';

  @override
  String get category => 'Categoria';

  @override
  String get categoryHint => 'Ad esempio, Cucina';

  @override
  String get favouriteItem => 'Tieni nei preferiti';

  @override
  String get favouriteItemBody =>
      'Gli articoli preferiti compaiono per primi durante la composizione.';

  @override
  String get chooseImage => 'Scegli immagine';

  @override
  String get changeImage => 'Cambia immagine';

  @override
  String get removeImage => 'Rimuovi immagine';

  @override
  String get imagePickerError =>
      'Impossibile aggiungere l’immagine. Provane un’altra.';

  @override
  String get itemRequired => 'Inserisci il nome dell’articolo.';

  @override
  String get itemNameTooLong => 'Usa al massimo 80 caratteri.';

  @override
  String get categoryTooLong => 'Usa al massimo 60 caratteri.';

  @override
  String get duplicateItemError => 'Un articolo attivo usa già questo nome.';

  @override
  String get emptyItemsTitle => 'Il tuo spazio articoli è pronto.';

  @override
  String get emptyItemsBody =>
      'Aggiungi articoli riutilizzabili per trovarli subito mentre componi una comanda.';

  @override
  String get noItemsFound => 'Nessun articolo corrisponde alla ricerca.';

  @override
  String get edit => 'Modifica';

  @override
  String get removeItem => 'Rimuovi articolo';

  @override
  String removeItemQuestion(String name) {
    return 'Rimuovere $name?';
  }

  @override
  String get removeItemBody =>
      'Le comande salvate conservano l’istantanea originale. L’articolo non comparirà più nelle nuove ricerche.';

  @override
  String get addToDraft => 'Aggiungi alla bozza';

  @override
  String get adHocItem => 'Articolo occasionale';

  @override
  String get adHocItemBody =>
      'Aggiungi un articolo a questa bozza senza salvarlo tra quelli riutilizzabili.';

  @override
  String get orderReference => 'Riferimento tavolo o ordine';

  @override
  String get orderReferenceHint => 'Facoltativo, ad esempio Tavolo 4';

  @override
  String get orderNotes => 'Note dell’ordine';

  @override
  String get orderFields => 'Campi dell’ordine';

  @override
  String get orderFieldsBody =>
      'Scegli quali campi facoltativi mostrare durante la composizione.';

  @override
  String get compactCompose => 'Composizione compatta';

  @override
  String get compactComposeBody =>
      'Mostra ogni articolo riutilizzabile in un’unica scheda ordine, con quantità iniziale 0.';

  @override
  String get preparationNotes => 'Note di preparazione';

  @override
  String get orderNotesHint => 'Note facoltative per l’intero ordine';

  @override
  String get draftEmptyTitle => 'Inizia con un articolo.';

  @override
  String get draftEmptyBody =>
      'Scegli un articolo riutilizzabile. Il lavoro viene salvato sul telefono mentre componi la comanda.';

  @override
  String get decreaseQuantity => 'Riduci quantità';

  @override
  String get increaseQuantity => 'Aumenta quantità';

  @override
  String get quantity => 'Quantità';

  @override
  String get preparationNote => 'Nota di preparazione';

  @override
  String get preparationNoteHint => 'Facoltativa, ad esempio senza cipolla';

  @override
  String get removeLine => 'Rimuovi riga';

  @override
  String get saveTicket => 'Stampa comanda';

  @override
  String get ticketSaved => 'Comanda salvata nello storico.';

  @override
  String get ticketNeedsItem =>
      'Aggiungi almeno un articolo prima di stampare.';

  @override
  String get draftSaveError =>
      'Impossibile salvare la bozza. Gli ultimi dettagli restano sullo schermo. Riprova.';

  @override
  String get storageErrorTitle => 'Un momento per il tuo spazio ordini';

  @override
  String get storageErrorBody =>
      'LibreSlip non è riuscito ad aprire il database locale degli ordini. Nulla è stato reimpostato o sovrascritto.';

  @override
  String get emptyTicketsTitle => 'Nessuna comanda salvata.';

  @override
  String get emptyTicketsBody =>
      'Quando stampi un ordine composto, la comanda viene salvata qui prima del tentativo di stampa.';

  @override
  String get reset => 'Ricomincia';

  @override
  String get resetOrderNumberQuestion =>
      'Ricominciare la numerazione degli ordini?';

  @override
  String get resetOrderNumberBody =>
      'Il prossimo ordine userà il numero 1. Le comande salvate e i relativi tentativi di stampa non verranno modificati.';

  @override
  String get orderNumberReset => 'La numerazione degli ordini riparte da 1.';

  @override
  String get orderNumberResetFailed =>
      'Impossibile reimpostare il numero dell’ordine. Riprova.';

  @override
  String orderNumber(int number) {
    return 'Ordine $number';
  }

  @override
  String ticketNumber(int number) {
    return 'Comanda $number';
  }

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articoli',
      one: '1 articolo',
      zero: 'Nessun articolo',
    );
    return '$_temp0';
  }

  @override
  String get viewTicket => 'Vedi comanda';

  @override
  String get duplicateTicket => 'Duplica come bozza';

  @override
  String get duplicatedTicket =>
      'È stata creata una nuova bozza modificabile da questa istantanea.';

  @override
  String get ticketDetails => 'Dettagli comanda';

  @override
  String get savedHeading => 'Intestazione salvata';

  @override
  String get close => 'Chiudi';

  @override
  String get savedSnapshot => 'Istantanea salvata';

  @override
  String get savedSnapshotBody =>
      'Le modifiche al catalogo non cambiano questa comanda.';

  @override
  String get oneOff => 'Occasionale';

  @override
  String get saved => 'Salvata';

  @override
  String get savingOrders => 'Salvataggio locale…';

  @override
  String get referenceTooLong => 'Usa al massimo 80 caratteri.';

  @override
  String get noteTooLong => 'Questa nota è troppo lunga.';

  @override
  String get searchTickets => 'Cerca comande';

  @override
  String get printerSetup => 'Connessione stampante';

  @override
  String get printerSetupBody =>
      'Connetti una stampante Bluetooth Classic già associata. LibreSlip la ricorda, controlla la connessione e si riconnette quando possibile. I dati di stampa non vengono mai rinviati automaticamente.';

  @override
  String get bluetoothUnsupported =>
      'Il Bluetooth non è disponibile su questo telefono.';

  @override
  String get bluetoothPermissionTitle =>
      'Consenti accesso ai dispositivi vicini';

  @override
  String get bluetoothPermissionBody =>
      'Android richiede questa autorizzazione per vedere e connettere le stampanti già associate.';

  @override
  String get allowBluetooth => 'Consenti accesso';

  @override
  String get bluetoothOffTitle => 'Il Bluetooth è disattivato';

  @override
  String get bluetoothOffBody =>
      'Attiva il Bluetooth, poi torna qui e aggiorna l’elenco dei dispositivi associati.';

  @override
  String get openBluetoothSettings => 'Apri impostazioni Bluetooth';

  @override
  String get refreshPrinters => 'Aggiorna stampanti';

  @override
  String get pairedDevices => 'Dispositivi associati';

  @override
  String get noPairedPrinters =>
      'Nessun dispositivo Bluetooth associato trovato.';

  @override
  String get pairPrinterBody =>
      'Associa la NETUM NT-1809DD nelle impostazioni Android. LibreSlip non cerca dispositivi nelle vicinanze.';

  @override
  String get connectPrinter => 'Connetti';

  @override
  String get connectingPrinter => 'Connessione…';

  @override
  String connectedPrinter(String name) {
    return 'Connessa a $name';
  }

  @override
  String get disconnectPrinter => 'Disconnetti';

  @override
  String get testTicket => 'Stampa test di connessione';

  @override
  String get sendingTestTicket => 'Invio comanda di prova…';

  @override
  String get testTicketSent => 'Byte di prova inviati';

  @override
  String get testTicketSentBody =>
      'Controlla la carta. La trasmissione Bluetooth è riuscita, ma LibreSlip non può confermare che la stampante abbia stampato.';

  @override
  String get testTicketFailed =>
      'Nessun dato inviato. Controlla che la stampante sia accesa e vicina, poi riconnettila.';

  @override
  String get testTicketUncertain =>
      'La connessione è caduta dopo l’invio di alcuni byte. La stampante potrebbe aver stampato parte o tutto il test. Controlla la carta prima di riprovare.';

  @override
  String get printerConnectionFailed =>
      'Impossibile connettere il dispositivo associato. Controlla che la stampante sia accesa, vicina e non connessa a un altro telefono.';

  @override
  String get printerOperationFailed =>
      'Operazione della stampante non riuscita. Aggiorna l’elenco e riprova.';

  @override
  String get testTicketSafety =>
      'Il test usa ESC/POS, fa avanzare la carta e non invia comandi di taglio o apertura cassetto.';

  @override
  String get ticketTemplate => 'Comanda stampata';

  @override
  String get ticketTemplateBody =>
      'Configura intestazione, logo, piè di pagina e dimensioni del testo stampato.';

  @override
  String get ticketTextSizes => 'Dimensioni del testo stampato';

  @override
  String get ticketTextSizesBody =>
      'Scegli una dimensione limitata per ogni tipo di contenuto della comanda.';

  @override
  String get ticketHeadingSize => 'Intestazione';

  @override
  String get orderDetailsSize => 'Dettagli dell’ordine';

  @override
  String get itemLinesSize => 'Righe degli articoli';

  @override
  String get notesSize => 'Note';

  @override
  String get footerSize => 'Piè di pagina';

  @override
  String get ticketFooter => 'Piè di pagina';

  @override
  String get ticketFooterHint => 'Facoltativo, ad esempio Preparato con cura';

  @override
  String get editFooter => 'Modifica piè di pagina';

  @override
  String get footerTooLong => 'Usa al massimo 120 caratteri.';

  @override
  String get ticketLogo => 'Logo della comanda';

  @override
  String get ticketLogoBody =>
      'Salvato in modo privato sul telefono e stampato in bianco e nero.';

  @override
  String get ticketLogoWidth => 'Larghezza del logo stampato';

  @override
  String get ticketLogoWidthBody =>
      'Scegli quanta parte della larghezza stampabile di 58 mm può usare il logo.';

  @override
  String get chooseLogo => 'Scegli logo';

  @override
  String get changeLogo => 'Cambia logo';

  @override
  String get removeLogo => 'Rimuovi logo';

  @override
  String get logoPickerError =>
      'Impossibile salvare il logo. Prova un’altra immagine.';

  @override
  String get ticketLabel => 'COMANDA';

  @override
  String get lineNoteLabel => 'Nota';

  @override
  String get printTicket => 'Stampa comanda';

  @override
  String get reprintTicket => 'Stampa di nuovo';

  @override
  String get sendQueuedTicket => 'Invia comanda in coda';

  @override
  String get shareTicketPdf => 'Condividi PDF';

  @override
  String get preparingTicket => 'Preparazione comanda…';

  @override
  String get connectBeforePrinting =>
      'Connetti una stampante nelle Impostazioni prima di stampare.';

  @override
  String get printQueued => 'Comanda in coda';

  @override
  String get printQueuedBody =>
      'Nessun dato è stato inviato. Connetti la stampante, poi usa Invia comanda in coda.';

  @override
  String get printTransmitted => 'Byte della comanda inviati';

  @override
  String get printTransmittedBody =>
      'Controlla la carta. LibreSlip non può confermare l’uscita fisica, quindi non ripete automaticamente l’invio.';

  @override
  String get printFailed => 'Nessun dato inviato';

  @override
  String get printFailedBody =>
      'Riconnetti la stampante e avvia un nuovo tentativo esplicito.';

  @override
  String get printUncertain => 'Esito della stampa incerto';

  @override
  String get printUncertainBody =>
      'Alcuni dati potrebbero essere arrivati alla stampante. Controlla la carta prima di scegliere Stampa di nuovo.';

  @override
  String get printAttempts => 'Tentativi di stampa';

  @override
  String get noPrintAttempts =>
      'Questa comanda salvata non è mai stata inviata a una stampante.';

  @override
  String get printStatusQueued => 'In coda';

  @override
  String get printStatusSending => 'Invio';

  @override
  String get printStatusTransmitted => 'Inviata, controlla la carta';

  @override
  String get printStatusFailed => 'Non inviata';

  @override
  String get printStatusUncertain => 'Incerta, controlla la carta';

  @override
  String get pdfShareFailed =>
      'Impossibile aprire il PDF nel pannello di condivisione del sistema.';

  @override
  String ticketPdfSubject(int number) {
    return 'Comanda LibreSlip $number';
  }

  @override
  String get hardwareTested =>
      'La connessione e la stampa di prova con la NETUM NT-1809DD fisica sono confermate.';

  @override
  String get printStorageError =>
      'Impossibile salvare il tentativo di stampa in modo sicuro, quindi LibreSlip non ha continuato automaticamente.';

  @override
  String get deleteTicket => 'Elimina comanda';

  @override
  String deleteTicketQuestion(int number) {
    return 'Eliminare la comanda $number?';
  }

  @override
  String get deleteTicketBody =>
      'La comanda salvata e la cronologia dei tentativi di stampa verranno eliminate. Il numero d’ordine corrente non cambierà. Le consegne e gli ordini ricevuti dal Server non vengono eliminati.';

  @override
  String get deleteAllTickets => 'Elimina tutte le comande precedenti';

  @override
  String get deleteAllTicketsQuestion =>
      'Eliminare tutte le comande precedenti?';

  @override
  String get deleteAllTicketsBody =>
      'Tutte le comande salvate e la cronologia dei tentativi di stampa verranno eliminate. La bozza e il numero d’ordine correnti non cambieranno. Le consegne e gli ordini ricevuti dal Server non vengono eliminati.';

  @override
  String get ticketDeleted => 'Comanda eliminata';

  @override
  String get allTicketsDeleted => 'Comande precedenti eliminate';

  @override
  String get portability => 'Importazione ed esportazione';

  @override
  String get portabilityBody =>
      'Trasferisci le impostazioni o crea un backup locale completo senza account o servizi cloud.';

  @override
  String get exportConfiguration => 'Esporta configurazione';

  @override
  String get exportConfigurationBody =>
      'Include lingua, aspetto, impostazioni della comanda stampata, campi dell’ordine e logo.';

  @override
  String get exportFullBackup => 'Esporta backup completo';

  @override
  String get exportFullBackupBody =>
      'Include anche articoli riutilizzabili, bozze, comande salvate, tentativi di stampa e immagini collegate.';

  @override
  String get importArchive => 'Importa ZIP';

  @override
  String get archivePrivacyWarning =>
      'I file ZIP esportati possono contenere note e cronologia private. Conservali e condividili con attenzione.';

  @override
  String get archivePairingWarning =>
      'L’associazione Bluetooth non viene mai inclusa. Associa e riconnetti la stampante dopo il ripristino su un altro telefono.';

  @override
  String get archivePreparing => 'Preparazione archivio…';

  @override
  String get archiveExportOpened =>
      'Archivio pronto nel pannello di condivisione';

  @override
  String get archiveImportTitle => 'Controlla importazione';

  @override
  String get configurationArchive => 'Configurazione';

  @override
  String get fullBackupArchive => 'Backup completo';

  @override
  String archiveCreated(String date) {
    return 'Creato il $date';
  }

  @override
  String archiveContents(int items, int drafts, int tickets, int attempts) {
    return '$items articoli, $drafts bozze, $tickets comande e $attempts tentativi di stampa';
  }

  @override
  String get configurationReplaceWarning =>
      'Sostituisce le impostazioni correnti e le opzioni dei campi dell’ordine. Articoli e cronologia restano invariati.';

  @override
  String get backupReplaceWarning =>
      'Sostituisce tutte le impostazioni, gli articoli riutilizzabili, le bozze, la cronologia e i tentativi di stampa con il contenuto dell’archivio.';

  @override
  String get restoreArchive => 'Sostituisci e ripristina';

  @override
  String get archiveRestored => 'Archivio ripristinato';

  @override
  String get archiveInvalid =>
      'Questo ZIP non è valido, è pericoloso, danneggiato o proviene da una versione LibreSlip non supportata. Nessun dato è stato modificato.';

  @override
  String get archiveOperationFailed =>
      'Impossibile completare l’operazione sull’archivio. I dati esistenti restano disponibili.';

  @override
  String get archiveRollbackFailed =>
      'Impossibile completare il ripristino in sicurezza. Riavvia LibreSlip e controlla i dati esistenti prima di riprovare.';

  @override
  String get itemBreakdownTitle => 'Totali articoli';

  @override
  String get viewItemTotals => 'Vedi totali articoli';

  @override
  String get itemBreakdownBody =>
      'Quantità totali ricavate dalle comande salvate per le date selezionate.';

  @override
  String get noItemsInPeriod =>
      'Nessun articolo è stato aggiunto alle comande salvate in questo periodo.';

  @override
  String itemQuantitySummary(String name, int quantity) {
    return '$name: $quantity';
  }

  @override
  String showAllItemStatistics(int count) {
    return 'Mostra elenco completo ($count)';
  }

  @override
  String get showFewerItemStatistics => 'Mostra meno';

  @override
  String get appMode => 'Modalità app';

  @override
  String get appModeBody =>
      'Scegli se questo dispositivo crea o riceve gli ordini.';

  @override
  String get clientMode => 'Client';

  @override
  String get clientModeBody =>
      'Crea, stampa e conserva le comande in locale. L’associazione a un Server locale è sempre facoltativa.';

  @override
  String get serverMode => 'Server';

  @override
  String get serverModeBody =>
      'Ricevi gli ordini su questo dispositivo e contrassegnali come completati. Un servizio in primo piano mantiene attiva la ricezione quando lo schermo è bloccato.';

  @override
  String get switchToServerTitle => 'Passare alla modalità Server?';

  @override
  String get switchToServerBody =>
      'Gli articoli, la composizione e lo storico del Client restano su questo telefono. La modalità Server riceve ordini non modificabili sulla rete locale, anche quando lo schermo è bloccato.';

  @override
  String get switchToClientTitle => 'Passare alla modalità Client?';

  @override
  String get switchToClientBody =>
      'Gli ordini ricevuti restano su questo telefono. La modalità Client ripristina catalogo, composizione, stampa locale e storico.';

  @override
  String get switchMode => 'Cambia modalità';

  @override
  String get modeSaveError =>
      'Impossibile salvare la modalità dell’app. Non è stato modificato nulla.';

  @override
  String get serverInboxTitle => 'Ordini';

  @override
  String get serverStarting => 'Avvio ricezione locale…';

  @override
  String get serverListening => 'Pronto a ricevere';

  @override
  String get serverNotListening => 'Ricezione non disponibile';

  @override
  String get serverForegroundOnly =>
      'Solo HTTPS locale. Un servizio in primo piano continua a ricevere quando il dispositivo è bloccato o LibreSlip è in background. Passa alla modalità Client per interromperlo.';

  @override
  String get serverAddresses => 'Indirizzi di connessione';

  @override
  String get noLocalAddress =>
      'Nessun indirizzo di rete locale disponibile. Collega questo dispositivo alla stessa rete Wi-Fi del Client.';

  @override
  String get serverRefresh => 'Aggiorna ordini del Server';

  @override
  String get clientPairing => 'Associazione Client';

  @override
  String get clientPairingBody =>
      'Le richieste di connessione vengono mostrate qui automaticamente. Controlla il dispositivo e poi accetta o rifiuta.';

  @override
  String get waitingForPairingRequest => 'In attesa di un Client';

  @override
  String get waitingForPairingRequestBody =>
      'Sul dispositivo Client, inserisci uno degli indirizzi di connessione mostrati sopra e tocca Associa.';

  @override
  String get pairingRequest => 'Richiesta di connessione';

  @override
  String pairingRequestBody(String name, String address) {
    return '$name richiede l’accesso da $address.';
  }

  @override
  String get acceptPairing => 'Accetta';

  @override
  String get rejectPairing => 'Rifiuta';

  @override
  String get receivedOrders => 'Ricevuti';

  @override
  String get completedOrders => 'Completati';

  @override
  String get noReceivedOrders => 'Nessun ordine ricevuto';

  @override
  String get noReceivedOrdersBody =>
      'I Client associati possono inviare ordini quando questa schermata indica Pronto a ricevere.';

  @override
  String get noCompletedOrders => 'Nessun ordine completato';

  @override
  String get noCompletedOrdersBody =>
      'Gli ordini che segnali come completati resteranno qui.';

  @override
  String get receivedAt => 'Ricevuto';

  @override
  String get createdAt => 'Creato';

  @override
  String get markDone => 'Segna completato';

  @override
  String get markingDone => 'Completamento…';

  @override
  String get markDoneFailed =>
      'Impossibile segnare l’ordine come completato. Resta tra i ricevuti.';

  @override
  String get markReceived => 'Riporta tra i ricevuti';

  @override
  String get markingReceived => 'Spostamento tra i ricevuti…';

  @override
  String get markReceivedFailed =>
      'Impossibile riportare l’ordine tra i ricevuti. Resta tra i completati.';

  @override
  String get deleteCompletedOrder => 'Elimina ordine';

  @override
  String deleteCompletedOrderQuestion(int number) {
    return 'Eliminare l’ordine completato $number?';
  }

  @override
  String get deleteCompletedOrderBody =>
      'Questo ordine completato verrà eliminato definitivamente dal Server. La copia sul Client non viene modificata.';

  @override
  String get deleteAllCompletedOrders => 'Elimina tutti gli ordini completati';

  @override
  String get deleteAllCompletedOrdersQuestion =>
      'Eliminare tutti gli ordini completati?';

  @override
  String deleteAllCompletedOrdersBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'questi $count ordini completati dal Server',
      one: 'questo ordine completato dal Server',
    );
    return 'Eliminare definitivamente $_temp0? Le copie sui Client non vengono modificate.';
  }

  @override
  String get deleteCompletedOrdersFailed =>
      'Impossibile eliminare lo storico degli ordini completati.';

  @override
  String get clientServerTitle => 'Server ordini facoltativo';

  @override
  String get clientServerBody =>
      'Associa un Server LibreSlip su questa rete locale. La stampa locale e lo storico continuano a funzionare anche quando il Server non è disponibile.';

  @override
  String get noPairedServer => 'Nessun Server associato';

  @override
  String get pairServer => 'Associa Server';

  @override
  String get pairedServer => 'Server associato';

  @override
  String get serverAddressInput => 'IP e porta del Server';

  @override
  String get serverAddressHint => '192.168.1.25:5119';

  @override
  String get pairServerTitle => 'Associa al Server';

  @override
  String get pairServerBody =>
      'Inserisci l’indirizzo IP e la porta mostrati nelle Impostazioni del Server. Il Server deve accettare la richiesta.';

  @override
  String get pair => 'Associa';

  @override
  String get pairingServer => 'In attesa del Server…';

  @override
  String get pairingWaitingBody =>
      'Controlla il dispositivo Server e accetta questa richiesta di connessione.';

  @override
  String get serverPaired => 'Server associato';

  @override
  String get unpairServer => 'Disassocia Server';

  @override
  String get unpairServerTitle => 'Disassociare questo Server?';

  @override
  String get unpairServerBody =>
      'Le nuove comande non creeranno più consegne. Le comande locali e lo storico delle consegne restano su questo telefono.';

  @override
  String get serverUnpaired => 'Server disassociato';

  @override
  String get pairingInvalid =>
      'Inserisci un indirizzo IPv4 locale e una porta validi.';

  @override
  String get pairingCertificateError =>
      'L’identità del Server è cambiata durante la connessione. Non è stato associato nulla.';

  @override
  String get pairingDenied =>
      'Il Server ha rifiutato la richiesta o non l’ha accettata in tempo.';

  @override
  String get pairingUnreachable =>
      'Impossibile raggiungere il Server. Mantieni entrambi i dispositivi sulla stessa rete locale e verifica che la modalità Server sia attiva.';

  @override
  String get pairingFailed =>
      'La risposta del Server non è valida per questa versione di LibreSlip.';

  @override
  String get pairingStorageFailed =>
      'L’associazione remota è riuscita, ma non è stato possibile salvarla in sicurezza sul telefono. Riprova.';

  @override
  String get pendingDeliveries => 'In attesa';

  @override
  String get failedDeliveries => 'Da controllare';

  @override
  String get serverDelivery => 'Consegna al Server';

  @override
  String get deliveryAwaitingPrint => 'In attesa della stampa';

  @override
  String get deliveryAwaitingPrintBody =>
      'Questo ordine non verrà inviato al Server finché una stampa locale non sarà trasmessa correttamente.';

  @override
  String get deliveryPending => 'In attesa';

  @override
  String get deliverySending => 'Invio';

  @override
  String get deliveryDelivered => 'Consegnato';

  @override
  String get deliveryFailed => 'Da controllare';

  @override
  String get deliveryPendingBody =>
      'Questa comanda è salvata in locale e verrà inviata automaticamente quando il Server associato sarà raggiungibile.';

  @override
  String get deliveryDeliveredBody =>
      'Il Server associato ha confermato questo ordine non modificabile.';

  @override
  String get deliveryFailedBody =>
      'La stampa locale e lo storico non sono interessati. Gli errori di rete temporanei vengono riprovati automaticamente; puoi anche riprovare subito la stessa consegna.';

  @override
  String get retryDelivery => 'Riprova consegna';

  @override
  String get retryingDelivery => 'Nuovo tentativo…';

  @override
  String get fieldRequired => 'Campo obbligatorio';

  @override
  String get defaultClientName => 'Client LibreSlip';

  @override
  String get includeInServerOrders => 'Includi negli ordini al Server';

  @override
  String get includeInServerOrdersBody =>
      'Se disattivato, l’articolo resta sulla comanda locale stampata ma viene omesso dall’ordine facoltativo al Server.';

  @override
  String get localOnlyItem => 'Solo locale';

  @override
  String get serverOrdersTab => 'Ordini';

  @override
  String get serverSettingsTab => 'Impostazioni';

  @override
  String get serverSettingsTitle => 'Impostazioni';

  @override
  String get outstandingItems => 'Ancora da preparare';

  @override
  String get outstandingItemsBody =>
      'Totali degli articoli in tutti gli ordini attualmente tra i Ricevuti.';

  @override
  String get noOutstandingItems =>
      'Non ci sono articoli in attesa di preparazione.';

  @override
  String appVersion(String version) {
    return 'Versione $version';
  }
}

/// The translations for Italian, as used in Italy (`it_IT`).
class AppLocalizationsItIt extends AppLocalizationsIt {
  AppLocalizationsItIt() : super('it_IT');
}
