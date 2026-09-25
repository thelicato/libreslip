import 'network_models.dart';
import 'server_security.dart';

class RunningServer {
  const RunningServer({required this.port, required this.addresses});

  final int port;
  final List<String> addresses;
}

class ClientPairingRequest {
  const ClientPairingRequest({
    required this.clientInstallationId,
    required this.displayName,
    required this.clientIdentityFingerprint,
    required this.sourceAddress,
  });

  final String clientInstallationId;
  final String displayName;
  final String clientIdentityFingerprint;
  final String sourceAddress;
}

abstract interface class ServerHost {
  Future<RunningServer> start({
    required ServerIdentity identity,
    required NetworkConfiguration configuration,
    required Future<bool> Function(ClientPairingRequest request)
    requestPairingApproval,
    required void Function() onOrderReceived,
  });

  Future<void> stop();
}
