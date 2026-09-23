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
  String get overviewSubtitle => 'Più ordine nella tua giornata.';

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
  String get settingsSubtitle =>
      'Piccoli dettagli. Uno spazio che ti somiglia.';

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
  String get itemsTitle => 'I tuoi preferiti, a portata di mano.';

  @override
  String get itemsBody =>
      'Tieni gli articoli pronti per il prossimo ordine. Articoli, categorie e foto saranno disponibili in un prossimo aggiornamento.';

  @override
  String get ticketsTitle => 'Ogni ordine ha una storia.';

  @override
  String get ticketsBody =>
      'Le tue comande salvate troveranno posto qui. Storico, copie e ristampe saranno disponibili in un prossimo aggiornamento.';

  @override
  String get backOverview => 'Torna alla panoramica';

  @override
  String get localOnly => 'LOCALE, PER NATURA';

  @override
  String get privacyTitle => 'Nessun accesso. Solo il tuo spazio.';

  @override
  String get privacyBody =>
      'Queste impostazioni funzionano senza connessione a Internet. Il backup automatico sul cloud è disattivato.';
}

/// The translations for Italian, as used in Italy (`it_IT`).
class AppLocalizationsItIt extends AppLocalizationsIt {
  AppLocalizationsItIt() : super('it_IT');
}
