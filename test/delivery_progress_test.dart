import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/networking/domain/network_protocol.dart';
import 'package:libreslip/features/networking/domain/server_inbox_models.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  test(
    'offline delivery survives restart and additions without rewriting tickets',
    () async {
      final dir = await Directory.systemTemp.createTemp('libreslip-progress-');
      addTearDown(() => dir.delete(recursive: true));
      final repository = _repository('${dir.path}/orders.db');
      await repository.open();
      addTearDown(repository.close);
      final ticket = await _saveOrder(repository);
      final id = ticket.managedOrderId!;
      await repository.setManagedLineDelivered(
        id,
        'soup',
        1,
        expectedQuantity: 0,
      );
      await repository.close();
      await repository.open();
      final order = (await repository.loadManagedOrders()).single;
      expect(order.deliveredCount, 1);
      expect(order.outstandingCount, 2);
      expect(order.revision, 1);
      expect((await repository.loadTickets()).single.lines.single.quantity, 3);
      expect(await repository.loadClientDeliveries(), isEmpty);

      // Progress changes can be made while additions are being composed.
      final blank = await repository.createDraft();
      final addition = await repository.beginOrderAddition(id, blank.id);
      await repository.setManagedLineDelivered(
        id,
        'soup',
        3,
        expectedQuantity: 1,
      );
      await repository.convertDraftToTicket(
        addition.copyWith(
          lines: const [TicketLine(id: 'new-soup', name: 'Soup', quantity: 2)],
        ),
        heading: 'Ignored',
      );
      final revised = (await repository.loadManagedOrders()).single;
      expect(revised.deliveredQuantity('soup'), 3);
      expect(revised.deliveredQuantity('new-soup'), 0);
      expect(revised.outstandingCount, 2);
      await repository.setManagedLineDelivered(
        id,
        'soup',
        0,
        expectedQuantity: 3,
      );
      expect(
        (await repository.loadManagedOrders()).single.deliveredQuantities,
        isEmpty,
      );
      expect((await repository.loadTickets()).length, 2);
      // Disabling managed mode does not prevent delivery edits on retained orders.
      await repository.saveFeatureSettings(const OrderFeatureSettings());
      await repository.setManagedLineDelivered(
        id,
        'new-soup',
        1,
        expectedQuantity: 0,
      );
      expect((await repository.loadManagedOrders()).single.deliveredCount, 1);
    },
  );

  test('invalid or stale local edits fail atomically and closed orders reject edits', () async {
    final environment = await createMemoryOrderEnvironment();
    final repository = environment.repository;
    addTearDown(repository.close);
    final ticket = await _saveOrder(repository);
    final id = ticket.managedOrderId!;
    await repository.setManagedLineDelivered(
      id,
      'soup',
      1,
      expectedQuantity: 0,
    );
    for (final (line, quantity, expected) in [
      ('soup', 2, 0),
      ('soup', -1, 1),
      ('soup', 4, 1),
      ('missing', 1, 0),
    ]) {
      await expectLater(
        repository.setManagedLineDelivered(
          id,
          line,
          quantity,
          expectedQuantity: expected,
        ),
        throwsA(isA<OrderStorageException>()),
      );
      expect((await repository.loadManagedOrders()).single.deliveredCount, 1);
    }
    await repository.closeManagedOrder(id);
    await expectLater(
      repository.setManagedLineDelivered(id, 'soup', 2, expectedQuantity: 1),
      throwsA(isA<OrderStorageException>()),
    );
    expect((await repository.loadTickets()).single.id, ticket.id);
  });

  test('portable progress round-trips; schema 12 defaults to zero; malformed progress is rejected', () async {
    final environment = await createMemoryOrderEnvironment();
    final repository = environment.repository;
    addTearDown(repository.close);
    final ticket = await _saveOrder(repository);
    await repository.setManagedLineDelivered(
      ticket.managedOrderId!,
      'soup',
      2,
      expectedQuantity: 0,
    );
    final snapshot = await repository.createPortableSnapshot();
    await repository.setManagedLineDelivered(
      ticket.managedOrderId!,
      'soup',
      0,
      expectedQuantity: 2,
    );
    await repository.replaceWithPortableSnapshot(snapshot);
    expect((await repository.loadManagedOrders()).single.deliveredCount, 2);
    for (final value in [
      '{"unknown":1}',
      '{"soup":4}',
      '{"soup":-1}',
      '{"soup":0}',
      '{"soup":1.5}',
      '{"soup":true}',
      '[]',
      'invalid',
      null,
    ]) {
      final broken = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
      ((broken['tables'] as Map)['managed_orders'] as List)
              .single['delivery_progress_json'] =
          value;
      await expectLater(
        repository.replaceWithPortableSnapshot(broken),
        throwsA(isA<OrderStorageException>()),
      );
      expect((await repository.loadManagedOrders()).single.deliveredCount, 2);
    }
    final legacy = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
    legacy['schemaVersion'] = 12;
    ((legacy['tables'] as Map)['managed_orders'] as List).single.remove(
      'delivery_progress_json',
    );
    await repository.replaceWithPortableSnapshot(legacy);
    expect((await repository.loadManagedOrders()).single.deliveredCount, 0);
  });

  test('Server quantities drive preparation totals, completion and reversible undo', () async {
    final environment = await createMemoryOrderEnvironment();
    final repository = environment.repository;
    addTearDown(repository.close);
    await _pair(repository);
    final receipt = await repository.receiveServerOrder(
      _envelope(1),
      receivedAt: _now,
    );
    final id = receipt.order.id;
    var order = await repository.setServerLineDelivered(
      id,
      'soup',
      1,
      expectedQuantity: 0,
    );
    expect(order.status, ServerOrderStatus.received);
    expect(summariseOutstandingItems([order]).single.quantity, 2);
    await expectLater(
      repository.setServerLineDelivered(id, 'soup', 2, expectedQuantity: 0),
      throwsA(isA<OrderStorageException>()),
    );
    await expectLater(
      repository.setServerLineDelivered(id, 'soup', 4, expectedQuantity: 1),
      throwsA(isA<OrderStorageException>()),
    );
    order = await repository.setServerLineDelivered(
      id,
      'soup',
      3,
      expectedQuantity: 1,
    );
    expect(order.status, ServerOrderStatus.done);
    expect(order.completedAt, isNotNull);
    expect(summariseOutstandingItems([order]), isEmpty);
    order = await repository.setServerLineDelivered(
      id,
      'soup',
      2,
      expectedQuantity: 3,
    );
    expect(order.status, ServerOrderStatus.received);
    expect(order.completedAt, isNull);
    expect(summariseOutstandingItems([order]).single.quantity, 1);
    order = await repository.markServerOrderDone(id, completedAt: _now);
    expect(order.lines.single.deliveredQuantity, 3);
    order = await repository.markServerOrderReceived(id);
    expect(order.lines.single.deliveredQuantity, 0);
    expect(summariseOutstandingItems([order]).single.quantity, 3);
  });

  test('Server revisions and lost-ack retries retain partial deliveries; additions start outstanding', () async {
    final environment = await createMemoryOrderEnvironment();
    final repository = environment.repository;
    addTearDown(repository.close);
    await _pair(repository);
    final receipt = await repository.receiveServerOrder(
      _envelope(1),
      receivedAt: _now,
    );
    await repository.setServerLineDelivered(
      receipt.order.id,
      'soup',
      2,
      expectedQuantity: 0,
    );
    final revised = await repository.receiveServerOrder(
      _envelope(2),
      receivedAt: _now,
    );
    expect(revised.order.lines.map((line) => line.deliveredQuantity), [2, 0]);
    expect(
      summariseOutstandingItems([revised.order]).map((line) => line.quantity),
      [1],
    );
    final retry = await repository.receiveServerOrder(
      _envelope(1),
      receivedAt: _now,
    );
    expect(retry.wasDuplicate, isTrue);
    expect(retry.order.lines.first.deliveredQuantity, 2);
    final next = await repository.setServerLineDelivered(
      receipt.order.id,
      'soup',
      3,
      expectedQuantity: 2,
    );
    expect(summariseOutstandingItems([next]).single.name, 'Water');
    expect(summariseOutstandingItems([next]).single.quantity, 2);
    final done = await repository.markServerOrderDone(
      receipt.order.id,
      completedAt: _now,
    );
    expect(done.lines.map((line) => line.deliveredQuantity), [3, 2]);
    final undone = await repository.markServerOrderReceived(receipt.order.id);
    expect(undone.lines.map((line) => line.deliveredQuantity), [0, 0]);

    final ordinary = await repository.receiveServerOrder(
      OrderDeliveryEnvelope.create(
        clientInstallationId: 'client',
        deliveryId: 'ordinary',
        ticketId: 'ordinary',
        ticketNumber: 2,
        createdAt: _now,
        heading: 'Kitchen',
        reference: '',
        orderNote: '',
        lines: const [DeliveryLine(name: 'Soup', quantity: 2)],
      ),
      receivedAt: _now,
    );
    await expectLater(
      repository.setServerLineDelivered(
        ordinary.order.id,
        'soup',
        1,
        expectedQuantity: 0,
      ),
      throwsA(isA<OrderStorageException>()),
    );
    expect(
      (await repository.markServerOrderDone(
        ordinary.order.id,
        completedAt: _now,
      )).status,
      ServerOrderStatus.done,
    );
    expect(
      (await repository.markServerOrderReceived(ordinary.order.id)).status,
      ServerOrderStatus.received,
    );
  });

  test('schema 12 migration preserves prior Done progress and immutable local history', () async {
    final dir = await Directory.systemTemp.createTemp(
      'libreslip-progress-migration-',
    );
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/orders.db';
    final repository = _repository(path);
    await repository.open();
    final ticket = await _saveOrder(repository);
    await _pair(repository);
    final initial = await repository.receiveServerOrder(
      _envelope(1),
      receivedAt: _now,
    );
    await repository.markServerOrderDone(initial.order.id, completedAt: _now);
    await repository.receiveServerOrder(_envelope(2), receivedAt: _now);
    await repository.close();
    final old = await databaseFactoryFfiNoIsolate.openDatabase(path);
    await removeDeliveryColumnsForLegacyFixture(old);
    await old.setVersion(12);
    await old.close();
    await repository.open();
    addTearDown(repository.close);
    final order = (await repository.loadServerOrders()).single;
    expect(order.status, ServerOrderStatus.received);
    expect(order.lines.map((line) => line.deliveredQuantity), [3, 0]);
    expect(summariseOutstandingItems([order]).single.name, 'Water');
    expect((await repository.loadManagedOrders()).single.deliveredCount, 0);
    expect((await repository.loadTickets()).single.id, ticket.id);
    await repository.setServerLineDelivered(
      order.id,
      'water',
      1,
      expectedQuantity: 0,
    );
    await repository.close();
    await repository.open();
    expect(
      (await repository.loadServerOrders()).single.lines.last.deliveredQuantity,
      1,
    );
  });
}

