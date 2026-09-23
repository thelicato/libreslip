import 'package:flutter/foundation.dart';

import '../data/settings_repository.dart';
import '../domain/app_settings.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(
    this._repository, {
    AppSettings initial = const AppSettings(),
  }) : _settings = initial;

  final SettingsRepository _repository;
  AppSettings _settings;
  bool _disposed = false;
  bool loaded = false;
  bool loading = false;
  bool loadFailed = false;
  bool saving = false;
  bool saveFailed = false;

  AppSettings get settings => _settings;

  Future<void> load() async {
    if (loading || _disposed) return;
    loading = true;
    loadFailed = false;
    _notify();
    try {
      final stored = await _repository.load();
      if (_disposed) return;
      _settings = stored ?? _settings;
      loaded = true;
    } catch (_) {
      loadFailed = true;
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<bool> update(AppSettings next) async {
    if (!loaded || saving || _disposed) return false;
    saving = true;
    saveFailed = false;
    _notify();
    try {
      await _repository.save(next);
      if (_disposed) return false;
      _settings = next;
      return true;
    } catch (_) {
      saveFailed = true;
      return false;
    } finally {
      saving = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
