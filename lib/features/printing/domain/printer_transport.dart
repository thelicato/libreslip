import 'dart:typed_data';

class PairedPrinter {
  const PairedPrinter({required this.name, required this.address});

  final String name;
  final String address;
}

enum BluetoothHostStatus { unsupported, permissionRequired, disabled, ready }

class BluetoothHostState {
  const BluetoothHostState({
    required this.status,
    this.devices = const [],
    this.connectedAddress,
    this.batteryPercentage,
  }) : assert(
         batteryPercentage == null ||
             (batteryPercentage >= 0 && batteryPercentage <= 100),
       );

  final BluetoothHostStatus status;
  final List<PairedPrinter> devices;
  final String? connectedAddress;

  /// Present only when the transport has documented battery telemetry.
  final int? batteryPercentage;
}

abstract interface class PrinterTransport {
  Future<BluetoothHostState> getState();

  Future<bool> requestPermission();

  Future<void> openBluetoothSettings();

  Future<void> connect(String address);

  Future<void> disconnect();

  Future<int> send(Uint8List bytes, {int chunkSize = 256});
}

class PrinterTransportException implements Exception {
  const PrinterTransportException({required this.code, this.bytesWritten = 0});

  final String code;
  final int bytesWritten;
}
