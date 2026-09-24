import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/server_identity_service.dart';
import '../domain/network_models.dart';
import '../domain/server_inbox_models.dart';
import '../domain/server_security.dart';
import '../domain/server_transport.dart';

class PairingWindow {
  const PairingWindow({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;

  bool get expired => !DateTime.now().isBefore(expiresAt);
}

class ServerInboxController extends ChangeNotifier {
  ServerInboxController(this._store, ServerSecretStore secrets, this._host)
    : _identityService = ServerIdentityService(secrets);

  final ServerInboxStore _store;
  final ServerIdentityService _identityService;
  final ServerHost _host;

  bool loading = false;
  bool listening = false;
  bool failed = false;
  bool updating = false;
  Object? lastError;
  RunningServer? runningServer;
  ServerIdentity? identity;
  PairingWindow? pairingWindow;
  List<ServerOrder> orders = const [];
  bool _pairingClaimed = false;
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
        claimPairingCode: _claimPairingCode,
        onOrderReceived: () => _reloadAfterReceipt(),
      );
      if (!_shouldListen || _disposed) {
        await _host.stop();
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
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> stop() async {
    _shouldListen = false;
    _pairingTimer?.cancel();
    _pairingTimer = null;
    pairingWindow = null;
    _pairingClaimed = false;
    await _host.stop();
    listening = false;
    runningServer = null;
    _notify();
  }

  void openPairingWindow() {
    final value = Random.secure().nextInt(1000000);
    pairingWindow = PairingWindow(
      code: value.toString().padLeft(6, '0'),
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
    _pairingClaimed = false;
    _pairingTimer?.cancel();
    _pairingTimer = Timer(const Duration(minutes: 5), closePairingWindow);
    _notify();
  }

  void closePairingWindow() {
    _pairingTimer?.cancel();
    _pairingTimer = null;
    pairingWindow = null;
    _pairingClaimed = false;
    _notify();
  }

  bool _claimPairingCode(String code) {
    final window = pairingWindow;
    if (window == null ||
        window.expired ||
        _pairingClaimed ||
        window.code != code) {
      return false;
    }
    _pairingClaimed = true;
    _pairingTimer?.cancel();
    _pairingTimer = null;
    pairingWindow = null;
    _notify();
    return true;
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
    _pairingTimer?.cancel();
    _host.stop();
    super.dispose();
  }
}
