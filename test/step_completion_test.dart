import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
import 'package:libreslip/features/networking/domain/server_inbox_models.dart';
import 'package:libreslip/features/networking/domain/network_protocol.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:libreslip/features/settings/application/settings_controller.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'shared_orders_test.dart';
import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  test('whole-step edits persist atomically, reject stale views and preserve additions and ticket snapshots', () async {
    final directory = await Directory.systemTemp.createTemp('libreslip-step-');
    addTearDown(() => directory.delete(recursive: true));
    final repository = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: '${directory.path}/orders.db',
    );
    await repository.open();
    addTearDown(repository.close);
    final ticket = await _seed(repository);
    var order = (await repository.loadManagedOrders()).single;
    await repository.setManagedLineDelivered(
      order.id,
      'soup',
      1,
      expectedQuantity: 0,
    );
    order = (await repository.loadManagedOrders()).single;
    await _step(repository, order, 'first', true);
    var complete = (await repository.loadManagedOrders()).single;
    expect(complete.deliveredQuantities, {'soup': 3, 'bread': 2});
    expect(complete.changedDeliveryIds, containsAll(['soup', 'bread']));
    expect(complete.deliveryEditRevision, order.deliveryEditRevision + 1);
    expect(complete.deliveredQuantity('water'), 0);
    expect(complete.deliveredQuantity('extra'), 0);
    await repository.close();
    await repository.open();
    complete = (await repository.loadManagedOrders()).single;
    expect(complete.deliveredQuantities, {'soup': 3, 'bread': 2});
    for (final (snapshot, course) in [
      (order, 'first'),
      (complete, 'missing'),
    ]) {
      await expectLater(
        _step(repository, snapshot, course, false),
        throwsA(isA<OrderStorageException>()),
      );
      expect(
        (await repository.loadManagedOrders()).single.deliveredQuantities,
        complete.deliveredQuantities,
      );
    }
    await _step(repository, complete, null, true);
    final beforeAddition = (await repository.loadManagedOrders()).single;
    final addition = await repository.beginOrderAddition(
      order.id,
      (await repository.createDraft()).id,
    );
    await repository.convertDraftToTicket(
      addition.copyWith(
        lines: const [
          TicketLine(
            id: 'new-bread',
            name: 'Bread',
            quantity: 1,
            courseId: 'first',
          ),
        ],
      ),
      heading: 'Kitchen',
    );
    await expectLater(
      _step(repository, beforeAddition, 'first', false),
      throwsA(isA<OrderStorageException>()),
    );
    final revised = (await repository.loadManagedOrders()).single;
    expect(revised.deliveredQuantity('new-bread'), 0);
    expect(revised.deliveredQuantity('soup'), 3);
    await _step(repository, revised, 'first', true);
    final all = (await repository.loadManagedOrders()).single;
    expect(all.deliveredQuantity('new-bread'), 1);
    await _step(repository, all, 'first', false);
    final undone = (await repository.loadManagedOrders()).single;
    expect(undone.deliveredQuantities, {'extra': 1});
    expect(
      undone.changedDeliveryIds,
      containsAll(['soup', 'bread', 'new-bread', 'extra']),
    );
    final saved = (await repository.loadTickets()).firstWhere(
      (value) => value.id == ticket.id,
    );
    expect(saved.lines.map((line) => line.quantity), [3, 2, 2, 1]);
    expect(
      saved.lines.map((line) => line.id),
      ticket.lines.map((line) => line.id),
    );
    expect(await repository.loadPrintJobs(), isEmpty);
    await repository.closeManagedOrder(undone.id);
    await expectLater(
      _step(repository, undone, 'first', true),
      throwsA(isA<OrderStorageException>()),
    );
  });

  test('whole-step completion and undo sync both Clients, retain private progress and recover a lost acknowledgement', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    await f.syncBoth();
    await f.a.add('Tea', divider: true);
    await f.a.delivery.ticketReady(f.a.workspace.tickets.first.id);
    await f.syncBoth();
    final a = f.a.order;
    expect(
      await f.a.workspace.setStepDelivered(
        a.id,
        null,
        true,
        expectedOrderRevision: a.revision,
        expectedDeliveryRevision: a.deliveryEditRevision,
        expectedQuantities: {
          for (final line in a.lines.where((line) => line.courseId == null))
            line.id: a.deliveredQuantity(line.id),
        },
      ),
      isTrue,
    );
    f.transport.loseProgressAck = true;
    await f.a.sync.synchronise();
    expect(f.a.sync.error, 'unreachable');
    final pending = (await f.a.repository.loadSharedLink(a.id))!
        .pending!
        .operationId;
    await f.syncBoth();
    expect(
      f.transport.progressOperations.where((id) => id == pending),
      hasLength(2),
    );
    expect(f.a.order.deliveredQuantity('private'), 1);
    expect(f.b.order.deliveredQuantity('soup'), 3);
    expect(f.b.order.deliveredQuantity('water'), 2);
    final server = (await f.server.loadServerOrders()).single;
    expect(server.status, ServerOrderStatus.received);
    expect(summariseOutstandingItems([server]).single.name, 'Tea');
    final stale = f.b.order;
    await f.server.setServerLineDelivered(
      server.id,
      'water',
      1,
      expectedQuantity: 2,
    );
    await f.b.sync.synchronise();
    expect(f.b.order.revision, stale.revision);
    expect(f.b.order.deliveryEditRevision, stale.deliveryEditRevision);
    expect(
      await f.b.workspace.setStepDelivered(
        stale.id,
        null,
        false,
        expectedOrderRevision: stale.revision,
        expectedDeliveryRevision: stale.deliveryEditRevision,
        expectedQuantities: {
          for (final line in stale.lines.where((line) => line.courseId == null))
            line.id: stale.deliveredQuantity(line.id),
        },
      ),
      isFalse,
    );
    expect(f.b.order.deliveredQuantity('soup'), 3);
    expect(f.b.order.deliveredQuantity('water'), 1);
    final b = f.b.order;
    expect(
      await f.b.workspace.setStepDelivered(
        b.id,
        null,
        false,
        expectedOrderRevision: b.revision,
        expectedDeliveryRevision: b.deliveryEditRevision,
        expectedQuantities: {
          for (final line in b.lines.where((line) => line.courseId == null))
            line.id: b.deliveredQuantity(line.id),
        },
      ),
      isTrue,
    );
    await f.syncBoth();
    expect(f.a.order.deliveredQuantity('soup'), 0);
    expect(f.a.order.deliveredQuantity('water'), 0);
    expect(f.a.order.deliveredQuantity('private'), 1);
    expect(
      summariseOutstandingItems(await f.server.loadServerOrders())
          .map((value) => value.name),
      ['Soup', 'Water'],
    );
  });

  test('Server step edits roll back interrupted writes, persist, guard revisions and maintain queues', () async {
    final directory = await Directory.systemTemp.createTemp(
      'libreslip-server-step-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/orders.db';
    final repository = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: path,
    );
    await repository.open();
    addTearDown(repository.close);
    await repository.pairClient(
      PairedClient(
        installationId: 'client',
        displayName: 'Client',
        identityFingerprint: 'b' * 64,
        pairedAt: DateTime.now(),
      ),
    );
    final receipt = await repository.receiveServerOrder(
      _serverEnvelope(1),
      receivedAt: DateTime.now(),
    );
    final initial = await repository.setServerLineDelivered(
      receipt.order.id,
      'soup',
      1,
      expectedQuantity: 0,
    );
    final connection = await databaseFactoryFfiNoIsolate.openDatabase(path);
    await connection.execute(
      "CREATE TRIGGER reject_step_bread BEFORE UPDATE OF delivered_quantity ON server_order_lines WHEN NEW.order_line_id = 'bread' AND NEW.delivered_quantity = 3 BEGIN SELECT RAISE(ABORT, 'Injected step write failure'); END",
    );
    await expectLater(
      _serverStep(repository, initial, 'first', true),
      throwsA(isA<DatabaseException>()),
    );
    final rolledBack = (await repository.loadServerOrders()).single;
    expect(rolledBack.lines.map((line) => line.deliveredQuantity), [
      1,
      0,
      0,
      0,
    ]);
    expect(rolledBack.progressRevision, initial.progressRevision);
    expect(rolledBack.status, ServerOrderStatus.received);
    await connection.execute('DROP TRIGGER reject_step_bread');
    final complete = await _serverStep(repository, initial, 'first', true);
    expect(complete.lines.map((line) => line.deliveredQuantity), [2, 3, 0, 0]);
    expect(complete.progressRevision, initial.progressRevision + 1);
    expect(complete.completedAt, isNull);
    for (final (snapshot, course) in [
      (initial, 'first'),
      (complete, 'missing'),
    ]) {
      await expectLater(
        _serverStep(repository, snapshot, course, false),
        throwsA(isA<OrderStorageException>()),
      );
      expect(
        (await repository.loadServerOrders()).single.lines.map(
          (line) => line.deliveredQuantity,
        ),
        [2, 3, 0, 0],
      );
    }
    await repository.close();
    await repository.open();
    final reopened = (await repository.loadServerOrders()).single;
    expect(reopened.progressRevision, complete.progressRevision);
    final later = await _serverStep(repository, reopened, 'later', true);
    final all = await _serverStep(repository, later, null, true);
    expect(all.status, ServerOrderStatus.done);
    expect(all.completedRevision, all.revision);
    expect(all.completedAt, isNotNull);
    final undo = await _serverStep(repository, all, 'first', false);
    expect(undo.status, ServerOrderStatus.received);
    expect(undo.completedAt, isNull);
    expect(undo.completedRevision, 0);
    expect(undo.lines.map((line) => line.deliveredQuantity), [0, 0, 1, 1]);
    await repository.receiveServerOrder(
      _serverEnvelope(2),
      receivedAt: DateTime.now(),
    );
    await expectLater(
      _serverStep(repository, undo, 'first', true),
      throwsA(isA<OrderStorageException>()),
    );
    final revision = (await repository.loadServerOrders()).single;
    expect(revision.lines.last.deliveredQuantity, 0);
    final ordinary = await repository.receiveServerOrder(
      OrderDeliveryEnvelope.create(
        clientInstallationId: 'client',
        deliveryId: 'ordinary',
        ticketId: 'ordinary',
        ticketNumber: 2,
        createdAt: DateTime.now(),
        heading: '',
        reference: '',
        orderNote: '',
        lines: const [DeliveryLine(name: 'Soup', quantity: 1)],
      ),
      receivedAt: DateTime.now(),
    );
    await expectLater(
      _serverStep(repository, ordinary.order, null, true),
      throwsA(isA<OrderStorageException>()),
    );
    await repository.deleteCompletedServerOrder(
      (await repository.markServerOrderDone(
        revision.id,
        completedAt: DateTime.now(),
      )).id,
    );
    await expectLater(
      _serverStep(repository, revision, 'first', true),
      throwsA(isA<OrderStorageException>()),
    );
  });

  test('Server whole-step completion and reopening reach both Clients without exposing private items', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    await f.syncBoth();
    final addition = await f.a.add('Tea', divider: true);
    await f.a.delivery.ticketReady(addition.id);
    await f.syncBoth();
    final original = (await f.server.loadServerOrders()).single;
    final completed = await _serverStep(f.server, original, null, true);
    expect(completed.status, ServerOrderStatus.received);
    await f.syncBoth();
    for (final client in [f.a, f.b]) {
      expect(client.order.deliveredQuantity('soup'), 3);
      expect(client.order.deliveredQuantity('water'), 2);
    }
    expect(f.a.order.deliveredQuantity('private'), 0);
    expect(summariseOutstandingItems([completed]).single.name, 'Tea');
    final tea = completed.lines.singleWhere((line) => line.name == 'Tea');
    final all = await _serverStep(f.server, completed, tea.courseId, true);
    expect(all.status, ServerOrderStatus.done);
    await f.syncBoth();
    expect(f.b.order.outstandingCount, 0);
    final undo = await _serverStep(f.server, all, null, false);
    expect(undo.status, ServerOrderStatus.received);
    await f.syncBoth();
    for (final client in [f.a, f.b]) {
      expect(client.order.deliveredQuantity('soup'), 0);
      expect(client.order.deliveredQuantity('water'), 0);
      expect(client.order.deliveredQuantity(tea.id!), 1);
    }
    expect(summariseOutstandingItems([undo]).map((line) => line.name), [
      'Soup',
      'Water',
    ]);
    await f.b.local('water', 1);
    await f.b.sync.synchronise();
    await expectLater(
      _serverStep(f.server, undo, null, true),
      throwsA(isA<OrderStorageException>()),
    );
    expect(
      (await f.server.loadServerOrders()).single.lines
          .firstWhere((line) => line.id == 'water')
          .deliveredQuantity,
      1,
    );
  });

  for (final (language, size, scale) in [
    ('en', const Size(1100, 900), 1.0),
    ('it', const Size(320, 740), 2.0),
    ('en', const Size(915, 412), 1.0),
  ]) {
    testWidgets(
      'Client toggle simplifies step delivery and restores individual controls $language $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final env = await createMemoryOrderEnvironment();
        addTearDown(env.repository.close);
        addTearDown(env.controller.dispose);
        await env.controller.updateFeatureSettings(
          const OrderFeatureSettings(
            managedOrdersEnabled: true,
            courseGroupsEnabled: true,
          ),
        );
        await _seed(env.repository, draft: env.controller.activeDraft);
        await env.controller.reloadAfterRestore();
        final store = MemorySettingsRepository()
          ..stored = AppSettings(language: language);
        final settings = SettingsController(store);
        await settings.load();
        addTearDown(settings.dispose);
        await tester.pumpWidget(
          LibreSlipApp(settings: settings, orders: env.controller),
        );
        await tester.pumpAndSettle();
        Future<void> tap(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        await tap(find.byKey(const ValueKey('nav-4')));
        final toggle = find.byKey(const ValueKey('toggle-whole-steps'));
        await tester.scrollUntilVisible(
          toggle,
          250,
          scrollable: find.byType(Scrollable).last,
        );
        await tap(toggle);
        expect(store.stored!.completeWholeSteps, isTrue);
        await tap(find.byKey(const ValueKey('nav-2')));
        await tap(find.byKey(const ValueKey('active-orders')));
        final expansion = find.byType(ExpansionTile).last;
        await tap(expansion);
        expect(find.byKey(const ValueKey('deliver-one-soup')), findsNothing);
        expect(find.byKey(const ValueKey('undo-delivery-soup')), findsNothing);
        expect(find.byKey(const ValueKey('deliver-all-soup')), findsNothing);
        expect(
          find.byKey(const ValueKey('complete-step-first')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('complete-step-later')),
          findsOneWidget,
        );
        await tap(find.byKey(const ValueKey('complete-step-first')));
        expect(env.controller.managedOrders.single.deliveredQuantities, {
          'soup': 3,
          'bread': 2,
        });
        await tap(find.byKey(const ValueKey('complete-step-first')));
        expect(
          env.controller.managedOrders.single.deliveredQuantities,
          isEmpty,
        );
        await tap(find.byKey(const ValueKey('complete-step-ungrouped')));
        expect(env.controller.managedOrders.single.deliveredQuantities, {
          'extra': 1,
        });
        await tap(find.text(language == 'it' ? 'Chiudi' : 'Close'));
        await tap(find.byKey(const ValueKey('nav-4')));
        await tester.scrollUntilVisible(
          toggle,
          250,
          scrollable: find.byType(Scrollable).last,
        );
        await tap(toggle);
        expect(store.stored!.completeWholeSteps, isFalse);
        await tap(find.byKey(const ValueKey('nav-2')));
        await tap(find.byKey(const ValueKey('active-orders')));
        await tap(find.byType(ExpansionTile).last);
        expect(find.byKey(const ValueKey('deliver-one-soup')), findsOneWidget);
        expect(find.byKey(const ValueKey('complete-step-first')), findsNothing);
        expect(env.controller.managedOrders.single.deliveredQuantities, {
          'extra': 1,
        });
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _step(
  SqliteOrderRepository repository,
  ManagedOrder order,
  String? courseId,
  bool delivered,
) => repository.setManagedStepDelivered(
  order.id,
  courseId,
  delivered,
  expectedOrderRevision: order.revision,
  expectedDeliveryRevision: order.deliveryEditRevision,
  expectedQuantities: {
    for (final line in order.lines.where((line) => line.courseId == courseId))
      line.id: order.deliveredQuantity(line.id),
  },
);

Future<SavedTicket> _seed(
  SqliteOrderRepository repository, {
  OrderDraft? draft,
}) async => repository.convertDraftToTicket(
  (draft ?? await repository.createDraft()).copyWith(
    reference: 'Table 4',
    courses: const [
      OrderCourse(id: 'first', name: 'First'),
      OrderCourse(id: 'empty', name: 'Empty'),
      OrderCourse(id: 'later', name: 'Later'),
    ],
    lines: const [
      TicketLine(
        id: 'soup',
        name: 'Soup',
        quantity: 3,
        courseId: 'first',
        preparationNote: 'No onion',
      ),
      TicketLine(id: 'bread', name: 'Bread', quantity: 2, courseId: 'first'),
      TicketLine(id: 'water', name: 'Water', quantity: 2, courseId: 'later'),
      TicketLine(id: 'extra', name: 'Extra', quantity: 1),
    ],
  ),
  heading: 'Kitchen',
  keepOpen: true,
);

Future<ServerOrder> _serverStep(
  SqliteOrderRepository repository,
  ServerOrder order,
  String? courseId,
  bool delivered,
) => repository.setServerStepDelivered(
  order.id,
  courseId,
  delivered,
  expectedOrderRevision: order.revision,
  expectedProgressRevision: order.progressRevision,
);

OrderDeliveryEnvelope _serverEnvelope(int revision) =>
    OrderDeliveryEnvelope.create(
      clientInstallationId: 'client',
      deliveryId: 'step-$revision',
      ticketId: 'ticket-$revision',
      managedOrderId: 'order',
      revision: revision,
      ticketNumber: 1,
      createdAt: DateTime.utc(2026, 10, 8),
      heading: 'Kitchen',
      reference: 'Table 4',
      orderNote: '',
      courses: const [
        OrderCourse(id: 'first', name: 'First'),
        OrderCourse(id: 'empty', name: 'Empty'),
        OrderCourse(id: 'later', name: 'Later'),
      ],
      lines: [
        const DeliveryLine(
          id: 'soup',
          name: 'Soup',
          quantity: 2,
          courseId: 'first',
        ),
        const DeliveryLine(
          id: 'bread',
          name: 'Bread',
          quantity: 3,
          courseId: 'first',
        ),
        const DeliveryLine(
          id: 'water',
          name: 'Water',
          quantity: 1,
          courseId: 'later',
        ),
        const DeliveryLine(id: 'extra', name: 'Extra', quantity: 1),
        if (revision > 1)
          const DeliveryLine(
            id: 'new-bread',
            name: 'Bread',
            quantity: 1,
            courseId: 'first',
          ),
      ],
    );
