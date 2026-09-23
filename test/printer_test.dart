import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/printing/application/esc_pos_test_ticket.dart';
import 'package:libreslip/features/printing/application/printer_controller.dart';
import 'package:libreslip/features/printing/domain/printer_transport.dart';
import 'package:libreslip/features/printing/presentation/printer_setup_card.dart';
import 'package:libreslip/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('printer setup remains usable on a small phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = PrinterController(FakePrinterTransport());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'GB'),
        supportedLocales: const [Locale('en', 'GB'), Locale('it', 'IT')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: PrinterSetupCard(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('NT-1809DD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('connection test ticket initialises, selects PC858 and never cuts or opens a drawer', () {
    final bytes = EscPosTestTicket.build();

    expect(bytes.take(2), [0x1B, 0x40]);
    expect(_contains(bytes, [0x1B, 0x74, 0x13]), isTrue);
    expect(_contains(bytes, [0x1D, 0x56]), isFalse);
    expect(_contains(bytes, [0x1B, 0x70]), isFalse);
    expect(_contains(bytes, [0x1B, 0x64, 0x04]), isTrue);
  });

  test('controller lists paired devices, connects and reports sent bytes as unconfirmed', () async {
    final transport = FakePrinterTransport();
    final controller = PrinterController(transport);
    addTearDown(controller.dispose);

    await controller.refresh();
    expect(controller.hostStatus, BluetoothHostStatus.ready);
    expect(controller.devices.single.name, 'NT-1809DD');

    expect(await controller.connect(controller.devices.single), isTrue);
    expect(controller.connected, isTrue);
    expect(await controller.printTestTicket(), TestPrintOutcome.sent);
    expect(transport.lastBytes, isNotEmpty);
  });

  test(
    'transport send failure is uncertain and never retried automatically',
    () async {
      final transport = FakePrinterTransport()..failAfterBytes = 0;
      final controller = PrinterController(transport);
      addTearDown(controller.dispose);
      await controller.refresh();
      await controller.connect(controller.devices.single);

      expect(await controller.printTestTicket(), TestPrintOutcome.uncertain);
      expect(transport.sendCalls, 1);
      expect(controller.connected, isFalse);
    },
  );

  test(
    'permission denial remains recoverable through an explicit refresh',
    () async {
      final transport = FakePrinterTransport()
        ..state = const BluetoothHostState(
          status: BluetoothHostStatus.permissionRequired,
        )
        ..grantPermission = false;
      final controller = PrinterController(transport);
      addTearDown(controller.dispose);

      await controller.refresh();
      expect(controller.hostStatus, BluetoothHostStatus.permissionRequired);
      await controller.requestPermission();
      expect(controller.hostStatus, BluetoothHostStatus.permissionRequired);

      transport
        ..grantPermission = true
        ..state = const BluetoothHostState(status: BluetoothHostStatus.ready);
      await controller.requestPermission();
      expect(controller.hostStatus, BluetoothHostStatus.ready);
    },
  );
}

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

class FakePrinterTransport implements PrinterTransport {
  BluetoothHostState state = const BluetoothHostState(
    status: BluetoothHostStatus.ready,
    devices: [PairedPrinter(name: 'NT-1809DD', address: '00:11:22:33:44:55')],
  );
  bool grantPermission = true;
  int? failAfterBytes;
  int sendCalls = 0;
  Uint8List lastBytes = Uint8List(0);
  String? connectedAddress;

  @override
  Future<void> connect(String address) async {
    connectedAddress = address;
    state = BluetoothHostState(
      status: BluetoothHostStatus.ready,
      devices: state.devices,
      connectedAddress: address,
    );
  }

  @override
  Future<void> disconnect() async {
    connectedAddress = null;
  }

  @override
  Future<BluetoothHostState> getState() async => state;

  @override
  Future<void> openBluetoothSettings() async {}

  @override
  Future<bool> requestPermission() async => grantPermission;

  @override
  Future<int> send(Uint8List bytes, {int chunkSize = 256}) async {
    sendCalls++;
    lastBytes = bytes;
    final partial = failAfterBytes;
    if (partial != null) {
      throw PrinterTransportException(
        code: 'sendFailed',
        bytesWritten: partial,
      );
    }
    return bytes.length;
  }
}
