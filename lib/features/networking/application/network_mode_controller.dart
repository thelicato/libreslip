import 'package:flutter/foundation.dart';

import '../domain/network_models.dart';

class NetworkModeController extends ChangeNotifier {
  NetworkModeController(this._store);

  final NetworkConfigurationStore _store;
  NetworkConfiguration? configuration;
  bool loaded = false;
  bool loading = false;
  bool loadFailed = false;
  bool saving = false;
  bool saveFailed = false;

  LibreSlipMode get mode => configuration?.mode ?? LibreSlipMode.client;

  Future<void> load() async {
    if (loading) return;
    loading = true;
    loadFailed = false;
    notifyListeners();
    try {
      configuration = await _store.loadNetworkConfiguration();
      loaded = true;
    } catch (_) {
      loaded = false;
      loadFailed = true;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> setMode(LibreSlipMode next) async {
    if (!loaded || saving || next == mode) return next == mode;
    saving = true;
    saveFailed = false;
    notifyListeners();
    try {
      await _store.saveLibreSlipMode(next);
      configuration = configuration!.copyWith(mode: next);
      return true;
    } catch (_) {
      saveFailed = true;
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
