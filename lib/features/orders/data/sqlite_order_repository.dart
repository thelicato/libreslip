import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../printing/domain/print_job.dart';
import '../domain/order_models.dart';

class SqliteOrderRepository implements OrderRepository, PrintJobStore {
  SqliteOrderRepository({DatabaseFactory? factory, this._databasePath})
    : _factory = factory ?? databaseFactory;

  static const databaseVersion = 3;
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
  Future<List<CatalogueItem>> loadItems() async {
    try {
      final rows = await (await _db).rawQuery('''
        SELECT i.*, c.name AS category_name
        FROM items i
        LEFT JOIN categories c ON c.id = i.category_id
        WHERE i.archived = 0
        ORDER BY i.is_favourite DESC, i.name COLLATE NOCASE
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
    required bool isFavourite,
    String? imagePath,
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
          'is_favourite': isFavourite ? 1 : 0,
          'image_path': imagePath,
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
        {'archived': 1, 'updated_at': _timestamp(DateTime.now())},
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
  Future<OrderDraft> createDraft({SavedTicket? fromTicket}) async {
    final now = DateTime.now().toUtc();
    final draft = OrderDraft(
      id: createLocalId(),
      createdAt: now,
      updatedAt: now,
      reference: fromTicket?.reference ?? '',
      orderNote: fromTicket?.orderNote ?? '',
      lines: [
        for (final line in fromTicket?.lines ?? const <TicketLine>[])
          TicketLine(
            id: createLocalId(),
            catalogueItemId: line.catalogueItemId,
            name: line.name,
            quantity: line.quantity,
            preparationNote: line.preparationNote,
          ),
      ],
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
        final counter = await transaction.query(
          'counters',
          columns: ['next_value'],
          where: 'name = ?',
          whereArgs: ['ticket'],
          limit: 1,
        );
        final number = counter.single['next_value']! as int;
        await transaction.update(
          'counters',
          {'next_value': number + 1},
          where: 'name = ?',
          whereArgs: ['ticket'],
        );
        final id = createLocalId();
        await transaction.insert('tickets', {
          'id': id,
          'ticket_number': number,
          'origin_draft_id': draft.id,
          'heading_snapshot': heading.trim(),
          'reference_snapshot': draft.reference.trim(),
          'order_note_snapshot': draft.orderNote.trim(),
          'created_at': _timestamp(DateTime.now()),
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
  Future<List<PrintJob>> loadPrintJobs({String? ticketId}) async {
    try {
      final database = await _db;
      final rows = await database.rawQuery('''
        SELECT p.*, t.ticket_number
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

  static Future<PrintJob> _loadPrintJob(
    DatabaseExecutor executor,
    String id,
  ) async {
    final rows = await executor.rawQuery(
      '''
      SELECT p.*, t.ticket_number
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
      number: row['ticket_number']! as int,
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
    isFavourite: row['is_favourite'] == 1,
    imagePath: row['image_path'] as String?,
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
