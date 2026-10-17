import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:libreslip/features/printing/domain/print_job.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'shared_orders_test.dart';
import 'test_support.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'updates replace one saved order, print everything and retire stale queues',
    () async {
      final env = await createMemoryOrderEnvironment();
      addTearDown(env.controller.dispose);
      addTearDown(env.repository.close);
      final c = env.controller;
      await c.updateFeatureSettings(
        const OrderFeatureSettings(managedOrdersEnabled: true),
      );
      await c.saveItem(name: 'Soup');
      c.addCatalogueItem(c.items.single);
      c.setQuantity(c.activeDraft!.lines.single.id, 3);
      final originalDraft = c.activeDraft!;
      final first = (await c.saveActiveTicket(heading: 'Kitchen'))!;
      final oldQueue = await env.repository.createPrintJob(
        requestId: 'old-queue',
        ticketId: first.id,
        expectedRevision: first.revision,
        payload: Uint8List.fromList([27, 64]),
      );
      await c.beginAddition(c.managedOrders.single.id);
      await c.saveItem(name: 'Water');
      c.addCatalogueItem(c.items.singleWhere((i) => i.name == 'Water'));
      final current = (await c.saveActiveTicket(heading: 'Kitchen'))!;
      expect(current.id, first.id);
      expect(current.createdAt, first.createdAt);
      expect(c.tickets, hasLength(1));
      expect(current.printLines.map((l) => l.name), ['Soup', 'Water']);
      expect(
        (await env.repository.loadPrintJobs()).single.status,
        PrintJobStatus.failed,
      );
      expect(
        (await env.repository.loadPrintJobs()).single.errorCode,
        'superseded',
      );
      await expectLater(
        env.repository.markPrintJobSending(
          oldQueue.id,
          printerAddress: 'printer',
          printerName: 'Test',
        ),
        throwsA(isA<OrderStorageException>()),
      );
      await expectLater(
        env.repository.createPrintJob(
          requestId: 'stale-screen',
          ticketId: first.id,
          expectedRevision: first.revision,
          payload: Uint8List.fromList([27, 64]),
        ),
        throwsA(isA<OrderStorageException>()),
      );
      expect(
        (await env.repository.convertDraftToTicket(
          originalDraft,
          heading: 'Kitchen',
          keepOpen: true,
        )).id,
        first.id,
      );
      expect(await env.repository.loadTickets(), hasLength(1));
      await c.beginAddition(c.managedOrders.single.id);
      final order = c.editingOrder!;
      final soup = order.lines.first;
      expect(
        await c.changeSavedItem(order, soup.id, 2, note: 'No salt'),
        isTrue,
      );
      expect(
        await c.changeSavedItem(order, soup.id, 1),
        isFalse,
      ); // stale token
      expect(c.tickets.single.lines.first.quantity, 2);
      expect(c.tickets.single.lines.first.preparationNote, 'No salt');
      expect(await c.changeSavedItem(c.editingOrder!, soup.id, 0), isTrue);
      expect(c.tickets.single.lines.single.name, 'Water');
      final snapshot = await env.repository.createPortableSnapshot();
      await env.repository.replaceWithPortableSnapshot(snapshot);
      expect(
        (await env.repository.loadTickets()).single.lines.single.name,
        'Water',
      );
      expect(
        (await env.repository.loadManagedOrders()).single.lines.single.name,
        'Water',
      );
    },
  );

  test('quantity edits and removals sync both Clients and preserve remaining deliveries', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    await f.syncBoth();
    await f.a.local('water', 1);
    await f.a.sync.synchronise();
    final stale = f.a.order;
    await f.a.sync.changeItem(stale, 'soup', 1, note: 'No cream');
    await f.syncBoth();
    expect(f.b.order.lines.first.quantity, 1);
    expect(f.b.order.lines.first.preparationNote, 'No cream');
    expect(f.b.order.deliveredQuantity('water'), 1);
    await expectLater(f.a.sync.changeItem(stale, 'soup', 0), throwsA(anything));
    while (f.a.sync.busy) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await f.a.sync.changeItem(f.a.order, 'soup', 0);
    await f.syncBoth();
    expect(f.b.order.lines.map((l) => l.id), ['water']);
    expect(f.b.workspace.tickets.single.lines.map((l) => l.id), ['water']);
    expect(f.a.workspace.tickets.single.lines.map((l) => l.id), [
      'water',
      'private',
    ]);
    await f.b.sync.changeItem(f.b.order, 'water', 0);
    await f.syncBoth();
    expect(f.b.order.lines, isEmpty);
    expect(f.b.workspace.tickets.single.lines, isEmpty);
    expect(f.a.order.lines.single.id, 'private');
  });

  test('shared edits keep confirmed content offline and recover a lost acknowledgement without replay', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    await f.syncBoth();
    final original = f.a.order;
    f.transport.supportsItemEdits = false;
    await expectLater(
      f.a.sync.changeItem(original, 'soup', 0),
      throwsA(anything),
    );
    while (f.a.sync.busy) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(f.a.order.lines.first.id, 'soup');
    f.transport.supportsItemEdits = true;
    f.transport.offline = true;
    await expectLater(
      f.a.sync.changeItem(f.a.order, 'soup', 0),
      throwsA(anything),
    );
    while (f.a.sync.busy) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(f.a.workspace.tickets.single.lines.first.id, 'soup');
    f.transport.offline = false;
    f.transport.loseItemAck = true;
    await expectLater(
      f.a.sync.changeItem(f.a.order, 'soup', 0),
      throwsA(anything),
    );
    while (f.a.sync.busy) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(f.a.order.lines.first.id, 'soup');
    f.transport.offline = false;
    await f.syncBoth();
    expect(f.a.order.lines.any((l) => l.id == 'soup'), isFalse);
    expect(f.b.order.lines.any((l) => l.id == 'soup'), isFalse);
    expect(f.a.workspace.tickets, hasLength(1));
    expect(f.b.workspace.tickets, hasLength(1));
  });

  test('a frozen addition survives another Client removing an item without resurrecting it', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    await f.syncBoth();
    final added = await f.b.add('Coffee', requirePrint: true);
    await f.b.sync.synchronise();
    expect(f.a.order.lines.any((l) => l.name == 'Coffee'), isFalse);
    await f.a.sync.changeItem(f.a.order, 'soup', 0);
    while (f.a.sync.busy) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await f.syncBoth();
    expect(f.b.order.lines.any((l) => l.id == 'soup'), isFalse);
    expect(f.b.order.lines.any((l) => l.name == 'Coffee'), isTrue);
    expect(
      f.b.workspace.tickets.single.lines.any((l) => l.id == 'soup'),
      isFalse,
    );
    final job = await f.b.repository.createPrintJob(
      requestId: 'current-full-print',
      ticketId: added.id,
      payload: Uint8List.fromList([27, 64]),
    );
    await f.b.repository.markPrintJobSending(
      job.id,
      printerAddress: 'printer',
      printerName: 'Test',
    );
    await f.b.repository.markPrintJobOutcome(
      job.id,
      status: PrintJobStatus.transmitted,
    );
    await f.b.delivery.ticketReady(added.id);
    expect(f.b.delivery.deliveryForTicket(added.id)!.errorCode, isNull);
    await f.syncBoth();
    expect(f.a.order.lines.any((l) => l.id == 'soup'), isFalse);
    expect(f.a.order.lines.any((l) => l.name == 'Coffee'), isTrue);
    expect(f.b.order.lines.any((l) => l.id == 'soup'), isFalse);
    expect(f.b.workspace.tickets, hasLength(1));
  });

  test('schema 18 upgrades to one latest copy and rejects obsolete queued printing', () async {
    final dir = await Directory.systemTemp.createTemp(
      'libreslip-latest-migration-',
    );
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/orders.sqlite3';
    final env = await createMemoryOrderEnvironment(databasePath: path);
    final c = env.controller;
    await c.updateFeatureSettings(
      const OrderFeatureSettings(managedOrdersEnabled: true),
    );
    await c.saveItem(name: 'Soup');
    c.addCatalogueItem(c.items.single);
    final first = (await c.saveActiveTicket(heading: 'Kitchen'))!;
    await c.beginAddition(c.managedOrders.single.id);
    c.addCatalogueItem(c.items.single);
    final last = (await c.saveActiveTicket(heading: 'Kitchen'))!;
    await env.repository.close();
    c.dispose();
    final db = await databaseFactoryFfiNoIsolate.openDatabase(path);
    final row = Map<String, Object?>.from((await db.query('tickets')).single);
    await db.insert('tickets', {
      ...row,
      'id': 'old-copy',
      'origin_draft_id': 'old-draft',
      'ticket_number': 100,
      'revision': 1,
      'addition_line_ids': jsonEncode([first.lines.first.id]),
    });
    final lines = await db.query(
      'ticket_lines',
      where: 'ticket_id = ?',
      whereArgs: [last.id],
    );
    await db.insert('ticket_lines', {
      ...lines.first,
      'id': 'old-line-row',
      'ticket_id': 'old-copy',
    });
    await db.insert('print_jobs', {
      'id': 'legacy-queue',
      'request_id': 'legacy-request',
      'ticket_id': 'old-copy',
      'payload': Uint8List.fromList([27, 64]),
      'status': 'queued',
      'created_at': row['created_at'],
      'updated_at': row['created_at'],
    });
    await db.execute('DROP TABLE order_save_receipts');
    await db.setVersion(18);
    await db.close();
    final upgraded = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: path,
    );
    await upgraded.open();
    addTearDown(upgraded.close);
    final saved = (await upgraded.loadTickets()).single;
    expect(saved.id, first.id);
    expect(saved.lines, hasLength(2));
    final queue = (await upgraded.loadPrintJobs()).single;
    expect(queue.ticketId, saved.id);
    expect(queue.status, PrintJobStatus.failed);
    await expectLater(
      upgraded.markPrintJobSending(
        queue.id,
        printerAddress: 'printer',
        printerName: 'Test',
      ),
      throwsA(isA<OrderStorageException>()),
    );
  });
}
