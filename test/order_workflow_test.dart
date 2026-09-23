import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
import 'package:libreslip/features/printing/application/printer_controller.dart';
import 'package:libreslip/features/printing/application/ticket_output_controller.dart';
import 'package:libreslip/features/printing/domain/print_job.dart';
import 'package:libreslip/features/printing/domain/printer_transport.dart';
import 'package:libreslip/features/settings/application/settings_controller.dart';

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
      final printer = PrinterController(_DisconnectedTransport());
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
      expect(find.text('Favourites'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('add-item')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('item-name')),
        'Mushroom toastie',
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(orders.items.single.name, 'Mushroom toastie');
      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pumpAndSettle();
      expect(find.text('Drafts'), findsNothing);
      expect(find.text('One-off item'), findsNothing);
      await tester.tap(
        find.byKey(ValueKey('compose-item-${orders.items.single.id}')),
      );
      await tester.pump();
      final draftId = orders.activeDraft!.id;
      await tester.enterText(
        find.byKey(ValueKey('reference-$draftId')),
        'Table 4',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('print-ticket')));
      await tester.pumpAndSettle();

      expect(orders.tickets, hasLength(1));
      expect(output.jobs, hasLength(1));
      expect(output.jobs.single.ticketId, orders.tickets.single.id);
      expect(output.jobs.single.status, PrintJobStatus.queued);
      expect(orders.tickets.single.reference, 'Table 4');
      expect(orders.tickets.single.lines.single.name, 'Mushroom toastie');

      await tester.tap(find.byKey(const ValueKey('nav-3')));
      await tester.pumpAndSettle();
      expect(find.text('Ticket 1'), findsOneWidget);
      expect(find.textContaining('Mushroom toastie'), findsOneWidget);
      expect(find.text('Duplicate as draft'), findsNothing);
      await tester.tap(find.text('Ticket 1'));
      await tester.pumpAndSettle();
      expect(find.text('Saved snapshot'), findsNothing);
      expect(find.text('Duplicate as draft'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _DisconnectedTransport implements PrinterTransport {
  @override
  Future<void> connect(String address) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<BluetoothHostState> getState() async =>
      const BluetoothHostState(status: BluetoothHostStatus.ready, devices: []);

  @override
  Future<void> openBluetoothSettings() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<int> send(Uint8List bytes, {int chunkSize = 256}) async =>
      bytes.length;
}
