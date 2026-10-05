import 'network_protocol.dart';
import '../../orders/domain/course_groups.dart';

enum ServerOrderStatus { received, done }

extension ServerOrderStatusValue on ServerOrderStatus {
  String get value => name;

  static ServerOrderStatus parse(String value) => switch (value) {
    'received' => ServerOrderStatus.received,
    'done' => ServerOrderStatus.done,
    _ => throw const FormatException('Unsupported server order status'),
  };
}

class PairedClient {
  const PairedClient({
    required this.installationId,
    required this.displayName,
    required this.identityFingerprint,
    required this.pairedAt,
    this.lastSeenAt,
  });

  final String installationId;
  final String displayName;
  final String identityFingerprint;
  final DateTime pairedAt;
  final DateTime? lastSeenAt;
}

class ServerOrderLine {
  const ServerOrderLine({
    required this.name,
    required this.quantity,
    this.preparationNote = '',
    this.courseId,
    this.id,
    this.addedRevision = 0,
    this.deliveredQuantity = 0,
  });

  final String name;
  final int quantity;
  final String preparationNote;
  final String? courseId;
  final String? id;
  final int addedRevision;
  final int deliveredQuantity;
  int get outstandingQuantity => quantity - deliveredQuantity;
}

class ServerOrder {
  const ServerOrder({
    required this.id,
    required this.clientInstallationId,
    required this.clientDisplayName,
    required this.deliveryId,
    required this.clientTicketId,
    required this.displayNumber,
    required this.sourceCreatedAt,
    required this.receivedAt,
    required this.heading,
    required this.reference,
    required this.orderNote,
    required this.lines,
    required this.payloadChecksum,
    required this.status,
    this.completedAt,
    this.courses = const [],
    this.managedOrderId,
    this.revision = 0,
    this.completedRevision = 0,
    this.progressRevision = 0,
  });

  final String id;
  final String clientInstallationId;
  final String clientDisplayName;
  final String deliveryId;
  final String clientTicketId;
  final int displayNumber;
  final DateTime sourceCreatedAt;
  final DateTime receivedAt;
  final String heading;
  final String reference;
  final String orderNote;
  final List<ServerOrderLine> lines;
  final List<OrderCourse> courses;
  final String? managedOrderId;
  final int revision;
  final int completedRevision;
  final int progressRevision;
  final String payloadChecksum;
  final ServerOrderStatus status;
  final DateTime? completedAt;
}

class ServerOrderReceipt {
  const ServerOrderReceipt({required this.order, required this.wasDuplicate});

  final ServerOrder order;
  final bool wasDuplicate;
}

class OutstandingItemTotal {
  const OutstandingItemTotal({required this.name, required this.quantity});

  final String name;
  final int quantity;
}

List<OutstandingItemTotal> summariseOutstandingItems(
  Iterable<ServerOrder> orders,
) {
  final totals = <String, ({String name, int quantity})>{};
  for (final order in orders) {
    if (order.status != ServerOrderStatus.received) continue;
    final lines = order.managedOrderId == null
        ? order.lines
        : courseSections(order.courses, order.lines, (line) => line.courseId)
                  .where(
                    (section) => section.lines.any(
                      (line) => line.outstandingQuantity > 0,
                    ),
                  )
                  .firstOrNull
                  ?.lines ??
              const <ServerOrderLine>[];
    for (final line in lines) {
      final outstanding = order.managedOrderId == null
          ? line.quantity
          : line.outstandingQuantity;
      if (outstanding == 0) continue;
      final name = line.name.trim();
      final key = name.toLowerCase();
      final current = totals[key];
      totals[key] = (
        name: current?.name ?? name,
        quantity: (current?.quantity ?? 0) + outstanding,
      );
    }
  }
  final result = [
    for (final total in totals.values)
      OutstandingItemTotal(name: total.name, quantity: total.quantity),
  ];
  result.sort((left, right) {
    final insensitive = left.name.toLowerCase().compareTo(
      right.name.toLowerCase(),
    );
    return insensitive != 0 ? insensitive : left.name.compareTo(right.name);
  });
  return List.unmodifiable(result);
}

class ServerOrderConflictException implements Exception {
  const ServerOrderConflictException();
}

abstract interface class ServerInboxStore {
  Future<void> pairClient(PairedClient client);

  Future<PairedClient?> findPairedClient(String installationId);

  Future<List<ServerOrder>> loadServerOrders();

  Future<ServerOrderReceipt> receiveServerOrder(
    OrderDeliveryEnvelope envelope, {
    required DateTime receivedAt,
  });

  Future<ServerOrder> setServerLineDelivered(
    String orderId,
    String lineId,
    int quantity, {
    required int expectedQuantity,
  });

  Future<ServerOrder> markServerOrderDone(
    String id, {
    required DateTime completedAt,
  });

  Future<ServerOrder> markServerOrderReceived(String id);

  Future<void> deleteCompletedServerOrder(String id);

  Future<int> deleteAllCompletedServerOrders();
}
