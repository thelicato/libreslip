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

enum TestPrintOutcome { none, sent, failed, uncertain }

class PrinterController extends ChangeNotifier {
  PrinterController(this._transport);

  final PrinterTransport _transport;

  BluetoothHostStatus hostStatus = BluetoothHostStatus.ready;
  List<PairedPrinter> devices = const [];
  String? connectedAddress;
  PrinterOperation operation = PrinterOperation.idle;
  TestPrintOutcome testOutcome = TestPrintOutcome.none;
  String? lastErrorCode;

  bool get busy => operation != PrinterOperation.idle;
  bool get connected => connectedAddress != null;

  Future<void> refresh() async {
    if (busy) return;
    operation = PrinterOperation.refreshing;
    lastErrorCode = null;
    notifyListeners();
    try {
      final state = await _transport.getState();
      hostStatus = state.status;
      devices = state.devices;
      connectedAddress = state.connectedAddress;
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
    lastErrorCode = null;
    testOutcome = TestPrintOutcome.none;
    notifyListeners();
    try {
      await _transport.connect(device.address);
      connectedAddress = device.address;
      return true;
    } on PrinterTransportException catch (error) {
      lastErrorCode = error.code;
      connectedAddress = null;
      return false;
    } catch (_) {
      lastErrorCode = 'connectionFailed';
      connectedAddress = null;
      return false;
    } finally {
      operation = PrinterOperation.idle;
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
      testOutcome = TestPrintOutcome.none;
      notifyListeners();
    }
  }

  Future<TestPrintOutcome> printTestTicket() async {
    if (busy || !connected) return TestPrintOutcome.failed;
    operation = PrinterOperation.sending;
    lastErrorCode = null;
    testOutcome = TestPrintOutcome.none;
    notifyListeners();
    try {
      await _transport.send(EscPosTestTicket.build());
      testOutcome = TestPrintOutcome.sent;
    } on PrinterTransportException catch (error) {
      lastErrorCode = error.code;
      testOutcome = error.code == 'sendFailed' || error.bytesWritten > 0
          ? TestPrintOutcome.uncertain
          : TestPrintOutcome.failed;
      connectedAddress = null;
    } catch (_) {
      lastErrorCode = 'sendFailed';
      testOutcome = TestPrintOutcome.failed;
      connectedAddress = null;
    } finally {
      operation = PrinterOperation.idle;
      notifyListeners();
    }
    return testOutcome;
  }
}
