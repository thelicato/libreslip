import 'dart:async';

import 'package:libreslip/features/settings/data/settings_repository.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';

class MemorySettingsRepository implements SettingsRepository {
  AppSettings? stored;
  bool failLoad = false;
  bool failSave = false;
  int writes = 0;
  Completer<void>? saveGate;

  @override
  Future<AppSettings?> load() async {
    if (failLoad) throw StateError('Storage unavailable');
    return stored;
  }

  @override
  Future<void> save(AppSettings settings) async {
    if (saveGate != null) await saveGate!.future;
    if (failSave) throw StateError('Storage unavailable');
    stored = settings;
    writes++;
  }
}
