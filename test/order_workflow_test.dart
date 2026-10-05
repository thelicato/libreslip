import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:libreslip/features/printing/application/printer_controller.dart';
import 'package:libreslip/features/printing/application/ticket_output_controller.dart';
import 'package:libreslip/features/printing/domain/print_job.dart';
import 'package:libreslip/features/printing/domain/printer_transport.dart';
import 'package:libreslip/features/settings/application/settings_controller.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';

import 'test_support.dart';

void main() {
  testWidgets(
    'reusable item to implicitly saved print ticket works end to end',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = SettingsController(MemorySettingsRepository());
      final environment = await createMemoryOrderEnvironment();
      final orders = environment.controller;
      final printer = PrinterController(_ConnectedTransport());
      final output = TicketOutputController(
        store: environment.repository,
        printer: printer,
      );
      addTearDown(settings.dispose);
      addTearDown(orders.dispose);
      addTearDown(printer.dispose);
      addTearDown(output.dispose);
      await settings.load();
      await printer.refresh();
      await output.load();
      await tester.pumpWidget(
        LibreSlipApp(
          settings: settings,
          orders: orders,
          printer: printer,
          ticketOutput: output,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pumpAndSettle();
      expect(find.text('Favourites'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('add-item')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('item-name')),
        'Mushroom toastie',
      );
      final serverSwitch = find.byKey(const ValueKey('item-send-to-server'));
      expect(tester.widget<SwitchListTile>(serverSwitch).value, isTrue);
      await tester.tap(serverSwitch);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(orders.items.single.name, 'Mushroom toastie');
      expect(orders.items.single.sendToServer, isFalse);
      expect(find.text('Local only'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav-2')));
      await tester.pumpAndSettle();
      expect(find.text('Order 1'), findsOneWidget);
      expect(find.text('Drafts'), findsNothing);
      expect(find.text('One-off item'), findsNothing);
      await tester.tap(
        find.byKey(ValueKey('compose-item-${orders.items.single.id}')),
      );
      await tester.pump();
      final lineId = orders.activeDraft!.lines.single.id;
      final lineWidth = tester
          .getSize(find.byKey(ValueKey('order-line-$lineId')))
          .width;
      final stepperWidth = tester
          .getSize(find.byKey(ValueKey('quantity-stepper-$lineId')))
          .width;
      expect(stepperWidth, lineWidth - 30);
      final draftId = orders.activeDraft!.id;
      await tester.enterText(
        find.byKey(ValueKey('reference-$draftId')),
        'Table 4',
      );
      await tester.pump();
      expect(find.text('Order title / table'), findsOneWidget);
      expect(find.text('Table 4'), findsWidgets);
      expect(find.text('Order 1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('print-ticket')));
      await tester.pumpAndSettle();

      expect(orders.tickets, hasLength(1));
      expect(output.jobs, hasLength(1));
      expect(output.jobs.single.ticketId, orders.tickets.single.id);
      expect(output.jobs.single.status, PrintJobStatus.transmitted);
      expect(orders.tickets.single.reference, 'Table 4');
      expect(orders.tickets.single.lines.single.name, 'Mushroom toastie');
      expect(find.text('Order 2'), findsOneWidget);
      expect(find.text('Table 4'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('reset-order-number')));
      await tester.pumpAndSettle();
      expect(find.text('Reset order number?'), findsOneWidget);
      expect(
        find.textContaining('Saved tickets and their print attempts'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('confirm-reset-order-number')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Order 1'), findsOneWidget);
      expect(orders.tickets, hasLength(1));

      await tester.tap(find.byKey(const ValueKey('nav-3')));
      await tester.pumpAndSettle();
      expect(find.text('Ticket 1'), findsOneWidget);
      expect(find.text('Table 4'), findsOneWidget);
      expect(find.textContaining('Mushroom toastie'), findsOneWidget);
      expect(find.text('Duplicate as draft'), findsNothing);
      await tester.tap(find.text('Ticket 1'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Table 4'),
        ),
        findsOneWidget,
      );
      expect(find.text('Saved snapshot'), findsNothing);
      expect(find.text('Duplicate as draft'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Compose blocks printing and saving while disconnected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = SettingsController(MemorySettingsRepository());
    final environment = await createMemoryOrderEnvironment();
    final orders = environment.controller;
    final printer = PrinterController(_NotConnectedTransport());
    final output = TicketOutputController(
      store: environment.repository,
      printer: printer,
    );
    addTearDown(settings.dispose);
    addTearDown(orders.dispose);
    addTearDown(printer.dispose);
    addTearDown(output.dispose);
    await settings.load();
    await output.load();
    await orders.saveItem(name: 'Tea');
    orders.addCatalogueItem(orders.items.single);

    await tester.pumpWidget(
      LibreSlipApp(
        settings: settings,
        orders: orders,
        printer: printer,
        ticketOutput: output,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();

    expect(
      find.text('Connect a printer in Settings before printing.'),
      findsOneWidget,
    );
    final printButton = find.byKey(const ValueKey('print-ticket'));
    expect(tester.widget<FilledButton>(printButton).onPressed, isNull);
    expect(orders.tickets, isEmpty);
    expect(output.jobs, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'it']) {
    testWidgets(
      'printer toggle enables offline orders and additions in $language',
      (tester) async {
        tester.view.physicalSize = const Size(520, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = SettingsController(
          MemorySettingsRepository()..stored = AppSettings(language: language),
        );
        final environment = await createMemoryOrderEnvironment();
        final orders = environment.controller;
        final printer = PrinterController(_NotConnectedTransport());
        final output = TicketOutputController(
          store: environment.repository,
          printer: printer,
        );
        addTearDown(settings.dispose);
        addTearDown(orders.dispose);
        addTearDown(printer.dispose);
        addTearDown(output.dispose);
        await settings.load();
        await output.load();
        await orders.updateFeatureSettings(
          const OrderFeatureSettings(managedOrdersEnabled: true),
        );
        await orders.saveItem(name: 'Tea');
        orders.addCatalogueItem(orders.items.single);
        await tester.pumpWidget(
          LibreSlipApp(
            settings: settings,
            orders: orders,
            printer: printer,
            ticketOutput: output,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('nav-4')));
        await tester.pumpAndSettle();
        final toggle = find.byKey(const ValueKey('toggle-printer-required'));
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(settings.settings.printerConnectionRequired, isFalse);
        await tester.tap(find.byKey(const ValueKey('nav-2')));
        await tester.pumpAndSettle();
        expect(
          find.text(language == 'it' ? 'Salva ordine' : 'Save order'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('print-ticket')));
        await tester.pumpAndSettle();
        expect(orders.tickets.single.lines.single.name, 'Tea');
        expect(orders.managedOrders, hasLength(1));
        expect(output.jobs, isEmpty);
        expect(await environment.repository.loadPrintJobs(), isEmpty);
        expect(
          find.text(
            language == 'it'
                ? 'Ordine salvato senza stampa.'
                : 'Order saved without printing.',
          ),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(
          await orders.beginAddition(orders.managedOrders.single.id),
          isTrue,
        );
        orders.addCatalogueItem(orders.items.single);
        await tester.pumpAndSettle();
        expect(
          find.text(language == 'it' ? 'Salva aggiunte' : 'Save additions'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('print-ticket')));
        await tester.pumpAndSettle();
        expect(orders.tickets, hasLength(2));
        expect(orders.managedOrders.single.revision, 2);
        expect(orders.managedOrders.single.lines, hasLength(2));
        expect(output.jobs, isEmpty);
        await tester.tap(find.byKey(const ValueKey('nav-4')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        orders.addCatalogueItem(orders.items.single);
        await tester.tap(find.byKey(const ValueKey('nav-2')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(find.byKey(const ValueKey('print-ticket')))
              .onPressed,
          isNull,
        );
        expect(orders.tickets, hasLength(2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('printer switch is reachable on a narrow phone at doubled text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final settings = SettingsController(
      MemorySettingsRepository()..stored = const AppSettings(language: 'it'),
    );
    final environment = await createMemoryOrderEnvironment();
    addTearDown(settings.dispose);
    addTearDown(environment.controller.dispose);
    await settings.load();
    await tester.pumpWidget(
      LibreSlipApp(settings: settings, orders: environment.controller),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-4')));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('toggle-printer-required'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    final control = find.descendant(of: toggle, matching: find.byType(Switch));
    expect(tester.getRect(control).top, greaterThan(0));
    expect(tester.getRect(control).bottom, lessThan(660));
    await tester.tap(control);
    await tester.pumpAndSettle();
    expect(settings.settings.printerConnectionRequired, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('optional printer saves on a device without a printer adapter', (
    tester,
  ) async {
    final settings = SettingsController(
      MemorySettingsRepository()
        ..stored = const AppSettings(printerConnectionRequired: false),
    );
    final environment = await createMemoryOrderEnvironment();
    addTearDown(settings.dispose);
    addTearDown(environment.controller.dispose);
    await settings.load();
    await environment.controller.saveItem(name: 'Water');
    environment.controller.addCatalogueItem(
      environment.controller.items.single,
    );
    await tester.pumpWidget(
      LibreSlipApp(settings: settings, orders: environment.controller),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('print-ticket')));
    await tester.pumpAndSettle();
    expect(environment.controller.tickets, hasLength(1));
    expect(await environment.repository.loadPrintJobs(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Compact Compose keeps order controls together and print always reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final settings = SettingsController(
        MemorySettingsRepository()
          ..stored = const AppSettings(
            compactCompose: true,
            printerConnectionRequired: false,
          ),
      );
      final environment = await createMemoryOrderEnvironment();
      final orders = environment.controller;
      final printer = PrinterController(_ConnectedTransport());
      final output = TicketOutputController(
        store: environment.repository,
        printer: printer,
      );
      addTearDown(settings.dispose);
      addTearDown(orders.dispose);
      addTearDown(printer.dispose);
      addTearDown(output.dispose);
      await settings.load();
      await printer.refresh();
      await output.load();
      await orders.saveItem(name: 'Mushroom toastie');

      await tester.pumpWidget(
        LibreSlipApp(
          settings: settings,
          orders: orders,
          printer: printer,
          ticketOutput: output,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-2')));
      await tester.pumpAndSettle();

      final itemId = orders.items.single.id;
      final quantityFinder = find.byKey(ValueKey('compact-quantity-$itemId'));
      final plusFinder = find.byKey(ValueKey('compose-item-$itemId'));
      final minusFinder = find.byKey(ValueKey('compact-minus-$itemId'));
      expect(
        find.byKey(const ValueKey('compact-compose-panel')),
        findsOneWidget,
      );
      expect(find.text('Add items'), findsNothing);
      expect(tester.widget<Text>(quantityFinder).data, '0');
      expect(orders.activeDraft!.lines, isEmpty);

      final printFinder = find.byKey(const ValueKey('print-ticket'));
      expect(printFinder, findsOneWidget);
      expect(tester.getBottomRight(printFinder).dy, lessThan(740));
      expect(tester.widget<FilledButton>(printFinder).onPressed, isNull);

      await tester.ensureVisible(plusFinder);
      await tester.pumpAndSettle();
      await tester.tap(plusFinder);
      await tester.pump();
      final lineId = orders.activeDraft!.lines.single.id;
      orders.setPreparationNote(lineId, 'No onion');
      await tester.pump();
      await tester.tap(plusFinder);
      await tester.pump();
      expect(orders.activeDraft!.lines, hasLength(1));
      expect(orders.activeDraft!.lines.single.quantity, 2);
      expect(tester.widget<Text>(quantityFinder).data, '2');

      await tester.tap(minusFinder);
      await tester.pump();
      await tester.tap(minusFinder);
      await tester.pump();
      expect(orders.activeDraft!.lines, isEmpty);
      expect(tester.widget<Text>(quantityFinder).data, '0');

      await tester.tap(plusFinder);
      await tester.pump();
      await tester.tap(plusFinder);
      await tester.pump();
      expect(orders.activeDraft!.lines.single.quantity, 2);
      await tester.tap(printFinder);
      await tester.pumpAndSettle();
      expect(orders.tickets, hasLength(1));
      expect(output.jobs, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ticket deletion confirmations preserve the current order number',
    (tester) async {
      tester.view.physicalSize = const Size(520, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = SettingsController(MemorySettingsRepository());
      final environment = await createMemoryOrderEnvironment();
      final orders = environment.controller;
      addTearDown(settings.dispose);
      addTearDown(orders.dispose);
      await settings.load();
      await orders.saveItem(name: 'Tea');
      orders.addCatalogueItem(orders.items.single);
      await orders.saveActiveTicket(heading: 'Kitchen');
      orders.addCatalogueItem(orders.items.single);
      await orders.saveActiveTicket(heading: 'Kitchen');
      expect(orders.nextOrderNumber, 3);

      await tester.pumpWidget(LibreSlipApp(settings: settings, orders: orders));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-3')));
      await tester.pumpAndSettle();

      final ticketId = orders.tickets.first.id;
      await tester.tap(find.byKey(ValueKey('delete-ticket-$ticketId')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('current order number will not change'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('confirm-delete-ticket')));
      await tester.pumpAndSettle();
      expect(orders.tickets, hasLength(1));
      expect(orders.nextOrderNumber, 3);

      await tester.tap(find.byKey(const ValueKey('delete-all-tickets')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('order number will not change'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('confirm-delete-all-tickets')),
      );
      await tester.pumpAndSettle();
      expect(orders.tickets, isEmpty);
      expect(orders.nextOrderNumber, 3);
      expect(find.text('No saved tickets yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _NotConnectedTransport implements PrinterTransport {
  @override
  Future<void> connect(String address) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<BluetoothHostState> getState() async =>
      const BluetoothHostState(status: BluetoothHostStatus.ready);

  @override
  Future<void> openBluetoothSettings() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<int> send(Uint8List bytes, {int chunkSize = 256}) async =>
      bytes.length;
}

class _ConnectedTransport implements PrinterTransport {
  @override
  Future<void> connect(String address) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<BluetoothHostState> getState() async => const BluetoothHostState(
    status: BluetoothHostStatus.ready,
    devices: [PairedPrinter(name: "NT-1809DD", address: "00:11:22:33:44:55")],
    connectedAddress: "00:11:22:33:44:55",
  );

  @override
  Future<void> openBluetoothSettings() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<int> send(Uint8List bytes, {int chunkSize = 256}) async =>
      bytes.length;
}
