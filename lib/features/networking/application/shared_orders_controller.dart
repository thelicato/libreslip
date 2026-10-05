import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../orders/application/order_workspace_controller.dart';
import '../../orders/domain/order_models.dart';
import '../domain/client_security.dart';
import '../domain/client_delivery_models.dart';
import '../domain/client_transport.dart';
import '../domain/network_models.dart';
import '../domain/order_progress.dart';
import '../domain/shared_orders.dart';
import 'client_delivery_controller.dart';
import 'network_mode_controller.dart';

/// Polls every connected local Server while Client mode is in the foreground.
/// Printing and its recovery queue are never driven by this controller.
class SharedOrdersController extends ChangeNotifier
    with WidgetsBindingObserver {
  SharedOrdersController({
    required this.store,
    required this.workspace,
    required this.delivery,
    required this.mode,
    required this.secrets,
    required this.transport,
    this.interval = const Duration(seconds: 5),
  });
  final SharedClientStore store;
  final OrderWorkspaceController workspace;
  final ClientDeliveryController delivery;
  final NetworkModeController mode;
  final ClientSecretStore secrets;
  final SharedOrdersTransport transport;
  final Duration interval;
  final Map<String, SharedOrderSnapshot> conflicts = {};
  final Set<String> sharedIds = {};
  final Set<String> unavailableIds = {};
  bool busy = false;
  String? error;
  final Map<String, String> serverErrors = {};
  final Map<String, DateTime> serverSyncedAt = {};
  DateTime? lastSyncedAt;
  bool _started = false;
  bool _disposed = false;
  bool _foreground = true;
  Timer? _timer;
  Timer? _debounce;
  String? _inputs;
  Future<void> _mergeQueue = Future<void>.value();

  bool get enabled =>
      workspace.loaded &&
      delivery.loaded &&
      mode.loaded &&
      mode.mode == LibreSlipMode.client &&
      workspace.featureSettings.managedOrdersEnabled &&
      delivery.servers.isNotEmpty;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    workspace.addListener(_changed);
    delivery.addListener(_changed);
    mode.addListener(_changed);
    for (final order in workspace.managedOrders) {
      if (await store.loadSharedLink(order.id) != null) sharedIds.add(order.id);
    }
    _timer = Timer.periodic(interval, (_) => unawaited(synchronise()));
    _changed();
  }

  void _changed() {
    if (_disposed) return;
    final fingerprint =
        '$enabled/${delivery.servers.map((s) => s.id).join(',')}/'
        '${workspace.managedOrders.map((o) => '${o.id}:${o.revision}:${o.deliveryEditRevision}').join(',')}/'
        '${delivery.deliveries.map((d) => '${d.id}:${d.status.name}').join(',')}';
    if (_inputs == fingerprint) return;
    _inputs = fingerprint;
    if (!enabled) {
      error = null;
      serverErrors.clear();
      serverSyncedAt.clear();
      conflicts.clear();
      lastSyncedAt = null;
    }
    notifyListeners();
    if (busy || !enabled || !_foreground) return;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(synchronise()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _debounce?.cancel();
    } else {
      unawaited(synchronise());
    }
  }

  Future<void> synchronise({
    String? resolveOrderId,
    ProgressResolution? resolution,
    String? serverId,
  }) async {
    if (_disposed || busy || !enabled || !_foreground || workspace.saving) {
      return;
    }
    busy = true;
    error = null;
    notifyListeners();
    final targets = List<PairedServer>.from(delivery.servers);
    if (resolveOrderId != null) {
      final order = workspace.managedOrders
          .where((o) => o.id == resolveOrderId)
          .firstOrNull;
      targets.removeWhere((s) => s.id != order?.destinationId);
    } else if (serverId != null) {
      targets.removeWhere((s) => s.id != serverId);
    }
    try {
      await Future.wait(
        targets.map(
          (server) => _synchroniseServer(
            server,
            resolveOrderId: resolveOrderId,
            resolution: resolution,
          ),
        ),
      );
      serverErrors.removeWhere((id, _) => delivery.serverFor(id) == null);
      error = serverErrors.values.firstOrNull;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _synchroniseServer(
    PairedServer server, {
    String? resolveOrderId,
    ProgressResolution? resolution,
  }) async {
    serverErrors.remove(server.id);
    final actor = mode.configuration!.installationId;
    bool current() =>
        !_disposed &&
        enabled &&
        _foreground &&
        delivery.serverFor(server.id) != null;
    try {
      final token = await secrets.readServerAccessToken(server.id);
      if (token == null || token.isEmpty) {
        throw const ClientTransportException('credentials');
      }
      final allLinks = (await store.loadSharedLinks())
          .where((link) => link.destinationId == server.id)
          .toList();
      final linksByServer = {
        for (final link in allLinks) link.baseline.serverOrderId: link,
      };
      final ordersByLocal = {
        for (final order in workspace.managedOrders) order.id: order,
      };
      sharedIds.addAll(allLinks.map((link) => link.orderId));
      var after = '';
      final heads = <String, SharedOrderHead>{};
      while (true) {
        final page = await transport.sharedOrderIds(
          server: server,
          accessToken: token,
          clientId: actor,
          after: after,
        );
        if (!current()) return;
        if (page.length > 50) {
          throw const ClientTransportException('invalid_response');
        }
        for (final head in page) {
          if (!validOrderId(head.id) ||
              head.id.compareTo(after) <= 0 ||
              heads.containsKey(head.id)) {
            throw const ClientTransportException('invalid_response');
          }
          heads[head.id] = head;
          after = head.id;
        }
        if (heads.length > 10000) {
          throw const ClientTransportException('invalid_response');
        }
        if (page.length < 50) break;
      }
      unavailableIds.removeAll(allLinks.map((link) => link.orderId));
      unavailableIds.addAll(
        allLinks
            .where((link) => !heads.containsKey(link.baseline.serverOrderId))
            .map((link) => link.orderId),
      );
      for (final head in heads.values) {
        final id = head.id;
        if (!current()) return;
        final known = linksByServer[id];
        final cachedOrder = known == null ? null : ordersByLocal[known.orderId];
        if (known != null &&
            known.pending == null &&
            !(cachedOrder?.changedDeliveryIds.any(
                  (line) =>
                      known.baseline.progress.quantities.containsKey(line),
                ) ??
                false) &&
            known.baseline.envelope.revision == head.orderRevision &&
            known.baseline.progress.progressRevision == head.progressRevision &&
            !conflicts.containsKey(known.orderId) &&
            resolveOrderId != known.orderId) {
          continue;
        }
        var remote = await transport.sharedOrder(
          server: server,
          accessToken: token,
          clientId: actor,
          serverOrderId: id,
        );
        if (!current()) return;
        final candidates = workspace.managedOrders
            .where(
              (order) =>
                  (known != null && known.orderId == order.id) ||
                  (known == null &&
                      remote.envelope.clientInstallationId == actor &&
                      remote.envelope.managedOrderId == order.id &&
                      order.destinationId == server.id),
            )
            .toList();
        var local = candidates.isEmpty ? null : candidates.single;
        if (local != null &&
            delivery.deliveries.any(
              (d) =>
                  d.destinationId == server.id &&
                  d.envelope.managedOrderId == local!.id &&
                  d.status != ClientDeliveryStatus.delivered,
            )) {
          continue;
        }
        var link = local == null ? null : await store.loadSharedLink(local.id);
        try {
          if (local != null && link?.pending != null) {
            try {
              final applied = await transport.changeSharedProgress(
                server: server,
                accessToken: token,
                clientId: actor,
                change: link!.pending!,
              );
              _validateApplied(link, applied);
              await store.settleSharedProgress(
                local.id,
                accepted: true,
                applied: applied,
              );
            } on ClientTransportException catch (e) {
              if (e.code != 'conflict') rethrow;
              await store.settleSharedProgress(local.id, accepted: false);
              throw ProgressConflict(remote.progress);
            }
            link = await store.loadSharedLink(local.id);
            remote = await transport.sharedOrder(
              server: server,
              accessToken: token,
              clientId: actor,
              serverOrderId: id,
            );
          }
          if (!current()) return;
          // Pull additions under the composition lock, preserving local edits.
          if (!await _merge(
            current,
            () => store.mergeSharedOrder(server.id, remote),
          )) {
            return;
          }
          for (final order in workspace.managedOrders) {
            final mapping = await store.loadSharedLink(order.id);
            if (mapping?.destinationId == server.id &&
                mapping?.baseline.serverOrderId == id) {
              local = order;
              sharedIds.add(order.id);
              break;
            }
          }
          if (local == null) continue; // This Client has closed its local view.
          final dirty = local.changedDeliveryIds
              .where((id) => remote.progress.quantities.containsKey(id))
              .toSet();
          final desired = {...remote.progress.quantities};
          final observed = conflicts[local.id];
          final resolving =
              resolveOrderId == local.id &&
              resolution != null &&
              observed != null;
          if (resolving &&
              (observed.progress.progressRevision !=
                      remote.progress.progressRevision ||
                  observed.envelope.revision != remote.envelope.revision)) {
            throw ProgressConflict(remote.progress);
          }
          final previous =
              link?.baseline.progress.quantities ?? <String, int>{};
          final diverged = dirty.any(
            (id) =>
                local!.deliveredQuantity(id) !=
                    remote.progress.quantities[id] &&
                remote.progress.quantities[id] != (previous[id] ?? 0),
          );
          if (diverged && !resolving) throw ProgressConflict(remote.progress);
          if (resolution != ProgressResolution.server || !resolving) {
            for (final id in dirty) {
              desired[id] = local.deliveredQuantity(id);
            }
          }
          if (desired.keys.any(
            (id) => desired[id] != remote.progress.quantities[id],
          )) {
            final change = OrderProgressChange(
              operationId: createLocalId(),
              orderId: id,
              orderRevision: remote.envelope.revision,
              expectedRevision: remote.progress.progressRevision,
              quantities: desired,
            );
            await store.saveSharedProgress(local, change);
            try {
              final applied = await transport.changeSharedProgress(
                server: server,
                accessToken: token,
                clientId: actor,
                change: change,
              );
              _validateApplied(
                (await store.loadSharedLink(local.id))!,
                applied,
              );
              await store.settleSharedProgress(
                local.id,
                accepted: true,
                applied: applied,
              );
            } on ClientTransportException catch (e) {
              if (e.code != 'conflict') rethrow;
              await store.settleSharedProgress(local.id, accepted: false);
              remote = await transport.sharedOrder(
                server: server,
                accessToken: token,
                clientId: actor,
                serverOrderId: id,
              );
              throw ProgressConflict(remote.progress);
            }
            remote = await transport.sharedOrder(
              server: server,
              accessToken: token,
              clientId: actor,
              serverOrderId: id,
            );
          } else if (dirty.isNotEmpty) {
            // Record this acknowledgement transactionally before clearing intent.
            await store.saveSharedProgress(
              local,
              OrderProgressChange(
                operationId: createLocalId(),
                orderId: id,
                orderRevision: remote.envelope.revision,
                expectedRevision: remote.progress.progressRevision,
                quantities: desired,
              ),
            );
            await store.settleSharedProgress(local.id, accepted: true);
          }
          if (!current()) return;
          if (!await _merge(
            current,
            () => store.mergeSharedOrder(server.id, remote),
          )) {
            return;
          }
          conflicts.remove(local.id);
        } on ProgressConflict {
          if (local != null) conflicts[local.id] = remote;
        }
      }
      if (current()) {
        lastSyncedAt = DateTime.now();
        serverSyncedAt[server.id] = lastSyncedAt!;
      }
    } on ClientTransportException catch (e) {
      if (current()) serverErrors[server.id] = e.code;
    } catch (_) {
      if (current()) serverErrors[server.id] = 'storage';
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Network requests run independently; composition merges share one writer.
  Future<bool> _merge(
    bool Function() current,
    Future<void> Function() merge,
  ) async {
    final previous = _mergeQueue;
    final released = Completer<void>();
    _mergeQueue = released.future;
    try {
      await previous;
      if (!current() || workspace.saving) return false;
      await workspace.refreshSharedOrders(merge);
      return true;
    } finally {
      released.complete();
    }
  }

  static void _validateApplied(
    SharedOrderLink link,
    OrderProgressSnapshot result,
  ) {
    if (result.clientId != link.baseline.envelope.clientInstallationId ||
        result.orderId != link.baseline.envelope.managedOrderId ||
        result.orderRevision != link.pending!.orderRevision ||
        result.progressRevision != link.pending!.expectedRevision + 1 ||
        result.quantities.length != link.pending!.quantities.length ||
        result.quantities.entries.any(
          (e) => e.value != link.pending!.quantities[e.key],
        )) {
      throw const ClientTransportException('invalid_response');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _debounce?.cancel();
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      workspace.removeListener(_changed);
      delivery.removeListener(_changed);
      mode.removeListener(_changed);
    }
    super.dispose();
  }
}
