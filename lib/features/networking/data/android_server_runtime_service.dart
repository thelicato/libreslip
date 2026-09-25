import 'package:flutter/services.dart';

import '../domain/server_runtime_service.dart';

class AndroidServerRuntimeService implements ServerRuntimeService {
  const AndroidServerRuntimeService();

  static const _channel = MethodChannel(
    'io.thelicato.libreslip/server_service',
  );

  @override
  Future<void> start() => _channel.invokeMethod<void>('start');

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');
}
