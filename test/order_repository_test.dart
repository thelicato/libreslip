import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory temporaryDirectory;
  late String databasePath;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'libreslip-orders-',
    );
    databasePath = '${temporaryDirectory.path}/orders.sqlite3';
  });

  tearDown(() async {
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('a draft survives closing and reopening the database', () async {
    final first = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: databasePath,
    );
    await first.open();
    final draft = await first.createDraft();
    final recovered = draft.copyWith(
      reference: 'Table 7',
      orderNote: 'Bring together',
      updatedAt: DateTime.now().toUtc(),
      lines: [
        TicketLine(
          id: createLocalId(),
          name: 'Soup of the day',
          quantity: 3,
          preparationNote: 'One without bread',
        ),
      ],
    );
    await first.saveDraft(recovered);
    await first.close();

    final second = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: databasePath,
    );
    addTearDown(second.close);
    await second.open();
    final drafts = await second.loadDrafts();

    expect(drafts, hasLength(1));
    expect(drafts.single.id, recovered.id);
    expect(drafts.single.reference, 'Table 7');
    expect(drafts.single.orderNote, 'Bring together');
    expect(drafts.single.lines.single.name, 'Soup of the day');
    expect(drafts.single.lines.single.quantity, 3);
    expect(drafts.single.lines.single.preparationNote, 'One without bread');
  });

  test('catalogue edits cannot rewrite a saved ticket snapshot', () async {
    final repository = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: databasePath,
    );
    addTearDown(repository.close);
    await repository.open();
    final item = await repository.saveItem(
      name: 'Mushroom toastie',
      categoryName: 'Kitchen',
      isFavourite: true,
    );
    final blank = await repository.createDraft();
    final draft = blank.copyWith(
      reference: 'Order A',
      orderNote: 'Together',
      updatedAt: DateTime.now().toUtc(),
      lines: [
        TicketLine(
          id: createLocalId(),
          catalogueItemId: item.id,
          name: item.name,
          quantity: 2,
          preparationNote: 'One without onion',
        ),
      ],
    );
    await repository.saveDraft(draft);
    final ticket = await repository.convertDraftToTicket(
      draft,
      heading: 'Corner & Co.',
    );

    await repository.saveItem(
      id: item.id,
      name: 'Renamed toastie',
      categoryName: 'Lunch',
      isFavourite: false,
    );
    await repository.archiveItem(item.id);
    final restored = (await repository.loadTickets()).single;

    expect(restored.id, ticket.id);
    expect(restored.heading, 'Corner & Co.');
    expect(restored.reference, 'Order A');
    expect(restored.orderNote, 'Together');
    expect(restored.lines.single.name, 'Mushroom toastie');
    expect(restored.lines.single.quantity, 2);
    expect(restored.lines.single.preparationNote, 'One without onion');
  });

  test('repeating draft conversion returns one stable ticket', () async {
    final repository = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: databasePath,
    );
    addTearDown(repository.close);
    await repository.open();
    final blank = await repository.createDraft();
    final draft = blank.copyWith(
      updatedAt: DateTime.now().toUtc(),
      lines: [TicketLine(id: createLocalId(), name: 'Espresso', quantity: 1)],
    );

    final first = await repository.convertDraftToTicket(
      draft,
      heading: 'Caffè Libertà',
    );
    final retried = await repository.convertDraftToTicket(
      draft,
      heading: 'Changed heading must not replace snapshot',
    );

    expect(retried.id, first.id);
    expect(retried.number, first.number);
    expect(retried.heading, 'Caffè Libertà');
    expect(await repository.loadTickets(), hasLength(1));
    expect(await repository.loadDrafts(), isEmpty);
  });

  test(
    'version 1 databases migrate in place without losing catalogue data',
    () async {
      final legacy = await databaseFactoryFfiNoIsolate.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (database, _) async {
            await _createVersionOneSchema(database);
            await database.insert('categories', {
              'id': 'category-1',
              'name': 'Counter',
              'created_at': '2026-09-20T10:00:00.000Z',
            });
            await database.insert('items', {
              'id': 'item-1',
              'name': 'Still water',
              'category_id': 'category-1',
              'archived': 0,
              'created_at': '2026-09-20T10:00:00.000Z',
              'updated_at': '2026-09-20T10:00:00.000Z',
            });
          },
        ),
      );
      await legacy.close();

      final repository = SqliteOrderRepository(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: databasePath,
      );
      await repository.open();
      final items = await repository.loadItems();

      expect(items, hasLength(1));
      expect(items.single.name, 'Still water');
      expect(items.single.category!.name, 'Counter');
      expect(items.single.isFavourite, isFalse);
      expect(items.single.imagePath, isNull);
      await repository.close();

      final database = await databaseFactoryFfiNoIsolate.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      final versionRows = await database.rawQuery('PRAGMA user_version');
      final version = versionRows.single.values.single as int;
      await database.close();
      expect(version, SqliteOrderRepository.databaseVersion);
    },
  );
}

Future<void> _createVersionOneSchema(Database database) async {
  await database.execute(
    'CREATE TABLE categories ('
    'id TEXT PRIMARY KEY, name TEXT NOT NULL COLLATE NOCASE UNIQUE, '
    'created_at TEXT NOT NULL)',
  );
  await database.execute(
    'CREATE TABLE items ('
    'id TEXT PRIMARY KEY, name TEXT NOT NULL, category_id TEXT, '
    'archived INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, '
    'updated_at TEXT NOT NULL)',
  );
  await database.execute(
    'CREATE TABLE drafts ('
    'id TEXT PRIMARY KEY, reference TEXT NOT NULL DEFAULT \'\', '
    'order_note TEXT NOT NULL DEFAULT \'\', created_at TEXT NOT NULL, '
    'updated_at TEXT NOT NULL)',
  );
  await database.execute(
    'CREATE TABLE draft_lines ('
    'id TEXT PRIMARY KEY, draft_id TEXT NOT NULL, catalogue_item_id TEXT, '
    'name_snapshot TEXT NOT NULL, quantity INTEGER NOT NULL, '
    'preparation_note TEXT NOT NULL DEFAULT \'\', position INTEGER NOT NULL)',
  );
  await database.execute(
    'CREATE TABLE tickets ('
    'id TEXT PRIMARY KEY, ticket_number INTEGER NOT NULL UNIQUE, '
    'origin_draft_id TEXT NOT NULL UNIQUE, heading_snapshot TEXT NOT NULL, '
    'reference_snapshot TEXT NOT NULL DEFAULT \'\', '
    'order_note_snapshot TEXT NOT NULL DEFAULT \'\', created_at TEXT NOT NULL)',
  );
  await database.execute(
    'CREATE TABLE ticket_lines ('
    'id TEXT PRIMARY KEY, ticket_id TEXT NOT NULL, catalogue_item_id TEXT, '
    'name_snapshot TEXT NOT NULL, quantity INTEGER NOT NULL, '
    'preparation_note TEXT NOT NULL DEFAULT \'\', position INTEGER NOT NULL)',
  );
  await database.execute(
    'CREATE TABLE counters ('
    'name TEXT PRIMARY KEY, next_value INTEGER NOT NULL)',
  );
  await database.insert('counters', {'name': 'ticket', 'next_value': 1});
}
