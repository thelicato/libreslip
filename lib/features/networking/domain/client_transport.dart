import 'client_delivery_models.dart';

class PairServerRequest {
  const PairServerRequest({
    required this.baseUrl,
    required this.clientInstallationId,
    required this.clientDisplayName,
    required this.clientIdentityFingerprint,
  });

  final Uri baseUrl;
  final String clientInstallationId;
  final String clientDisplayName;
  final String clientIdentityFingerprint;
}

class PairServerResult {
  const PairServerResult({required this.server, required this.accessToken});

  final PairedServer server;
  final String accessToken;
}

class DeliveryAcknowledgement {
  const DeliveryAcknowledgement({
    required this.deliveryId,
    required this.serverOrderId,
    required this.duplicate,
  });

  final String deliveryId;
  final String serverOrderId;
  final bool duplicate;
}

abstract interface class ClientServerTransport {
  Future<PairServerResult> pair(PairServerRequest request);

  Future<DeliveryAcknowledgement> deliver({
    required PairedServer server,
    required String accessToken,
    required ClientDelivery delivery,
  });
}

class ClientTransportException implements Exception {
  const ClientTransportException(this.code);

  final String code;

  @override
  String toString() => code;
}
