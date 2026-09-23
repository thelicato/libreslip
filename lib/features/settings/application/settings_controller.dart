import 'package:flutter/foundation.dart';

import '../data/settings_repository.dart';
import '../data/ticket_logo_store.dart';
import '../domain/app_settings.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(
    this._repository, {
    AppSettings initial = const AppSettings(),
    this._logoStore,
  }) : _settings = initial;

  final SettingsRepository _repository;
  final TicketLogoStore? _logoStore;
  AppSettings _settings;
  bool _disposed = false;
  bool loaded = false;
  bool loading = false;
  bool loadFailed = false;
  bool saving = false;
  bool saveFailed = false;
  bool logoFailed = false;

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

  Future<bool> chooseLogo() async {
    final store = _logoStore;
    if (store == null || saving || _disposed) return false;
    logoFailed = false;
    _notify();
    try {
      final selected = await store.chooseAndStore();
      if (selected == null || _disposed) return false;
      final previous = _settings.logoPath;
      final saved = await update(_settings.copyWith(logoPath: selected));
      if (!saved) {
        await store.remove(selected);
        return false;
      }
      if (previous != null && previous != selected) {
        try {
          await store.remove(previous);
        } catch (_) {
          // The selected logo is already saved and remains usable.
        }
      }
      return true;
    } catch (_) {
      logoFailed = true;
      _notify();
      return false;
    }
  }

  Future<bool> removeLogo() async {
    final previous = _settings.logoPath;
    if (previous == null) return true;
    final saved = await update(_settings.copyWith(clearLogo: true));
    if (saved && _logoStore != null) {
      try {
        await _logoStore.remove(previous);
      } catch (_) {
        // The preference is already safe and no longer references this file.
      }
    }
    return saved;
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
