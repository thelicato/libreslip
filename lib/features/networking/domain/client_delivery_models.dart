import 'network_protocol.dart';

enum ClientDeliveryStatus { pending, sending, delivered, failed }

extension ClientDeliveryStatusValue on ClientDeliveryStatus {
  String get value => name;

  static ClientDeliveryStatus parse(String value) => switch (value) {
    'pending' => ClientDeliveryStatus.pending,
    'sending' => ClientDeliveryStatus.sending,
    'delivered' => ClientDeliveryStatus.delivered,
    'failed' => ClientDeliveryStatus.failed,
    _ => throw const FormatException('Unsupported client delivery status'),
  };
}

class PairedServer {
  const PairedServer({
    required this.id,
    required this.displayName,
    required this.baseUrl,
    required this.certificateFingerprint,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String displayName;
  final Uri baseUrl;
  final String certificateFingerprint;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ClientDelivery {
  const ClientDelivery({
    required this.id,
    required this.destinationId,
    required this.clientInstallationId,
    required this.ticketId,
    required this.ticketNumber,
    required this.envelope,
    required this.status,
    required this.attemptCount,
    required this.createdAt,
    required this.updatedAt,
    this.errorCode,
    this.deliveredAt,
    this.serverOrderId,
  });

  final String id;
  final String destinationId;
  final String clientInstallationId;
  final String ticketId;
  final int ticketNumber;
  final OrderDeliveryEnvelope envelope;
  final ClientDeliveryStatus status;
  final int attemptCount;
  final String? errorCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deliveredAt;
  final String? serverOrderId;
}

abstract interface class ClientDeliveryStore {
  Future<PairedServer?> loadActiveServer();

  Future<void> savePairedServer(PairedServer server);

  Future<void> deactivateServer(String id);

  Future<List<ClientDelivery>> loadClientDeliveries();

  Future<ClientDelivery> markClientDeliverySending(String id);

  Future<ClientDelivery> markClientDeliveryDelivered(
    String id, {
    required String serverOrderId,
    required DateTime deliveredAt,
  });

  Future<ClientDelivery> markClientDeliveryFailed(
    String id, {
    required String errorCode,
  });

  Future<ClientDelivery> resetClientDeliveryForRetry(String id);
}