final _now = DateTime.utc(2026, 10, 5);
SqliteOrderRepository _repository(String path) => SqliteOrderRepository(
  factory: databaseFactoryFfiNoIsolate,
  databasePath: path,
);
Future<SavedTicket> _saveOrder(SqliteOrderRepository repository) async {
  final draft = await repository.createDraft();
  return repository.convertDraftToTicket(
    draft.copyWith(
      courses: const [OrderCourse(id: 'first', name: 'First')],
      lines: const [
        TicketLine(id: 'soup', name: 'Soup', quantity: 3, courseId: 'first'),
      ],
    ),
    heading: 'Kitchen',
    keepOpen: true,
  );
}

Future<void> _pair(SqliteOrderRepository repository) => repository.pairClient(
  PairedClient(
    installationId: 'client',
    displayName: 'Client',
    identityFingerprint: 'b' * 64,
    pairedAt: _now,
  ),
);
OrderDeliveryEnvelope _envelope(int revision) => OrderDeliveryEnvelope.create(
  clientInstallationId: 'client',
  deliveryId: 'delivery-$revision',
  ticketId: 'ticket-$revision',
  managedOrderId: 'order',
  revision: revision,
  ticketNumber: 1,
  createdAt: _now,
  heading: 'Kitchen',
  reference: 'Table 4',
  orderNote: '',
  courses: const [
    OrderCourse(id: 'first', name: 'First'),
    OrderCourse(id: 'drinks', name: 'Drinks'),
  ],
  lines: [
    const DeliveryLine(
      id: 'soup',
      name: 'Soup',
      quantity: 3,
      courseId: 'first',
    ),
    if (revision > 1)
      const DeliveryLine(
        id: 'water',
        name: 'Water',
        quantity: 2,
        courseId: 'drinks',
      ),
  ],
);
