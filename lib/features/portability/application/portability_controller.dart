import 'package:flutter/foundation.dart';

import '../../orders/application/order_workspace_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../domain/portability_models.dart';
import 'portability_service.dart';

class PortabilityController extends ChangeNotifier {
  PortabilityController(this._service, this._settings, this._orders);

  final PortabilityService _service;
  final SettingsController _settings;
  final OrderWorkspaceController _orders;

  bool busy = false;
  String? errorCode;
  ImportPreview? preview;

  Future<void> recoverAtStartup() async {
    try {
      await _service.recoverInterruptedRestore();
    } on PortabilityException catch (error) {
      errorCode = error.code;
      notifyListeners();
    } catch (_) {
      errorCode = 'rollbackFailed';
      notifyListeners();
    }
  }

  Future<bool> export(PortableArchiveKind kind) => _run(() async {
    await _orders.flushWrites();
    await _service.exportAndShare(kind);
  });

  Future<bool?> chooseImport() async {
    if (busy) return false;
    busy = true;
    errorCode = null;
    preview = null;
    notifyListeners();
    try {
      preview = await _service.pickAndInspect();
      return preview == null ? null : true;
    } on PortabilityException catch (error) {
      errorCode = error.code;
      return false;
    } catch (_) {
      errorCode = 'invalidArchive';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> restorePreview() async {
    final selected = preview;
    if (selected == null) return false;
    final restored = await _run(() async {
      await _orders.flushWrites();
      await _service.restore(selected);
      final settingsReloaded = await _settings.reloadAfterRestore();
      final ordersReloaded = await _orders.reloadAfterRestore();
      if (!settingsReloaded || !ordersReloaded) {
        throw const PortabilityException('reloadFailed');
      }
    });
    if (restored) preview = null;
    return restored;
  }

  void discardPreview() {
    preview = null;
    errorCode = null;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() operation) async {
    if (busy) return false;
    busy = true;
    errorCode = null;
    notifyListeners();
    try {
      await operation();
      return true;
    } on PortabilityException catch (error) {
      errorCode = error.code;
      return false;
    } catch (_) {
      errorCode = 'operationFailed';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
