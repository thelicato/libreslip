import 'dart:async';

import 'package:libreslip/features/orders/application/order_workspace_controller.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/settings/data/settings_repository.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<OrderWorkspaceController> createMemoryOrders() async {
  sqfliteFfiInit();
  final controller = OrderWorkspaceController(
    SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    ),
  );
  await controller.load();
  return controller;
}

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
