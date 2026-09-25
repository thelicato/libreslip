import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/server_identity_service.dart';
import '../domain/network_models.dart';
import '../domain/server_inbox_models.dart';
import '../domain/server_runtime_service.dart';
import '../domain/server_security.dart';
import '../domain/server_transport.dart';

class ServerInboxController extends ChangeNotifier {
  ServerInboxController(
    this._store,
    ServerSecretStore secrets,
    this._host, {
    this.runtimeService = const NoopServerRuntimeService(),
  }) : _identityService = ServerIdentityService(secrets);

  final ServerInboxStore _store;
  final ServerIdentityService _identityService;
  final ServerHost _host;
  final ServerRuntimeService runtimeService;

  bool loading = false;
  bool listening = false;
  bool failed = false;
  bool updating = false;
  Object? lastError;
  RunningServer? runningServer;
  ServerIdentity? identity;
  ClientPairingRequest? pendingPairingRequest;
  List<ServerOrder> orders = const [];
  Completer<bool>? _pairingDecision;
  bool _disposed = false;
  bool _shouldListen = false;
  Timer? _pairingTimer;

  List<ServerOrder> get receivedOrders => orders
      .where((order) => order.status == ServerOrderStatus.received)
      .toList(growable: false);

  List<ServerOrder> get completedOrders => orders
      .where((order) => order.status == ServerOrderStatus.done)
      .toList(growable: false);

  Future<void> start(NetworkConfiguration configuration) async {
    if (_disposed || listening) return;
    _shouldListen = true;
    if (loading) return;
    loading = true;
    failed = false;
    lastError = null;
    _notify();
    try {
      identity ??= await _identityService.loadOrCreate();
      if (!_shouldListen || _disposed) return;
      orders = await _store.loadServerOrders();
      if (!_shouldListen || _disposed) return;
      final started = await _host.start(
        identity: identity!,
        configuration: configuration,
        requestPairingApproval: _requestPairingApproval,
        onOrderReceived: () => _reloadAfterReceipt(),
      );
      if (!_shouldListen || _disposed) {
        await _host.stop();
        return;
      }
      await runtimeService.start();
      if (!_shouldListen || _disposed) {
        await _host.stop();
        await runtimeService.stop();
        return;
      }
      runningServer = started;
      listening = true;
    } catch (error) {
      failed = true;
      lastError = error;
      listening = false;
      runningServer = null;
      await _host.stop();
      await runtimeService.stop();
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> stop() async {
    _shouldListen = false;
    _completePairingRequest(false);
    await _host.stop();
    await runtimeService.stop();
    listening = false;
    runningServer = null;
    _notify();
  }

  Future<bool> _requestPairingApproval(ClientPairingRequest request) {
    if (_disposed || _pairingDecision != null) return Future.value(false);
    final decision = Completer<bool>();
    _pairingDecision = decision;
    pendingPairingRequest = request;
    _pairingTimer?.cancel();
    _pairingTimer = Timer(
      const Duration(minutes: 2),
      () => _completePairingRequest(false),
    );
    _notify();
    return decision.future;
  }

  void acceptPairingRequest() => _completePairingRequest(true);

  void rejectPairingRequest() => _completePairingRequest(false);

  void _completePairingRequest(bool accepted) {
    final decision = _pairingDecision;
    _pairingTimer?.cancel();
    _pairingTimer = null;
    _pairingDecision = null;
    pendingPairingRequest = null;
    if (decision != null && !decision.isCompleted) {
      decision.complete(accepted);
    }
    _notify();
  }

  Future<void> refresh() async {
    try {
      orders = await _store.loadServerOrders();
      failed = false;
    } catch (_) {
      failed = true;
    }
    _notify();
  }

  Future<bool> markDone(String id) async {
    if (updating) return false;
    updating = true;
    _notify();
    try {
      await _store.markServerOrderDone(id, completedAt: DateTime.now().toUtc());
      orders = await _store.loadServerOrders();
      return true;
    } catch (_) {
      failed = true;
      return false;
    } finally {
      updating = false;
      _notify();
    }
  }

  Future<bool> markReceived(String id) async {
    if (updating) return false;
    updating = true;
    _notify();
    try {
      await _store.markServerOrderReceived(id);
      orders = await _store.loadServerOrders();
      return true;
    } catch (_) {
      failed = true;
      return false;
    } finally {
      updating = false;
      _notify();
    }
  }

  Future<bool> deleteCompleted(String id) async {
    if (updating) return false;
    updating = true;
    _notify();
    try {
      await _store.deleteCompletedServerOrder(id);
      orders = await _store.loadServerOrders();
      return true;
    } catch (_) {
      failed = true;
      return false;
    } finally {
      updating = false;
      _notify();
    }
  }

  Future<bool> deleteAllCompleted() async {
    if (updating) return false;
    updating = true;
    _notify();
    try {
      await _store.deleteAllCompletedServerOrders();
      orders = await _store.loadServerOrders();
      return true;
    } catch (_) {
      failed = true;
      return false;
    } finally {
      updating = false;
      _notify();
    }
  }

  void _reloadAfterReceipt() {
    Future<void>(refresh);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _shouldListen = false;
    _completePairingRequest(false);
    unawaited(_host.stop());
    unawaited(runtimeService.stop());
    super.dispose();
  }
}
