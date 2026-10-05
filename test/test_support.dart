import 'dart:async';

import 'package:libreslip/features/orders/application/order_workspace_controller.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/settings/data/settings_repository.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<
  ({OrderWorkspaceController controller, SqliteOrderRepository repository})
>
createMemoryOrderEnvironment() async {
  sqfliteFfiInit();
  final repository = SqliteOrderRepository(
    factory: databaseFactoryFfiNoIsolate,
    databasePath: inMemoryDatabasePath,
  );
  final controller = OrderWorkspaceController(repository);
  await controller.load();
  return (controller: controller, repository: repository);
}

Future<OrderWorkspaceController> createMemoryOrders() async =>
    (await createMemoryOrderEnvironment()).controller;

/// Removes schema 11 additions before simulating an earlier schema version.
Future<void> removeCourseColumnsForLegacyFixture(Database database) async {
  for (final table in ['drafts', 'tickets', 'server_orders']) {
    await database.execute('ALTER TABLE $table DROP COLUMN courses_json');
  }
  for (final table in ['draft_lines', 'ticket_lines', 'server_order_lines']) {
    await database.execute('ALTER TABLE $table DROP COLUMN course_id');
  }
  await database.execute('ALTER TABLE drafts DROP COLUMN active_course_id');
  await database.execute(
    'ALTER TABLE order_feature_settings DROP COLUMN course_groups_enabled',
  );
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
