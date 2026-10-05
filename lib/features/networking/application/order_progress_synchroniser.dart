import '../../orders/domain/order_models.dart';
import '../domain/client_security.dart';
import '../domain/client_transport.dart';
import '../domain/order_progress.dart';

/// Runs only on an explicit user action. Pending writes retain their identity.
class OrderProgressSynchroniser {
  const OrderProgressSynchroniser(this.store, this.secrets, this.transport);
  final ClientProgressStore store;
  final ClientSecretStore secrets;
  final OrderProgressTransport transport;

  Future<void> synchronise(
    ManagedOrder order, {
    OrderProgressSnapshot? conflict,
    ProgressResolution? resolution,
  }) async {
    final serverId = order.destinationId;
    final clientId = order.clientInstallationId;
    if (serverId == null || clientId == null) {
      throw const ProgressSyncException('local');
    }
    final server = await store.loadProgressServer(serverId);
    final token = await secrets.readServerAccessToken(serverId);
    if (server == null || token == null || token.isEmpty) {
      throw const ProgressSyncException('credentials');
    }
    var state = await store.loadProgressSyncState(order);
    final pending = state.pending;
    if (pending != null) {
      try {
        final applied = await transport.changeProgress(
          server: server,
          accessToken: token,
          clientId: clientId,
          change: pending,
        );
        await store.acknowledgeProgress(order, applied);
      } on ClientTransportException catch (error) {
        // A 409 proves this immutable operation was not accepted. A lost
        // acknowledgement retains it for an explicit idempotent retry.
        if (error.code != 'conflict') rethrow;
        await store.discardRejectedProgress(order);
      }
      state = await store.loadProgressSyncState(order);
    }
    final remote = await transport.fetchProgress(
      server: server,
      accessToken: token,
      clientId: clientId,
      orderId: order.id,
    );
    _validateRemote(order, remote);
    final baseline = state.baseline;
    order = await store.reloadProgressOrder(order);
    _validateRemote(order, remote);
    final local = {
      for (final line in order.lines.where((line) => line.sendToServer))
        line.id: order.deliveredQuantity(line.id),
    };
    final dirty = local.keys
        .where(
          (id) =>
              order.changedDeliveryIds.contains(id) ||
              local[id] != (baseline?.quantities[id] ?? 0),
        )
        .toSet();
    final diverged =
        (dirty.any((id) => local[id] != remote.quantities[id]) &&
            remote.progressRevision != (baseline?.progressRevision ?? 0)) ||
        (baseline != null &&
            remote.progressRevision < baseline.progressRevision);
    final resolving = conflict != null && resolution != null;
    if (resolving &&
        (conflict.progressRevision != remote.progressRevision ||
            conflict.orderRevision != remote.orderRevision)) {
      throw ProgressConflict(remote);
    }
    if (diverged && !resolving) throw ProgressConflict(remote);
    final desired = {...remote.quantities};
    if (resolution != ProgressResolution.server) {
      for (final id in resolving ? local.keys : dirty) {
        desired[id] = local[id]!;
      }
    }
    var result = remote;
    if (desired.keys.any((id) => desired[id] != remote.quantities[id])) {
      final change = OrderProgressChange(
        operationId: createLocalId(),
        orderId: order.id,
        orderRevision: remote.orderRevision,
        expectedRevision: remote.progressRevision,
        quantities: desired,
      );
      await store.savePendingProgress(order, change);
      try {
        result = await transport.changeProgress(
          server: server,
          accessToken: token,
          clientId: clientId,
          change: change,
        );
        await store.acknowledgeProgress(order, result);
      } on ClientTransportException catch (error) {
        if (error.code != 'conflict') rethrow;
        await store.discardRejectedProgress(order);
        final latest = await transport.fetchProgress(
          server: server,
          accessToken: token,
          clientId: clientId,
          orderId: order.id,
        );
        _validateRemote(order, latest);
        throw ProgressConflict(latest);
      }
    }
    await store.applySyncedProgress(order, result);
  }

  static void _validateRemote(
    ManagedOrder order,
    OrderProgressSnapshot remote,
  ) {
    if (remote.clientId != order.clientInstallationId ||
        remote.orderId != order.id) {
      throw const ProgressSyncException('identity');
    }
    if (remote.orderRevision > order.serverRevision) {
      throw const ProgressSyncException('server_newer');
    }
    if (remote.orderRevision < order.serverRevision) {
      throw const ProgressSyncException('pending_items');
    }
    final lines = order.lines.where((line) => line.sendToServer).toList();
    if (lines.length != remote.quantities.length ||
        lines.any(
          (line) =>
              !remote.quantities.containsKey(line.id) ||
              remote.quantities[line.id]! < 0 ||
              remote.quantities[line.id]! > line.quantity,
        )) {
      throw const ProgressSyncException('pending_items');
    }
  }
}
