import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
import 'package:libreslip/features/printing/application/printer_controller.dart';
import 'package:libreslip/features/printing/domain/printer_transport.dart';
import 'package:libreslip/features/settings/application/settings_controller.dart';

import 'test_support.dart';

void main() {
  testWidgets('overview shows saved-ticket statistics and date controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = SettingsController(MemorySettingsRepository());
    final orders = await createMemoryOrders();
    addTearDown(settings.dispose);
    addTearDown(orders.dispose);
    await settings.load();
    await orders.saveItem(name: 'Toastie');
    orders.addCatalogueItem(orders.items.single);
    orders.setQuantity(orders.activeDraft!.lines.single.id, 3);
    await orders.flushWrites();
    await orders.saveActiveTicket(heading: 'Kitchen');

    await tester.pumpWidget(LibreSlipApp(settings: settings, orders: orders));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('statistics-start-date')), findsOneWidget);
    expect(find.byKey(const ValueKey('statistics-end-date')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('statistic-tickets')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('statistic-items')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('statistic-average')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    final breakdown = find.byKey(const ValueKey('item-statistics-breakdown'));
    expect(
      find.descendant(of: breakdown, matching: find.text('Toastie')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: breakdown, matching: find.text('3')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('overview can reveal a longer item breakdown', (tester) async {
    tester.view.physicalSize = const Size(520, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = SettingsController(MemorySettingsRepository());
    final orders = await createMemoryOrders();
    addTearDown(settings.dispose);
    addTearDown(orders.dispose);
    await settings.load();
    for (var index = 0; index < 9; index++) {
      await orders.saveItem(name: 'Item $index');
    }
    for (final item in orders.items) {
      orders.addCatalogueItem(item);
    }
    await orders.flushWrites();
    await orders.saveActiveTicket(heading: 'Kitchen');

    await tester.pumpWidget(LibreSlipApp(settings: settings, orders: orders));
    await tester.pumpAndSettle();

    expect(find.text('Item 8'), findsNothing);
    final toggle = find.byKey(const ValueKey('toggle-item-statistics'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.text('Item 8'), findsOneWidget);
    expect(find.text('Show fewer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('overview reports connection changes and optional battery data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = SettingsController(MemorySettingsRepository());
    final orders = await createMemoryOrders();
    final transport = _DashboardPrinterTransport();
    final printer = PrinterController(transport);
    addTearDown(settings.dispose);
    addTearDown(orders.dispose);
    addTearDown(printer.dispose);
    await settings.load();

    await tester.pumpWidget(
      LibreSlipApp(settings: settings, orders: orders, printer: printer),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Connected to NETUM NT-1809DD'), findsOneWidget);
    expect(find.text('73%'), findsOneWidget);

    transport.state = const BluetoothHostState(
      status: BluetoothHostStatus.ready,
      devices: [
        PairedPrinter(name: 'NETUM NT-1809DD', address: '00:11:22:33:44:55'),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('refresh-printer-status')));
    await tester.pumpAndSettle();

    expect(find.text('Not connected'), findsOneWidget);
    expect(
      find.text('Not reported by this printer. Check its battery indicator.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _DashboardPrinterTransport implements PrinterTransport {
  BluetoothHostState state = const BluetoothHostState(
    status: BluetoothHostStatus.ready,
    devices: [
      PairedPrinter(name: 'NETUM NT-1809DD', address: '00:11:22:33:44:55'),
    ],
    connectedAddress: '00:11:22:33:44:55',
    batteryPercentage: 73,
  );

  @override
  Future<void> connect(String address) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<BluetoothHostState> getState() async => state;

  @override
  Future<void> openBluetoothSettings() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<int> send(Uint8List bytes, {int chunkSize = 256}) async =>
      bytes.length;
}
