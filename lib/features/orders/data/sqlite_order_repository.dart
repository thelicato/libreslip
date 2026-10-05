import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../networking/domain/client_delivery_models.dart';
import '../../networking/domain/network_models.dart';
import '../../networking/domain/network_protocol.dart';
import '../../networking/domain/order_progress.dart';
import '../../networking/domain/server_inbox_models.dart';
import '../../printing/domain/print_job.dart';
import '../domain/order_models.dart';

class SqliteOrderRepository
    implements
        OrderRepository,
        PrintJobStore,
        NetworkConfigurationStore,
        ClientDeliveryStore,
        ServerInboxStore,
        ClientProgressStore,
        ServerProgressStore,
        ProgressRecoveryStore {
  SqliteOrderRepository({DatabaseFactory? factory, this._databasePath})
    : _factory = factory ?? databaseFactory;

  static const databaseVersion = 15;
  static const portableSchemaVersions = {
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    databaseVersion,
  };
  static const databaseFileName = 'libreslip.sqlite3';

  final DatabaseFactory _factory;
  final String? _databasePath;
  Database? _database;

  Future<Database> get _db async {
    final database = _database;
    if (database == null) {
      throw const OrderStorageException('The order database is not open.');
    }
    return database;
  }

  @override
  Future<void> open() async {
    if (_database != null) return;
    try {
      final path =
          _databasePath ?? p.join(await getDatabasesPath(), databaseFileName);
      _database = await _factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          singleInstance: path != inMemoryDatabasePath,
          version: databaseVersion,
          onConfigure: (database) async {
            await database.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: (database, version) async {
            await _migrate(database, 0, version);
          },
          onUpgrade: _migrate,
        ),
      );
      await _database!.transaction((transaction) async {
        await transaction.update(
          'print_jobs',
          {
            'status': printJobStatusValue(PrintJobStatus.uncertain),
            'error_code': 'interrupted',
            'updated_at': _timestamp(DateTime.now()),
          },
          where: 'status = ?',
          whereArgs: [printJobStatusValue(PrintJobStatus.sending)],
        );
        await transaction.update(
          'server_delivery_outbox',
          {
            'status': 'pending',
            'error_code': 'interrupted',
            'updated_at': _timestamp(DateTime.now()),
          },
          where: 'status = ?',
          whereArgs: ['sending'],
        );
      });
    } catch (error) {
      throw OrderStorageException('Could not open the order database.', error);
    }
  }

  static Future<void> _migrate(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 1 && newVersion >= 1) {
      await database.execute('''
        CREATE TABLE categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL COLLATE NOCASE UNIQUE,
          created_at TEXT NOT NULL
        )
      ''');
      await database.execute('''
        CREATE TABLE items (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          category_id TEXT REFERENCES categories(id) ON DELETE SET NULL,
          archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1)),
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await database.execute('''
        CREATE UNIQUE INDEX items_active_name_unique
        ON items(name COLLATE NOCASE) WHERE archived = 0
      ''');
      await database.execute('''
        CREATE TABLE drafts (
          id TEXT PRIMARY KEY,
          reference TEXT NOT NULL DEFAULT '',
          order_note TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await database.execute('''
        CREATE TABLE draft_lines (
          id TEXT PRIMARY KEY,
          draft_id TEXT NOT NULL REFERENCES drafts(id) ON DELETE CASCADE,
          catalogue_item_id TEXT REFERENCES items(id) ON DELETE SET NULL,
          name_snapshot TEXT NOT NULL,
          quantity INTEGER NOT NULL CHECK (quantity > 0 AND quantity <= 999),
          preparation_note TEXT NOT NULL DEFAULT '',
          position INTEGER NOT NULL,
          UNIQUE(draft_id, position)
        )
      ''');
      await database.execute('''
        CREATE TABLE tickets (
          id TEXT PRIMARY KEY,
          ticket_number INTEGER NOT NULL UNIQUE,
          origin_draft_id TEXT NOT NULL UNIQUE,
          heading_snapshot TEXT NOT NULL,
          reference_snapshot TEXT NOT NULL DEFAULT '',
          order_note_snapshot TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL
        )
      ''');
      await database.execute('''
        CREATE TABLE ticket_lines (
          id TEXT PRIMARY KEY,
          ticket_id TEXT NOT NULL REFERENCES tickets(id) ON DELETE RESTRICT,
          catalogue_item_id TEXT,
          name_snapshot TEXT NOT NULL,
          quantity INTEGER NOT NULL CHECK (quantity > 0 AND quantity <= 999),
          preparation_note TEXT NOT NULL DEFAULT '',
          position INTEGER NOT NULL,
          UNIQUE(ticket_id, position)
        )
      ''');
      await database.execute('''
        CREATE TABLE counters (
          name TEXT PRIMARY KEY,
          next_value INTEGER NOT NULL CHECK (next_value > 0)
        )
      ''');
      await database.insert('counters', {'name': 'ticket', 'next_value': 1});
    }
    if (oldVersion < 2 && newVersion >= 2) {
      await database.execute(
        'ALTER TABLE items ADD COLUMN is_favourite INTEGER NOT NULL '
        'DEFAULT 0 CHECK (is_favourite IN (0, 1))',
      );
      await database.execute('ALTER TABLE items ADD COLUMN image_path TEXT');
      await database.execute(
        'ALTER TABLE tickets ADD COLUMN source_ticket_id TEXT',
      );
    }
    if (oldVersion < 3 && newVersion >= 3) {
      await database.execute('''
        CREATE TABLE print_jobs (
          id TEXT PRIMARY KEY,
          request_id TEXT NOT NULL UNIQUE,
          ticket_id TEXT NOT NULL REFERENCES tickets(id) ON DELETE RESTRICT,
          payload BLOB NOT NULL,
          status TEXT NOT NULL CHECK (
            status IN ('queued', 'sending', 'transmitted', 'failed', 'uncertain')
          ),
          printer_address TEXT,
          printer_name TEXT,
          error_code TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await database.execute(
        'CREATE INDEX print_jobs_ticket_index '
        'ON print_jobs(ticket_id, created_at DESC)',
      );
    }
    if (oldVersion < 4 && newVersion >= 4) {
      await database.execute('''
        CREATE TABLE order_feature_settings (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          order_reference_enabled INTEGER NOT NULL DEFAULT 1
            CHECK (order_reference_enabled IN (0, 1)),
          preparation_notes_enabled INTEGER NOT NULL DEFAULT 1
            CHECK (preparation_notes_enabled IN (0, 1)),
          order_notes_enabled INTEGER NOT NULL DEFAULT 1
            CHECK (order_notes_enabled IN (0, 1))
        )
      ''');
      await database.insert('order_feature_settings', {
        'id': 1,
        'order_reference_enabled': 1,
        'preparation_notes_enabled': 1,
        'order_notes_enabled': 1,
      });
    }
    if (oldVersion < 5 && newVersion >= 5) {
      await database.execute(
        'ALTER TABLE tickets ADD COLUMN display_number INTEGER NOT NULL '
        'DEFAULT 1 CHECK (display_number > 0)',
      );
      await database.execute(
        'UPDATE tickets SET display_number = ticket_number',
      );
      await database.execute('''
        INSERT INTO counters(name, next_value)
        SELECT 'order', next_value FROM counters WHERE name = 'ticket'
      ''');
    }
    if (oldVersion < 6 && newVersion >= 6) {
      await database.execute('''
        CREATE TABLE network_settings (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          app_mode TEXT NOT NULL DEFAULT 'client'
            CHECK (app_mode IN ('client', 'server')),
          installation_id TEXT NOT NULL UNIQUE
            CHECK (length(installation_id) BETWEEN 16 AND 128),
          server_name TEXT NOT NULL DEFAULT 'LibreSlip Server'
            CHECK (length(server_name) BETWEEN 1 AND 80)
        )
      ''');
      await database.insert('network_settings', {
        'id': 1,
        'app_mode': 'client',
        'installation_id': createInstallationId(),
        'server_name': 'LibreSlip Server',
      });
      await database.execute('''
        CREATE TABLE network_destinations (
          id TEXT PRIMARY KEY,
          display_name TEXT NOT NULL
            CHECK (length(display_name) BETWEEN 1 AND 80),
          base_url TEXT NOT NULL CHECK (length(base_url) BETWEEN 1 AND 2048),
          certificate_fingerprint TEXT NOT NULL UNIQUE
            CHECK (length(certificate_fingerprint) = 64),
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await database.execute('''
        CREATE TABLE server_delivery_outbox (
          id TEXT PRIMARY KEY,
          destination_id TEXT NOT NULL
            REFERENCES network_destinations(id) ON DELETE RESTRICT,
          client_installation_id TEXT NOT NULL,
          ticket_id TEXT NOT NULL,
          payload_json TEXT NOT NULL CHECK (length(payload_json) <= 65536),
          payload_checksum TEXT NOT NULL CHECK (length(payload_checksum) = 64),
          status TEXT NOT NULL CHECK (
            status IN ('pending', 'sending', 'delivered', 'failed')
          ),
          attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
          error_code TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          delivered_at TEXT,
          UNIQUE(destination_id, ticket_id),
          UNIQUE(client_installation_id, id)
        )
      ''');
      await database.execute('''
        CREATE INDEX server_delivery_outbox_status_index
        ON server_delivery_outbox(status, created_at)
      ''');
      await database.execute('''
        CREATE TABLE server_clients (
          installation_id TEXT PRIMARY KEY,
          display_name TEXT NOT NULL
            CHECK (length(display_name) BETWEEN 1 AND 80),
          certificate_fingerprint TEXT NOT NULL UNIQUE
            CHECK (length(certificate_fingerprint) = 64),
          paired_at TEXT NOT NULL,
          last_seen_at TEXT
        )
      ''');
      await database.execute('''
        CREATE TABLE server_orders (
          id TEXT PRIMARY KEY,
          client_installation_id TEXT NOT NULL
            REFERENCES server_clients(installation_id) ON DELETE RESTRICT,
          delivery_id TEXT NOT NULL,
          client_ticket_id TEXT NOT NULL,
          display_number INTEGER NOT NULL CHECK (display_number > 0),
          source_created_at TEXT NOT NULL,
          received_at TEXT NOT NULL,
          heading_snapshot TEXT NOT NULL
            CHECK (length(heading_snapshot) <= 60),
          reference_snapshot TEXT NOT NULL
            CHECK (length(reference_snapshot) <= 80),
          order_note_snapshot TEXT NOT NULL
            CHECK (length(order_note_snapshot) <= 500),
          payload_checksum TEXT NOT NULL CHECK (length(payload_checksum) = 64),
          status TEXT NOT NULL DEFAULT 'received'
            CHECK (status IN ('received', 'done')),
          completed_at TEXT,
          UNIQUE(client_installation_id, delivery_id)
        )
      ''');
      await database.execute('''
        CREATE INDEX server_orders_status_index
        ON server_orders(status, received_at DESC)
      ''');
      await database.execute('''
        CREATE TABLE server_order_lines (
          id TEXT PRIMARY KEY,
          order_id TEXT NOT NULL
            REFERENCES server_orders(id) ON DELETE CASCADE,
          name_snapshot TEXT NOT NULL
            CHECK (length(name_snapshot) BETWEEN 1 AND 80),
          quantity INTEGER NOT NULL CHECK (quantity BETWEEN 1 AND 999),
          preparation_note TEXT NOT NULL DEFAULT ''
            CHECK (length(preparation_note) <= 300),
          position INTEGER NOT NULL CHECK (position >= 0),
          UNIQUE(order_id, position)
        )
      ''');
    }
    if (oldVersion < 7 && newVersion >= 7) {
      await database.execute(
        'ALTER TABLE network_destinations ADD COLUMN is_active INTEGER '
        'NOT NULL DEFAULT 0 CHECK (is_active IN (0, 1))',
      );
      await database.execute(
        'ALTER TABLE server_delivery_outbox ADD COLUMN server_order_id TEXT',
      );
      await database.execute('''
        CREATE UNIQUE INDEX network_destinations_one_active
        ON network_destinations(is_active) WHERE is_active = 1
      ''');
    }
    if (oldVersion < 8 && newVersion >= 8) {
      await database.execute(
        'ALTER TABLE items ADD COLUMN send_to_server INTEGER NOT NULL '
        'DEFAULT 1 CHECK (send_to_server IN (0, 1))',
      );
    }
    if (oldVersion < 9 && newVersion >= 9) {
      await database.rawUpdate(
        'UPDATE network_destinations '
        'SET base_url = replace(base_url, ?, ?) '
        'WHERE base_url LIKE ?',
        [':42837', ':${NetworkProtocol.defaultPort}', '%:42837'],
      );
    }
    if (oldVersion < 10 && newVersion >= 10) {
      await database.execute(
        'ALTER TABLE server_delivery_outbox '
        'RENAME TO server_delivery_outbox_before_print_gate',
      );
      await database.execute('''
        CREATE TABLE server_delivery_outbox (
          id TEXT PRIMARY KEY,
          destination_id TEXT NOT NULL
            REFERENCES network_destinations(id) ON DELETE RESTRICT,
          client_installation_id TEXT NOT NULL,
          ticket_id TEXT NOT NULL,
          payload_json TEXT NOT NULL CHECK (length(payload_json) <= 65536),
          payload_checksum TEXT NOT NULL CHECK (length(payload_checksum) = 64),
          status TEXT NOT NULL CHECK (
            status IN (
              'awaiting_print', 'pending', 'sending', 'delivered', 'failed'
            )
          ),
          attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
          error_code TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          delivered_at TEXT,
          server_order_id TEXT,
          UNIQUE(destination_id, ticket_id),
          UNIQUE(client_installation_id, id)
        )
      ''');
      await database.execute('''
        INSERT INTO server_delivery_outbox (
          id, destination_id, client_installation_id, ticket_id, payload_json,
          payload_checksum, status, attempt_count, error_code, created_at,
          updated_at, delivered_at, server_order_id
        )
        SELECT
          id, destination_id, client_installation_id, ticket_id, payload_json,
          payload_checksum,
          CASE
            WHEN status = 'pending' AND NOT EXISTS (
              SELECT 1 FROM print_jobs
              WHERE print_jobs.ticket_id =
                server_delivery_outbox_before_print_gate.ticket_id
                AND print_jobs.status = 'transmitted'
            ) THEN 'awaiting_print'
            ELSE status
          END,
          attempt_count, error_code, created_at, updated_at, delivered_at,
          server_order_id
        FROM server_delivery_outbox_before_print_gate
      ''');
      await database.execute(
        'DROP TABLE server_delivery_outbox_before_print_gate',
      );
      await database.execute('''
        CREATE INDEX server_delivery_outbox_status_index
        ON server_delivery_outbox(status, created_at)
      ''');
    }
    if (oldVersion < 11 && newVersion >= 11) {
      for (final table in ['drafts', 'tickets', 'server_orders']) {
        await database.execute(
          "ALTER TABLE $table ADD COLUMN courses_json TEXT NOT NULL "
          "DEFAULT '[]' CHECK (length(courses_json) <= 16384)",
        );
      }
      for (final table in [
        'draft_lines',
        'ticket_lines',
        'server_order_lines',
      ]) {
        await database.execute('ALTER TABLE $table ADD COLUMN course_id TEXT');
      }
      await database.execute(
        'ALTER TABLE drafts ADD COLUMN active_course_id TEXT',
      );
      await database.execute(
        'ALTER TABLE order_feature_settings ADD COLUMN course_groups_enabled '
        'INTEGER NOT NULL DEFAULT 0 CHECK (course_groups_enabled IN (0, 1))',
      );
    }
    if (oldVersion < 12 && newVersion >= 12) {
      await database.execute(
        "ALTER TABLE order_feature_settings ADD COLUMN managed_orders_enabled INTEGER NOT NULL DEFAULT 0 CHECK (managed_orders_enabled IN (0, 1))",
      );
      await database.execute(
        "ALTER TABLE drafts ADD COLUMN managed_order_id TEXT",
      );
      await database.execute(
        "ALTER TABLE drafts ADD COLUMN base_revision INTEGER NOT NULL DEFAULT 0 CHECK (base_revision >= 0)",
      );
      await database.execute(
        "ALTER TABLE tickets ADD COLUMN managed_order_id TEXT",
      );
      await database.execute(
        "ALTER TABLE tickets ADD COLUMN revision INTEGER NOT NULL DEFAULT 0 CHECK (revision >= 0)",
      );
      await database.execute(
        "ALTER TABLE tickets ADD COLUMN addition_line_ids TEXT NOT NULL DEFAULT '[]'",
      );
      await database.execute(
        "ALTER TABLE ticket_lines ADD COLUMN order_line_id TEXT",
      );
      await database.execute(
        "ALTER TABLE server_orders ADD COLUMN managed_order_id TEXT",
      );
      await database.execute(
        "ALTER TABLE server_orders ADD COLUMN revision INTEGER NOT NULL DEFAULT 0 CHECK (revision >= 0)",
      );
      await database.execute(
        "ALTER TABLE server_order_lines ADD COLUMN order_line_id TEXT",
      );
      await database.execute(
        "ALTER TABLE server_order_lines ADD COLUMN added_revision INTEGER NOT NULL DEFAULT 0",
      );
      await database.execute(
        'ALTER TABLE server_orders ADD COLUMN completed_revision INTEGER NOT NULL DEFAULT 0 CHECK (completed_revision >= 0)',
      );
      await database.execute(
        "CREATE UNIQUE INDEX server_managed_order_unique ON server_orders(client_installation_id, managed_order_id) WHERE managed_order_id IS NOT NULL",
      );
      await database.execute('''
        CREATE TABLE server_order_revisions (
          client_installation_id TEXT NOT NULL,
          delivery_id TEXT NOT NULL,
          managed_order_id TEXT NOT NULL,
          revision INTEGER NOT NULL CHECK (revision > 0),
          order_id TEXT NOT NULL,
          payload_checksum TEXT NOT NULL,
          PRIMARY KEY(client_installation_id,
          delivery_id),
          UNIQUE(client_installation_id,
          managed_order_id,
          revision)
        )
      ''');
      await database.execute('''
        CREATE TABLE managed_orders (
          id TEXT PRIMARY KEY,
          display_number INTEGER NOT NULL CHECK (display_number > 0),
          revision INTEGER NOT NULL CHECK (revision > 0),
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          closed_at TEXT,
          heading_snapshot TEXT NOT NULL,
          reference_snapshot TEXT NOT NULL,
          order_note_snapshot TEXT NOT NULL,
          courses_json TEXT NOT NULL CHECK (length(courses_json) <= 16384),
          lines_json TEXT NOT NULL CHECK (length(lines_json) <= 262144),
          destination_id TEXT,
          client_installation_id TEXT,
          server_revision INTEGER NOT NULL DEFAULT 0 CHECK (server_revision >= 0)
        )
      ''');
    }
    if (oldVersion < 13 && newVersion >= 13) {
      await database.execute(
        "ALTER TABLE managed_orders ADD COLUMN delivery_progress_json TEXT NOT NULL DEFAULT '{}' CHECK (length(delivery_progress_json) <= 32768)",
      );
      await database.execute(
        'ALTER TABLE server_order_lines ADD COLUMN delivered_quantity INTEGER NOT NULL DEFAULT 0 CHECK (delivered_quantity >= 0 AND delivered_quantity <= quantity)',
      );
      // Preserve earlier Done actions, including orders reopened by additions.
      await database.execute('''
        UPDATE server_order_lines SET delivered_quantity = quantity
        WHERE order_id IN (SELECT id FROM server_orders WHERE managed_order_id IS NOT NULL)
          AND added_revision <= (SELECT completed_revision FROM server_orders WHERE id = order_id)
      ''');
    }
    if (oldVersion < 14 && newVersion >= 14) {
      await database.execute(
        "ALTER TABLE managed_orders ADD COLUMN delivery_changed_ids TEXT NOT NULL DEFAULT '[]' CHECK (length(delivery_changed_ids) <= 32768)",
      );
      await database.execute(
        'ALTER TABLE managed_orders ADD COLUMN delivery_edit_revision INTEGER NOT NULL DEFAULT 0 CHECK (delivery_edit_revision >= 0)',
      );
      final orders = await database.query('managed_orders');
      for (final row in orders) {
        // Earlier versions did not record zero-valued undo intent. Treat all
        // retained lines as edited until the first explicit synchronisation.
        final ids = decodeOrderLines(row['lines_json'])
            .map((line) => line.id)
            .toList();
        await database.update(
          'managed_orders',
          {'delivery_changed_ids': jsonEncode(ids)},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
      await database.execute(
        'ALTER TABLE server_orders ADD COLUMN progress_revision INTEGER NOT NULL DEFAULT 0 CHECK (progress_revision >= 0)',
      );
      await database.execute(
        'UPDATE server_orders SET progress_revision = 1 WHERE managed_order_id IS NOT NULL',
      );
      await database.execute('''CREATE TABLE client_progress_sync (
        order_id TEXT PRIMARY KEY, destination_id TEXT NOT NULL, client_id TEXT NOT NULL,
        baseline_json TEXT, pending_json TEXT, pending_local_revision INTEGER,
        FOREIGN KEY (order_id) REFERENCES managed_orders(id) ON DELETE CASCADE
      )''');
      await database.execute('''CREATE TABLE server_progress_receipts (
        client_id TEXT NOT NULL, operation_id TEXT NOT NULL, order_id TEXT NOT NULL,
        request_json TEXT NOT NULL, applied_json TEXT NOT NULL,
        PRIMARY KEY (client_id, operation_id),
        FOREIGN KEY (order_id) REFERENCES server_orders(id) ON DELETE CASCADE
      )''');
    }
    if (oldVersion < 15 && newVersion >= 15) {
      for (final table in ['items', 'draft_lines', 'ticket_lines']) {
        await database.execute(
          "ALTER TABLE $table ADD COLUMN price_minor_units INTEGER CHECK (price_minor_units IS NULL OR (typeof(price_minor_units) = 'integer' AND price_minor_units BETWEEN 0 AND 99999999))",
        );
        await database.execute(
          "ALTER TABLE $table ADD COLUMN price_currency TEXT CHECK ((price_minor_units IS NULL AND price_currency IS NULL) OR (price_minor_units IS NOT NULL AND price_currency IS NOT NULL AND price_currency IN ('EUR', 'GBP', 'USD')))",
        );
      }
      await database.execute(
        'ALTER TABLE order_feature_settings ADD COLUMN prices_enabled INTEGER NOT NULL DEFAULT 0 CHECK (prices_enabled IN (0, 1))',
      );
      // Preserve existing content while giving current managed snapshots an
      // explicit absent price. No catalogue lookup rewrites historical data.
      for (final row in await database.query('managed_orders')) {
        await database.update(
          'managed_orders',
          {'lines_json': encodeOrderLines(decodeOrderLines(row['lines_json']))},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
  }

  @override
  Future<NetworkConfiguration> loadNetworkConfiguration() async {
    try {
      final rows = await (await _db).query(
        'network_settings',
        where: 'id = 1',
        limit: 1,
      );
      if (rows.length != 1) {
        throw const OrderStorageException(
          'The network configuration could not be found.',
        );
      }
      final row = rows.single;
      return NetworkConfiguration(
        mode: LibreSlipModeValue.parse(row['app_mode']! as String),
        installationId: row['installation_id']! as String,
        serverName: row['server_name']! as String,
      );
    } catch (error) {
      if (error is OrderStorageException) rethrow;
      throw OrderStorageException(
        'Could not read the network configuration.',
        error,
      );
    }
  }

  @override
  Future<void> saveLibreSlipMode(LibreSlipMode mode) async {
    try {
      final changed = await (await _db).update('network_settings', {
        'app_mode': mode.value,
      }, where: 'id = 1');
      if (changed != 1) {
        throw const OrderStorageException(
          'The network configuration could not be found.',
        );
      }
    } catch (error) {
      if (error is OrderStorageException) rethrow;
      throw OrderStorageException('Could not save the app mode.', error);
    }
  }

  @override
  Future<PairedServer?> loadProgressServer(String serverId) async {
    final rows = await (await _db).query(
      'network_destinations',
      where: 'id = ?',
      whereArgs: [serverId],
    );
    return rows.isEmpty ? null : _pairedServerFromRow(rows.single);
  }

  static Future<ManagedOrder> _checkProgressScope(
    DatabaseExecutor tx,
    ManagedOrder expected, {
    bool checkEdits = false,
  }) async {
    final rows = await tx.query(
      'managed_orders',
      where: 'id = ? AND closed_at IS NULL',
      whereArgs: [expected.id],
    );
    if (rows.length != 1) throw const ProgressSyncException('local_changed');
    final current = _managedFromRow(rows.single);
    if (current.destinationId != expected.destinationId ||
        current.clientInstallationId != expected.clientInstallationId ||
        (checkEdits &&
            (current.revision != expected.revision ||
                current.deliveryEditRevision !=
                    expected.deliveryEditRevision))) {
      throw const ProgressSyncException('local_changed');
    }
    return current;
  }

  static Future<Map<String, Object?>?> _progressStateRow(
    DatabaseExecutor tx,
    ManagedOrder order,
  ) async {
    final rows = await tx.query(
      'client_progress_sync',
      where: 'order_id = ? AND destination_id = ? AND client_id = ?',
      whereArgs: [order.id, order.destinationId, order.clientInstallationId],
    );
    return rows.firstOrNull;
  }

  @override
  Future<ManagedOrder> reloadProgressOrder(ManagedOrder order) async =>
      _checkProgressScope(await _db, order);

  @override
  Future<ProgressSyncState> loadProgressSyncState(ManagedOrder order) async {
    final database = await _db;
    await _checkProgressScope(database, order);
    final row = await _progressStateRow(database, order);
    return ProgressSyncState(
      baseline: row?['baseline_json'] == null
          ? null
          : OrderProgressSnapshot.fromJson(
              jsonDecode(row!['baseline_json'] as String),
            ),
      pending: row?['pending_json'] == null
          ? null
          : OrderProgressChange.fromJson(
              jsonDecode(row!['pending_json'] as String),
            ),
    );
  }

  @override
  Future<void> savePendingProgress(
    ManagedOrder order,
    OrderProgressChange change,
  ) async {
    await (await _db).transaction((tx) async {
      await _checkProgressScope(tx, order, checkEdits: true);
      final previous = await _progressStateRow(tx, order);
      if (previous?['pending_json'] != null || change.orderId != order.id) {
        throw const ProgressSyncException('local_changed');
      }
      await tx.insert('client_progress_sync', {
        'order_id': order.id,
        'destination_id': order.destinationId,
        'client_id': order.clientInstallationId,
        'baseline_json': previous?['baseline_json'],
        'pending_json': jsonEncode(change.toJson()),
        'pending_local_revision': order.deliveryEditRevision,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  @override
  Future<void> acknowledgeProgress(
    ManagedOrder order,
    OrderProgressSnapshot applied,
  ) async {
    await (await _db).transaction((tx) async {
      final current = await _checkProgressScope(tx, order);
      final row = await _progressStateRow(tx, order);
      if (row?['pending_json'] == null) {
        throw const ProgressSyncException('local_changed');
      }
      final pending = OrderProgressChange.fromJson(
        jsonDecode(row!['pending_json'] as String),
      );
      if (applied.clientId != order.clientInstallationId ||
          applied.orderId != order.id ||
          applied.orderRevision != pending.orderRevision ||
          applied.progressRevision != pending.expectedRevision + 1 ||
          applied.quantities.length != pending.quantities.length ||
          pending.quantities.keys.any(
            (id) => pending.quantities[id] != applied.quantities[id],
          )) {
        throw const ProgressSyncException('identity');
      }
      if (current.deliveryEditRevision == row['pending_local_revision']) {
        await tx.update(
          'managed_orders',
          {
            'delivery_changed_ids': jsonEncode(
              current.changedDeliveryIds
                  .difference(applied.quantities.keys.toSet())
                  .toList()
                ..sort(),
            ),
          },
          where: 'id = ?',
          whereArgs: [order.id],
        );
      }
      await tx.update(
        'client_progress_sync',
        {
          'baseline_json': jsonEncode(applied.toJson()),
          'pending_json': null,
          'pending_local_revision': null,
        },
        where: 'order_id = ?',
        whereArgs: [order.id],
      );
    });
  }

  @override
  Future<void> discardRejectedProgress(ManagedOrder order) async {
    await (await _db).transaction((tx) async {
      await _checkProgressScope(tx, order);
      await tx.update(
        'client_progress_sync',
        {'pending_json': null, 'pending_local_revision': null},
        where: 'order_id = ? AND destination_id = ? AND client_id = ?',
        whereArgs: [order.id, order.destinationId, order.clientInstallationId],
      );
    });
  }

  @override
  Future<void> applySyncedProgress(
    ManagedOrder order,
    OrderProgressSnapshot snapshot,
  ) async {
    await (await _db).transaction((tx) async {
      final current = await _checkProgressScope(tx, order, checkEdits: true);
      final lines = current.lines.where((line) => line.sendToServer).toList();
      if (snapshot.clientId != order.clientInstallationId ||
          snapshot.orderId != order.id ||
          snapshot.orderRevision != current.serverRevision ||
          snapshot.quantities.length != lines.length ||
          lines.any(
            (line) =>
                snapshot.quantities[line.id] == null ||
                snapshot.quantities[line.id]! < 0 ||
                snapshot.quantities[line.id]! > line.quantity,
          )) {
        throw const ProgressSyncException('pending_items');
      }
      final progress = {...current.deliveredQuantities};
      for (final entry in snapshot.quantities.entries) {
        if (entry.value == 0) {
          progress.remove(entry.key);
        } else {
          progress[entry.key] = entry.value;
        }
      }
      await tx.update(
        'managed_orders',
        {
          'delivery_progress_json': jsonEncode(progress),
          'delivery_changed_ids': jsonEncode(
            current.changedDeliveryIds
                .difference(snapshot.quantities.keys.toSet())
                .toList()
              ..sort(),
          ),
          'delivery_edit_revision': current.deliveryEditRevision + 1,
        },
        where: 'id = ?',
        whereArgs: [order.id],
      );
      await tx.insert('client_progress_sync', {
        'order_id': order.id,
        'destination_id': order.destinationId,
        'client_id': order.clientInstallationId,
        'baseline_json': jsonEncode(snapshot.toJson()),
        'pending_json': null,
        'pending_local_revision': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  static OrderProgressSnapshot _serverProgress(ServerOrder order) =>
      OrderProgressSnapshot(
        clientId: order.clientInstallationId,
        orderId: order.managedOrderId!,
        orderRevision: order.revision,
        progressRevision: order.progressRevision,
        quantities: {
          for (final line in order.lines) line.id!: line.deliveredQuantity,
        },
      );

  static Future<ServerOrder> _scopedServerProgressOrder(
    DatabaseExecutor tx,
    String clientId,
    String orderId,
  ) async {
    final rows = await tx.query(
      'server_orders',
      where: 'client_installation_id = ? AND managed_order_id = ?',
      whereArgs: [clientId, orderId],
    );
    if (rows.length != 1) throw const ProgressSyncException('missing');
    return _loadServerOrder(tx, rows.single['id'] as String);
  }

  @override
  Future<OrderProgressSnapshot> loadServerProgress(
    String clientId,
    String orderId,
  ) async => (await _db).transaction(
    (tx) async => _serverProgress(
      await _scopedServerProgressOrder(tx, clientId, orderId),
    ),
  );

  @override
  Future<OrderProgressSnapshot> applyServerProgress(
    String clientId,
    OrderProgressChange change,
  ) async {
    return (await _db).transaction((tx) async {
      final order = await _scopedServerProgressOrder(
        tx,
        clientId,
        change.orderId,
      );
      final request = canonicalProgressChange(change);
      final receipts = await tx.query(
        'server_progress_receipts',
        where: 'client_id = ? AND operation_id = ?',
        whereArgs: [clientId, change.operationId],
      );
      if (receipts.isNotEmpty) {
        if (receipts.single['request_json'] != request ||
            receipts.single['order_id'] != order.id) {
          throw const ServerOrderConflictException();
        }
        return OrderProgressSnapshot.fromJson(
          jsonDecode(receipts.single['applied_json'] as String),
        );
      }
      if (order.revision != change.orderRevision ||
          order.progressRevision != change.expectedRevision) {
        throw const ServerOrderConflictException();
      }
      if (change.quantities.length != order.lines.length ||
          order.lines.any(
            (line) =>
                change.quantities[line.id] == null ||
                change.quantities[line.id]! < 0 ||
                change.quantities[line.id]! > line.quantity,
          )) {
        throw const FormatException('Invalid shared delivery inventory');
      }
      for (final line in order.lines) {
        await tx.update(
          'server_order_lines',
          {'delivered_quantity': change.quantities[line.id]},
          where: 'order_id = ? AND order_line_id = ?',
          whereArgs: [order.id, line.id],
        );
      }
      final complete = order.lines.every(
        (line) => change.quantities[line.id] == line.quantity,
      );
      await tx.update(
        'server_orders',
        {
          'progress_revision': order.progressRevision + 1,
          'status': complete
              ? ServerOrderStatus.done.value
              : ServerOrderStatus.received.value,
          'completed_at': complete ? _timestamp(DateTime.now().toUtc()) : null,
          'completed_revision': complete ? order.revision : 0,
        },
        where: 'id = ?',
        whereArgs: [order.id],
      );
      final result = _serverProgress(await _loadServerOrder(tx, order.id));
      await tx.insert('server_progress_receipts', {
        'client_id': clientId,
        'operation_id': change.operationId,
        'order_id': order.id,
        'request_json': request,
        'applied_json': jsonEncode(result.toJson()),
      });
      return result;
    });
  }

  @override
  Future<PairedServer?> loadActiveServer() async {
    try {
      final rows = await (await _db).query(
        'network_destinations',
        where: 'is_active = 1',
        limit: 1,
      );
      return rows.isEmpty ? null : _pairedServerFromRow(rows.single);
    } catch (error) {
      throw OrderStorageException('Could not read the paired server.', error);
    }
  }

  @override
  Future<void> savePairedServer(PairedServer server) async {
    try {
      await (await _db).transaction((transaction) async {
        await transaction.update('network_destinations', {'is_active': 0});
        final existing = await transaction.query(
          'network_destinations',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [server.id],
          limit: 1,
        );
        final values = <String, Object?>{
          'display_name': server.displayName,
          'base_url': server.baseUrl.toString(),
          'certificate_fingerprint': server.certificateFingerprint,
          'updated_at': _timestamp(server.updatedAt),
          'is_active': 1,
        };
        if (existing.isEmpty) {
          await transaction.insert('network_destinations', {
            'id': server.id,
            ...values,
            'created_at': _timestamp(server.createdAt),
          });
        } else {
          await transaction.update(
            'network_destinations',
            values,
            where: 'id = ?',
            whereArgs: [server.id],
          );
        }
      });
    } catch (error) {
      throw OrderStorageException('Could not save the paired server.', error);
    }
  }

  @override
  Future<void> deactivateServer(String id) async {
    try {
      await (await _db).update(
        'network_destinations',
        {'is_active': 0, 'updated_at': _timestamp(DateTime.now().toUtc())},
        where: 'id = ? AND is_active = 1',
        whereArgs: [id],
      );
    } catch (error) {
      throw OrderStorageException('Could not disconnect the server.', error);
    }
  }

  @override
  Future<List<ClientDelivery>> loadClientDeliveries() async {
    try {
      final rows = await (await _db).query(
        'server_delivery_outbox',
        orderBy: 'created_at DESC',
      );
      return rows.map(_clientDeliveryFromRow).toList(growable: false);
    } catch (error) {
      throw OrderStorageException('Could not read server deliveries.', error);
    }
  }

  @override
  Future<ClientDelivery> markClientDeliverySending(String id) async {
    try {
      final database = await _db;
      final delivery = await _loadClientDelivery(database, id);
      if (delivery.envelope.managedOrderId != null) {
        final rows = await database.query(
          'server_delivery_outbox',
          where: "destination_id = ? AND status != 'delivered' AND id != ?",
          whereArgs: [delivery.destinationId, id],
        );
        for (final row in rows) {
          final earlier = OrderDeliveryEnvelope.fromJsonString(
            row['payload_json'] as String,
          );
          if (earlier.managedOrderId == delivery.envelope.managedOrderId &&
              earlier.revision < delivery.envelope.revision) {
            throw const OrderStorageException(
              'An earlier revision must be delivered first.',
            );
          }
        }
      }
      final changed = await database.rawUpdate(
        '''
        UPDATE server_delivery_outbox
        SET status = 'sending', attempt_count = attempt_count + 1,
            error_code = NULL, updated_at = ?
        WHERE id = ? AND status = 'pending'
        ''',
        [_timestamp(DateTime.now().toUtc()), id],
      );
      if (changed != 1) {
        throw const OrderStorageException(
          'Only a pending server delivery can be sent.',
        );
      }
      return await _loadClientDelivery(database, id);
    } catch (error) {
      if (error is OrderStorageException) rethrow;
      throw OrderStorageException('Could not start server delivery.', error);
    }
  }

  @override
  Future<ClientDelivery> markClientDeliveryDelivered(
    String id, {
    required String serverOrderId,
    required DateTime deliveredAt,
  }) async {
    try {
      final database = await _db;
      final changed = await database.update(
        'server_delivery_outbox',
        {
          'status': ClientDeliveryStatus.delivered.value,
          'error_code': null,
          'updated_at': _timestamp(deliveredAt),
          'delivered_at': _timestamp(deliveredAt),
          'server_order_id': serverOrderId,
        },
        where: 'id = ? AND status = ?',
        whereArgs: [id, ClientDeliveryStatus.sending.value],
      );
      if (changed != 1) {
        throw const OrderStorageException(
          'Only a sending server delivery can be completed.',
        );
      }
      return await _loadClientDelivery(database, id);
    } catch (error) {
      if (error is OrderStorageException) rethrow;
      throw OrderStorageException('Could not complete server delivery.', error);
    }
  }

  @override
  Future<ClientDelivery> markClientDeliveryFailed(
    String id, {
    required String errorCode,
  }) async {
    try {
      final database = await _db;
      final changed = await database.rawUpdate(
        '''
        UPDATE server_delivery_outbox
        SET status = 'failed', error_code = ?, updated_at = ?
        WHERE id = ? AND status IN ('pending', 'sending')
        ''',
        [errorCode, _timestamp(DateTime.now().toUtc()), id],
      );
      if (changed != 1) {
        throw const OrderStorageException(
          'Only an unfinished server delivery can fail.',
        );
      }
      return await _loadClientDelivery(database, id);
    } catch (error) {
      if (error is OrderStorageException) rethrow;
      throw OrderStorageException('Could not record delivery failure.', error);
    }
  }

  @override
  Future<ClientDelivery> resetClientDeliveryForRetry(String id) async {
    try {
      final database = await _db;
      final changed = await database.update(
        'server_delivery_outbox',
        {
          'status': ClientDeliveryStatus.pending.value,
          'error_code': null,
          'updated_at': _timestamp(DateTime.now().toUtc()),
        },
        where: 'id = ? AND status IN (?, ?)',
        whereArgs: [
          id,
          ClientDeliveryStatus.failed.value,
          ClientDeliveryStatus.pending.value,
        ],
      );
      if (changed != 1) {
        throw const OrderStorageException(
          'This server delivery cannot be retried.',
        );
      }
      return await _loadClientDelivery(database, id);
    } catch (error) {
      if (error is OrderStorageException) rethrow;
      throw OrderStorageException('Could not retry server delivery.', error);
    }
  }

  @override
  Future<void> pairClient(PairedClient client) async {
    try {
      await (await _db).transaction((transaction) async {
        final existing = await transaction.query(
          'server_clients',
          columns: ['installation_id'],
          where: 'installation_id = ?',
          whereArgs: [client.installationId],
          limit: 1,
        );
        final values = <String, Object?>{
          'display_name': client.displayName,
          'certificate_fingerprint': client.identityFingerprint,
          'paired_at': _timestamp(client.pairedAt),
          'last_seen_at': client.lastSeenAt == null
              ? null
              : _timestamp(client.lastSeenAt!),
        };
        if (existing.isEmpty) {
          await transaction.insert('server_clients', {
            'installation_id': client.installationId,
            ...values,
          });
        } else {
          await transaction.update(
            'server_clients',
            values,
            where: 'installation_id = ?',
            whereArgs: [client.installationId],
          );
        }
      });
    } catch (error) {
      throw OrderStorageException('Could not pair the client.', error);
    }
  }

  @override
  Future<PairedClient?> findPairedClient(String installationId) async {
    try {
      final rows = await (await _db).query(
        'server_clients',
        where: 'installation_id = ?',
        whereArgs: [installationId],
        limit: 1,
      );
      return rows.isEmpty ? null : _pairedClientFromRow(rows.single);
    } catch (error) {
      throw OrderStorageException('Could not read the paired client.', error);
    }
  }

  @override
  Future<List<ServerOrder>> loadServerOrders() async {
    try {
      final database = await _db;
      final rows = await database.rawQuery('''
        SELECT o.*, c.display_name AS client_display_name
        FROM server_orders o
        JOIN server_clients c
          ON c.installation_id = o.client_installation_id
        ORDER BY o.received_at ASC, o.id ASC
      ''');
      final orders = <ServerOrder>[];
      for (final row in rows) {
        orders.add(await _serverOrderFromRow(database, row));
      }
      return orders;
    } catch (error) {
      throw OrderStorageException('Could not read received orders.', error);
    }
  }

  @override
  Future<ServerOrderReceipt> receiveServerOrder(
    OrderDeliveryEnvelope envelope, {
    required DateTime receivedAt,
  }) async {
    try {
      final database = await _db;
      if (envelope.managedOrderId != null) {
        return await _receiveManagedOrder(database, envelope, receivedAt);
      }
      final result = await database.transaction<({String id, bool duplicate})>((
        transaction,
      ) async {
        final managedReceipt = await transaction.query(
          'server_order_revisions',
          columns: ['delivery_id'],
          where: 'client_installation_id = ? AND delivery_id = ?',
          whereArgs: [envelope.clientInstallationId, envelope.deliveryId],
        );
        if (managedReceipt.isNotEmpty) {
          throw const ServerOrderConflictException();
        }
        final existing = await transaction.query(
          'server_orders',
          columns: ['id', 'payload_checksum'],
          where: 'client_installation_id = ? AND delivery_id = ?',
          whereArgs: [envelope.clientInstallationId, envelope.deliveryId],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          if (existing.single['payload_checksum'] != envelope.payloadChecksum) {
            throw const ServerOrderConflictException();
          }
          await transaction.update(
            'server_clients',
            {'last_seen_at': _timestamp(receivedAt)},
            where: 'installation_id = ?',
            whereArgs: [envelope.clientInstallationId],
          );
          return (id: existing.single['id']! as String, duplicate: true);
        }
        final client = await transaction.query(
          'server_clients',
          columns: ['installation_id'],
          where: 'installation_id = ?',
          whereArgs: [envelope.clientInstallationId],
          limit: 1,
        );
        if (client.isEmpty) {
          throw const OrderStorageException('The client is not paired.');
        }
        final id = createLocalId();
        await transaction.insert('server_orders', {
          'id': id,
          'client_installation_id': envelope.clientInstallationId,
          'delivery_id': envelope.deliveryId,
          'client_ticket_id': envelope.ticketId,
          'display_number': envelope.ticketNumber,
          'source_created_at': _timestamp(envelope.createdAt),
          'received_at': _timestamp(receivedAt),
          'heading_snapshot': envelope.heading,
          'reference_snapshot': envelope.reference,
          'order_note_snapshot': envelope.orderNote,
          'courses_json': jsonEncode([
            for (final course in envelope.courses) course.toJson(),
          ]),
          'payload_checksum': envelope.payloadChecksum,
          'status': ServerOrderStatus.received.value,
        });
        for (var index = 0; index < envelope.lines.length; index++) {
          final line = envelope.lines[index];
          await transaction.insert('server_order_lines', {
            'id': createLocalId(),
            'order_id': id,
            'name_snapshot': line.name,
            'quantity': line.quantity,
            'preparation_note': line.preparationNote,
            'course_id': line.courseId,
            'position': index,
          });
        }
        await transaction.update(
          'server_clients',
          {'last_seen_at': _timestamp(receivedAt)},
          where: 'installation_id = ?',
          whereArgs: [envelope.clientInstallationId],
        );
        return (id: id, duplicate: false);
      });
      final order = await _loadServerOrder(database, result.id);
      return ServerOrderReceipt(order: order, wasDuplicate: result.duplicate);
    } on ServerOrderConflictException {
      rethrow;
    } catch (error) {
      if (error is OrderStorageException) rethrow;
      throw OrderStorageException('Could not store the received order.', error);
    }
  }

  static Future<ServerOrderReceipt> _receiveManagedOrder(
    Database database,
    OrderDeliveryEnvelope envelope,
    DateTime receivedAt,
  ) async {
    final result = await database.transaction<({String id, bool duplicate})>((
      tx,
    ) async {
      final ordinary = await tx.query(
        'server_orders',
        columns: ['id'],
        where: 'client_installation_id = ? AND delivery_id = ? AND managed_order_id IS NULL',
        whereArgs: [envelope.clientInstallationId, envelope.deliveryId],
      );
      if (ordinary.isNotEmpty) throw const ServerOrderConflictException();
      final receipts = await tx.query(
        'server_order_revisions',
        where: 'client_installation_id = ? AND delivery_id = ?',
        whereArgs: [envelope.clientInstallationId, envelope.deliveryId],
      );
      if (receipts.isNotEmpty) {
        final receipt = receipts.single;
        if (receipt['payload_checksum'] != envelope.payloadChecksum) {
          throw const ServerOrderConflictException();
        }
        final order = await tx.query(
          'server_orders',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [receipt['order_id']],
        );
        if (order.isEmpty) throw const ServerOrderConflictException();
        return (id: receipt['order_id'] as String, duplicate: true);
      }
      final clients = await tx.query(
        'server_clients',
        columns: ['installation_id'],
        where: 'installation_id = ?',
        whereArgs: [envelope.clientInstallationId],
      );
      if (clients.isEmpty) {
        throw const OrderStorageException('The client is not paired.');
      }
      final current = await tx.query(
        'server_orders',
        where: 'client_installation_id = ? AND managed_order_id = ?',
        whereArgs: [envelope.clientInstallationId, envelope.managedOrderId],
      );
      String id;
      final oldRevisions = <String, int>{};
      final oldDelivered = <String, int>{};
      if (current.isEmpty) {
        final deleted = await tx.query(
          'server_order_revisions',
          columns: ['order_id'],
          where: 'client_installation_id = ? AND managed_order_id = ?',
          whereArgs: [envelope.clientInstallationId, envelope.managedOrderId],
          limit: 1,
        );
        if (envelope.revision != 1 || deleted.isNotEmpty) {
          throw const ServerOrderConflictException();
        }
        id = createLocalId();
      } else {
        final row = current.single;
        id = row['id'] as String;
        if (envelope.revision != (row['revision'] as int) + 1 ||
            row['display_number'] != envelope.ticketNumber ||
            row['source_created_at'] != _timestamp(envelope.createdAt) ||
            row['heading_snapshot'] != envelope.heading ||
            row['reference_snapshot'] != envelope.reference ||
            row['order_note_snapshot'] != envelope.orderNote) {
          throw const ServerOrderConflictException();
        }
        final oldCourses = decodeCourses(row['courses_json']);
        final retained = envelope.courses
            .where((course) => oldCourses.any((old) => old.id == course.id))
            .toList();
        if (retained.length != oldCourses.length ||
            List.generate(
              oldCourses.length,
              (i) =>
                  retained[i].id != oldCourses[i].id ||
                  retained[i].name != oldCourses[i].name,
            ).contains(true)) {
          throw const ServerOrderConflictException();
        }
        final oldLines = await tx.query(
          'server_order_lines',
          where: 'order_id = ?',
          whereArgs: [id],
          orderBy: 'position',
        );
        if (envelope.lines.length <= oldLines.length) {
          throw const ServerOrderConflictException();
        }
        for (var i = 0; i < oldLines.length; i++) {
          final old = oldLines[i];
          final line = envelope.lines[i];
          if (old['order_line_id'] != line.id ||
              old['name_snapshot'] != line.name ||
              old['quantity'] != line.quantity ||
              old['preparation_note'] != line.preparationNote ||
              old['course_id'] != line.courseId) {
            throw const ServerOrderConflictException();
          }
          oldRevisions[line.id!] = old['added_revision'] as int;
          oldDelivered[line.id!] = old['delivered_quantity'] as int;
        }
      }
      final values = <String, Object?>{
        'delivery_id': envelope.deliveryId,
        'client_ticket_id': envelope.ticketId,
        'display_number': envelope.ticketNumber,
        'source_created_at': _timestamp(envelope.createdAt),
        'received_at': _timestamp(receivedAt),
        'heading_snapshot': envelope.heading,
        'reference_snapshot': envelope.reference,
        'order_note_snapshot': envelope.orderNote,
        'courses_json': jsonEncode([
          for (final course in envelope.courses) course.toJson(),
        ]),
        'payload_checksum': envelope.payloadChecksum,
        'status': ServerOrderStatus.received.value,
        'completed_at': null,
        'managed_order_id': envelope.managedOrderId,
        'revision': envelope.revision,
      };
      if (current.isEmpty) {
        await tx.insert('server_orders', {
          'id': id,
          'client_installation_id': envelope.clientInstallationId,
          ...values,
        });
      } else {
        await tx.update(
          'server_orders',
          values,
          where: 'id = ?',
          whereArgs: [id],
        );
        await tx.delete(
          'server_order_lines',
          where: 'order_id = ?',
          whereArgs: [id],
        );
      }
      for (var i = 0; i < envelope.lines.length; i++) {
        final line = envelope.lines[i];
        await tx.insert('server_order_lines', {
          'id': createLocalId(),
          'order_id': id,
          'order_line_id': line.id,
          'added_revision': oldRevisions[line.id] ?? envelope.revision,
          'delivered_quantity': oldDelivered[line.id] ?? 0,
          'name_snapshot': line.name,
          'quantity': line.quantity,
          'preparation_note': line.preparationNote,
          'course_id': line.courseId,
          'position': i,
        });
      }
      await tx.insert('server_order_revisions', {
        'client_installation_id': envelope.clientInstallationId,
        'delivery_id': envelope.deliveryId,
        'managed_order_id': envelope.managedOrderId,
        'revision': envelope.revision,
        'order_id': id,
        'payload_checksum': envelope.payloadChecksum,
      });
      await tx.update(
        'server_clients',
        {'last_seen_at': _timestamp(receivedAt)},
        where: 'installation_id = ?',
        whereArgs: [envelope.clientInstallationId],
      );
      return (id: id, duplicate: false);
    });
    return ServerOrderReceipt(
      order: await _loadServerOrder(database, result.id),
      wasDuplicate: result.duplicate,
    );
  }

  @override
  Future<ServerOrder> setServerLineDelivered(
    String orderId,
    String lineId,
    int quantity, {
    required int expectedQuantity,
  }) async {
    final database = await _db;
    await database.transaction((tx) async {
      final order = await _loadServerOrder(tx, orderId);
      final lines = order.lines.where((line) => line.id == lineId).toList();
      if (order.managedOrderId == null ||
          lines.length != 1 ||
          quantity < 0 ||
          quantity > lines.single.quantity ||
          lines.single.deliveredQuantity != expectedQuantity) {
        throw const OrderStorageException(
          'Invalid or stale delivery progress.',
        );
      }
      await tx.update(
        'server_order_lines',
        {'delivered_quantity': quantity},
        where: 'order_id = ? AND order_line_id = ?',
        whereArgs: [orderId, lineId],
      );
      final complete = order.lines.every(
        (line) =>
            (line.id == lineId ? quantity : line.deliveredQuantity) ==
            line.quantity,
      );
      await tx.update(
        'server_orders',
        {
          'status': complete
              ? ServerOrderStatus.done.value
              : ServerOrderStatus.received.value,
          'completed_at': complete ? _timestamp(DateTime.now().toUtc()) : null,
          'completed_revision': complete ? order.revision : 0,
          'progress_revision': order.progressRevision + 1,
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
    });
    return _loadServerOrder(database, orderId);
  }

  @override
  Future<ServerOrder> markServerOrderDone(
    String id, {
    required DateTime completedAt,
  }) async {
    try {
      final database = await _db;
      await database.transaction((transaction) async {
        final rows = await transaction.query(
          'server_orders',
          columns: [
            'status',
            'revision',
            'managed_order_id',
            'progress_revision',
          ],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw const OrderStorageException(
            'The received order was not found.',
          );
        }
        if (rows.single['status'] == ServerOrderStatus.received.value) {
          if (rows.single['managed_order_id'] != null) {
            await transaction.rawUpdate(
              'UPDATE server_order_lines SET delivered_quantity = quantity WHERE order_id = ?',
              [id],
            );
          }
          await transaction.update(
            'server_orders',
            {
              'status': ServerOrderStatus.done.value,
              'completed_at': _timestamp(completedAt),
              'completed_revision': rows.single['revision'],
              'progress_revision':
                  (rows.single['progress_revision'] as int) + 1,
            },
            where: 'id = ? AND status = ?',
            whereArgs: [id, ServerOrderStatus.received.value],
          );
        }
      });
      return await _loadServerOrder(database, id);
    } catch (error) {
      if (error is OrderStorageException) rethrow;
      throw OrderStorageException('Could not mark the order done.', error);
    }
  }

  @override
  Future<ServerOrder> markServerOrderReceived(String id) async {
    try {
      final database = await _db;
      await database.transaction((transaction) async {
        final rows = await transaction.query(
          'server_orders',
          columns: ['status', 'managed_order_id', 'progress_revision'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw const OrderStorageException(
            'The received order was not found.',
          );
        }
        if (rows.single['status'] == ServerOrderStatus.done.value) {
          if (rows.single['managed_order_id'] != null) {
            await transaction.update(
              'server_order_lines',
              {'delivered_quantity': 0},
              where: 'order_id = ?',
              whereArgs: [id],
            );
          }
          await transaction.update(
            'server_orders',
            {
              'status': ServerOrderStatus.received.value,
              'completed_at': null,
              'completed_revision': 0,
              'progress_revision':
                  (rows.single['progress_revision'] as int) + 1,
            },
            where: 'id = ? AND status = ?',
            whereArgs: [id, ServerOrderStatus.done.value],
          );
        }
      });
      return await _loadServerOrder(database, id);
    } catch (error) {
      if (error is OrderStorageException) rethrow;
      throw OrderStorageException(
        'Could not move the order back to Received.',
        error,
      );
    }
  }

  @override
  Future<void> deleteCompletedServerOrder(String id) async {
    try {
      final changed = await (await _db).delete(
        'server_orders',
        where: 'id = ? AND status = ?',
        whereArgs: [id, ServerOrderStatus.done.value],
      );
      if (changed != 1) {
        throw const OrderStorageException('The completed order was not found.');
      }
    } catch (error) {
      if (error is OrderStorageException) rethrow;
      throw OrderStorageException(
        'Could not delete the completed order.',
        error,
      );
    }
  }

  @override
  Future<int> deleteAllCompletedServerOrders() async {
    try {
      return await (await _db).transaction(
        (transaction) => transaction.delete(
          'server_orders',
          where: 'status = ?',
          whereArgs: [ServerOrderStatus.done.value],
        ),
      );
    } catch (error) {
      throw OrderStorageException('Could not delete completed orders.', error);
    }
  }

  @override
  Future<List<ItemCategory>> loadCategories() async {
    try {
      final rows = await (await _db).query(
        'categories',
        orderBy: 'name COLLATE NOCASE',
      );
      return rows.map(_categoryFromRow).toList(growable: false);
    } catch (error) {
      throw OrderStorageException('Could not read categories.', error);
    }
  }

  @override
  Future<OrderFeatureSettings> loadFeatureSettings() async {
    try {
      final rows = await (await _db).query(
        'order_feature_settings',
        where: 'id = 1',
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const OrderStorageException(
          'The order feature settings could not be found.',
        );
      }
      final row = rows.single;
      return OrderFeatureSettings(
        orderReferenceEnabled: row['order_reference_enabled'] == 1,
        preparationNotesEnabled: row['preparation_notes_enabled'] == 1,
        orderNotesEnabled: row['order_notes_enabled'] == 1,
        courseGroupsEnabled: row['course_groups_enabled'] == 1,
        managedOrdersEnabled: row['managed_orders_enabled'] == 1,
        pricesEnabled: row['prices_enabled'] == 1,
      );
    } catch (error) {
      if (error is OrderStorageException) rethrow;
      throw OrderStorageException(
        'Could not read order feature settings.',
        error,
      );
    }
  }

  @override
  Future<void> saveFeatureSettings(OrderFeatureSettings settings) async {
    try {
      final changed = await (await _db).update('order_feature_settings', {
        'order_reference_enabled': settings.orderReferenceEnabled ? 1 : 0,
        'preparation_notes_enabled': settings.preparationNotesEnabled ? 1 : 0,
        'order_notes_enabled': settings.orderNotesEnabled ? 1 : 0,
        'course_groups_enabled': settings.courseGroupsEnabled ? 1 : 0,
        'managed_orders_enabled': settings.managedOrdersEnabled ? 1 : 0,
        'prices_enabled': settings.pricesEnabled ? 1 : 0,
      }, where: 'id = 1');
      if (changed != 1) {
        throw const OrderStorageException(
          'The order feature settings could not be found.',
        );
      }
    } catch (error) {
      throw OrderStorageException(
        'Could not save order feature settings.',
        error,
      );
    }
  }

  @override
  Future<int> loadNextOrderNumber() async {
    try {
      final rows = await (await _db).query(
        'counters',
        columns: ['next_value'],
        where: 'name = ?',
        whereArgs: ['order'],
        limit: 1,
      );
      if (rows.isEmpty || rows.single['next_value'] is! int) {
        throw const OrderStorageException(
          'The next order number could not be found.',
        );
      }
      return rows.single['next_value']! as int;
    } catch (error) {
      if (error is OrderStorageException) rethrow;
      throw OrderStorageException(
        'Could not read the next order number.',
        error,
      );
    }
  }

  @override
  Future<void> resetOrderNumber() async {
    try {
      final changed = await (await _db).update(
        'counters',
        {'next_value': 1},
        where: 'name = ?',
        whereArgs: ['order'],
      );
      if (changed != 1) {
        throw const OrderStorageException(
          'The order number could not be reset.',
        );
      }
    } catch (error) {
      if (error is OrderStorageException) rethrow;
      throw OrderStorageException('Could not reset the order number.', error);
    }
  }

  @override
  Future<List<CatalogueItem>> loadItems() async {
    try {
      final rows = await (await _db).rawQuery('''
        SELECT i.*, c.name AS category_name
        FROM items i
        LEFT JOIN categories c ON c.id = i.category_id
        WHERE i.archived = 0
        ORDER BY i.name COLLATE NOCASE
      ''');
      return rows.map(_itemFromRow).toList(growable: false);
    } catch (error) {
      throw OrderStorageException('Could not read items.', error);
    }
  }

  @override
  Future<CatalogueItem> saveItem({
    String? id,
    required String name,
    String? categoryName,
    String? imagePath,
    bool sendToServer = true,
    ProductPrice? price,
  }) async {
    if (price != null && !price.isValid) {
      throw const OrderStorageException('The price is invalid.');
    }
    final cleanName = name.trim();
    final cleanCategory = categoryName?.trim();
    if (cleanName.isEmpty || cleanName.length > 80) {
      throw const OrderStorageException('The item name is invalid.');
    }
    if (cleanCategory != null && cleanCategory.length > 60) {
      throw const OrderStorageException('The category name is invalid.');
    }
    try {
      final database = await _db;
      final itemId = id ?? createLocalId();
      await database.transaction((transaction) async {
        String? categoryId;
        if (cleanCategory != null && cleanCategory.isNotEmpty) {
          final existing = await transaction.query(
            'categories',
            columns: ['id'],
            where: 'name = ? COLLATE NOCASE',
            whereArgs: [cleanCategory],
            limit: 1,
          );
          if (existing.isEmpty) {
            categoryId = createLocalId();
            await transaction.insert('categories', {
              'id': categoryId,
              'name': cleanCategory,
              'created_at': _timestamp(DateTime.now()),
            });
          } else {
            categoryId = existing.single['id']! as String;
          }
        }
        final now = _timestamp(DateTime.now());
        final values = <String, Object?>{
          'id': itemId,
          'name': cleanName,
          'category_id': categoryId,
          'archived': 0,
          'is_favourite': 0,
          'image_path': imagePath,
          'send_to_server': sendToServer ? 1 : 0,
          'price_minor_units': price?.minorUnits,
          'price_currency': price?.currency,
          'updated_at': now,
        };
        if (id == null) {
          values['created_at'] = now;
          await transaction.insert('items', values);
        } else {
          final changed = await transaction.update(
            'items',
            values,
            where: 'id = ? AND archived = 0',
            whereArgs: [id],
          );
          if (changed != 1) {
            throw const OrderStorageException('The item no longer exists.');
          }
        }
      });
      return (await loadItems()).singleWhere((item) => item.id == itemId);
    } catch (error) {
      if (error is OrderStorageException) rethrow;
      throw OrderStorageException('Could not save the item.', error);
    }
  }

  @override
  Future<void> archiveItem(String id) async {
    try {
      await (await _db).update(
        'items',
        {
          'archived': 1,
          'image_path': null,
          'updated_at': _timestamp(DateTime.now()),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (error) {
      throw OrderStorageException('Could not remove the item.', error);
    }
  }

  @override
  Future<List<OrderDraft>> loadDrafts() async {
    try {
      final database = await _db;
      final rows = await database.query('drafts', orderBy: 'updated_at DESC');
      final drafts = <OrderDraft>[];
      for (final row in rows) {
        drafts.add(await _draftFromRow(database, row));
      }
      return drafts;
    } catch (error) {
      throw OrderStorageException('Could not read drafts.', error);
    }
  }

  @override
  Future<OrderDraft> createDraft() async {
    final now = DateTime.now().toUtc();
    final draft = OrderDraft(
      id: createLocalId(),
      createdAt: now,
      updatedAt: now,
    );
    await saveDraft(draft);
    return draft;
  }

  @override
  Future<void> saveDraft(OrderDraft draft) async {
    _validateDraft(draft);
    try {
      await (await _db).transaction(
        (transaction) => _writeDraft(transaction, draft),
      );
    } catch (error) {
      if (error is OrderStorageException) rethrow;
      throw OrderStorageException('Could not save the draft.', error);
    }
  }

  static Future<void> _writeDraft(
    DatabaseExecutor executor,
    OrderDraft draft,
  ) async {
    await executor.insert('drafts', {
      'id': draft.id,
      'reference': draft.reference.trim(),
      'order_note': draft.orderNote.trim(),
      'courses_json': jsonEncode([
        for (final course in draft.courses) course.toJson(),
      ]),
      'active_course_id': draft.activeCourseId,
      'managed_order_id': draft.managedOrderId,
      'base_revision': draft.baseRevision,
      'created_at': _timestamp(draft.createdAt),
      'updated_at': _timestamp(draft.updatedAt),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await executor.delete(
      'draft_lines',
      where: 'draft_id = ?',
      whereArgs: [draft.id],
    );
    for (var index = 0; index < draft.lines.length; index++) {
      final line = draft.lines[index];
      await executor.insert('draft_lines', {
        'id': line.id,
        'draft_id': draft.id,
        'catalogue_item_id': line.catalogueItemId,
        'name_snapshot': line.name,
        'quantity': line.quantity,
        'preparation_note': line.preparationNote.trim(),
        'course_id': line.courseId,
        'price_minor_units': line.price?.minorUnits,
        'price_currency': line.price?.currency,
        'position': index,
      });
    }
  }

  @override
  Future<void> deleteDraft(String id) async {
    try {
      await (await _db).delete('drafts', where: 'id = ?', whereArgs: [id]);
    } catch (error) {
      throw OrderStorageException('Could not delete the draft.', error);
    }
  }

  @override
  Future<SavedTicket> convertDraftToTicket(
    OrderDraft draft, {
    required String heading,
    bool keepOpen = false,
  }) async {
    _validateDraft(draft, requireLines: true);
    final database = await _db;
    try {
      final ticketId = await database.transaction<String>((transaction) async {
        final existing = await transaction.query(
          'tickets',
          columns: ['id'],
          where: 'origin_draft_id = ?',
          whereArgs: [draft.id],
          limit: 1,
        );
        if (existing.isNotEmpty) return existing.single['id']! as String;

        ManagedOrder? previous;
        if (draft.managedOrderId != null) {
          final rows = await transaction.query(
            'managed_orders',
            where: 'id = ? AND closed_at IS NULL',
            whereArgs: [draft.managedOrderId],
          );
          if (rows.length != 1) {
            throw const OrderStorageException('The order is no longer open.');
          }
          previous = _managedFromRow(rows.single);
          if (draft.baseRevision != previous.revision ||
              draft.reference.trim() != previous.reference ||
              draft.orderNote.trim() != previous.orderNote ||
              draft.courses.length < previous.courses.length ||
              List.generate(
                previous.courses.length,
                (i) =>
                    draft.courses[i].id != previous!.courses[i].id ||
                    draft.courses[i].name != previous.courses[i].name,
              ).contains(true) ||
              draft.lines.any(
                (line) => previous!.lines.any((old) => old.id == line.id),
              )) {
            throw const OrderStorageException(
              'The addition conflicts with the current order.',
            );
          }
        }
        final managedId = previous?.id ?? (keepOpen ? draft.id : null);
        final revision = managedId == null ? 0 : (previous?.revision ?? 0) + 1;
        final cleanHeading = previous?.heading ?? heading.trim();
        final additionLines = <TicketLine>[];
        for (final line in draft.lines) {
          var send = true;
          if (line.catalogueItemId != null) {
            final rows = await transaction.query(
              'items',
              columns: ['send_to_server'],
              where: 'id = ?',
              whereArgs: [line.catalogueItemId],
            );
            if (rows.isNotEmpty) send = rows.single['send_to_server'] == 1;
          }
          additionLines.add(
            TicketLine(
              id: line.id,
              catalogueItemId: line.catalogueItemId,
              name: line.name,
              quantity: line.quantity,
              preparationNote: line.preparationNote.trim(),
              courseId: line.courseId,
              sendToServer: send,
              price: line.price,
            ),
          );
        }
        final allLines = [...?previous?.lines, ...additionLines];
        _validateDraft(draft.copyWith(lines: allLines), requireLines: true);
        await _writeDraft(transaction, draft);
        final ticketCounter = await transaction.query(
          'counters',
          columns: ['next_value'],
          where: 'name = ?',
          whereArgs: ['ticket'],
          limit: 1,
        );
        final ticketNumber = ticketCounter.single['next_value']! as int;
        final orderCounter = await transaction.query(
          'counters',
          columns: ['next_value'],
          where: 'name = ?',
          whereArgs: ['order'],
          limit: 1,
        );
        final orderNumber =
            previous?.number ?? orderCounter.single['next_value']! as int;
        await transaction.update(
          'counters',
          {'next_value': ticketNumber + 1},
          where: 'name = ?',
          whereArgs: ['ticket'],
        );
        if (previous == null) {
          await transaction.update(
            'counters',
            {'next_value': orderNumber + 1},
            where: 'name = ?',
            whereArgs: ['order'],
          );
        }
        final id = createLocalId();
        final createdAt = DateTime.now().toUtc();
        await transaction.insert('tickets', {
          'id': id,
          'ticket_number': ticketNumber,
          'display_number': orderNumber,
          'origin_draft_id': draft.id,
          'heading_snapshot': cleanHeading,
          'reference_snapshot': draft.reference.trim(),
          'order_note_snapshot': draft.orderNote.trim(),
          'courses_json': jsonEncode([
            for (final course in draft.courses) course.toJson(),
          ]),
          'created_at': _timestamp(createdAt),
          'source_ticket_id': null,
          'managed_order_id': managedId,
          'revision': revision,
          'addition_line_ids': jsonEncode(
            managedId == null
                ? <String>[]
                : additionLines.map((line) => line.id).toList(),
          ),
        });
        for (var index = 0; index < allLines.length; index++) {
          final line = allLines[index];
          await transaction.insert('ticket_lines', {
            'id': createLocalId(),
            'ticket_id': id,
            'order_line_id': managedId == null ? null : line.id,
            'catalogue_item_id': line.catalogueItemId,
            'name_snapshot': line.name,
            'quantity': line.quantity,
            'preparation_note': line.preparationNote.trim(),
            'course_id': line.courseId,
            'price_minor_units': line.price?.minorUnits,
            'price_currency': line.price?.currency,
            'position': index,
          });
        }
        final configuration = (await transaction.query(
          'network_settings',
          where: 'id = 1',
        )).single;
        final installationId = configuration['installation_id'] as String;
        final destinations = await transaction.query(
          'network_destinations',
          columns: ['id'],
          where: 'is_active = 1',
          limit: 1,
        );
        final destinationId = previous == null
            ? (destinations.isEmpty
                  ? null
                  : destinations.single['id'] as String)
            : (previous.clientInstallationId == installationId
                  ? previous.destinationId
                  : null);
        final eligible = allLines.where((line) => line.sendToServer).toList();
        final hasNewEligible = additionLines.any((line) => line.sendToServer);
        var serverRevision = previous?.serverRevision ?? 0;
        if (destinationId != null && eligible.isNotEmpty && hasNewEligible) {
          if (managedId != null) serverRevision++;
          final deliveryId = createLocalId();
          final envelope = OrderDeliveryEnvelope.create(
            clientInstallationId: installationId,
            deliveryId: deliveryId,
            ticketId: id,
            ticketNumber: orderNumber,
            createdAt: previous?.createdAt ?? createdAt,
            heading: cleanHeading,
            reference: draft.reference.trim(),
            orderNote: draft.orderNote.trim(),
            managedOrderId: managedId,
            revision: serverRevision,
            lines: [
              for (final line in eligible)
                DeliveryLine(
                  name: line.name,
                  quantity: line.quantity,
                  preparationNote: line.preparationNote,
                  courseId: line.courseId,
                  id: managedId == null ? null : line.id,
                ),
            ],
            courses: draft.courses
                .where(
                  (course) =>
                      eligible.any((line) => line.courseId == course.id),
                )
                .toList(),
          );
          final now = _timestamp(createdAt);
          await transaction.insert('server_delivery_outbox', {
            'id': deliveryId,
            'destination_id': destinationId,
            'client_installation_id': installationId,
            'ticket_id': id,
            'payload_json': envelope.toJsonString(),
            'payload_checksum': envelope.payloadChecksum,
            'status': ClientDeliveryStatus.awaitingPrint.value,
            'attempt_count': 0,
            'created_at': now,
            'updated_at': now,
          });
        }
        if (managedId != null) {
          final values = <String, Object?>{
            'display_number': orderNumber,
            'revision': revision,
            'updated_at': _timestamp(createdAt),
            'heading_snapshot': cleanHeading,
            'reference_snapshot': draft.reference.trim(),
            'order_note_snapshot': draft.orderNote.trim(),
            'courses_json': jsonEncode([
              for (final course in draft.courses) course.toJson(),
            ]),
            'lines_json': encodeOrderLines(allLines),
            'server_revision': destinationId == null ? 0 : serverRevision,
            'destination_id': destinationId,
            'client_installation_id': destinationId == null
                ? null
                : installationId,
          };
          if (previous == null) {
            await transaction.insert('managed_orders', {
              'id': managedId,
              'created_at': _timestamp(createdAt),
              ...values,
            });
          } else {
            await transaction.update(
              'managed_orders',
              values,
              where: 'id = ? AND revision = ?',
              whereArgs: [managedId, previous.revision],
            );
          }
        }
        await transaction.delete(
          'drafts',
          where: 'id = ?',
          whereArgs: [draft.id],
        );
        return id;
      });
      return await _loadTicket(database, ticketId);
    } catch (error) {
      if (error is OrderStorageException) rethrow;
      throw OrderStorageException('Could not save the ticket.', error);
    }
  }

  @override
  Future<List<ManagedOrder>> loadManagedOrders() async {
    final rows = await (await _db).query(
      'managed_orders',
      where: 'closed_at IS NULL',
      orderBy: 'updated_at DESC',
    );
    final installation = (await loadNetworkConfiguration()).installationId;
    return rows
        .map(
          (row) => _managedFromRow(
            row['client_installation_id'] != null &&
                    row['client_installation_id'] != installation
                ? {
                    ...row,
                    'destination_id': null,
                    'client_installation_id': null,
                    'server_revision': 0,
                  }
                : row,
          ),
        )
        .toList(growable: false);
  }

  static ManagedOrder _managedFromRow(Map<String, Object?> row) {
    final lines = decodeOrderLines(row['lines_json']);
    final courses = decodeCourses(row['courses_json']);
    validateCourses(courses, lines.map((line) => line.courseId));
    return ManagedOrder(
      id: row['id'] as String,
      number: row['display_number'] as int,
      revision: row['revision'] as int,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      closedAt: row['closed_at'] == null
          ? null
          : DateTime.parse(row['closed_at'] as String),
      heading: row['heading_snapshot'] as String,
      reference: row['reference_snapshot'] as String,
      orderNote: row['order_note_snapshot'] as String,
      lines: lines,
      courses: courses,
      destinationId: row['destination_id'] as String?,
      clientInstallationId: row['client_installation_id'] as String?,
      serverRevision: row['server_revision'] as int,
      deliveredQuantities: decodeDeliveryProgress(
        row['delivery_progress_json'] ?? '{}',
        lines,
      ),
      changedDeliveryIds: decodeChangedDeliveryIds(
        row['delivery_changed_ids'] ??
            jsonEncode(
              (jsonDecode(
                row['delivery_progress_json'] as String? ?? '{}',
              ) as Map).keys.toList(),
            ),
        lines,
      ),
      deliveryEditRevision: row['delivery_edit_revision'] as int? ?? 0,
    );
  }

  @override
  Future<void> setManagedLineDelivered(
    String orderId,
    String lineId,
    int quantity, {
    required int expectedQuantity,
  }) async {
    await (await _db).transaction((tx) async {
      final rows = await tx.query(
        'managed_orders',
        where: 'id = ? AND closed_at IS NULL',
        whereArgs: [orderId],
      );
      if (rows.length != 1) {
        throw const OrderStorageException('The active order was not found.');
      }
      final order = _managedFromRow(rows.single);
      final lines = order.lines.where((line) => line.id == lineId).toList();
      if (lines.length != 1 ||
          quantity < 0 ||
          quantity > lines.single.quantity ||
          order.deliveredQuantity(lineId) != expectedQuantity) {
        throw const OrderStorageException(
          'Invalid or stale delivery progress.',
        );
      }
      final progress = {...order.deliveredQuantities};
      if (quantity == 0) {
        progress.remove(lineId);
      } else {
        progress[lineId] = quantity;
      }
      await tx.update(
        'managed_orders',
        {
          'delivery_progress_json': jsonEncode(progress),
          'delivery_changed_ids': jsonEncode(
            {...order.changedDeliveryIds, lineId}.toList()..sort(),
          ),
          'delivery_edit_revision': order.deliveryEditRevision + 1,
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
    });
  }

  @override
  Future<OrderDraft> beginOrderAddition(String orderId, String draftId) async {
    return (await _db).transaction((tx) async {
      final drafts = await tx.query('drafts');
      final lineCount =
          Sqflite.firstIntValue(
            await tx.rawQuery('SELECT COUNT(*) FROM draft_lines'),
          ) ??
          0;
      if (drafts.length != 1 ||
          drafts.single['id'] != draftId ||
          lineCount != 0 ||
          (drafts.single['reference'] as String).isNotEmpty ||
          (drafts.single['order_note'] as String).isNotEmpty ||
          drafts.single['managed_order_id'] != null) {
        throw const OrderStorageException(
          'Finish the current composition first.',
        );
      }
      final rows = await tx.query(
        'managed_orders',
        where: 'id = ? AND closed_at IS NULL',
        whereArgs: [orderId],
      );
      if (rows.length != 1) {
        throw const OrderStorageException('The order is no longer open.');
      }
      final order = _managedFromRow(rows.single);
      final now = DateTime.now().toUtc();
      final draft = OrderDraft(
        id: createLocalId(),
        createdAt: now,
        updatedAt: now,
        managedOrderId: order.id,
        baseRevision: order.revision,
        reference: order.reference,
        orderNote: order.orderNote,
        courses: order.courses,
      );
      await tx.delete('drafts', where: 'id = ?', whereArgs: [draftId]);
      await _writeDraft(tx, draft);
      return draft;
    });
  }

  @override
  Future<void> closeManagedOrder(String orderId) async {
    await (await _db).transaction((tx) async {
      final linked = await tx.query(
        'drafts',
        where: 'managed_order_id = ?',
        whereArgs: [orderId],
      );
      if (linked.isNotEmpty) {
        throw const OrderStorageException('Finish the current addition first.');
      }
      final changed = await tx.update(
        'managed_orders',
        {'closed_at': _timestamp(DateTime.now())},
        where: 'id = ? AND closed_at IS NULL',
        whereArgs: [orderId],
      );
      if (changed != 1) {
        throw const OrderStorageException('The order is no longer open.');
      }
      await _pruneClosedOrders(tx);
    });
  }

  static void validatePortablePrices(Map<String, Object?> snapshot) {
    final tables = snapshot['tables'] as Map;
    final modern = (snapshot['schemaVersion'] as int) >= 15;
    for (final table in ['items', 'draft_lines', 'ticket_lines']) {
      for (final value in tables[table] as List) {
        final row = value as Map;
        if (modern &&
            (!row.containsKey('price_minor_units') ||
                !row.containsKey('price_currency'))) {
          throw const FormatException('Missing price fields');
        }
        final price = ProductPrice.fromColumns(
          row['price_minor_units'],
          row['price_currency'],
        );
        if (!modern && price != null) {
          throw const FormatException('Unsupported legacy price');
        }
      }
    }
    for (final value in (tables['managed_orders'] as List? ?? [])) {
      final rows = jsonDecode((value as Map)['lines_json'] as String) as List;
      for (final row in rows) {
        if (modern &&
            (row is! Map ||
                row.length != 9 ||
                !row.containsKey('priceMinorUnits') ||
                !row.containsKey('priceCurrency'))) {
          throw const FormatException('Missing managed price fields');
        }
        if (row is Map) {
          final price = ProductPrice.fromColumns(
            row['priceMinorUnits'],
            row['priceCurrency'],
          );
          if (!modern && price != null) {
            throw const FormatException('Unsupported legacy price');
          }
        }
      }
    }
    final row = (tables['order_feature_settings'] as List).single as Map;
    final enabled = row['prices_enabled'] ?? (modern ? null : 0);
    if (enabled is! int ||
        (enabled != 0 && enabled != 1) ||
        (!modern && enabled != 0)) {
      throw const FormatException('Invalid price option');
    }
  }

  static void validatePortableManagedOrders(Map<String, Object?> snapshot) {
    final tables = snapshot['tables'] as Map;
    final modern = (snapshot['schemaVersion'] as int) >= 12;
    final rows = tables['managed_orders'] ?? (modern ? null : <Object?>[]);
    if (rows is! List || (!modern && rows.isNotEmpty)) {
      throw const FormatException('Invalid managed inventory');
    }
    final orders = <String, ManagedOrder>{};
    for (final value in rows) {
      if (value is! Map) throw const FormatException('Invalid managed order');
      final row = Map<String, Object?>.from(value);
      for (final key in [
        'id',
        'heading_snapshot',
        'reference_snapshot',
        'order_note_snapshot',
        'created_at',
        'updated_at',
      ]) {
        if (row[key] is! String || (row[key] as String).contains('\u0000')) {
          throw const FormatException('Invalid managed text');
        }
      }
      if (!validOrderId(row['id'] as String) ||
          row['display_number'] is! int ||
          (row['display_number'] as int) < 1 ||
          row['revision'] is! int ||
          (row['revision'] as int) < 1 ||
          row['server_revision'] is! int ||
          (row['server_revision'] as int) < 0 ||
          (row['server_revision'] as int) > (row['revision'] as int) ||
          (row['heading_snapshot'] as String).length > 60 ||
          (row['reference_snapshot'] as String).length > 80 ||
          (row['order_note_snapshot'] as String).length > 500 ||
          (row['destination_id'] != null &&
              (row['destination_id'] is! String ||
                  !validOrderId(row['destination_id'] as String))) ||
          (row['client_installation_id'] != null &&
              (row['client_installation_id'] is! String ||
                  !validOrderId(row['client_installation_id'] as String))) ||
          ((row['destination_id'] == null) !=
              (row['client_installation_id'] == null)) ||
          (row['destination_id'] == null && row['server_revision'] != 0)) {
        throw const FormatException('Invalid managed metadata');
      }
      for (final key in ['created_at', 'updated_at', 'closed_at']) {
        final value = row[key];
        if (key == 'closed_at' && value == null) continue;
        final timestamp = value is String ? DateTime.tryParse(value) : null;
        if (timestamp == null ||
            !timestamp.isUtc ||
            !(value as String).endsWith('Z')) {
          throw const FormatException('Invalid managed timestamp');
        }
      }
      if ((snapshot['schemaVersion'] as int) >= 13 &&
          row['delivery_progress_json'] is! String) {
        throw const FormatException('Missing delivery progress');
      }
      if ((snapshot['schemaVersion'] as int) >= 14 &&
          (row['delivery_changed_ids'] is! String ||
              row['delivery_edit_revision'] is! int ||
              ((row['delivery_edit_revision'] as int) < 0 ||
                  (row['delivery_edit_revision'] as int) > 9007199254740991))) {
        throw const FormatException('Invalid progress edits');
      }
      final order = _managedFromRow(row);
      if (orders.containsKey(order.id)) {
        throw const FormatException('Duplicate managed order');
      }
      orders[order.id] = order;
    }
    final editing = <String>{};
    for (final value in tables['drafts'] as List) {
      final row = value as Map;
      final id = row['managed_order_id'];
      final revision = row['base_revision'] ?? (modern ? null : 0);
      if (revision is! int ||
          (modern && !row.containsKey('managed_order_id'))) {
        throw const FormatException('Invalid addition');
      }
      if (id == null) {
        if (revision != 0) {
          throw const FormatException('Invalid addition revision');
        }
        continue;
      }
      final order = orders[id];
      if (!modern ||
          order == null ||
          order.closedAt != null ||
          revision != order.revision ||
          !editing.add(order.id) ||
          row['reference'] != order.reference ||
          row['order_note'] != order.orderNote) {
        throw const FormatException('Invalid addition relationship');
      }
      final courses = decodeCourses(row['courses_json']);
      if (courses.length < order.courses.length ||
          List.generate(
            order.courses.length,
            (i) =>
                courses[i].id != order.courses[i].id ||
                courses[i].name != order.courses[i].name,
          ).contains(true)) {
        throw const FormatException('Invalid addition courses');
      }
      final previous = order.lines.map((line) => line.id).toSet();
      final additions = (tables['draft_lines'] as List).cast<Map>().where(
        (line) => line['draft_id'] == row['id'],
      );
      if (additions.any((line) => previous.contains(line['id'])) ||
          order.lines.length + additions.length > 200) {
        throw const FormatException('Invalid addition lines');
      }
    }
    final ticketLines = <Object?, List<Map>>{};
    for (final line in (tables['ticket_lines'] as List).cast<Map>()) {
      ticketLines.putIfAbsent(line['ticket_id'], () => []).add(line);
    }
    for (final row in (tables['tickets'] as List).cast<Map>()) {
      final id = row['managed_order_id'];
      final revision = row['revision'] ?? (modern ? null : 0);
      final encoded = row['addition_line_ids'] ?? (modern ? null : '[]');
      if (revision is! int || encoded is! String || encoded.length > 32768) {
        throw const FormatException('Invalid ticket revision');
      }
      final additions = jsonDecode(encoded);
      if (additions is! List ||
          additions.any((id) => id is! String) ||
          additions.toSet().length != additions.length) {
        throw const FormatException('Invalid addition inventory');
      }
      if (id == null) {
        if (revision != 0 || additions.isNotEmpty) {
          throw const FormatException('Invalid ordinary revision');
        }
        continue;
      }
      final order = orders[id];
      final lines = ticketLines[row['id']] ?? <Map>[];
      final stableIds = lines.map((line) => line['order_line_id']).toSet();
      if (!modern ||
          order == null ||
          revision < 1 ||
          revision > order.revision ||
          row['display_number'] != order.number ||
          row['heading_snapshot'] != order.heading ||
          row['reference_snapshot'] != order.reference ||
          row['order_note_snapshot'] != order.orderNote ||
          additions.isEmpty ||
          additions.any((id) => !stableIds.contains(id)) ||
          stableIds.contains(null) ||
          stableIds.length != lines.length ||
          (revision == 1 && additions.length != lines.length)) {
        throw const FormatException('Invalid ticket relationship');
      }
      for (final line in lines) {
        final matching = order.lines.where(
          (old) => old.id == line['order_line_id'],
        );
        if (matching.length != 1 ||
            matching.single.name != line['name_snapshot'] ||
            matching.single.quantity != line['quantity'] ||
            matching.single.preparationNote != line['preparation_note'] ||
            matching.single.courseId != line['course_id'] ||
            matching.single.price !=
                ProductPrice.fromColumns(
                  line['price_minor_units'],
                  line['price_currency'],
                )) {
          throw const FormatException('Invalid immutable line');
        }
      }
    }
    final features = (tables['order_feature_settings'] as List).single as Map;
    final enabled = features['managed_orders_enabled'] ?? (modern ? null : 0);
    if (enabled != 0 && enabled != 1 || (!modern && enabled != 0)) {
      throw const FormatException('Invalid managed settings');
    }
  }

  @override
  Future<List<SavedTicket>> loadTickets() async {
    try {
      final database = await _db;
      final rows = await database.query('tickets', orderBy: 'created_at DESC');
      final tickets = <SavedTicket>[];
      for (final row in rows) {
        tickets.add(await _ticketFromRow(database, row));
      }
      return tickets;
    } catch (error) {
      throw OrderStorageException('Could not read tickets.', error);
    }
  }

  @override
  Future<void> deleteTicket(String id) async {
    try {
      await (await _db).transaction((transaction) async {
        final unfinished = await transaction.rawQuery(
          "SELECT o.id FROM server_delivery_outbox o JOIN tickets t ON t.id = o.ticket_id WHERE t.managed_order_id IS NOT NULL AND o.status != 'delivered' AND t.id = ?",
          [id],
        );
        if (unfinished.isNotEmpty) {
          throw const OrderStorageException(
            'Deliver pending managed revisions before deleting their tickets.',
          );
        }
        await transaction.delete(
          'print_jobs',
          where: 'ticket_id = ?',
          whereArgs: [id],
        );
        await transaction.delete(
          'ticket_lines',
          where: 'ticket_id = ?',
          whereArgs: [id],
        );
        await transaction.delete('tickets', where: 'id = ?', whereArgs: [id]);
        await _pruneClosedOrders(transaction);
      });
    } catch (error) {
      throw OrderStorageException('Could not delete the ticket.', error);
    }
  }

  @override
  Future<void> deleteAllTickets() async {
    try {
      await (await _db).transaction((transaction) async {
        final unfinished = await transaction.rawQuery(
          "SELECT o.id FROM server_delivery_outbox o JOIN tickets t ON t.id = o.ticket_id WHERE t.managed_order_id IS NOT NULL AND o.status != 'delivered'",
        );
        if (unfinished.isNotEmpty) {
          throw const OrderStorageException(
            'Deliver pending managed revisions before deleting their tickets.',
          );
        }
        await transaction.delete('print_jobs');
        await transaction.delete('ticket_lines');
        await transaction.delete('tickets');
        await _pruneClosedOrders(transaction);
      });
    } catch (error) {
      throw OrderStorageException('Could not delete ticket history.', error);
    }
  }

  static Future<void> _pruneClosedOrders(DatabaseExecutor executor) async {
    await executor.rawDelete('''
      DELETE FROM managed_orders
      WHERE closed_at IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM tickets WHERE managed_order_id = managed_orders.id)
        AND NOT EXISTS (SELECT 1 FROM drafts WHERE managed_order_id = managed_orders.id)
    ''');
  }

  static const _portableTables = <String>[
    'managed_orders',
    'categories',
    'items',
    'drafts',
    'draft_lines',
    'tickets',
    'ticket_lines',
    'counters',
    'print_jobs',
    'order_feature_settings',
  ];

  static const _deleteOrder = <String>[
    'managed_orders',
    'print_jobs',
    'ticket_lines',
    'tickets',
    'draft_lines',
    'drafts',
    'items',
    'categories',
    'counters',
    'order_feature_settings',
  ];

  static Future<Map<String, Object?>> _portableSnapshot(
    DatabaseExecutor tx,
  ) async {
    final tables = <String, Object?>{};
    for (final table in _portableTables) {
      final rows = await tx.query(table);
      tables[table] = [
        for (final row in rows)
          {
            for (final entry in row.entries)
              entry.key: entry.value is Uint8List
                  ? base64Encode(entry.value as Uint8List)
                  : entry.value,
          },
      ];
    }
    return {'schemaVersion': databaseVersion, 'tables': tables};
  }

  @override
  Future<Map<String, Object?>> createPortableSnapshot() async {
    try {
      return await (await _db).transaction(_portableSnapshot);
    } catch (error) {
      throw OrderStorageException('Could not create the data snapshot.', error);
    }
  }

  @override
  Future<Map<String, Object?>> createProgressRecoverySnapshot() async =>
      (await _db).transaction(
        (tx) async => {
          'database': await _portableSnapshot(tx),
          'progressSync': await tx.query('client_progress_sync'),
        },
      );

  @override
  Future<void> replaceProgressRecoverySnapshot(
    Map<String, Object?> recovery,
  ) async {
    final database = recovery['database'];
    final rows = recovery['progressSync'];
    if (database is! Map<String, Object?> || rows is! List) {
      throw const FormatException('Invalid progress recovery snapshot');
    }
    await replaceWithPortableSnapshot(database, progressRecovery: rows);
  }

  static Future<void> _restoreProgressRecovery(
    DatabaseExecutor tx,
    List<Object?> rows,
  ) async {
    final ids = <String>{};
    for (final value in rows) {
      if (value is! Map<String, Object?> ||
          value.length != 6 ||
          value['order_id'] is! String ||
          !ids.add(value['order_id'] as String)) {
        throw const FormatException('Invalid progress recovery inventory');
      }
      final orders = await tx.query(
        'managed_orders',
        where: 'id = ?',
        whereArgs: [value['order_id']],
      );
      if (orders.length != 1) {
        throw const FormatException('Missing recovered order');
      }
      final order = _managedFromRow(orders.single);
      if (value['destination_id'] != order.destinationId ||
          value['client_id'] != order.clientInstallationId ||
          order.destinationId == null ||
          order.clientInstallationId == null) {
        throw const FormatException('Invalid recovery scope');
      }
      final quantities = {
        for (final line in order.lines.where((line) => line.sendToServer))
          line.id: line.quantity,
      };
      bool validQuantities(Map<String, int> counts) => counts.entries.every(
        (entry) =>
            quantities[entry.key] != null &&
            entry.value >= 0 &&
            entry.value <= quantities[entry.key]!,
      );
      final baseline = value['baseline_json'];
      if (baseline != null) {
        if (baseline is! String || baseline.length > 65536) {
          throw const FormatException('Invalid recovery baseline');
        }
        final snapshot = OrderProgressSnapshot.fromJson(jsonDecode(baseline));
        if (snapshot.clientId != order.clientInstallationId ||
            snapshot.orderId != order.id ||
            snapshot.orderRevision > order.serverRevision ||
            !validQuantities(snapshot.quantities)) {
          throw const FormatException('Invalid recovery baseline');
        }
      }
      final pending = value['pending_json'];
      final generation = value['pending_local_revision'];
      if (pending == null) {
        if (generation != null) {
          throw const FormatException('Invalid recovery generation');
        }
      } else {
        if (pending is! String ||
            pending.length > 65536 ||
            generation is! int ||
            generation < 0 ||
            generation > order.deliveryEditRevision) {
          throw const FormatException('Invalid recovery operation');
        }
        final change = OrderProgressChange.fromJson(jsonDecode(pending));
        if (change.orderId != order.id ||
            change.orderRevision > order.serverRevision ||
            !validQuantities(change.quantities)) {
          throw const FormatException('Invalid recovery operation');
        }
      }
      await tx.insert(
        'client_progress_sync',
        value,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  @override
  Future<void> replaceWithPortableSnapshot(
    Map<String, Object?> snapshot, {
    List<Object?>? progressRecovery,
  }) async {
    try {
      if (!portableSchemaVersions.contains(snapshot['schemaVersion']) ||
          snapshot['tables'] is! Map<String, dynamic>) {
        throw const FormatException('Unsupported database snapshot');
      }
      validatePortablePrices(snapshot);
      validatePortableCourses(snapshot);
      validatePortableManagedOrders(snapshot);
      final tables = Map<String, dynamic>.from(snapshot['tables']! as Map);
      if ((snapshot['schemaVersion'] as int) < 12) {
        tables.putIfAbsent('managed_orders', () => <Object?>[]);
      }
      if ((snapshot['schemaVersion'] as int) < 14 &&
          tables['managed_orders'] is List) {
        tables['managed_orders'] = [
          for (final value in tables['managed_orders'] as List)
            <String, Object?>{
              ...Map<String, Object?>.from(value as Map),
              'delivery_changed_ids': jsonEncode(
                (snapshot['schemaVersion'] as int) >= 13
                    ? decodeOrderLines(value['lines_json'])
                          .map((line) => line.id)
                          .toList()
                    : (jsonDecode(
                        value['delivery_progress_json'] as String? ?? '{}',
                      ) as Map).keys.toList(),
              ),
              'delivery_edit_revision': 0,
            },
        ];
      }
      if (tables.keys.toSet().difference(_portableTables.toSet()).isNotEmpty ||
          _portableTables.any((table) => tables[table] is! List)) {
        throw const FormatException('Invalid database table inventory');
      }
      final totalRows = _portableTables.fold<int>(
        0,
        (total, table) => total + (tables[table]! as List).length,
      );
      if (totalRows > 100000) {
        throw const FormatException('Database snapshot is too large');
      }
      await (await _db).transaction((transaction) async {
        await transaction.execute('PRAGMA defer_foreign_keys = ON');
        for (final table in _deleteOrder) {
          await transaction.delete(table);
        }
        for (final table in _portableTables) {
          for (final value in tables[table]! as List) {
            if (value is! Map<String, dynamic>) {
              throw const FormatException('Invalid database row');
            }
            final row = Map<String, Object?>.from(value);
            if (table == 'managed_orders' &&
                (snapshot['schemaVersion'] as int) < 15) {
              row['lines_json'] = encodeOrderLines(
                decodeOrderLines(row['lines_json']),
              );
            }
            if (table == 'print_jobs') {
              final payload = row['payload'];
              if (payload is! String) {
                throw const FormatException('Invalid print payload');
              }
              row['payload'] = base64Decode(payload);
            }
            await transaction.insert(table, row);
          }
        }
        if (progressRecovery != null) {
          await _restoreProgressRecovery(transaction, progressRecovery);
        }
        final violations = await transaction.rawQuery(
          'PRAGMA foreign_key_check',
        );
        if (violations.isNotEmpty) {
          throw const FormatException('Database relationships are invalid');
        }
        final counters = await transaction.query('counters');
        if (counters.length != 2 ||
            !counters.any((row) => row['name'] == 'ticket') ||
            !counters.any((row) => row['name'] == 'order')) {
          throw const FormatException('Database counters are invalid');
        }
      });
    } catch (error) {
      if (error is OrderStorageException) rethrow;
      throw OrderStorageException(
        'Could not restore the data snapshot.',
        error,
      );
    }
  }

  /// Validates JSON-backed course relationships before preview or replacement.
  static void validatePortableCourses(Map<String, Object?> snapshot) {
    final tables = snapshot['tables'];
    if (tables is! Map) throw const FormatException('Invalid course snapshot');
    final current = (snapshot['schemaVersion'] as int) >= 11;
    for (final (parents, children, parentKey) in [
      ('drafts', 'draft_lines', 'draft_id'),
      ('tickets', 'ticket_lines', 'ticket_id'),
    ]) {
      final rows = tables[parents];
      final lines = tables[children];
      if (rows is! List ||
          lines is! List ||
          rows.any((row) => row is! Map) ||
          lines.any((row) => row is! Map)) {
        throw const FormatException('Invalid course snapshot');
      }
      final lineCourses = <Object?, List<String?>>{};
      for (final line in lines.cast<Map>()) {
        final id = line['course_id'];
        if ((id != null && id is! String) ||
            (current && !line.containsKey('course_id'))) {
          throw const FormatException('Invalid course relationship');
        }
        lineCourses.putIfAbsent(line[parentKey], () => []).add(id as String?);
      }
      for (final row in rows.cast<Map>()) {
        final courses = decodeCourses(
          row['courses_json'] ?? (current ? null : '[]'),
        );
        final active = row['active_course_id'];
        if (active != null && active is! String) {
          throw const FormatException('Invalid active course');
        }
        final courseIds = lineCourses[row['id']] ?? const <String?>[];
        if (!current &&
            (courses.isNotEmpty ||
                active != null ||
                courseIds.any((id) => id != null))) {
          throw const FormatException('Courses require schema 11');
        }
        validateCourses(courses, courseIds, activeCourseId: active as String?);
      }
    }
    final features = tables['order_feature_settings'];
    if (features is! List || features.length != 1 || features.single is! Map) {
      throw const FormatException('Invalid course settings');
    }
    final enabled = (features.single as Map)['course_groups_enabled'];
    if ((current && enabled == null) ||
        (enabled != null && enabled != 0 && enabled != 1) ||
        (!current && enabled == 1)) {
      throw const FormatException('Invalid course settings');
    }
  }

  @override
  Future<List<PrintJob>> loadPrintJobs({String? ticketId}) async {
    try {
      final database = await _db;
      final rows = await database.rawQuery('''
        SELECT p.*, t.display_number AS ticket_number
        FROM print_jobs p
        JOIN tickets t ON t.id = p.ticket_id
        ${ticketId == null ? '' : 'WHERE p.ticket_id = ?'}
        ORDER BY p.created_at DESC
        ''', ticketId == null ? null : [ticketId]);
      return rows.map(_printJobFromRow).toList(growable: false);
    } catch (error) {
      if (error is OrderStorageException) rethrow;
      throw OrderStorageException('Could not read print jobs.', error);
    }
  }

  @override
  Future<PrintJob> createPrintJob({
    required String requestId,
    required String ticketId,
    required Uint8List payload,
  }) async {
    if (requestId.isEmpty || payload.isEmpty || payload.length > 2097152) {
      throw const OrderStorageException('The print job is invalid.');
    }
    try {
      final database = await _db;
      final id = await database.transaction<String>((transaction) async {
        final existing = await transaction.query(
          'print_jobs',
          columns: ['id'],
          where: 'request_id = ?',
          whereArgs: [requestId],
          limit: 1,
        );
        if (existing.isNotEmpty) return existing.single['id']! as String;
        final now = _timestamp(DateTime.now());
        final jobId = createLocalId();
        await transaction.insert('print_jobs', {
          'id': jobId,
          'request_id': requestId,
          'ticket_id': ticketId,
          'payload': payload,
          'status': printJobStatusValue(PrintJobStatus.queued),
          'created_at': now,
          'updated_at': now,
        });
        return jobId;
      });
      return await _loadPrintJob(database, id);
    } catch (error) {
      if (error is OrderStorageException) rethrow;
      throw OrderStorageException('Could not create the print job.', error);
    }
  }

  @override
  Future<PrintJob> markPrintJobSending(
    String id, {
    required String printerAddress,
    required String printerName,
  }) async {
    try {
      final database = await _db;
      final changed = await database.update(
        'print_jobs',
        {
          'status': printJobStatusValue(PrintJobStatus.sending),
          'printer_address': printerAddress,
          'printer_name': printerName,
          'error_code': null,
          'updated_at': _timestamp(DateTime.now()),
        },
        where: 'id = ? AND status = ?',
        whereArgs: [id, printJobStatusValue(PrintJobStatus.queued)],
      );
      if (changed != 1) {
        throw const OrderStorageException(
          'Only a queued print job can be sent.',
        );
      }
      return await _loadPrintJob(database, id);
    } catch (error) {
      if (error is OrderStorageException) rethrow;
      throw OrderStorageException('Could not start the print job.', error);
    }
  }

  @override
  Future<PrintJob> markPrintJobOutcome(
    String id, {
    required PrintJobStatus status,
    String? errorCode,
  }) async {
    if (!{
      PrintJobStatus.transmitted,
      PrintJobStatus.failed,
      PrintJobStatus.uncertain,
    }.contains(status)) {
      throw const OrderStorageException('The print outcome is invalid.');
    }
    try {
      final database = await _db;
      await database.transaction((transaction) async {
        final now = _timestamp(DateTime.now());
        final changed = await transaction.update(
          'print_jobs',
          {
            'status': printJobStatusValue(status),
            'error_code': errorCode,
            'updated_at': now,
          },
          where: 'id = ? AND status = ?',
          whereArgs: [id, printJobStatusValue(PrintJobStatus.sending)],
        );
        if (changed != 1) {
          throw const OrderStorageException(
            'Only a sending print job can receive an outcome.',
          );
        }
        if (status == PrintJobStatus.transmitted) {
          await transaction.rawUpdate(
            '''
            UPDATE server_delivery_outbox
            SET status = 'pending', error_code = NULL, updated_at = ?
            WHERE ticket_id = (
              SELECT ticket_id FROM print_jobs WHERE id = ?
            ) AND status = 'awaiting_print'
            ''',
            [now, id],
          );
        }
      });
      return await _loadPrintJob(database, id);
    } catch (error) {
      if (error is OrderStorageException) rethrow;
      throw OrderStorageException('Could not finish the print job.', error);
    }
  }

  static PairedServer _pairedServerFromRow(Map<String, Object?> row) =>
      PairedServer(
        id: row['id']! as String,
        displayName: row['display_name']! as String,
        baseUrl: Uri.parse(row['base_url']! as String),
        certificateFingerprint: row['certificate_fingerprint']! as String,
        createdAt: DateTime.parse(row['created_at']! as String),
        updatedAt: DateTime.parse(row['updated_at']! as String),
      );

  static Future<ClientDelivery> _loadClientDelivery(
    DatabaseExecutor executor,
    String id,
  ) async {
    final rows = await executor.query(
      'server_delivery_outbox',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const OrderStorageException(
        'The server delivery could not be found.',
      );
    }
    return _clientDeliveryFromRow(rows.single);
  }

  static ClientDelivery _clientDeliveryFromRow(Map<String, Object?> row) {
    final envelope = OrderDeliveryEnvelope.fromJsonString(
      row['payload_json']! as String,
    );
    return ClientDelivery(
      id: row['id']! as String,
      destinationId: row['destination_id']! as String,
      clientInstallationId: row['client_installation_id']! as String,
      ticketId: row['ticket_id']! as String,
      ticketNumber: envelope.ticketNumber,
      envelope: envelope,
      status: ClientDeliveryStatusValue.parse(row['status']! as String),
      attemptCount: row['attempt_count']! as int,
      errorCode: row['error_code'] as String?,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
      deliveredAt: row['delivered_at'] == null
          ? null
          : DateTime.parse(row['delivered_at']! as String),
      serverOrderId: row['server_order_id'] as String?,
    );
  }

  static Future<PrintJob> _loadPrintJob(
    DatabaseExecutor executor,
    String id,
  ) async {
    final rows = await executor.rawQuery(
      '''
      SELECT p.*, t.display_number AS ticket_number
      FROM print_jobs p
      JOIN tickets t ON t.id = p.ticket_id
      WHERE p.id = ?
      ''',
      [id],
    );
    if (rows.isEmpty) {
      throw const OrderStorageException('The print job could not be found.');
    }
    return _printJobFromRow(rows.single);
  }

  static PrintJob _printJobFromRow(Map<String, Object?> row) => PrintJob(
    id: row['id']! as String,
    requestId: row['request_id']! as String,
    ticketId: row['ticket_id']! as String,
    ticketNumber: row['ticket_number']! as int,
    createdAt: DateTime.parse(row['created_at']! as String),
    updatedAt: DateTime.parse(row['updated_at']! as String),
    status: parsePrintJobStatus(row['status']! as String),
    payload: row['payload']! as Uint8List,
    printerAddress: row['printer_address'] as String?,
    printerName: row['printer_name'] as String?,
    errorCode: row['error_code'] as String?,
  );

  static PairedClient _pairedClientFromRow(Map<String, Object?> row) =>
      PairedClient(
        installationId: row['installation_id']! as String,
        displayName: row['display_name']! as String,
        identityFingerprint: row['certificate_fingerprint']! as String,
        pairedAt: DateTime.parse(row['paired_at']! as String),
        lastSeenAt: row['last_seen_at'] == null
            ? null
            : DateTime.parse(row['last_seen_at']! as String),
      );

  static Future<ServerOrder> _loadServerOrder(
    DatabaseExecutor executor,
    String id,
  ) async {
    final rows = await executor.rawQuery(
      '''
      SELECT o.*, c.display_name AS client_display_name
      FROM server_orders o
      JOIN server_clients c
        ON c.installation_id = o.client_installation_id
      WHERE o.id = ?
      ''',
      [id],
    );
    if (rows.isEmpty) {
      throw const OrderStorageException('The received order was not found.');
    }
    return _serverOrderFromRow(executor, rows.single);
  }

  static Future<ServerOrder> _serverOrderFromRow(
    DatabaseExecutor executor,
    Map<String, Object?> row,
  ) async {
    final lineRows = await executor.query(
      'server_order_lines',
      where: 'order_id = ?',
      whereArgs: [row['id']],
      orderBy: 'position',
    );
    return ServerOrder(
      id: row['id']! as String,
      clientInstallationId: row['client_installation_id']! as String,
      clientDisplayName: row['client_display_name']! as String,
      deliveryId: row['delivery_id']! as String,
      clientTicketId: row['client_ticket_id']! as String,
      displayNumber: row['display_number']! as int,
      sourceCreatedAt: DateTime.parse(row['source_created_at']! as String),
      receivedAt: DateTime.parse(row['received_at']! as String),
      heading: row['heading_snapshot']! as String,
      reference: row['reference_snapshot']! as String,
      orderNote: row['order_note_snapshot']! as String,
      courses: decodeCourses(row['courses_json']),
      managedOrderId: row['managed_order_id'] as String?,
      revision: row['revision'] as int? ?? 0,
      completedRevision: row['completed_revision'] as int? ?? 0,
      progressRevision: row['progress_revision'] as int? ?? 0,
      payloadChecksum: row['payload_checksum']! as String,
      status: ServerOrderStatusValue.parse(row['status']! as String),
      completedAt: row['completed_at'] == null
          ? null
          : DateTime.parse(row['completed_at']! as String),
      lines: [
        for (final line in lineRows)
          ServerOrderLine(
            name: line['name_snapshot']! as String,
            quantity: line['quantity']! as int,
            preparationNote: line['preparation_note']! as String,
            courseId: line['course_id'] as String?,
            id: line['order_line_id'] as String?,
            addedRevision: line['added_revision'] as int? ?? 0,
            deliveredQuantity: line['delivered_quantity'] as int? ?? 0,
          ),
      ],
    );
  }

  static Future<SavedTicket> _loadTicket(
    DatabaseExecutor executor,
    String id,
  ) async {
    final rows = await executor.query(
      'tickets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const OrderStorageException('The saved ticket could not be found.');
    }
    return _ticketFromRow(executor, rows.single);
  }

  static Future<SavedTicket> _ticketFromRow(
    DatabaseExecutor executor,
    Map<String, Object?> row,
  ) async {
    final lines = await executor.query(
      'ticket_lines',
      where: 'ticket_id = ?',
      whereArgs: [row['id']],
      orderBy: 'position',
    );
    return SavedTicket(
      id: row['id']! as String,
      number: row['display_number']! as int,
      createdAt: DateTime.parse(row['created_at']! as String),
      heading: row['heading_snapshot']! as String,
      reference: row['reference_snapshot']! as String,
      orderNote: row['order_note_snapshot']! as String,
      courses: decodeCourses(row['courses_json']),
      sourceTicketId: row['source_ticket_id'] as String?,
      managedOrderId: row['managed_order_id'] as String?,
      revision: row['revision'] as int? ?? 0,
      additionLineIds: (jsonDecode(
        row['addition_line_ids'] as String? ?? '[]',
      ) as List).cast<String>(),
      lines: lines.map(_lineFromTicketRow).toList(growable: false),
    );
  }

  static Future<OrderDraft> _draftFromRow(
    DatabaseExecutor executor,
    Map<String, Object?> row,
  ) async {
    final lines = await executor.query(
      'draft_lines',
      where: 'draft_id = ?',
      whereArgs: [row['id']],
      orderBy: 'position',
    );
    return OrderDraft(
      id: row['id']! as String,
      reference: row['reference']! as String,
      orderNote: row['order_note']! as String,
      courses: decodeCourses(row['courses_json']),
      activeCourseId: row['active_course_id'] as String?,
      managedOrderId: row['managed_order_id'] as String?,
      baseRevision: row['base_revision'] as int? ?? 0,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
      lines: lines.map(_lineFromDraftRow).toList(growable: false),
    );
  }

  static TicketLine _lineFromDraftRow(Map<String, Object?> row) => TicketLine(
    id: row['id']! as String,
    catalogueItemId: row['catalogue_item_id'] as String?,
    name: row['name_snapshot']! as String,
    quantity: row['quantity']! as int,
    preparationNote: row['preparation_note']! as String,
    courseId: row['course_id'] as String?,
    price: ProductPrice.fromColumns(
      row['price_minor_units'],
      row['price_currency'],
    ),
  );

  static TicketLine _lineFromTicketRow(Map<String, Object?> row) => TicketLine(
    id: (row['order_line_id'] ?? row['id']) as String,
    catalogueItemId: row['catalogue_item_id'] as String?,
    name: row['name_snapshot']! as String,
    quantity: row['quantity']! as int,
    preparationNote: row['preparation_note']! as String,
    courseId: row['course_id'] as String?,
    price: ProductPrice.fromColumns(
      row['price_minor_units'],
      row['price_currency'],
    ),
  );

  static ItemCategory _categoryFromRow(Map<String, Object?> row) =>
      ItemCategory(id: row['id']! as String, name: row['name']! as String);

  static CatalogueItem _itemFromRow(Map<String, Object?> row) => CatalogueItem(
    id: row['id']! as String,
    name: row['name']! as String,
    category: row['category_id'] == null
        ? null
        : ItemCategory(
            id: row['category_id']! as String,
            name: row['category_name']! as String,
          ),
    imagePath: row['image_path'] as String?,
    sendToServer: row['send_to_server']! as int == 1,
    price: ProductPrice.fromColumns(
      row['price_minor_units'],
      row['price_currency'],
    ),
  );

  static void _validateDraft(OrderDraft draft, {bool requireLines = false}) {
    validateCourses(
      draft.courses,
      draft.lines.map((line) => line.courseId),
      activeCourseId: draft.activeCourseId,
    );
    if (draft.reference.trim().length > 80 ||
        draft.orderNote.trim().length > 500) {
      throw const OrderStorageException('The draft contains invalid text.');
    }
    if (requireLines && draft.lines.isEmpty) {
      throw const OrderStorageException('A ticket needs at least one item.');
    }
    if (draft.lines.length > 200) {
      throw const OrderStorageException('The draft has too many lines.');
    }
    for (final line in draft.lines) {
      if (line.name.trim().isEmpty ||
          line.name.trim().length > 80 ||
          line.quantity < 1 ||
          line.quantity > 999 ||
          line.preparationNote.trim().length > 300 ||
          (line.price != null && !line.price!.isValid)) {
        throw const OrderStorageException(
          'The draft contains an invalid item.',
        );
      }
    }
  }

  static String _timestamp(DateTime dateTime) =>
      dateTime.toUtc().toIso8601String();

  @override
  Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
  }
}
