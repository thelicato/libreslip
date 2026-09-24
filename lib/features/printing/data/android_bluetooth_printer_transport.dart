import 'package:flutter/services.dart';

import '../domain/printer_transport.dart';

class AndroidBluetoothPrinterTransport implements PrinterTransport {
  AndroidBluetoothPrinterTransport({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'io.thelicato.libreslip/printer';
  final MethodChannel _channel;

  @override
  Future<BluetoothHostState> getState() async {
    final value = await _channel.invokeMapMethod<String, Object?>('getState');
    final map = value ?? const <String, Object?>{};
    final status = switch (map['status']) {
      'unsupported' => BluetoothHostStatus.unsupported,
      'permissionRequired' => BluetoothHostStatus.permissionRequired,
      'disabled' => BluetoothHostStatus.disabled,
      _ => BluetoothHostStatus.ready,
    };
    final rawDevices = map['devices'] as List<Object?>? ?? const [];
    final devices = rawDevices
        .map((entry) {
          final device = Map<Object?, Object?>.from(entry! as Map);
          return PairedPrinter(
            name: (device['name'] as String?)?.trim().isNotEmpty == true
                ? device['name']! as String
                : device['address']! as String,
            address: device['address']! as String,
          );
        })
        .toList(growable: false);
    final battery = map['batteryPercentage'] as int?;
    return BluetoothHostState(
      status: status,
      devices: devices,
      connectedAddress: map['connectedAddress'] as String?,
      batteryPercentage: battery != null && battery >= 0 && battery <= 100
          ? battery
          : null,
    );
  }

  @override
  Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestPermission') ?? false;

  @override
  Future<void> openBluetoothSettings() =>
      _channel.invokeMethod<void>('openBluetoothSettings');

  @override
  Future<void> connect(String address) =>
      _invoke('connect', {'address': address});

  @override
  Future<void> disconnect() => _invoke('disconnect');

  @override
  Future<int> send(Uint8List bytes, {int chunkSize = 256}) async {
    try {
      return await _channel.invokeMethod<int>('send', {
            'bytes': bytes,
            'chunkSize': chunkSize,
          }) ??
          0;
    } on PlatformException catch (error) {
      final details = error.details;
      final written = details is Map ? details['bytesWritten'] as int? ?? 0 : 0;
      throw PrinterTransportException(code: error.code, bytesWritten: written);
    }
  }

  Future<void> _invoke(String method, [Map<String, Object?>? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (error) {
      final details = error.details;
      final written = details is Map ? details['bytesWritten'] as int? ?? 0 : 0;
      throw PrinterTransportException(code: error.code, bytesWritten: written);
    }
  }
}
