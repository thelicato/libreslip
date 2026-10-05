import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../data/pinned_https_client.dart';
import '../domain/client_delivery_models.dart';
import '../domain/client_security.dart';
import '../domain/client_transport.dart';
import '../domain/network_models.dart';
import '../domain/order_progress.dart';
import '../domain/shared_orders.dart';
import '../../orders/domain/order_models.dart';
import 'order_progress_synchroniser.dart';

class ClientDeliveryController extends ChangeNotifier {
  ClientDeliveryController(
    this._store,
    this._secrets,
    this._transport, {
    this.retryDelay = const Duration(seconds: 10),
  });

  final ClientDeliveryStore _store;
  final ClientSecretStore _secrets;
  final ClientServerTransport _transport;
  final Duration retryDelay;

  PairedServer? activeServer;
  List<ClientDelivery> deliveries = const [];
  bool loaded = false;
  bool loadFailed = false;
  bool pairing = false;
  bool unpairing = false;
  String? lastPairingError;
  final Set<String> _sendingIds = {};
  Timer? _retryTimer;
  bool _draining = false;
  bool _disposed = false;

  static const _automaticallyRetryableErrors = {'unreachable', 'server'};

  int get pendingCount => deliveries
      .where(
        (delivery) =>
            delivery.status == ClientDeliveryStatus.awaitingPrint ||
            delivery.status == ClientDeliveryStatus.pending ||
            delivery.status == ClientDeliveryStatus.sending,
      )
      .length;

  int get failedCount => deliveries
      .where((delivery) => delivery.status == ClientDeliveryStatus.failed)
      .length;

  ClientDelivery? deliveryForTicket(String ticketId) {
    for (final delivery in deliveries) {
      if (delivery.ticketId == ticketId) return delivery;
    }
    return null;
  }

  bool isSending(String deliveryId) => _sendingIds.contains(deliveryId);

  void clearPairingError() {
    if (lastPairingError == null) return;
    lastPairingError = null;
    notifyListeners();
  }

  Future<void> load() async {
    loadFailed = false;
    notifyListeners();
    try {
      activeServer = await _store.loadActiveServer();
      deliveries = await _store.loadClientDeliveries();
      loaded = true;
      unawaited(_drainRecoverableDeliveries());
    } catch (_) {
      loaded = false;
      loadFailed = true;
    }
    notifyListeners();
  }

  Future<bool> pair({
    required NetworkConfiguration configuration,
    required String address,
    required String clientName,
  }) async {
    if (pairing || unpairing) return false;
    pairing = true;
    lastPairingError = null;
    notifyListeners();
    String? serverId;
    String? previousToken;
    try {
      final baseUrl = PinnedHttpsClient.normaliseServerAddress(address);
      final result = await _transport.pair(
        PairServerRequest(
          baseUrl: baseUrl,
          clientInstallationId: configuration.installationId,
          clientDisplayName: clientName.trim(),
          clientIdentityFingerprint: _clientIdentityFingerprint(
            configuration.installationId,
          ),
        ),
      );
      serverId = result.server.id;
      previousToken = await _secrets.readServerAccessToken(serverId);
      await _secrets.writeServerAccessToken(serverId, result.accessToken);
      try {
        await _store.savePairedServer(result.server);
      } catch (_) {
        if (previousToken == null) {
          await _secrets.deleteServerAccessToken(serverId);
        } else {
          await _secrets.writeServerAccessToken(serverId, previousToken);
        }
        rethrow;
      }
      activeServer = await _store.loadActiveServer();
      deliveries = await _store.loadClientDeliveries();
      return true;
    } on FormatException {
      lastPairingError = 'invalid_pairing';
      return false;
    } on ClientTransportException catch (error) {
      lastPairingError = error.code;
      return false;
    } catch (_) {
      lastPairingError = 'storage';
      return false;
    } finally {
      pairing = false;
      notifyListeners();
    }
  }

  Future<bool> unpair() async {
    final server = activeServer;
    if (server == null || pairing || unpairing) return server == null;
    unpairing = true;
    lastPairingError = null;
    notifyListeners();
    try {
      await _secrets.deleteServerAccessToken(server.id);
      await _store.deactivateServer(server.id);
      _retryTimer?.cancel();
      _retryTimer = null;
      activeServer = null;
      deliveries = await _store.loadClientDeliveries();
      return true;
    } catch (_) {
      lastPairingError = 'storage';
      return false;
    } finally {
      unpairing = false;
      notifyListeners();
    }
  }

  Future<void> synchroniseProgress(
    ManagedOrder order, {
    OrderProgressSnapshot? conflict,
    ProgressResolution? resolution,
  }) async {
    final store = _store;
    final transport = _transport;
    if (store is! ClientProgressStore || transport is! OrderProgressTransport) {
      throw const ProgressSyncException('unsupported_progress');
    }
    await OrderProgressSynchroniser(
      store as ClientProgressStore,
      _secrets,
      transport as OrderProgressTransport,
    ).synchronise(order, conflict: conflict, resolution: resolution);
  }

  Future<void> ticketPrinted(String ticketId) => ticketReady(ticketId);

  /// The database decides readiness: transmitted print or explicit optional print.
  Future<void> ticketReady(String ticketId) async {
    try {
      await _refresh();
    } catch (_) {
      loadFailed = true;
      notifyListeners();
      return;
    }
    final delivery = deliveryForTicket(ticketId);
    if (delivery?.status == ClientDeliveryStatus.pending &&
        !waitingForEarlierRevision(delivery!)) {
      if (await _send(delivery)) await _drainRecoverableDeliveries();
    } else if (delivery?.status == ClientDeliveryStatus.pending) {
      await _drainRecoverableDeliveries();
    }
  }

