import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:libreslip/features/printing/application/esc_pos_ticket_encoder.dart';
import 'package:libreslip/features/printing/application/printer_controller.dart';
import 'package:libreslip/features/printing/application/ticket_output_controller.dart';
import 'package:libreslip/features/printing/application/ticket_pdf_sharer.dart';
import 'package:libreslip/features/printing/domain/ticket_document.dart';
import 'package:libreslip/features/printing/domain/ticket_typography.dart';
import 'package:libreslip/features/printing/presentation/ticket_detail_dialog.dart';
import 'package:libreslip/features/printing/presentation/ticket_preview.dart';
import 'package:libreslip/features/printing/presentation/ticket_price_labels.dart';
import 'package:libreslip/features/settings/application/settings_controller.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';
import 'package:libreslip/l10n/generated/app_localizations.dart';

import 'test_support.dart';
import 'ticket_output_test.dart';

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  for (final language in ['en', 'it']) {
    testWidgets(
      'saved prices, partial subtotals and currency separation render in preview, ESC/POS and PDF $language',
      (tester) async {
        late TicketDocument enabled;
        late TicketDocument disabled;
        await tester.pumpWidget(
          _app(
            language,
            Builder(
              builder: (context) {
                enabled = _document(_ticket, context, prices: true);
                disabled = _document(_ticket, context);
                return SingleChildScrollView(
                  child: TicketPreview(document: enabled),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          enabled.lines.first.priceText,
          isNot(contains(language == 'it' ? '1,25' : '1.25')),
        );
        expect(
          enabled.lines.first.priceText,
          contains(language == 'it' ? '2,50' : '2.50'),
        );
        expect(enabled.priceSummary!.totals, hasLength(3));
        expect(
          enabled.priceSummary!.totals.first,
          contains(language == 'it' ? '2,50' : '2.50'),
        );
        expect(
          enabled.priceSummary!.totals.last,
          contains(language == 'it' ? '0,00' : '0.00'),
        );
        expect(enabled.priceSummary!.notes, hasLength(2));
        expect(enabled.priceSummary!.notes.first, contains('3'));
        expect(find.text(enabled.priceSummary!.label), findsOneWidget);
        expect(find.text(enabled.priceSummary!.notes.first), findsOneWidget);
        expect(disabled.priceSummary, isNull);
        expect(disabled.lines.every((line) => line.priceText.isEmpty), isTrue);
        final encoded = (await tester.runAsync(
          () => const EscPosTicketEncoder().encode(enabled),
        ))!;
        final plain = (await tester.runAsync(
          () => const EscPosTicketEncoder().encode(disabled),
        ))!;
        final text = String.fromCharCodes(encoded);
        final amount = language == 'it' ? '2,50 EUR' : 'EUR 2.50';
        expect(text, contains('2 x Soup${' ' * 16}$amount'));
        expect(text, isNot(contains(language == 'it' ? 'ciascuno' : 'each')));
        expect(text, contains('EUR'));
        expect(text, contains('GBP'));
        expect(text, contains('USD'));
        expect(text, contains(language == 'it' ? '2,50' : '2.50'));
        expect(String.fromCharCodes(plain), isNot(contains('EUR')));
        expect(encoded, isNot(plain));
        final pdf = (await tester.runAsync(
          () => LocalTicketPdfSharer().build(
            enabled,
            subject: 'LibreSlip price example',
          ),
        ))!;
        final plainPdf = (await tester.runAsync(
          () => LocalTicketPdfSharer().build(
            disabled,
            subject: 'LibreSlip price example',
          ),
        ))!;
        expect(String.fromCharCodes(pdf.take(4)), '%PDF');
        expect(pdf.length, greaterThan(plainPdf.length));
        const capture = bool.fromEnvironment('LIBRESLIP_CAPTURE_PREVIEWS');
        if (capture) {
          final directory = Directory('build/previews')
            ..createSync(recursive: true);
          File('${directory.path}/printed-prices-$language.pdf')
              .writeAsBytesSync(pdf);
          File('${directory.path}/printed-prices-disabled-$language.pdf')
              .writeAsBytesSync(plainPdf);
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'updated orders print every item and the complete total $language',
      (tester) async {
        late TicketDocument addition;
        late TicketDocument first;
        await tester.pumpWidget(
          _app(
            language,
            Builder(
              builder: (context) {
                final selected = SavedTicket(
                  id: 'addition',
                  number: 1,
                  createdAt: _ticket.createdAt,
                  heading: 'Kitchen',
                  reference: 'Table 4',
                  orderNote: '',
                  lines: _ticket.lines,
                  managedOrderId: 'order',
                  revision: 2,
                  additionLineIds: const ['soup'],
                );
                addition = _document(selected, context, prices: true);
                first = _document(
                  SavedTicket(
                    id: 'first',
                    number: 1,
                    createdAt: _ticket.createdAt,
                    heading: 'Kitchen',
                    reference: '',
                    orderNote: '',
                    lines: [_ticket.lines.first],
                  ),
                  context,
                  prices: true,
                );
                return TicketPreview(document: addition);
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(addition.lines, hasLength(_ticket.lines.length));
        expect(addition.additionLabel, '');
        expect(first.additionLabel, isEmpty);
        expect(
          find.textContaining(
            RegExp('revision|revisione', caseSensitive: false),
          ),
          findsNothing,
        );
        expect(addition.priceSummary!.totals, hasLength(3));
        expect(
          addition.priceSummary!.label,
          language == 'it'
              ? 'Subtotale degli articoli con prezzo'
              : 'Subtotal of priced items',
        );
        expect(addition.priceSummary!.notes, isNotEmpty);
        expect(
          first.priceSummary!.label,
          language == 'it' ? 'Totale' : 'Total',
        );
        expect(
          first.priceSummary!.totals,
          isNot(addition.priceSummary!.totals),
        );
        final bytes = (await tester.runAsync(
          () => const EscPosTicketEncoder().encode(addition),
        ))!;
        expect(
          String.fromCharCodes(bytes),
          contains(language == 'it' ? 'Totale' : 'Total'),
        );
        expect(String.fromCharCodes(bytes), contains('GBP'));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (language, size, scale, typography) in [
    ('en', const Size(1100, 900), 1.0, const TicketTypography()),
    ('it', const Size(320, 740), 2.0, const TicketTypography()),
    (
      'it',
      const Size(915, 412),
      1.0,
      const TicketTypography(items: 18, details: 14),
    ),
  ]) {
    testWidgets(
      'receipt rows wrap long names and amounts without revision numbers $language $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        const capture = bool.fromEnvironment('LIBRESLIP_CAPTURE_PREVIEWS');
        if (capture) {
          await (FontLoader('RobotoTicket')
                ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
                ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf')))
              .load();
        }
        final boundary = GlobalKey();
        final ticket = SavedTicket(
          id: 'receipt-additions',
          number: 1,
          createdAt: _ticket.createdAt,
          heading: 'Kitchen',
          reference: 'Table 4',
          orderNote: '',
          managedOrderId: 'open-order',
          revision: 7,
          additionLineIds: const ['long', 'maximum', 'unicode'],
          lines: const [
            TicketLine(
              id: 'long',
              name: 'Caffè con latte e una preparazione particolarmente lunga',
              quantity: 2,
              preparationNote: 'Caldo',
              price: ProductPrice(minorUnits: 125, currency: 'EUR'),
            ),
            TicketLine(
              id: 'maximum',
              name: 'Water',
              quantity: 999,
              price: ProductPrice(minorUnits: 99999999, currency: 'EUR'),
            ),
            TicketLine(
              id: 'unicode',
              name: 'Crème brûlée',
              quantity: 1,
              price: ProductPrice(minorUnits: 0, currency: 'USD'),
            ),
          ],
        );
        late TicketDocument document;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: _app(
              language,
              Builder(
                builder: (context) {
                  document = _document(
                    ticket,
                    context,
                    prices: true,
                    typography: typography,
                  );
                  return SingleChildScrollView(
                    child: Center(child: TicketPreview(document: document)),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            RegExp('revision|revisione', caseSensitive: false),
          ),
          findsNothing,
        );
        expect(
          document.lines.first.priceText,
          contains(language == 'it' ? '2,50' : '2.50'),
        );
        expect(
          document.lines.last.priceText,
          contains(language == 'it' ? '0,00' : '0.00'),
        );
        final bytes = (await tester.runAsync(
          () => const EscPosTicketEncoder().encode(document),
        ))!;
        expect(bytes, containsAllInOrder([0x1D, 0x76, 0x30, 0x00]));
        expect(String.fromCharCodes(bytes), isNot(contains('revision')));
        final pdf = (await tester.runAsync(
          () =>
              LocalTicketPdfSharer().build(document, subject: 'Receipt layout'),
        ))!;
        expect(String.fromCharCodes(pdf.take(4)), '%PDF');
        expect(ticket.revision, 7);
        expect(tester.takeException(), isNull);
        if (capture) {
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage();
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            final base =
                'build/previews/receipt-rows-$language-${size.width.toInt()}';
            await File('$base.png').writeAsBytes(png!.buffer.asUint8List());
            await File('$base.pdf').writeAsBytes(pdf);
            image.dispose();
          });
        }
      },
    );
  }

  testWidgets(
    'new reprints and PDFs use current preference; queued recovery retains its original priced bytes',
    (tester) async {
      final store = MemoryPrintJobStore();
      final transport = OutputTransport();
      final printer = PrinterController(transport);
      await printer.refresh();
      await printer.connect(printer.devices.single);
      final sharer = CapturingPdfSharer();
      final output = TicketOutputController(
        store: store,
        printer: printer,
        pdfSharer: sharer,
      );
      addTearDown(output.dispose);
      addTearDown(printer.dispose);
      await tester.pumpWidget(
        _app(
          'en',
          TicketDetailDialog(
            ticket: _ticket,
            settings: const AppSettings(printTicketPrices: true),
            output: output,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final preview = tester.widget<TicketPreview>(find.byType(TicketPreview));
      final original = await const EscPosTicketEncoder().encode(
        preview.document,
      );
      await tester.runAsync(
        () => output.printTicket(ticket: _ticket, document: preview.document),
      );
      expect(store.jobs.single.payload, original);
      await output.sharePdf(
        document: preview.document,
        subject: 'Order',
        ticketId: _ticket.id,
      );
      expect(sharer.document!.priceSummary, isNotNull);
      final queued = await store.createPrintJob(
        requestId: 'queued-price-test',
        ticketId: _ticket.id,
        payload: original,
      );
      await tester.pumpWidget(
        _app(
          'en',
          TicketDetailDialog(
            ticket: _ticket,
            settings: const AppSettings(),
            output: output,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final unpriced = tester
          .widget<TicketPreview>(find.byType(TicketPreview))
          .document;
      expect(unpriced.priceSummary, isNull);
      await output.sendQueued(queued);
      expect(
        store.jobs.firstWhere((job) => job.id == queued.id).payload,
        original,
      );
      await tester.runAsync(
        () => output.printTicket(ticket: _ticket, document: unpriced),
      );
      expect(store.jobs.first.payload, isNot(original));
      expect(store.jobs.map((job) => job.ticketId).toSet(), {_ticket.id});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Compose prints snapshotted prices and creates one ticket and one durable attempt',
    (tester) async {
      final env = await createMemoryOrderEnvironment();
      addTearDown(env.controller.dispose);
      addTearDown(env.repository.close);
      await env.controller.updateFeatureSettings(
        const OrderFeatureSettings(pricesEnabled: true),
      );
      final item = await env.repository.saveItem(
        name: 'Soup',
        price: const ProductPrice(minorUnits: 125, currency: 'EUR'),
      );
      env.controller.addCatalogueItem(item);
      env.controller.setQuantity(
        env.controller.activeDraft!.lines.single.id,
        2,
      );
      await env.controller.flushWrites();
      final settings = SettingsController(
        MemorySettingsRepository()
          ..stored = const AppSettings(
            heading: 'Kitchen',
            printTicketPrices: true,
          ),
      );
      await settings.load();
      addTearDown(settings.dispose);
      final store = MemoryPrintJobStore();
      final printer = PrinterController(OutputTransport());
      await printer.refresh();
      await printer.connect(printer.devices.single);
      final output = TicketOutputController(
        store: store,
        printer: printer,
        pdfSharer: CapturingPdfSharer(),
      );
      await output.load();
      addTearDown(printer.dispose);
      addTearDown(output.dispose);
      await tester.pumpWidget(
        LibreSlipApp(
          settings: settings,
          orders: env.controller,
          printer: printer,
          ticketOutput: output,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-2')));
      await tester.pumpAndSettle();
      final print = find.byKey(const ValueKey('print-ticket'));
      await tester.ensureVisible(print);
      await tester.pumpAndSettle();
      await tester.tap(print);
      await tester.pumpAndSettle();
      expect(env.controller.tickets, hasLength(1));
      expect(env.controller.tickets.single.lines.single.price, item.price);
      expect(store.jobs, hasLength(1));
      final bytes = String.fromCharCodes(store.jobs.single.payload);
      expect(bytes, contains('EUR 2.50'));
      expect(bytes, contains('Total'));
      expect(tester.takeException(), isNull);
    },
  );

  for (final (language, scale) in [('en', 1.0), ('it', 2.0)]) {
    testWidgets(
      'printed-price toggle is reachable and persists independently of catalogue prices $language',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final env = await createMemoryOrderEnvironment();
        addTearDown(env.controller.dispose);
        addTearDown(env.repository.close);
        final store = MemorySettingsRepository();
        final settings = SettingsController(store);
        await settings.load();
        addTearDown(settings.dispose);
        await tester.pumpWidget(
          LibreSlipApp(settings: settings, orders: env.controller),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('nav-4')));
        await tester.pumpAndSettle();
        final control = find.descendant(
          of: find.byKey(const ValueKey('toggle-ticket-prices')),
          matching: find.byType(Switch),
        );
        await tester.ensureVisible(control);
        await tester.pumpAndSettle();
        await tester.tap(control);
        await tester.pumpAndSettle();
        expect(settings.settings.printTicketPrices, isTrue);
        expect(env.controller.featureSettings.pricesEnabled, isFalse);
        final restarted = SettingsController(store);
        addTearDown(restarted.dispose);
        await restarted.load();
        expect(restarted.settings.printTicketPrices, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _app(String language, Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: Locale(language, language == 'it' ? 'IT' : 'GB'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

TicketDocument _document(
  SavedTicket ticket,
  BuildContext context, {
  bool prices = false,
  TicketTypography typography = const TicketTypography(),
}) {
  final l = AppLocalizations.of(context);
  return TicketDocument.fromTicket(
    ticket: ticket,
    fallbackHeading: l.defaultHeading,
    ticketLabel: l.ticketLabel,
    createdAt: MaterialLocalizations.of(context)
        .formatFullDate(ticket.createdAt.toLocal()),
    referenceLabel: l.orderReference,
    orderNotesLabel: l.orderNotes,
    lineNotePrefix: l.lineNoteLabel,
    footer: '',
    typography: typography,
    additionLabel: l.ticketAdditionsHeading,
    priceLabels: prices ? ticketPriceLabels(context) : null,
  );
}

final _ticket = SavedTicket(
  id: 'priced-ticket',
  number: 1,
  createdAt: DateTime.utc(2026, 10, 12),
  heading: 'Kitchen',
  reference: 'Table 4',
  orderNote: '',
  lines: const [
    TicketLine(
      id: 'soup',
      name: 'Soup',
      quantity: 2,
      price: ProductPrice(minorUnits: 125, currency: 'EUR'),
    ),
    TicketLine(
      id: 'tea',
      name: 'Tea',
      quantity: 3,
      price: ProductPrice(minorUnits: 250, currency: 'GBP'),
    ),
    TicketLine(id: 'water', name: 'Water', quantity: 3),
    TicketLine(
      id: 'zero',
      name: 'Included',
      quantity: 1,
      price: ProductPrice(minorUnits: 0, currency: 'USD'),
    ),
  ],
);
