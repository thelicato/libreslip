import 'network_models.dart';
import 'server_security.dart';

class RunningServer {
  const RunningServer({required this.port, required this.addresses});

  final int port;
  final List<String> addresses;
}

abstract interface class ServerHost {
  Future<RunningServer> start({
    required ServerIdentity identity,
    required NetworkConfiguration configuration,
    required bool Function(String code) claimPairingCode,
    required void Function() onOrderReceived,
  });

  Future<void> stop();
}
