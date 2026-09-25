import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../networking/domain/client_delivery_models.dart';
import '../../networking/domain/network_models.dart';
import '../../networking/domain/network_protocol.dart';
import '../../networking/domain/server_inbox_models.dart';
import '../../printing/domain/print_job.dart';
import '../domain/order_models.dart';

class SqliteOrderRepository
    implements
        OrderRepository,
        PrintJobStore,
        NetworkConfigurationStore,
        ClientDeliveryStore,
        ServerInboxStore {
  SqliteOrderRepository({DatabaseFactory? factory, this._databasePath})
    : _factory = factory ?? databaseFactory;

  static const databaseVersion = 9;
  static const portableSchemaVersions = {5, 6, 7, 8, databaseVersion};
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
      final result = await database.transaction<({String id, bool duplicate})>((
        transaction,
      ) async {
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
          columns: ['status'],
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
          await transaction.update(
            'server_orders',
            {
              'status': ServerOrderStatus.done.value,
              'completed_at': _timestamp(completedAt),
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
  }) async {
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
        final orderNumber = orderCounter.single['next_value']! as int;
        await transaction.update(
          'counters',
          {'next_value': ticketNumber + 1},
          where: 'name = ?',
          whereArgs: ['ticket'],
        );
        await transaction.update(
          'counters',
          {'next_value': orderNumber + 1},
          where: 'name = ?',
          whereArgs: ['order'],
        );
        final id = createLocalId();
        final createdAt = DateTime.now().toUtc();
        await transaction.insert('tickets', {
          'id': id,
          'ticket_number': ticketNumber,
          'display_number': orderNumber,
          'origin_draft_id': draft.id,
          'heading_snapshot': heading.trim(),
          'reference_snapshot': draft.reference.trim(),
          'order_note_snapshot': draft.orderNote.trim(),
          'created_at': _timestamp(createdAt),
          'source_ticket_id': null,
        });
        for (var index = 0; index < draft.lines.length; index++) {
          final line = draft.lines[index];
          await transaction.insert('ticket_lines', {
            'id': createLocalId(),
            'ticket_id': id,
            'catalogue_item_id': line.catalogueItemId,
            'name_snapshot': line.name,
            'quantity': line.quantity,
            'preparation_note': line.preparationNote.trim(),
            'position': index,
          });
        }
        final destinations = await transaction.query(
          'network_destinations',
          columns: ['id'],
          where: 'is_active = 1',
          limit: 1,
        );
        if (destinations.isNotEmpty) {
          final catalogueIds = draft.lines
              .map((line) => line.catalogueItemId)
              .whereType<String>()
              .toSet();
          final excludedIds = <String>{};
          if (catalogueIds.isNotEmpty) {
            final placeholders = List.filled(
              catalogueIds.length,
              '?',
            ).join(',');
            final excluded = await transaction.query(
              'items',
              columns: ['id'],
              where: 'send_to_server = 0 AND id IN ($placeholders)',
              whereArgs: catalogueIds.toList(growable: false),
            );
            excludedIds.addAll(excluded.map((row) => row['id']! as String));
          }
          final deliveryLines = [
            for (final line in draft.lines)
              if (line.catalogueItemId == null ||
                  !excludedIds.contains(line.catalogueItemId))
                DeliveryLine(
                  name: line.name,
                  quantity: line.quantity,
                  preparationNote: line.preparationNote.trim(),
                ),
          ];
          if (deliveryLines.isNotEmpty) {
            final settings = await transaction.query(
              'network_settings',
              columns: ['installation_id'],
              where: 'id = 1',
              limit: 1,
            );
            if (settings.length != 1) {
              throw const OrderStorageException(
                'The client installation identity could not be found.',
              );
            }
            final deliveryId = createLocalId();
            final clientInstallationId =
                settings.single['installation_id']! as String;
            final envelope = OrderDeliveryEnvelope.create(
              clientInstallationId: clientInstallationId,
              deliveryId: deliveryId,
              ticketId: id,
              ticketNumber: orderNumber,
              createdAt: createdAt,
              heading: heading.trim(),
              reference: draft.reference.trim(),
              orderNote: draft.orderNote.trim(),
              lines: deliveryLines,
            );
            final now = _timestamp(createdAt);
            await transaction.insert('server_delivery_outbox', {
              'id': deliveryId,
              'destination_id': destinations.single['id']! as String,
              'client_installation_id': clientInstallationId,
              'ticket_id': id,
              'payload_json': envelope.toJsonString(),
              'payload_checksum': envelope.payloadChecksum,
              'status': ClientDeliveryStatus.pending.value,
              'attempt_count': 0,
              'created_at': now,
              'updated_at': now,
            });
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
      });
    } catch (error) {
      throw OrderStorageException('Could not delete the ticket.', error);
    }
  }

  @override
  Future<void> deleteAllTickets() async {
    try {
      await (await _db).transaction((transaction) async {
        await transaction.delete('print_jobs');
        await transaction.delete('ticket_lines');
        await transaction.delete('tickets');
      });
    } catch (error) {
      throw OrderStorageException('Could not delete ticket history.', error);
    }
  }

  static const _portableTables = <String>[
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

  @override
  Future<Map<String, Object?>> createPortableSnapshot() async {
    try {
      return await (await _db).transaction((transaction) async {
        final tables = <String, Object?>{};
        for (final table in _portableTables) {
          final rows = await transaction.query(table);
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
        return <String, Object?>{
          'schemaVersion': databaseVersion,
          'tables': tables,
        };
      });
    } catch (error) {
      throw OrderStorageException('Could not create the data snapshot.', error);
    }
  }

  @override
  Future<void> replaceWithPortableSnapshot(
    Map<String, Object?> snapshot,
  ) async {
    try {
      if (!portableSchemaVersions.contains(snapshot['schemaVersion']) ||
          snapshot['tables'] is! Map<String, dynamic>) {
        throw const FormatException('Unsupported database snapshot');
      }
      final tables = snapshot['tables']! as Map<String, dynamic>;
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
      final changed = await database.update(
        'print_jobs',
        {
          'status': printJobStatusValue(status),
          'error_code': errorCode,
          'updated_at': _timestamp(DateTime.now()),
        },
        where: 'id = ? AND status = ?',
        whereArgs: [id, printJobStatusValue(PrintJobStatus.sending)],
      );
      if (changed != 1) {
        throw const OrderStorageException(
          'Only a sending print job can receive an outcome.',
        );
      }
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
      sourceTicketId: row['source_ticket_id'] as String?,
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
  );

  static TicketLine _lineFromTicketRow(Map<String, Object?> row) => TicketLine(
    id: row['id']! as String,
    catalogueItemId: row['catalogue_item_id'] as String?,
    name: row['name_snapshot']! as String,
    quantity: row['quantity']! as int,
    preparationNote: row['preparation_note']! as String,
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
  );

  static void _validateDraft(OrderDraft draft, {bool requireLines = false}) {
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
          line.preparationNote.trim().length > 300) {
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