  Future<bool> retry(String deliveryId) async {
    final existing = deliveries.where((delivery) => delivery.id == deliveryId);
    if (_sendingIds.contains(deliveryId) ||
        (existing.isNotEmpty && waitingForEarlierRevision(existing.single))) {
      return false;
    }
    try {
      final pending = await _store.resetClientDeliveryForRetry(deliveryId);
      await _refresh();
      final result = await _send(pending);
      if (result) await _drainRecoverableDeliveries();
      return result;
    } catch (_) {
      await _refreshSafely();
      return false;
    }
  }

  Future<void> _drainRecoverableDeliveries() async {
    if (_disposed || _draining) return;
    _draining = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    try {
      final ordered = List<ClientDelivery>.from(deliveries)
        ..sort((a, b) {
          final created = a.envelope.createdAt.compareTo(b.envelope.createdAt);
          if (created != 0) return created;
          final order = (a.envelope.managedOrderId ?? a.id).compareTo(
            b.envelope.managedOrderId ?? b.id,
          );
          return order != 0
              ? order
              : a.envelope.revision.compareTo(b.envelope.revision);
        });
      for (var delivery in ordered) {
        if (waitingForEarlierRevision(delivery)) continue;
        if (_disposed) return;
        if (delivery.status == ClientDeliveryStatus.failed &&
            _isAutomaticallyRetryable(delivery)) {
          try {
            delivery = await _store.resetClientDeliveryForRetry(delivery.id);
            await _refresh();
          } catch (_) {
            await _refreshSafely();
            continue;
          }
        }
        if (delivery.status == ClientDeliveryStatus.pending) {
          await _send(delivery);
        }
      }
    } finally {
      _draining = false;
      _scheduleRetry();
    }
  }

  bool _isAutomaticallyRetryable(ClientDelivery delivery) =>
      delivery.status == ClientDeliveryStatus.failed &&
      _automaticallyRetryableErrors.contains(delivery.errorCode);

  void _cancelRetryWhenSettled() {
    if (deliveries.any(_isAutomaticallyRetryable)) return;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _scheduleRetry() {
    if (_disposed ||
        _draining ||
        _retryTimer != null ||
        activeServer == null ||
        !deliveries.any(_isAutomaticallyRetryable)) {
      return;
    }
    _retryTimer = Timer(retryDelay, () {
      _retryTimer = null;
      unawaited(_drainRecoverableDeliveries());
    });
  }

  bool waitingForEarlierRevision(ClientDelivery delivery) {
    final orderId = delivery.envelope.managedOrderId;
    return orderId != null &&
        deliveries.any(
          (other) =>
              other.destinationId == delivery.destinationId &&
              other.envelope.managedOrderId == orderId &&
              other.envelope.revision < delivery.envelope.revision &&
              other.status != ClientDeliveryStatus.delivered,
        );
  }

  Future<bool> _send(ClientDelivery delivery) async {
    if (_sendingIds.contains(delivery.id)) return false;
    final server = activeServer;
    if (server == null || server.id != delivery.destinationId) {
      await _fail(delivery.id, 'destination');
      return false;
    }
    _sendingIds.add(delivery.id);
    notifyListeners();
    try {
      final token = await _secrets.readServerAccessToken(server.id);
      if (token == null || token.isEmpty) {
        await _fail(delivery.id, 'credentials');
        return false;
      }
      final sending = await _store.markClientDeliverySending(delivery.id);
      await _refresh();
      final target = _store is SharedClientStore
          ? await (_store as SharedClientStore).sharedDeliveryTarget(sending)
          : null;
      final acknowledgement = await _deliverToServer(
        server,
        token,
        sending,
        target,
      );
      await _store.markClientDeliveryDelivered(
        delivery.id,
        serverOrderId: acknowledgement.serverOrderId,
        deliveredAt: DateTime.now().toUtc(),
      );
      await _refresh();
      _cancelRetryWhenSettled();
      return true;
    } on ClientTransportException catch (error) {
      await _fail(delivery.id, error.code);
      return false;
    } catch (_) {
      await _fail(delivery.id, 'storage');
      return false;
    } finally {
      _sendingIds.remove(delivery.id);
      notifyListeners();
    }
  }

  Future<DeliveryAcknowledgement> _deliverToServer(
    PairedServer server,
    String token,
    ClientDelivery delivery,
    SharedDeliveryTarget? target,
  ) async {
    if (target != null && _transport is SharedOrdersTransport) {
      try {
        return await (_transport as SharedOrdersTransport).appendSharedOrder(
          server: server,
          accessToken: token,
          delivery: delivery,
          target: target,
        );
      } on ClientTransportException catch (error) {
        // Capability rejection precedes any mutation. Ambiguous responses
        // retain the shared operation and must never switch protocols.
        if (error.code != 'unsupported_shared' || target.requiresSharing) {
          rethrow;
        }
      }
    } else if (target?.requiresSharing ?? false) {
      throw const ClientTransportException('unsupported_shared');
    }
    return _transport.deliver(
      server: server,
      accessToken: token,
      delivery: delivery,
    );
  }

  Future<void> _fail(String id, String code) async {
    try {
      await _store.markClientDeliveryFailed(id, errorCode: code);
    } catch (_) {
      // A sending row is recovered to pending when storage next opens.
    }
    await _refreshSafely();
    _scheduleRetry();
  }

  Future<void> _refresh() async {
    activeServer = await _store.loadActiveServer();
    deliveries = await _store.loadClientDeliveries();
    notifyListeners();
  }

  Future<void> _refreshSafely() async {
    try {
      await _refresh();
    } catch (_) {
      loadFailed = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    super.dispose();
  }

  static String _clientIdentityFingerprint(String installationId) => sha256
      .convert(utf8.encode('libreslip-client-identity-v1:$installationId'))
      .toString();
}
