import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../data/pinned_https_client.dart';
import '../domain/client_delivery_models.dart';
import '../domain/client_security.dart';
import '../domain/client_transport.dart';
import '../domain/network_models.dart';

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

  Future<void> ticketFinalised(String ticketId) async {
    await _refresh();
    final delivery = deliveryForTicket(ticketId);
    if (delivery?.status == ClientDeliveryStatus.pending) {
      await _send(delivery!);
    }
  }

  Future<bool> retry(String deliveryId) async {
    if (_sendingIds.contains(deliveryId)) return false;
    try {
      final pending = await _store.resetClientDeliveryForRetry(deliveryId);
      await _refresh();
      return await _send(pending);
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
      for (var delivery in List<ClientDelivery>.from(deliveries)) {
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
      final acknowledgement = await _transport.deliver(
        server: server,
        accessToken: token,
        delivery: sending,
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
