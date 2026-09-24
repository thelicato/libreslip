import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:libreslip/features/printing/application/esc_pos_ticket_encoder.dart';
import 'package:libreslip/features/printing/application/printer_controller.dart';
import 'package:libreslip/features/printing/application/ticket_output_controller.dart';
import 'package:libreslip/features/printing/application/ticket_pdf_sharer.dart';
import 'package:libreslip/features/printing/domain/print_job.dart';
import 'package:libreslip/features/printing/domain/printer_transport.dart';
import 'package:libreslip/features/printing/domain/ticket_document.dart';
import 'package:libreslip/features/printing/domain/ticket_typography.dart';
import 'package:libreslip/features/printing/presentation/ticket_detail_dialog.dart';
import 'package:libreslip/features/printing/presentation/ticket_preview.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';
import 'package:libreslip/l10n/generated/app_localizations.dart';

void main() {
  testWidgets(
    '58 mm encoder preserves Italian text, rasterises unsupported text and never cuts',
    (tester) async {
      const encoder = EscPosTicketEncoder();
      final italian = await encoder.encode(_document(name: 'Caffè più tè'));
      expect(_contains(italian, [0x1B, 0x74, 0x13]), isTrue);
      expect(_contains(italian, [0x1D, 0x56]), isFalse);
      expect(_contains(italian, [0x1B, 0x70]), isFalse);
      expect(_contains(italian, [0x1B, 0x64, 0x04]), isTrue);

      final raster = (await tester.runAsync(
        () => encoder.encode(_document(name: 'Привет')),
      ))!;
      expect(_contains(raster, [0x1D, 0x76, 0x30, 0x00]), isTrue);
      expect(raster.length, greaterThan(italian.length));

      final custom = (await tester.runAsync(
        () => encoder.encode(
          _document(typography: const TicketTypography(items: 18)),
        ),
      ))!;
      expect(_contains(custom, [0x1D, 0x76, 0x30, 0x00]), isTrue);
      expect(custom.length, greaterThan(italian.length));
    },
  );

  testWidgets(
    'offline PDF builder creates a 58 mm document with bundled fonts',
    (tester) async {
      final bytes = (await tester.runAsync(
        () => LocalTicketPdfSharer().build(
          _document(
            name: 'Caffè più tè',
            typography: const TicketTypography(
              heading: 20,
              details: 10,
              items: 12,
              notes: 9,
              footer: 11,
            ),
          ),
          subject: 'LibreSlip ticket 7',
        ),
      ))!;

      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    },
  );

  testWidgets('ticket preview uses every configured text size', (tester) async {
    const typography = TicketTypography(
      heading: 20,
      details: 10,
      items: 12,
      notes: 9,
      footer: 11,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: SingleChildScrollView(
          child: TicketPreview(
            document: TicketDocument(
              heading: 'Bottega',
              ticketLabel: 'ORDER TICKET',
              ticketNumber: '7',
              createdAt: '23 September 2026 12:00',
              referenceLabel: 'Reference',
              reference: 'Table 4',
              orderNotesLabel: 'Order notes',
              orderNote: 'Together',
              lineNotePrefix: 'Note',
              footer: 'Prepared with care',
              typography: typography,
              lines: [
                TicketDocumentLine(
                  quantity: 2,
                  name: 'Toastie',
                  note: 'No onion',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    double sizeOf(String text) =>
        tester.widget<Text>(find.text(text)).style!.fontSize!;
    expect(sizeOf('Bottega'), 20 * TicketTypography.previewScale);
    expect(sizeOf('ORDER TICKET #7'), 10 * TicketTypography.previewScale);
    expect(sizeOf('Toastie'), 12 * TicketTypography.previewScale);
    expect(sizeOf('Note: No onion'), 9 * TicketTypography.previewScale);
    expect(sizeOf('Prepared with care'), 11 * TicketTypography.previewScale);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'saved ticket preview prints once and remains usable on a phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final printer = PrinterController(OutputTransport());
      await printer.refresh();
      await printer.connect(printer.devices.single);
      final output = TicketOutputController(
        store: MemoryPrintJobStore(),
        printer: printer,
        pdfSharer: CapturingPdfSharer(),
      );
      addTearDown(printer.dispose);
      addTearDown(output.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en', 'GB'),
          supportedLocales: const [Locale('en', 'GB'), Locale('it', 'IT')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: TicketDetailDialog(
              ticket: _ticket,
              settings: const AppSettings(footer: 'Prepared with care'),
              output: output,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ORDER TICKET #7'), findsOneWidget);
      expect(find.text('Print ticket'), findsOneWidget);
      final shareButton = find.widgetWithText(OutlinedButton, 'Share PDF');
      final printButton = find.byKey(const ValueKey('print-ticket-ticket-7'));
      final closeButton = find.widgetWithText(TextButton, 'Close');
      final shareRect = tester.getRect(shareButton);
      final printRect = tester.getRect(printButton);
      final closeRect = tester.getRect(closeButton);
      expect(shareRect.left, printRect.left);
      expect(printRect.left, closeRect.left);
      expect(shareRect.right, printRect.right);
      expect(printRect.right, closeRect.right);
      expect(shareRect.height, greaterThanOrEqualTo(48));
      expect(printRect.height, greaterThanOrEqualTo(48));
      expect(closeRect.height, greaterThanOrEqualTo(48));
      expect(shareRect.left, greaterThanOrEqualTo(24));
      expect(390 - shareRect.right, greaterThanOrEqualTo(24));
      expect(printRect.top - shareRect.bottom, 10);
      expect(closeRect.top - printRect.bottom, 10);
      await tester.tap(printButton);
      await tester.pumpAndSettle();

      expect(find.text('Ticket bytes sent'), findsOneWidget);
      expect(find.text('Print again'), findsOneWidget);
      expect(output.jobs, hasLength(1));
      expect(output.jobs.single.status, PrintJobStatus.transmitted);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saved ticket print is disabled while disconnected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final printer = PrinterController(OutputTransport());
    final output = TicketOutputController(
      store: MemoryPrintJobStore(),
      printer: printer,
      pdfSharer: CapturingPdfSharer(),
    );
    addTearDown(printer.dispose);
    addTearDown(output.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'GB'),
        supportedLocales: const [Locale('en', 'GB'), Locale('it', 'IT')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: TicketDetailDialog(
            ticket: _ticket,
            settings: const AppSettings(),
            output: output,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Connect a printer in Settings before printing.'),
      findsOneWidget,
    );
    final printButton = find.byKey(const ValueKey('print-ticket-ticket-7'));
    expect(tester.widget<FilledButton>(printButton).onPressed, isNull);
    expect(output.jobs, isEmpty);
    expect(tester.takeException(), isNull);
  });

  test(
    'disconnected output creates no attempt and retains legacy queues',
    () async {
      final store = MemoryPrintJobStore();
      final transport = OutputTransport();
      final printer = PrinterController(transport);
      final output = TicketOutputController(
        store: store,
        printer: printer,
        pdfSharer: CapturingPdfSharer(),
      );
      addTearDown(printer.dispose);
      addTearDown(output.dispose);

      expect(
        await output.printTicket(ticket: _ticket, document: _document()),
        TicketPrintResult.notConnected,
      );
      expect(store.jobs, isEmpty);
      expect(transport.sendCalls, 0);

      final legacy = await store.createPrintJob(
        requestId: 'legacy-queue',
        ticketId: _ticket.id,
        payload: Uint8List.fromList([1, 2, 3]),
      );
      expect(await output.sendQueued(legacy), TicketPrintResult.notConnected);
      expect(store.jobs.single.status, PrintJobStatus.queued);

      await printer.refresh();
      await printer.connect(printer.devices.single);
      expect(await output.sendQueued(legacy), TicketPrintResult.transmitted);
      expect(store.jobs.single.status, PrintJobStatus.transmitted);
      expect(transport.sendCalls, 1);
    },
  );

  test(
    'an uncertain transmission is never retried without a new explicit attempt',
    () async {
      final store = MemoryPrintJobStore();
      final transport = OutputTransport()..failSend = true;
      final printer = PrinterController(transport);
      final output = TicketOutputController(
        store: store,
        printer: printer,
        pdfSharer: CapturingPdfSharer(),
      );
      addTearDown(printer.dispose);
      addTearDown(output.dispose);
      await printer.refresh();
      await printer.connect(printer.devices.single);

      expect(
        await output.printTicket(ticket: _ticket, document: _document()),
        TicketPrintResult.uncertain,
      );
      final uncertain = store.jobs.single;
      expect(uncertain.status, PrintJobStatus.uncertain);
      expect(transport.sendCalls, 1);

      expect(await output.sendQueued(uncertain), TicketPrintResult.failed);
      expect(transport.sendCalls, 1);
      expect(store.jobs, hasLength(1));
    },
  );

  test('PDF sharing receives the same immutable ticket document', () async {
    final sharer = CapturingPdfSharer();
    final output = TicketOutputController(
      store: MemoryPrintJobStore(),
      printer: PrinterController(OutputTransport()),
      pdfSharer: sharer,
    );
    addTearDown(output.dispose);
    final document = _document(name: 'Caffè');

    expect(
      await output.sharePdf(
        document: document,
        subject: 'Ticket 7',
        ticketId: _ticket.id,
      ),
      isTrue,
    );
    expect(sharer.document, same(document));
    expect(sharer.subject, 'Ticket 7');
  });
}

final _ticket = SavedTicket(
  id: 'ticket-7',
  number: 7,
  createdAt: DateTime.utc(2026, 9, 23, 12),
  heading: 'Bottega',
  reference: 'Table 4',
  orderNote: 'Together',
  lines: [
    TicketLine(
      id: 'line-1',
      name: 'Toastie',
      quantity: 2,
      preparationNote: 'No onion',
    ),
  ],
);

TicketDocument _document({
  String name = 'Toastie',
  TicketTypography typography = const TicketTypography(),
}) => TicketDocument(
  heading: 'Bottega',
  ticketLabel: 'ORDER TICKET',
  ticketNumber: '7',
  createdAt: '23 September 2026 12:00',
  referenceLabel: 'Reference',
  reference: 'Table 4',
  orderNotesLabel: 'Order notes',
  orderNote: 'Together',
  lineNotePrefix: 'Note',
  footer: 'Prepared with care',
  typography: typography,
  lines: [TicketDocumentLine(quantity: 2, name: name, note: 'No onion')],
);

bool _contains(Uint8List bytes, List<int> pattern) {
  for (var index = 0; index <= bytes.length - pattern.length; index++) {
    var matches = true;
    for (var offset = 0; offset < pattern.length; offset++) {
      if (bytes[index + offset] != pattern[offset]) matches = false;
    }
    if (matches) return true;
  }
  return false;
}

class OutputTransport implements PrinterTransport {
  bool failSend = false;
  int sendCalls = 0;
  bool connected = false;

  @override
  Future<void> connect(String address) async {
    connected = true;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }

  @override
  Future<BluetoothHostState> getState() async => BluetoothHostState(
    status: BluetoothHostStatus.ready,
    devices: const [
      PairedPrinter(name: 'NT-1809DD', address: '00:11:22:33:44:55'),
    ],
    connectedAddress: connected ? '00:11:22:33:44:55' : null,
  );

  @override
  Future<void> openBluetoothSettings() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<int> send(Uint8List bytes, {int chunkSize = 256}) async {
    sendCalls++;
    if (failSend) {
      throw const PrinterTransportException(
        code: 'sendFailed',
        bytesWritten: 0,
      );
    }
    return bytes.length;
  }
}

class MemoryPrintJobStore implements PrintJobStore {
  final List<PrintJob> jobs = [];

  @override
  Future<PrintJob> createPrintJob({
    required String requestId,
    required String ticketId,
    required Uint8List payload,
  }) async {
    for (final job in jobs) {
      if (job.requestId == requestId) return job;
    }
    final now = DateTime.now().toUtc();
    final job = PrintJob(
      id: 'job-${jobs.length + 1}',
      requestId: requestId,
      ticketId: ticketId,
      ticketNumber: 7,
      createdAt: now,
      updatedAt: now,
      status: PrintJobStatus.queued,
      payload: payload,
    );
    jobs.insert(0, job);
    return job;
  }

  @override
  Future<List<PrintJob>> loadPrintJobs({String? ticketId}) async => [
    for (final job in jobs)
      if (ticketId == null || job.ticketId == ticketId) job,
  ];

  @override
  Future<PrintJob> markPrintJobOutcome(
    String id, {
    required PrintJobStatus status,
    String? errorCode,
  }) async {
    final index = jobs.indexWhere((job) => job.id == id);
    final changed = _copy(jobs[index], status: status, errorCode: errorCode);
    jobs[index] = changed;
    return changed;
  }

  @override
  Future<PrintJob> markPrintJobSending(
    String id, {
    required String printerAddress,
    required String printerName,
  }) async {
    final index = jobs.indexWhere((job) => job.id == id);
    if (jobs[index].status != PrintJobStatus.queued) {
      throw StateError('Not queued');
    }
    final changed = _copy(
      jobs[index],
      status: PrintJobStatus.sending,
      printerAddress: printerAddress,
      printerName: printerName,
    );
    jobs[index] = changed;
    return changed;
  }

  PrintJob _copy(
    PrintJob job, {
    required PrintJobStatus status,
    String? printerAddress,
    String? printerName,
    String? errorCode,
  }) => PrintJob(
    id: job.id,
    requestId: job.requestId,
    ticketId: job.ticketId,
    ticketNumber: job.ticketNumber,
    createdAt: job.createdAt,
    updatedAt: DateTime.now().toUtc(),
    status: status,
    payload: job.payload,
    printerAddress: printerAddress ?? job.printerAddress,
    printerName: printerName ?? job.printerName,
    errorCode: errorCode,
  );
}

class CapturingPdfSharer implements TicketPdfSharer {
  TicketDocument? document;
  String? subject;

  @override
  Future<void> share(TicketDocument document, {required String subject}) async {
    this.document = document;
    this.subject = subject;
  }
}
