import 'dart:convert';
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
  await removeManagedColumnsForLegacyFixture(database);
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

Future<void> removeManagedColumnsForLegacyFixture(Database database) async {
  await removeDeliveryColumnsForLegacyFixture(database);
  await database.execute('DROP INDEX server_managed_order_unique');
  await database.execute('DROP TABLE managed_orders');
  await database.execute('DROP TABLE server_order_revisions');
  for (final table in ['drafts', 'tickets', 'server_orders']) {
    await database.execute('ALTER TABLE $table DROP COLUMN managed_order_id');
  }
  for (final (table, column) in [
    ('drafts', 'base_revision'),
    ('tickets', 'revision'),
    ('tickets', 'addition_line_ids'),
    ('ticket_lines', 'order_line_id'),
    ('server_orders', 'revision'),
    ('server_orders', 'completed_revision'),
    ('server_order_lines', 'order_line_id'),
    ('server_order_lines', 'added_revision'),
    ('order_feature_settings', 'managed_orders_enabled'),
  ]) {
    await database.execute('ALTER TABLE $table DROP COLUMN $column');
  }
}

Future<void> removeDeliveryColumnsForLegacyFixture(Database database) async {
  await removeProgressSyncColumnsForLegacyFixture(database);
  await database.execute(
    'ALTER TABLE managed_orders DROP COLUMN delivery_progress_json',
  );
  await database.execute(
    'ALTER TABLE server_order_lines DROP COLUMN delivered_quantity',
  );
}

Future<void> removeProgressSyncColumnsForLegacyFixture(
  Database database,
) async {
  await removePriceColumnsForLegacyFixture(database);
  await database.execute('DROP TABLE client_progress_sync');
  await database.execute('DROP TABLE server_progress_receipts');
  await database.execute(
    'ALTER TABLE managed_orders DROP COLUMN delivery_changed_ids',
  );
  await database.execute(
    'ALTER TABLE managed_orders DROP COLUMN delivery_edit_revision',
  );
  await database.execute(
    'ALTER TABLE server_orders DROP COLUMN progress_revision',
  );
}

Future<void> removePriceColumnsForLegacyFixture(Database database) async {
  await removeSharedTablesForLegacyFixture(database);
  for (final table in ['items', 'draft_lines', 'ticket_lines']) {
    await database.execute('ALTER TABLE $table DROP COLUMN price_currency');
    await database.execute('ALTER TABLE $table DROP COLUMN price_minor_units');
  }
  await database.execute(
    'ALTER TABLE order_feature_settings DROP COLUMN prices_enabled',
  );
  for (final row in await database.query('managed_orders')) {
    final lines = jsonDecode(row['lines_json'] as String) as List;
    for (final line in lines) {
      (line as Map).remove('priceMinorUnits');
      line.remove('priceCurrency');
    }
    await database.update(
      'managed_orders',
      {'lines_json': jsonEncode(lines)},
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }
}

Future<void> removeSharedTablesForLegacyFixture(Database database) async {
  await removeMultipleServerColumnsForLegacyFixture(database);
  await database.execute('DROP TABLE shared_order_links');
  await database.execute('DROP TABLE server_shared_receipts');
  await database.execute(
    'ALTER TABLE server_delivery_outbox DROP COLUMN shared_addition_ids',
  );
  await database.execute(
    'ALTER TABLE server_delivery_outbox DROP COLUMN shared_server_order_id',
  );
}

Future<void> removeMultipleServerColumnsForLegacyFixture(
  Database database,
) async {
  await database.execute(
    'UPDATE network_destinations SET is_active = is_default',
  );
  await database.execute('DROP INDEX network_destinations_one_default');
  await database.execute(
    'ALTER TABLE network_destinations DROP COLUMN is_default',
  );
  await database.execute(
    'CREATE UNIQUE INDEX network_destinations_one_active ON network_destinations(is_active) WHERE is_active = 1',
  );
}
