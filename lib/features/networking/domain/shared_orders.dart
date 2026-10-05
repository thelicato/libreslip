import 'dart:convert';

import '../../orders/domain/order_models.dart';
import 'client_delivery_models.dart';
import 'client_transport.dart';
import 'network_protocol.dart';
import 'order_progress.dart';
import 'server_inbox_models.dart';

/// Shared orders contain preparation content only, never catalogue or prices.
class SharedOrderSnapshot {
  const SharedOrderSnapshot(this.serverOrderId, this.envelope, this.progress);
  static const maxBytes = 128 * 1024;
  final String serverOrderId;
  final OrderDeliveryEnvelope envelope;
  final OrderProgressSnapshot progress;

  factory SharedOrderSnapshot.fromOrder(ServerOrder order) =>
      SharedOrderSnapshot(
        order.id,
        OrderDeliveryEnvelope.create(
          clientInstallationId: order.clientInstallationId,
          deliveryId: order.deliveryId,
          ticketId: order.clientTicketId,
          ticketNumber: order.displayNumber,
          createdAt: order.sourceCreatedAt,
          heading: order.heading,
          reference: order.reference,
          orderNote: order.orderNote,
          managedOrderId: order.managedOrderId,
          revision: order.revision,
          courses: order.courses,
          lines: [
            for (final line in order.lines)
              DeliveryLine(
                id: line.id,
                name: line.name,
                quantity: line.quantity,
                preparationNote: line.preparationNote,
                courseId: line.courseId,
              ),
          ],
        ),
        OrderProgressSnapshot(
          clientId: order.clientInstallationId,
          orderId: order.managedOrderId!,
          orderRevision: order.revision,
          progressRevision: order.progressRevision,
          quantities: {
            for (final line in order.lines) line.id!: line.deliveredQuantity,
          },
        ),
      );
  Map<String, Object?> toJson() => {
    'serverOrderId': serverOrderId,
    'envelope': envelope.toJson(),
    'progress': progress.toJson(),
  };
  factory SharedOrderSnapshot.fromJson(Object? value) {
    if (value is! Map ||
        value.length != 3 ||
        value['serverOrderId'] is! String ||
        !validOrderId(value['serverOrderId'] as String)) {
      throw const FormatException('Invalid shared order');
    }
    final envelope = OrderDeliveryEnvelope.fromJsonString(
      jsonEncode(value['envelope']),
    );
    final progress = OrderProgressSnapshot.fromJson(value['progress']);
    if (envelope.managedOrderId == null ||
        progress.clientId != envelope.clientInstallationId ||
        progress.orderId != envelope.managedOrderId ||
        progress.orderRevision != envelope.revision ||
        progress.quantities.length != envelope.lines.length ||
        envelope.lines.any(
          (line) =>
              progress.quantities[line.id] == null ||
              progress.quantities[line.id]! > line.quantity,
        )) {
      throw const FormatException('Invalid shared inventory');
    }
    return SharedOrderSnapshot(
      value['serverOrderId'] as String,
      envelope,
      progress,
    );
  }
}

class SharedOrderHead {
  const SharedOrderHead(this.id, this.orderRevision, this.progressRevision);
  final String id;
  final int orderRevision;
  final int progressRevision;
  Map<String, Object?> toJson() => {
    'id': id,
    'orderRevision': orderRevision,
    'progressRevision': progressRevision,
  };
  factory SharedOrderHead.fromJson(Object? value) {
    if (value is! Map ||
        value.length != 3 ||
        value['id'] is! String ||
        !validOrderId(value['id'] as String) ||
        value['orderRevision'] is! int ||
        (value['orderRevision'] as int) < 1 ||
        (value['orderRevision'] as int) > 9007199254740991 ||
        value['progressRevision'] is! int ||
        (value['progressRevision'] as int) < 0 ||
        (value['progressRevision'] as int) > 9007199254740991) {
      throw const FormatException('Invalid shared order head');
    }
    return SharedOrderHead(
      value['id'] as String,
      value['orderRevision'] as int,
      value['progressRevision'] as int,
    );
  }
}

class SharedOrderLink {
  const SharedOrderLink({
    required this.orderId,
    required this.destinationId,
    required this.baseline,
    this.pending,
    this.pendingLocalRevision,
  });
  final String orderId;
  final String destinationId;
  final SharedOrderSnapshot baseline;
  final OrderProgressChange? pending;
  final int? pendingLocalRevision;
}

class SharedDeliveryTarget {
  const SharedDeliveryTarget(
    this.serverOrderId,
    this.additionIds, {
    this.requiresSharing = true,
  });
  final String serverOrderId;
  final List<String> additionIds;
  final bool requiresSharing;
}

abstract interface class SharedClientStore {
  Future<SharedOrderLink?> loadSharedLink(String orderId);
  Future<List<SharedOrderLink>> loadSharedLinks();
  Future<SharedDeliveryTarget?> sharedDeliveryTarget(ClientDelivery delivery);
  Future<void> mergeSharedOrder(
    String destinationId,
    SharedOrderSnapshot snapshot,
  );
  Future<void> saveSharedProgress(
    ManagedOrder order,
    OrderProgressChange change,
  );
  Future<void> settleSharedProgress(
    String orderId, {
    required bool accepted,
    OrderProgressSnapshot? applied,
  });
}

abstract interface class SharedServerStore {
  Future<List<SharedOrderHead>> sharedOrderIds(String after);
  Future<SharedOrderSnapshot> sharedOrder(String serverOrderId);
  Future<ServerOrderReceipt> appendSharedOrder(
    String actorId,
    String serverOrderId,
    OrderDeliveryEnvelope envelope,
    List<String> additionIds,
  );
  Future<OrderProgressSnapshot> changeSharedProgress(
    String actorId,
    OrderProgressChange change,
  );
}

abstract interface class SharedOrdersTransport {
  Future<List<SharedOrderHead>> sharedOrderIds({
    required PairedServer server,
    required String accessToken,
    required String clientId,
    required String after,
  });
  Future<SharedOrderSnapshot> sharedOrder({
    required PairedServer server,
    required String accessToken,
    required String clientId,
    required String serverOrderId,
  });
  Future<DeliveryAcknowledgement> appendSharedOrder({
    required PairedServer server,
    required String accessToken,
    required ClientDelivery delivery,
    required SharedDeliveryTarget target,
  });
  Future<OrderProgressSnapshot> changeSharedProgress({
    required PairedServer server,
    required String accessToken,
    required String clientId,
    required OrderProgressChange change,
  });
}
