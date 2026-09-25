import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/printer_transport.dart';
import 'esc_pos_test_ticket.dart';

enum PrinterOperation {
  idle,
  refreshing,
  requestingPermission,
  connecting,
  disconnecting,
  sending,
}

enum PrinterTransmissionOutcome { transmitted, failed, uncertain }

enum TestPrintOutcome { none, sent, failed, uncertain }

typedef PreferredPrinterChanged = Future<void> Function(String? address);

class PrinterController extends ChangeNotifier {
  PrinterController(
    this._transport, {
    this.monitorInterval = const Duration(seconds: 15),
    this.onPreferredPrinterChanged,
  });

  final PrinterTransport _transport;
  final Duration monitorInterval;
  final PreferredPrinterChanged? onPreferredPrinterChanged;

  BluetoothHostStatus hostStatus = BluetoothHostStatus.ready;
  List<PairedPrinter> devices = const [];
  String? connectedAddress;
  String? preferredAddress;
  int? batteryPercentage;
  String? connectingAddress;
  PrinterOperation operation = PrinterOperation.idle;
  TestPrintOutcome testOutcome = TestPrintOutcome.none;
  String? lastErrorCode;
  Timer? _monitorTimer;
  bool _disposed = false;

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

  Future<void> start({String? preferredPrinterAddress}) async {
    if (_disposed) return;
    preferredAddress = preferredPrinterAddress;
    _monitorTimer?.cancel();
    await _checkState(showProgress: true, reconnect: true);
    if (_disposed) return;
    _monitorTimer = Timer.periodic(
      monitorInterval,
      (_) => unawaited(checkConnection()),
    );
  }

  Future<void> refresh() =>
      _checkState(showProgress: true, reconnect: true, clearError: true);

  Future<void> checkConnection() =>
      _checkState(showProgress: false, reconnect: true);

  Future<void> _checkState({
    required bool showProgress,
    required bool reconnect,
    bool clearError = false,
  }) async {
    if (busy || _disposed) return;
    operation = PrinterOperation.refreshing;
    if (clearError) lastErrorCode = null;
    if (showProgress) _notify();
    try {
      final state = await _transport.getState();
      _applyState(state);
      final address = preferredAddress;
      if (reconnect &&
          hostStatus == BluetoothHostStatus.ready &&
          connectedAddress == null &&
          address != null) {
        PairedPrinter? preferred;
        for (final device in devices) {
          if (device.address == address) preferred = device;
        }
        if (preferred != null) {
          await _connect(preferred, remember: false);
        }
      }
    } on PrinterTransportException catch (error) {
      lastErrorCode = error.code;
    } catch (_) {
      lastErrorCode = 'unavailable';
    } finally {
      if (operation == PrinterOperation.refreshing) {
        operation = PrinterOperation.idle;
      }
      _notify();
    }
  }

  Future<void> requestPermission() async {
    if (busy || _disposed) return;
    operation = PrinterOperation.requestingPermission;
    lastErrorCode = null;
    _notify();
    try {
      final granted = await _transport.requestPermission();
      if (!granted) hostStatus = BluetoothHostStatus.permissionRequired;
    } on PrinterTransportException catch (error) {
      lastErrorCode = error.code;
    } finally {
      operation = PrinterOperation.idle;
      _notify();
    }
    await refresh();
  }

  Future<void> openBluetoothSettings() => _transport.openBluetoothSettings();

  Future<bool> connect(PairedPrinter device) =>
      _connect(device, remember: true);

  Future<bool> _connect(PairedPrinter device, {required bool remember}) async {
    if ((busy && operation != PrinterOperation.refreshing) || _disposed) {
      return false;
    }
    operation = PrinterOperation.connecting;
    connectingAddress = device.address;
    lastErrorCode = null;
    testOutcome = TestPrintOutcome.none;
    _notify();
    try {
      await _transport.connect(device.address);
      connectedAddress = device.address;
      batteryPercentage = null;
      if (remember) {
        preferredAddress = device.address;
        await _persistPreferredPrinter(device.address);
      }
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
      _notify();
    }
  }

  Future<void> disconnect() async {
    if (busy || _disposed) return;
    operation = PrinterOperation.disconnecting;
    lastErrorCode = null;
    preferredAddress = null;
    _notify();
    await _persistPreferredPrinter(null);
    try {
      await _transport.disconnect();
    } on PrinterTransportException catch (error) {
      lastErrorCode = error.code;
    } finally {
      connectedAddress = null;
      batteryPercentage = null;
      testOutcome = TestPrintOutcome.none;
      operation = PrinterOperation.idle;
      _notify();
    }
  }

  Future<void> _persistPreferredPrinter(String? address) async {
    try {
      await onPreferredPrinterChanged?.call(address);
    } catch (_) {
      // The live connection remains usable if preference storage fails.
    }
  }

  Future<PrinterTransmissionOutcome> transmit(Uint8List bytes) async {
    if (busy || !connected || bytes.isEmpty) {
      lastErrorCode = 'notConnected';
      _notify();
      return PrinterTransmissionOutcome.failed;
    }
    operation = PrinterOperation.sending;
    lastErrorCode = null;
    _notify();
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
      _notify();
    }
  }

  Future<TestPrintOutcome> printTestTicket() async {
    if (busy || !connected) return TestPrintOutcome.failed;
    testOutcome = TestPrintOutcome.none;
    _notify();
    final outcome = await transmit(EscPosTestTicket.build());
    testOutcome = switch (outcome) {
      PrinterTransmissionOutcome.transmitted => TestPrintOutcome.sent,
      PrinterTransmissionOutcome.failed => TestPrintOutcome.failed,
      PrinterTransmissionOutcome.uncertain => TestPrintOutcome.uncertain,
    };
    _notify();
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _monitorTimer?.cancel();
    _monitorTimer = null;
    super.dispose();
  }
}
