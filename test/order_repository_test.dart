import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:libreslip/features/printing/domain/print_job.dart';
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

  test(
    'visible order numbers can restart without changing saved tickets',
    () async {
      final first = SqliteOrderRepository(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: databasePath,
      );
      await first.open();
      expect(await first.loadNextOrderNumber(), 1);

      Future<SavedTicket> save(String name) async {
        final blank = await first.createDraft();
        final draft = blank.copyWith(
          updatedAt: DateTime.now().toUtc(),
          lines: [TicketLine(id: createLocalId(), name: name, quantity: 1)],
        );
        return first.convertDraftToTicket(draft, heading: 'Kitchen');
      }

      final original = await save('Tea');
      final secondOrder = await save('Coffee');
      expect(original.number, 1);
      expect(secondOrder.number, 2);
      expect(await first.loadNextOrderNumber(), 3);

      await first.resetOrderNumber();
      expect(await first.loadNextOrderNumber(), 1);
      final restarted = await save('Water');
      expect(restarted.number, 1);
      expect(restarted.id, isNot(original.id));
      expect(await first.loadTickets(), hasLength(3));
      await first.close();

      final reopened = SqliteOrderRepository(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: databasePath,
      );
      addTearDown(reopened.close);
      await reopened.open();
      expect(await reopened.loadNextOrderNumber(), 2);
      final restored = await reopened.loadTickets();
      expect(restored, hasLength(3));
      expect(
        restored.singleWhere((ticket) => ticket.id == original.id).number,
        1,
      );
      expect(
        restored.singleWhere((ticket) => ticket.id == restarted.id).number,
        1,
      );
    },
  );

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
    'print jobs are idempotent and interrupted sending recovers as uncertain',
    () async {
      final first = SqliteOrderRepository(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: databasePath,
      );
      await first.open();
      final blank = await first.createDraft();
      final draft = blank.copyWith(
        updatedAt: DateTime.now().toUtc(),
        lines: [
          TicketLine(id: createLocalId(), name: 'Caffè lungo', quantity: 2),
        ],
      );
      final ticket = await first.convertDraftToTicket(
        draft,
        heading: 'Bottega',
      );
      final created = await first.createPrintJob(
        requestId: 'request-1',
        ticketId: ticket.id,
        payload: Uint8List.fromList([0x1B, 0x40, 0x0A]),
      );
      final duplicate = await first.createPrintJob(
        requestId: 'request-1',
        ticketId: ticket.id,
        payload: Uint8List.fromList([0x00]),
      );
      expect(duplicate.id, created.id);
      await first.markPrintJobSending(
        created.id,
        printerAddress: '00:11:22:33:44:55',
        printerName: 'NT-1809DD',
      );
      await first.close();

      final recovered = SqliteOrderRepository(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: databasePath,
      );
      addTearDown(recovered.close);
      await recovered.open();
      final jobs = await recovered.loadPrintJobs(ticketId: ticket.id);

      expect(jobs, hasLength(1));
      expect(jobs.single.status, PrintJobStatus.uncertain);
      expect(jobs.single.errorCode, 'interrupted');
      expect(jobs.single.printerName, 'NT-1809DD');
      await expectLater(
        recovered.markPrintJobSending(
          jobs.single.id,
          printerAddress: '00:11:22:33:44:55',
          printerName: 'NT-1809DD',
        ),
        throwsA(isA<OrderStorageException>()),
      );

      final reprint = await recovered.createPrintJob(
        requestId: 'request-2',
        ticketId: ticket.id,
        payload: Uint8List.fromList([0x1B, 0x40, 0x0A]),
      );
      await recovered.markPrintJobSending(
        reprint.id,
        printerAddress: '00:11:22:33:44:55',
        printerName: 'NT-1809DD',
      );
      await recovered.markPrintJobOutcome(
        reprint.id,
        status: PrintJobStatus.transmitted,
      );
      expect(await recovered.loadPrintJobs(ticketId: ticket.id), hasLength(2));
      expect(await recovered.loadTickets(), hasLength(1));
    },
  );

  test('composition feature settings default on and survive restart', () async {
    final first = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: databasePath,
    );
    await first.open();
    expect(
      await first.loadFeatureSettings(),
      isA<OrderFeatureSettings>()
          .having((value) => value.orderReferenceEnabled, 'reference', isTrue)
          .having(
            (value) => value.preparationNotesEnabled,
            'preparation notes',
            isTrue,
          )
          .having((value) => value.orderNotesEnabled, 'order notes', isTrue),
    );
    const disabled = OrderFeatureSettings(
      orderReferenceEnabled: false,
      preparationNotesEnabled: false,
      orderNotesEnabled: false,
    );
    await first.saveFeatureSettings(disabled);
    await first.close();

    final second = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: databasePath,
    );
    addTearDown(second.close);
    await second.open();
    final restored = await second.loadFeatureSettings();
    expect(restored.orderReferenceEnabled, isFalse);
    expect(restored.preparationNotesEnabled, isFalse);
    expect(restored.orderNotesEnabled, isFalse);
  });

  test(
    'deleting one or all tickets leaves the current order number unchanged',
    () async {
      final repository = SqliteOrderRepository(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: databasePath,
      );
      addTearDown(repository.close);
      await repository.open();

      Future<SavedTicket> save(String name) async {
        final blank = await repository.createDraft();
        final draft = blank.copyWith(
          updatedAt: DateTime.now().toUtc(),
          lines: [TicketLine(id: createLocalId(), name: name, quantity: 1)],
        );
        return repository.convertDraftToTicket(draft, heading: 'Kitchen');
      }

      final first = await save('Tea');
      final second = await save('Coffee');
      await repository.createPrintJob(
        requestId: 'delete-history-job',
        ticketId: first.id,
        payload: Uint8List.fromList([0x1b, 0x40]),
      );
      expect(await repository.loadNextOrderNumber(), 3);

      await repository.deleteTicket(first.id);
      expect((await repository.loadTickets()).single.id, second.id);
      expect(await repository.loadPrintJobs(), isEmpty);
      expect(await repository.loadNextOrderNumber(), 3);

      await repository.deleteAllTickets();
      expect(await repository.loadTickets(), isEmpty);
      expect(await repository.loadNextOrderNumber(), 3);

      final next = await save('Water');
      expect(next.number, 3);
    },
  );

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
            await database.insert('tickets', {
              'id': 'ticket-1',
              'ticket_number': 1,
              'origin_draft_id': 'draft-1',
              'heading_snapshot': 'Legacy kitchen',
              'reference_snapshot': '',
              'order_note_snapshot': '',
              'created_at': '2026-09-20T10:05:00.000Z',
            });
            await database.insert('ticket_lines', {
              'id': 'line-1',
              'ticket_id': 'ticket-1',
              'catalogue_item_id': 'item-1',
              'name_snapshot': 'Still water',
              'quantity': 1,
              'preparation_note': '',
              'position': 0,
            });
            await database.update(
              'counters',
              {'next_value': 2},
              where: 'name = ?',
              whereArgs: ['ticket'],
            );
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
      expect(items.single.imagePath, isNull);
      expect(items.single.sendToServer, isTrue);
      final tickets = await repository.loadTickets();
      expect(tickets, hasLength(1));
      expect(tickets.single.number, 1);
      expect(tickets.single.lines.single.name, 'Still water');
      expect(await repository.loadNextOrderNumber(), 2);
      final features = await repository.loadFeatureSettings();
      expect(features.orderReferenceEnabled, isTrue);
      expect(features.preparationNotesEnabled, isTrue);
      expect(features.orderNotesEnabled, isTrue);
      final network = await repository.loadNetworkConfiguration();
      expect(network.mode.name, 'client');
      expect(network.installationId, hasLength(32));
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
