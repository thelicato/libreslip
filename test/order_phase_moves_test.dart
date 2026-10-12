import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/networking/domain/client_transport.dart';
import 'package:libreslip/features/networking/domain/shared_orders.dart';
import 'package:libreslip/features/networking/domain/server_inbox_models.dart';
import 'package:libreslip/features/portability/application/portability_service.dart';
import 'package:libreslip/features/portability/domain/portability_models.dart';

import 'test_support.dart';

import 'package:libreslip/features/orders/application/order_workspace_controller.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'shared_orders_test.dart' show SharedFixture;

final phases = [
  OrderCourse.divider(id: 'one', ordinal: 1),
  OrderCourse.divider(id: 'two', ordinal: 2),
];

Future<void> idle(SharedFixture f) async {
  while (f.a.sync.busy || f.b.sync.busy) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  test('phase commands validate destinations and stale whole-step actions cannot change moved items', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed(courses: phases);
    await f.syncBoth();
    final before = (await f.server.loadServerOrders()).single;
    final actor = f.a.mode.configuration!.installationId;
    final command = OrderPhaseChange(
      orderId: before.id,
      lineId: 'soup',
      courseId: phases.last.id,
      course: phases.last,
      expectedRevision: before.revision,
    );
    expect(
      OrderPhaseChange.fromJson(command.toJson()).course!.id,
      phases.last.id,
    );
    for (final invalid in [
      {...command.toJson(), 'expectedRevision': 0},
      {...command.toJson(), 'lineId': 'invalid/id'},
      {...command.toJson(), 'courseId': phases.first.id},
      {...command.toJson(), 'extra': true},
    ]) {
      expect(() => OrderPhaseChange.fromJson(invalid), throwsFormatException);
    }
    await expectLater(
      f.server.moveSharedLine(
        actor,
        OrderPhaseChange(
          orderId: before.id,
          lineId: 'soup',
          courseId: 'absent',
          expectedRevision: before.revision,
        ),
      ),
      throwsFormatException,
    );
    expect(
      (await f.server.loadServerOrders()).single.revision,
      before.revision,
    );
    await f.server.moveSharedLine(actor, command);
    await expectLater(
      f.server.setServerStepDelivered(
        before.id,
        null,
        true,
        expectedOrderRevision: before.revision,
        expectedProgressRevision: before.progressRevision,
      ),
      throwsA(isA<OrderStorageException>()),
    );
    expect(
      (await f.server.loadServerOrders()).single.lines.first.deliveredQuantity,
      0,
    );
  });

  test('saved local items move into a new phase and rebase the same composition without rewriting tickets', () async {
    final repository = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    );
    final workspace = OrderWorkspaceController(repository);
    await workspace.load();
    addTearDown(workspace.dispose);
    addTearDown(repository.close);
    await workspace.updateFeatureSettings(
      const OrderFeatureSettings(
        managedOrdersEnabled: true,
        courseGroupsEnabled: true,
      ),
    );
    await workspace.saveItem(name: 'Soup');
    workspace.addCatalogueItem(workspace.items.single);
    final ticket = (await workspace.saveActiveTicket(heading: 'Kitchen'))!;
    await workspace.beginAddition(workspace.managedOrders.single.id);
    expect(workspace.addDivider(), isTrue);
    final phase = workspace.activeDraft!.courses.last.id;
    expect(
      await workspace.moveSavedLine(
        workspace.editingOrder!.id,
        ticket.lines.single.id,
        phase,
        expectedRevision: 1,
      ),
      isTrue,
    );
    expect(workspace.editingOrder!.lines.single.courseId, phase);
    expect(
      workspace.activeDraft!.baseRevision,
      workspace.editingOrder!.revision,
    );
    expect(workspace.tickets.single.lines.single.courseId, isNull);
    workspace.addCatalogueItemInCourse(workspace.items.single, null);
    expect(workspace.activeDraft!.lines.single.courseId, isNull);
    final snapshot = await repository.createPortableSnapshot();
    await repository.replaceWithPortableSnapshot(snapshot);
    expect((await repository.loadDrafts()).single.courses.single.id, phase);
    expect(
      (await repository.loadManagedOrders()).single.lines.single.courseId,
      phase,
    );
  });

  test('publishing a new phase preserves preceding pending phases and other Clients receive the same structure', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed(courses: [phases.first]);
    await f.syncBoth();
    await f.a.workspace.beginAddition(f.a.order.id);
    await f.a.workspace.saveItem(name: 'Coffee');
    final coffee = f.a.workspace.items.firstWhere(
      (item) => item.name == 'Coffee',
    );
    expect(f.a.workspace.addDivider(), isTrue);
    final firstNew = f.a.workspace.activeDraft!.courses.last.id;
    f.a.workspace.addCatalogueItemInCourse(coffee, firstNew);
    expect(f.a.workspace.addDivider(), isTrue);
    final secondNew = f.a.workspace.activeDraft!.courses.last.id;
    final inventory = f.a.workspace.activeDraft!.courses
        .map((c) => c.id)
        .toList();
    await f.a.sync.moveLine(f.a.order, 'soup', secondNew);
    await idle(f);
    await f.syncBoth();
    expect(f.a.order.courses.map((c) => c.id), inventory);
    expect(f.b.order.courses.map((c) => c.id), inventory);
    expect(f.b.order.lines.first.courseId, secondNew);
    expect(f.b.order.lines.any((line) => line.name == 'Coffee'), isFalse);
    expect(f.a.workspace.activeDraft!.lines.single.courseId, firstNew);
    expect(f.a.workspace.activeDraft!.baseRevision, f.a.order.revision);
    expect(f.a.workspace.tickets.single.lines.first.courseId, isNull);
    final ticket = (await f.a.workspace.saveActiveTicket(
      heading: 'Kitchen',
      requirePrintForDelivery: false,
    ))!;
    await f.a.delivery.ticketReady(ticket.id);
    await f.syncBoth();
    expect(f.b.order.lines.last.courseId, firstNew);
    expect(f.b.order.lines.first.courseId, secondNew);
  });

  test('schema 17 upgrades without rewriting history; offline saved moves and selected additions recover', () async {
    final dir = await Directory.systemTemp.createTemp('libreslip-phase-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/orders.db';
    var repository = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: path,
    );
    var workspace = OrderWorkspaceController(repository);
    await workspace.load();
    await workspace.updateFeatureSettings(
      const OrderFeatureSettings(
        managedOrdersEnabled: true,
        courseGroupsEnabled: true,
      ),
    );
    final ticket = await repository.convertDraftToTicket(
      workspace.activeDraft!.copyWith(
        courses: phases,
        lines: [
          const TicketLine(
            id: 'soup',
            name: 'Soup',
            quantity: 3,
            preparationNote: 'No salt',
            price: ProductPrice(minorUnits: 650, currency: 'EUR'),
          ),
          TicketLine(
            id: 'water',
            name: 'Water',
            quantity: 2,
            courseId: phases.first.id,
          ),
        ],
      ),
      heading: 'Kitchen',
      keepOpen: true,
    );
    final job = await repository.createPrintJob(
      requestId: 'phase-job',
      ticketId: ticket.id,
      payload: Uint8List.fromList([27, 64, 83]),
    );
    workspace.dispose();
    await repository.close();
    final legacy = await databaseFactoryFfiNoIsolate.openDatabase(path);
    await legacy.setVersion(17);
    await legacy.close();
    repository = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: path,
    );
    workspace = OrderWorkspaceController(repository);
    await workspace.load();
    expect(workspace.tickets.single.lines.first.courseId, isNull);
    final order = workspace.managedOrders.single;
    await workspace.setLineDelivered(order.id, 'soup', 1, expectedQuantity: 0);
    await workspace.beginAddition(order.id);
    workspace.selectCourse(phases.first.id);
    await workspace.saveItem(name: 'Tea');
    workspace.addCatalogueItem(workspace.items.single);
    await workspace.flushWrites();
    final unsaved = workspace.activeDraft!.lines.single;
    expect(
      await workspace.moveSavedLine(
        order.id,
        'soup',
        phases.last.id,
        expectedRevision: order.revision,
      ),
      isTrue,
    );
    expect(workspace.activeDraft!.baseRevision, 2);
    expect(workspace.activeDraft!.activeCourseId, phases.first.id);
    expect(workspace.activeDraft!.lines.single.id, unsaved.id);
    final moved = workspace.managedOrders.single.lines.first;
    expect(moved.id, 'soup');
    expect(moved.courseId, phases.last.id);
    expect(moved.price, const ProductPrice(minorUnits: 650, currency: 'EUR'));
    expect(moved.preparationNote, 'No salt');
    expect(workspace.managedOrders.single.deliveredQuantity('soup'), 1);
    expect(
      await workspace.moveSavedLine(
        order.id,
        'soup',
        null,
        expectedRevision: 1,
      ),
      isFalse,
    );
    expect(
      await workspace.moveSavedLine(
        order.id,
        'soup',
        'absent',
        expectedRevision: 2,
      ),
      isFalse,
    );
    expect((await repository.loadPrintJobs()).single.payload, job.payload);
    expect(
      (await repository.loadTickets()).single.lines.first.courseId,
      isNull,
    );
    workspace.dispose();
    await repository.close();
    repository = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: path,
    );
    workspace = OrderWorkspaceController(repository);
    await workspace.load();
    addTearDown(workspace.dispose);
    addTearDown(repository.close);
    expect(workspace.managedOrders.single.lines.first.courseId, phases.last.id);
    expect(workspace.activeDraft!.activeCourseId, phases.first.id);
    final addition = await workspace.saveActiveTicket(heading: 'Kitchen');
    expect(addition!.printLines.single.id, unsaved.id);
    expect(addition.printLines.single.courseId, phases.first.id);
    expect(
      workspace.tickets
          .firstWhere((t) => t.id == ticket.id)
          .lines
          .first
          .courseId,
      isNull,
    );

    final snapshot = await repository.createPortableSnapshot();
    expect(snapshot['schemaVersion'], 18);
    final fresh = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: '${dir.path}/fresh.db',
    );
    await fresh.open();
    addTearDown(fresh.close);
    final service = PortabilityService(
      repository,
      MemorySettingsRepository(),
      supportDirectory: () async =>
          Directory('${dir.path}/support')..createSync(),
      temporaryDirectory: () async => dir,
      appVersion: () => File('VERSION').readAsString(),
    );
    final archive = await service.createArchive(PortableArchiveKind.fullBackup);
    final freshService = PortabilityService(
      fresh,
      MemorySettingsRepository(),
      supportDirectory: () async =>
          Directory('${dir.path}/fresh-support')..createSync(),
      temporaryDirectory: () async => dir,
      appVersion: () => File('VERSION').readAsString(),
    );
    await freshService.restore(await freshService.inspectArchive(archive));
    expect(
      (await fresh.loadManagedOrders()).single.lines.first.courseId,
      phases.last.id,
    );
    expect(
      (await fresh.loadManagedOrders()).single.deliveredQuantity('soup'),
      1,
    );
    expect(
      (await fresh.loadTickets())
          .firstWhere((t) => t.id == ticket.id)
          .lines
          .first
          .courseId,
      isNull,
    );
    expect((await fresh.loadPrintJobs()).single.payload, job.payload);
    final tampered = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
    ((tampered['tables'] as Map)['ticket_lines'] as List).first['quantity'] =
        99;
    await expectLater(
      fresh.replaceWithPortableSnapshot(tampered),
      throwsA(isA<OrderStorageException>()),
    );
    expect((await fresh.loadManagedOrders()).single.lines.first.quantity, 3);
    final downgraded = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
    downgraded['schemaVersion'] = 17;
    await expectLater(
      fresh.replaceWithPortableSnapshot(downgraded),
      throwsA(isA<OrderStorageException>()),
    );
  });

  test('saved moves sync both Clients, retain private prices and rebase additions in the selected phase', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed(courses: phases);
    await f.syncBoth();
    await f.a.local('soup', 1);
    await f.syncBoth();
    await f.b.workspace.beginAddition(f.b.order.id);
    f.b.workspace.selectCourse(phases.first.id);
    await f.b.workspace.saveItem(name: 'Tea');
    f.b.workspace.addCatalogueItem(f.b.workspace.items.single);
    await f.b.workspace.flushWrites();
    final draftLine = f.b.workspace.activeDraft!.lines.single;
    final history = f.a.workspace.tickets.single;
    await f.a.sync.moveLine(f.a.order, 'soup', phases.last.id);
    await idle(f);
    await f.syncBoth();
    expect(f.b.order.lines.first.courseId, phases.last.id);
    expect(f.b.order.deliveredQuantity('soup'), 1);
    expect(f.a.order.lines.first.price, history.lines.first.price);
    expect(f.b.order.lines.first.price, isNull);
    expect(f.b.workspace.tickets, isEmpty);
    expect(f.a.workspace.tickets.single.lines.first.courseId, isNull);
    expect(f.b.workspace.activeDraft!.activeCourseId, phases.first.id);
    expect(f.b.workspace.activeDraft!.lines.single.id, draftLine.id);
    expect(f.b.workspace.activeDraft!.baseRevision, f.b.order.revision);
    final added = await f.b.workspace.saveActiveTicket(
      heading: 'Kitchen',
      requirePrintForDelivery: false,
    );
    expect(added!.printLines.single.courseId, phases.first.id);
    await f.b.delivery.ticketReady(added.id);
    await f.syncBoth();
    expect(f.a.order.lines.first.courseId, phases.last.id);
    expect(
      (await f.server.loadServerOrders()).single.lines.first.courseId,
      phases.last.id,
    );
    expect(
      (await f.server.loadServerOrders()).single.lines.last.courseId,
      phases.first.id,
    );
    final old = f.a.order.revision;
    expect(
      await f.a.workspace.moveSavedLine(
        f.a.order.id,
        'soup',
        null,
        expectedRevision: old,
      ),
      isFalse,
    );
    // Private items can move locally even while the Server is unavailable.
    f.transport.offline = true;
    expect(
      await f.a.workspace.moveSavedLine(
        f.a.order.id,
        'private',
        phases.first.id,
        expectedRevision: old,
      ),
      isTrue,
    );
    expect(
      f.a.order.lines.firstWhere((l) => l.id == 'private').courseId,
      phases.first.id,
    );
    expect(
      (await f.server.loadServerOrders()).single.lines.any(
        (l) => l.id == 'private',
      ),
      isFalse,
    );
  });

  test('a frozen addition appends after a concurrent phase move without restoring old placement', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed(courses: phases);
    await f.syncBoth();
    final ticket = await f.b.add('Coffee');
    expect(ticket.lines.first.courseId, isNull);
    await expectLater(
      f.b.sync.moveLine(f.b.order, 'soup', phases.first.id),
      throwsA(
        isA<ClientTransportException>().having(
          (e) => e.code,
          'code',
          'phase_move_pending',
        ),
      ),
    );
    await idle(f);
    expect(f.transport.phaseWrites, 0);
    await f.a.sync.moveLine(f.a.order, 'soup', phases.last.id);
    await idle(f);
    await f.b.delivery.ticketReady(ticket.id);
    await f.syncBoth();
    expect(f.b.order.lines.first.courseId, phases.last.id);
    final server = (await f.server.loadServerOrders()).single;
    expect(server.lines.first.courseId, phases.last.id);
    expect(server.lines.where((l) => l.name == 'Coffee'), hasLength(1));
    expect(f.b.workspace.tickets.single.lines.first.courseId, isNull);
  });

  test('lost move acknowledgement recovers; duplicate retry and stale concurrent edits cannot overwrite newer placements', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed(courses: phases);
    await f.syncBoth();
    final initial = (await f.server.loadServerOrders()).single;
    final actor = f.a.mode.configuration!.installationId;
    final first = OrderPhaseChange(
      orderId: initial.id,
      lineId: 'soup',
      courseId: phases.last.id,
      expectedRevision: initial.revision,
      course: phases.last,
    );
    f.transport.losePhaseAck = true;
    await expectLater(
      f.a.sync.moveLine(f.a.order, 'soup', phases.last.id),
      throwsA(isA<ClientTransportException>()),
    );
    await idle(f);
    expect(f.a.order.lines.first.courseId, isNull);
    expect(
      (await f.server.loadServerOrders()).single.lines.first.courseId,
      phases.last.id,
    );
    final retried = await f.server.moveSharedLine(actor, first);
    expect(retried.envelope.revision, initial.revision + 1);
    await f.server.moveSharedLine(
      actor,
      OrderPhaseChange(
        orderId: initial.id,
        lineId: 'soup',
        courseId: phases.first.id,
        expectedRevision: retried.envelope.revision,
      ),
    );
    await expectLater(
      f.server.moveSharedLine(actor, first),
      throwsA(isA<ServerOrderConflictException>()),
    );
    f.transport.offline = false;
    await f.syncBoth();
    expect(f.a.order.lines.first.courseId, phases.first.id);
    expect(f.b.order.lines.first.courseId, phases.first.id);
    expect(f.a.workspace.tickets, hasLength(1));
    expect(await f.a.repository.loadPrintJobs(), isEmpty);
  });

  test('offline and unsupported Servers keep the confirmed placement; stale snapshots fail without overwriting', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed(courses: phases);
    await f.syncBoth();
    f.transport.offline = true;
    await expectLater(
      f.a.sync.moveLine(f.a.order, 'soup', phases.last.id),
      throwsA(isA<ClientTransportException>()),
    );
    await idle(f);
    expect(f.a.order.lines.first.courseId, isNull);
    f.transport.offline = false;
    f.transport.supportsPhaseMoves = false;
    await expectLater(
      f.a.sync.moveLine(f.a.order, 'soup', phases.last.id),
      throwsA(
        isA<ClientTransportException>().having(
          (e) => e.code,
          'code',
          'unsupported_phase_moves',
        ),
      ),
    );
    await idle(f);
    expect(f.transport.phaseWrites, 0);
    final link = (await f.a.repository.loadSharedLink(f.a.order.id))!;
    final json =
        jsonDecode(jsonEncode(link.baseline.toJson())) as Map<String, dynamic>;
    // A genuine older snapshot must be rejected after a successful new move.
    f.transport.supportsPhaseMoves = true;
    await f.a.sync.moveLine(f.a.order, 'soup', phases.last.id);
    await idle(f);
    await expectLater(
      f.a.repository.mergeSharedOrder(
        f.a.order.destinationId!,
        SharedOrderSnapshot.fromJson(json),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      (await f.a.repository.loadManagedOrders()).single.lines.first.courseId,
      phases.last.id,
    );
  });
}
