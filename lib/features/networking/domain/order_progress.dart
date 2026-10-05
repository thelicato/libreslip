import 'dart:convert';

import '../../orders/domain/order_models.dart';
import 'client_delivery_models.dart';
import 'network_protocol.dart';

class OrderProgressSnapshot {
  const OrderProgressSnapshot({
    required this.clientId,
    required this.orderId,
    required this.orderRevision,
    required this.progressRevision,
    required this.quantities,
  });
  final String clientId;
  final String orderId;
  final int orderRevision;
  final int progressRevision;
  final Map<String, int> quantities;
  Map<String, Object?> toJson() => {
    'protocol': NetworkProtocol.name,
    'version': 1,
    'clientId': clientId,
    'orderId': orderId,
    'orderRevision': orderRevision,
    'progressRevision': progressRevision,
    'quantities': quantities,
  };
  factory OrderProgressSnapshot.fromJson(Object? value) {
    final row = _object(value, 7);
    _protocol(row);
    return OrderProgressSnapshot(
      clientId: _id(row['clientId']),
      orderId: _id(row['orderId']),
      orderRevision: _revision(row['orderRevision'], positive: true),
      progressRevision: _revision(row['progressRevision']),
      quantities: _quantities(row['quantities']),
    );
  }
}

class OrderProgressChange {
  const OrderProgressChange({
    required this.operationId,
    required this.orderId,
    required this.orderRevision,
    required this.expectedRevision,
    required this.quantities,
  });
  final String operationId;
  final String orderId;
  final int orderRevision;
  final int expectedRevision;
  final Map<String, int> quantities;
  Map<String, Object?> toJson() => {
    'protocol': NetworkProtocol.name,
    'version': 1,
    'operationId': operationId,
    'orderId': orderId,
    'orderRevision': orderRevision,
    'expectedRevision': expectedRevision,
    'quantities': quantities,
  };
  factory OrderProgressChange.fromJson(Object? value) {
    final row = _object(value, 7);
    _protocol(row);
    return OrderProgressChange(
      operationId: _id(row['operationId']),
      orderId: _id(row['orderId']),
      orderRevision: _revision(row['orderRevision'], positive: true),
      expectedRevision: _revision(row['expectedRevision']),
      quantities: _quantities(row['quantities']),
    );
  }
}

class ProgressSyncState {
  const ProgressSyncState({this.baseline, this.pending});
  final OrderProgressSnapshot? baseline;
  final OrderProgressChange? pending;
}

class ProgressConflict implements Exception {
  const ProgressConflict(this.remote);
  final OrderProgressSnapshot remote;
}

class ProgressSyncException implements Exception {
  const ProgressSyncException(this.code);
  final String code;
}

enum ProgressResolution { server, client }

abstract interface class OrderProgressTransport {
  Future<OrderProgressSnapshot> fetchProgress({
    required PairedServer server,
    required String accessToken,
    required String clientId,
    required String orderId,
  });
  Future<OrderProgressSnapshot> changeProgress({
    required PairedServer server,
    required String accessToken,
    required String clientId,
    required OrderProgressChange change,
  });
}

abstract interface class ClientProgressStore {
  Future<PairedServer?> loadProgressServer(String serverId);
  Future<ManagedOrder> reloadProgressOrder(ManagedOrder order);
  Future<ProgressSyncState> loadProgressSyncState(ManagedOrder order);
  Future<void> savePendingProgress(
    ManagedOrder order,
    OrderProgressChange change,
  );
  Future<void> acknowledgeProgress(
    ManagedOrder order,
    OrderProgressSnapshot applied,
  );
  Future<void> discardRejectedProgress(ManagedOrder order);
  Future<void> applySyncedProgress(
    ManagedOrder order,
    OrderProgressSnapshot snapshot,
  );
}

abstract interface class ServerProgressStore {
  Future<OrderProgressSnapshot> loadServerProgress(
    String clientId,
    String orderId,
  );
  Future<OrderProgressSnapshot> applyServerProgress(
    String clientId,
    OrderProgressChange change,
  );
}

Map<String, dynamic> _object(Object? value, int count) {
  if (value is! Map<String, dynamic> || value.length != count) {
    throw const FormatException('Invalid progress object');
  }
  return value;
}

void _protocol(Map<String, dynamic> row) {
  if (row['protocol'] != NetworkProtocol.name ||
      row['version'] is! int ||
      row['version'] != 1) {
    throw const FormatException('Unsupported progress protocol');
  }
}

String _id(Object? value) {
  if (value is! String || !validOrderId(value)) {
    throw const FormatException('Invalid progress identity');
  }
  return value;
}

int _revision(Object? value, {bool positive = false}) {
  if (value is! int || value < (positive ? 1 : 0) || value > 9007199254740991) {
    throw const FormatException('Invalid progress revision');
  }
  return value;
}

Map<String, int> _quantities(Object? value) {
  if (value is! Map || value.isEmpty || value.length > 200) {
    throw const FormatException('Invalid progress inventory');
  }
  final result = <String, int>{};
  for (final entry in value.entries) {
    if (entry.value is! int ||
        (entry.value as int) < 0 ||
        (entry.value as int) > 999) {
      throw const FormatException('Invalid progress quantity');
    }
    result[_id(entry.key)] = entry.value as int;
  }
  return Map.unmodifiable(result);
}

String canonicalProgressChange(OrderProgressChange change) => jsonEncode({
  ...change.toJson(),
  'quantities': {
    for (final id in (change.quantities.keys.toList()..sort()))
      id: change.quantities[id],
  },
});

/// Private rollback data never appears in a transferable archive.
abstract interface class ProgressRecoveryStore {
  Future<Map<String, Object?>> createProgressRecoverySnapshot();
  Future<void> replaceProgressRecoverySnapshot(Map<String, Object?> recovery);
}
