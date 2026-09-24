import 'package:flutter/foundation.dart';

import '../domain/printer_transport.dart';
import 'esc_pos_test_ticket.dart';

enum PrinterOperation {
  idle,
  refreshing,
  requestingPermission,
  connecting,
  sending,
}

enum PrinterTransmissionOutcome { transmitted, failed, uncertain }

enum TestPrintOutcome { none, sent, failed, uncertain }

class PrinterController extends ChangeNotifier {
  PrinterController(this._transport);

  final PrinterTransport _transport;

  BluetoothHostStatus hostStatus = BluetoothHostStatus.ready;
  List<PairedPrinter> devices = const [];
  String? connectedAddress;
  int? batteryPercentage;
  String? connectingAddress;
  PrinterOperation operation = PrinterOperation.idle;
  TestPrintOutcome testOutcome = TestPrintOutcome.none;
  String? lastErrorCode;

  bool get busy => operation != PrinterOperation.idle;
  bool get connected => connectedAddress != null;

  PairedPrinter? get connectedPrinter {
    final address = connectedAddress;
    if (address == null) return null;
    for (final device in devices) {
      if (device.address == address) return device;
    }
    return PairedPrinter(name: address, address: address);
  }

  Future<void> refresh() async {
    if (busy) return;
    operation = PrinterOperation.refreshing;
    lastErrorCode = null;
    notifyListeners();
    try {
      final state = await _transport.getState();
      _applyState(state);
    } on PrinterTransportException catch (error) {
      lastErrorCode = error.code;
    } catch (_) {
      lastErrorCode = 'unavailable';
    } finally {
      operation = PrinterOperation.idle;
      notifyListeners();
    }
  }

  Future<void> requestPermission() async {
    if (busy) return;
    operation = PrinterOperation.requestingPermission;
    lastErrorCode = null;
    notifyListeners();
    try {
      final granted = await _transport.requestPermission();
      if (!granted) hostStatus = BluetoothHostStatus.permissionRequired;
    } on PrinterTransportException catch (error) {
      lastErrorCode = error.code;
    } finally {
      operation = PrinterOperation.idle;
      notifyListeners();
    }
    await refresh();
  }

  Future<void> openBluetoothSettings() => _transport.openBluetoothSettings();

  Future<bool> connect(PairedPrinter device) async {
    if (busy) return false;
    operation = PrinterOperation.connecting;
    connectingAddress = device.address;
    lastErrorCode = null;
    testOutcome = TestPrintOutcome.none;
    notifyListeners();
    try {
      await _transport.connect(device.address);
      connectedAddress = device.address;
      batteryPercentage = null;
      try {
        _applyState(await _transport.getState());
        connectedAddress ??= device.address;
      } catch (_) {
        // The established socket remains usable even if status refresh fails.
      }
      return true;
    } on PrinterTransportException catch (error) {
      lastErrorCode = error.code;
      connectedAddress = null;
      batteryPercentage = null;
      return false;
    } catch (_) {
      lastErrorCode = 'connectionFailed';
      connectedAddress = null;
      batteryPercentage = null;
      return false;
    } finally {
      operation = PrinterOperation.idle;
      connectingAddress = null;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (busy) return;
    lastErrorCode = null;
    try {
      await _transport.disconnect();
    } on PrinterTransportException catch (error) {
      lastErrorCode = error.code;
    } finally {
      connectedAddress = null;
      batteryPercentage = null;
      testOutcome = TestPrintOutcome.none;
      notifyListeners();
    }
  }

  Future<PrinterTransmissionOutcome> transmit(Uint8List bytes) async {
    if (busy || !connected || bytes.isEmpty) {
      lastErrorCode = 'notConnected';
      notifyListeners();
      return PrinterTransmissionOutcome.failed;
    }
    operation = PrinterOperation.sending;
    lastErrorCode = null;
    notifyListeners();
    try {
      final written = await _transport.send(bytes);
      if (written != bytes.length) {
        lastErrorCode = 'sendFailed';
        await _dropConnection();
        return PrinterTransmissionOutcome.uncertain;
      }
      return PrinterTransmissionOutcome.transmitted;
    } on PrinterTransportException catch (error) {
      lastErrorCode = error.code;
      await _dropConnection();
      return error.code == 'sendFailed' || error.bytesWritten > 0
          ? PrinterTransmissionOutcome.uncertain
          : PrinterTransmissionOutcome.failed;
    } catch (_) {
      lastErrorCode = 'sendFailed';
      await _dropConnection();
      return PrinterTransmissionOutcome.uncertain;
    } finally {
      operation = PrinterOperation.idle;
      notifyListeners();
    }
  }

  Future<TestPrintOutcome> printTestTicket() async {
    if (busy || !connected) return TestPrintOutcome.failed;
    testOutcome = TestPrintOutcome.none;
    notifyListeners();
    final outcome = await transmit(EscPosTestTicket.build());
    testOutcome = switch (outcome) {
      PrinterTransmissionOutcome.transmitted => TestPrintOutcome.sent,
      PrinterTransmissionOutcome.failed => TestPrintOutcome.failed,
      PrinterTransmissionOutcome.uncertain => TestPrintOutcome.uncertain,
    };
    notifyListeners();
    return testOutcome;
  }

  Future<void> _dropConnection() async {
    try {
      await _transport.disconnect();
    } catch (_) {
      // A failed transport is already unusable.
    }
    connectedAddress = null;
    batteryPercentage = null;
  }

  void _applyState(BluetoothHostState state) {
    hostStatus = state.status;
    devices = state.devices;
    connectedAddress = state.connectedAddress;
    batteryPercentage = state.connectedAddress == null
        ? null
        : state.batteryPercentage;
  }
}
