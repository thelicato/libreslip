import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
import 'package:libreslip/features/networking/domain/client_delivery_models.dart';
import 'package:libreslip/features/networking/domain/network_protocol.dart';
import 'package:libreslip/features/networking/domain/server_inbox_models.dart';
import 'package:libreslip/features/orders/application/order_workspace_controller.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:libreslip/features/printing/domain/print_job.dart';
import 'package:libreslip/features/printing/domain/ticket_document.dart';
import 'package:libreslip/features/printing/application/esc_pos_ticket_encoder.dart';
import 'package:libreslip/features/settings/application/settings_controller.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';
import 'package:libreslip/features/workspace/application/ticket_statistics.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  test(
    'schema 11 migration preserves grouped history and disables active orders',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'libreslip-managed-migrate-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/orders.db';
      final repository = _repository(path);
      await repository.open();
      final draft = await repository.createDraft();
      final ticket = await repository.convertDraftToTicket(
        draft.copyWith(
          courses: _courses,
          lines: const [
            TicketLine(
              id: 'soup',
              name: 'Soup',
              quantity: 2,
              courseId: 'first',
            ),
          ],
        ),
        heading: 'Kitchen',
      );
      final job = await repository.createPrintJob(
        requestId: 'old-job',
        ticketId: ticket.id,
        payload: Uint8List.fromList([27, 64, 65]),
      );
      await repository.close();
      final old = await databaseFactoryFfiNoIsolate.openDatabase(path);
      await removeManagedColumnsForLegacyFixture(old);
      await old.setVersion(11);
      await old.close();
      final migrated = _repository(path);
      await migrated.open();
      addTearDown(migrated.close);
      expect((await migrated.loadTickets()).single.id, ticket.id);
      expect(
        (await migrated.loadTickets()).single.courses.single.name,
        'First',
      );
      expect((await migrated.loadPrintJobs()).single.payload, job.payload);
      expect(
        (await migrated.loadFeatureSettings()).managedOrdersEnabled,
        isFalse,
      );
      expect(await migrated.loadManagedOrders(), isEmpty);
    },
  );

  test('additions survive restart; revisions stay immutable, numbered and independent of history', () async {
    final directory = await Directory.systemTemp.createTemp(
      'libreslip-managed-recovery-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/orders.db';
    var repository = _repository(path);
    var controller = OrderWorkspaceController(repository);
    await controller.load();
    await controller.updateFeatureSettings(
      const OrderFeatureSettings(
        managedOrdersEnabled: true,
        courseGroupsEnabled: true,
      ),
    );
    await controller.saveItem(name: 'Soup');
    controller.saveCourse('First');
    controller.setReference('Table 4');
    controller.addCatalogueItem(controller.items.single);
    controller.setPreparationNote(
      controller.activeDraft!.lines.single.id,
      'No salt',
    );
    final first = (await controller.saveActiveTicket(heading: 'Kitchen'))!;
    final order = controller.managedOrders.single;
    expect(first.revision, 1);
    expect(first.managedOrderId, order.id);
    await controller.saveItem(
      existing: controller.items.single,
      name: 'Renamed soup',
    );
    expect(await controller.beginAddition(order.id), isTrue);
    controller.addCatalogueItem(controller.items.single);
    controller.setPreparationNote(
      controller.activeDraft!.lines.single.id,
      'Extra salt',
    );
    await controller.flushWrites();
    await repository.close();
    repository = _repository(path);
    controller = OrderWorkspaceController(repository);
    await controller.load();
    addTearDown(repository.close);
    expect(controller.editingOrder!.lines.single.name, 'Soup');
    expect(controller.activeDraft!.lines.single.name, 'Renamed soup');
    expect(controller.activeDraft!.baseRevision, 1);
    expect(
      controller.saveCourse('Rename', id: order.courses.single.id),
      isFalse,
    );
    controller.setReference('Ignored');
    expect(controller.activeDraft!.reference, 'Table 4');
    await controller.updateFeatureSettings(
      const OrderFeatureSettings(
        managedOrdersEnabled: false,
        preparationNotesEnabled: true,
        orderReferenceEnabled: false,
      ),
    );
    final second = (await controller.saveActiveTicket(
      heading: 'Changed heading',
    ))!;
    expect(second.number, first.number);
    expect(second.heading, 'Kitchen');
    expect(second.reference, 'Table 4');
    expect(second.revision, 2);
    expect(second.lines.map((line) => line.name), ['Soup', 'Renamed soup']);
    expect(second.lines.map((line) => line.preparationNote), [
      'No salt',
      'Extra salt',
    ]);
    expect(second.lines.first.id, first.lines.single.id);
    expect(second.printLines.single.name, 'Renamed soup');
    expect(controller.nextOrderNumber, 2);
    final statistics = TicketStatistics.calculate(controller.tickets);
    expect(statistics.ticketCount, 2);
    expect(statistics.itemQuantity, 2);
    final doc = _document(second);
    final bytes = await EscPosTicketEncoder().encode(doc);
    final encoded = latin1.decode(bytes);
    expect(encoded, contains('Additions'));
    expect(encoded, contains('Renamed soup'));
    expect(encoded, isNot(contains('No salt')));
    final job = await repository.createPrintJob(
      requestId: 'additions-print',
      ticketId: second.id,
      payload: bytes,
    );
    await repository.markPrintJobSending(
      job.id,
      printerAddress: '00:11',
      printerName: 'Test',
    );
    await repository.close();
    await repository.open();
    expect(
      (await repository.loadPrintJobs()).single.status,
      PrintJobStatus.uncertain,
    );
    expect((await repository.loadPrintJobs()).single.payload, bytes);
    await controller.deleteAllTickets();
    expect(await repository.loadTickets(), isEmpty);
    expect((await repository.loadManagedOrders()).single.lines.length, 2);
    expect(await controller.beginAddition(order.id), isTrue);
    expect(await controller.closeOrder(order.id), isFalse);
    expect(await controller.cancelAddition(), isTrue);
    expect(await controller.closeOrder(order.id), isTrue);
    expect(
      ((await repository.createPortableSnapshot())['tables']
          as Map)['managed_orders'],
      isEmpty,
    );
    controller.addCatalogueItem(controller.items.single);
    expect(
      (await controller.saveActiveTicket(heading: 'Kitchen'))!.managedOrderId,
      isNull,
    );
  });

  test('finalisation is idempotent; stale, edited or closed additions fail atomically', () async {
    final environment = await createMemoryOrderEnvironment();
    final repository = environment.repository;
    addTearDown(repository.close);
    final blank = environment.controller.activeDraft!;
    final first = await repository.convertDraftToTicket(
      blank.copyWith(
        courses: _courses,
        reference: 'Table 1',
        lines: const [
          TicketLine(
            id: 'first-line',
            name: 'Soup',
            quantity: 1,
            courseId: 'first',
          ),
        ],
      ),
      heading: 'Kitchen',
      keepOpen: true,
    );
    final order = (await repository.loadManagedOrders()).single;
    final next = await repository.createDraft();
    final addition = await repository.beginOrderAddition(order.id, next.id);
    final ready = addition.copyWith(
      lines: const [TicketLine(id: 'drink-line', name: 'Water', quantity: 2)],
    );
    await expectLater(
      repository.convertDraftToTicket(
        ready.copyWith(reference: 'Different'),
        heading: 'Kitchen',
      ),
      throwsA(isA<OrderStorageException>()),
    );
    final saved = await repository.convertDraftToTicket(
      ready,
      heading: 'Kitchen',
    );
    final again = await repository.convertDraftToTicket(
      ready,
      heading: 'Kitchen',
    );
    expect(again.id, saved.id);
    expect((await repository.loadManagedOrders()).single.revision, 2);
    final stale = OrderDraft(
      id: 'stale-addition',
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      managedOrderId: order.id,
      baseRevision: 1,
      reference: 'Table 1',
      courses: _courses,
      lines: const [TicketLine(id: 'late', name: 'Tea', quantity: 1)],
    );
    await expectLater(
      repository.convertDraftToTicket(stale, heading: 'Kitchen'),
      throwsA(isA<OrderStorageException>()),
    );
    expect((await repository.loadTickets()).length, 2);
    expect(first.lines.single.quantity, 1);
    await repository.closeManagedOrder(order.id);
    await expectLater(
      repository.convertDraftToTicket(stale, heading: 'Kitchen'),
      throwsA(isA<OrderStorageException>()),
    );
  });

  test('managed envelopes validate identifiers, checksums and revisions while v1/v2 stay available', () {
    final first = _envelope(1, const [
      DeliveryLine(id: 'soup', name: 'Soup', quantity: 1),
    ]);
    expect(first.version, 3);
    expect(
      OrderDeliveryEnvelope.fromJsonString(first.toJsonString()).managedOrderId,
      'managed-order',
    );
    expect(
      OrderDeliveryEnvelope.fromJsonString(first.toJsonString())
          .lines
          .single
          .id,
      'soup',
    );
    final changed = first.toJson();
    (changed['ticket'] as Map)['revision'] = 2;
    expect(
      () => OrderDeliveryEnvelope.fromJsonString(jsonEncode(changed)),
      throwsFormatException,
    );
    expect(
      () => _envelope(0, const [
        DeliveryLine(id: 'soup', name: 'Soup', quantity: 1),
      ]),
      throwsFormatException,
    );
    expect(
      () => _envelope(1, const [DeliveryLine(name: 'Soup', quantity: 1)]),
      throwsFormatException,
    );
    expect(
      () => _envelope(1, const [
        DeliveryLine(id: 'same', name: 'Soup', quantity: 1),
        DeliveryLine(id: 'same', name: 'Water', quantity: 1),
      ]),
      throwsFormatException,
    );
  });

  test('Server keeps one order, rejects conflicts and stale revisions, deduplicates old acknowledgements and prevents resurrection', () async {
    final environment = await createMemoryOrderEnvironment();
    final repository = environment.repository;
    addTearDown(repository.close);
    final now = DateTime.utc(2026, 10, 5);
    await repository.pairClient(
      PairedClient(
        installationId: 'client',
        displayName: 'Client',
        identityFingerprint: 'a' * 64,
        pairedAt: now,
      ),
    );
    final first = _envelope(1, const [
      DeliveryLine(id: 'soup', name: 'Soup', quantity: 1),
    ]);
    final second = _envelope(2, const [
      DeliveryLine(id: 'soup', name: 'Soup', quantity: 1),
      DeliveryLine(id: 'water', name: 'Water', quantity: 2),
    ]);
    final initial = await repository.receiveServerOrder(first, receivedAt: now);
    await repository.markServerOrderDone(initial.order.id, completedAt: now);
    final skipped = _envelope(3, second.lines);
    await expectLater(
      repository.receiveServerOrder(skipped, receivedAt: now),
      throwsA(isA<ServerOrderConflictException>()),
    );
    final revised = await repository.receiveServerOrder(
      second,
      receivedAt: now,
    );
    expect(revised.order.id, initial.order.id);
    expect(revised.order.status, ServerOrderStatus.received);
    expect(revised.order.revision, 2);
    expect(revised.order.lines.map((line) => line.addedRevision), [1, 2]);
    expect(revised.order.completedRevision, 1);
    expect(summariseOutstandingItems([revised.order]).single.name, 'Water');
    expect(summariseOutstandingItems([revised.order]).single.quantity, 2);
    expect((await repository.loadServerOrders()).length, 1);
    final conflict = _envelope(3, const [
      DeliveryLine(id: 'soup', name: 'Changed', quantity: 1),
      DeliveryLine(id: 'water', name: 'Water', quantity: 2),
      DeliveryLine(id: 'tea', name: 'Tea', quantity: 1),
    ]);
    await expectLater(
      repository.receiveServerOrder(conflict, receivedAt: now),
      throwsA(isA<ServerOrderConflictException>()),
    );
    await repository.markServerOrderDone(initial.order.id, completedAt: now);
    final duplicate = await repository.receiveServerOrder(
      first,
      receivedAt: now,
    );
    expect(duplicate.wasDuplicate, isTrue);
    expect(duplicate.order.status, ServerOrderStatus.done);
    expect(duplicate.order.revision, 2);
    await repository.deleteCompletedServerOrder(initial.order.id);
    await expectLater(
      repository.receiveServerOrder(second, receivedAt: now),
      throwsA(isA<ServerOrderConflictException>()),
    );
    await expectLater(
      repository.receiveServerOrder(
        _envelope(3, [
          ...second.lines,
          const DeliveryLine(id: 'tea', name: 'Tea', quantity: 1),
        ]),
        receivedAt: now,
      ),
      throwsA(isA<ServerOrderConflictException>()),
    );
    expect(await repository.loadServerOrders(), isEmpty);
  });

  test('restore validates managed relationships and preserves interrupted additions and history independence', () async {
    final environment = await createMemoryOrderEnvironment();
    final controller = environment.controller;
    final repository = environment.repository;
    addTearDown(repository.close);
    await controller.updateFeatureSettings(
      const OrderFeatureSettings(managedOrdersEnabled: true),
    );
    await controller.saveItem(name: 'Tea');
    controller.addCatalogueItem(controller.items.single);
    await controller.saveActiveTicket(heading: 'Kitchen');
    final order = controller.managedOrders.single;
    await controller.beginAddition(order.id);
    controller.addCatalogueItem(controller.items.single);
    await controller.flushWrites();
    final snapshot = await repository.createPortableSnapshot();
    await repository.replaceWithPortableSnapshot(snapshot);
    expect((await repository.loadDrafts()).single.managedOrderId, order.id);
    expect(
      (await repository.loadManagedOrders()).single.lines.single.name,
      'Tea',
    );
    final invalid = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
    ((invalid['tables'] as Map)['drafts'] as List).single['base_revision'] = 99;
    await expectLater(
      repository.replaceWithPortableSnapshot(invalid),
      throwsA(isA<OrderStorageException>()),
    );
    expect((await repository.loadDrafts()).single.baseRevision, 1);
    final invalidLine =
        jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
    ((invalidLine['tables'] as Map)['tickets'] as List)
            .single['addition_line_ids'] =
        '["missing-line"]';
    await expectLater(
      repository.replaceWithPortableSnapshot(invalidLine),
      throwsA(isA<OrderStorageException>()),
    );
    await controller.cancelAddition();
    await controller.deleteAllTickets();
    final independent = await repository.createPortableSnapshot();
    await repository.replaceWithPortableSnapshot(independent);
    expect((await repository.loadManagedOrders()).single.id, order.id);
  });

  test('outbox freezes routing and local-only flags, gates ordered revisions and protects pending history', () async {
    final environment = await createMemoryOrderEnvironment();
    final controller = environment.controller;
    final repository = environment.repository;
    addTearDown(repository.close);
    final now = DateTime.now().toUtc();
    await repository.savePairedServer(
      PairedServer(
        id: 'server',
        displayName: 'Kitchen',
        baseUrl: Uri.parse('https://127.0.0.1:5119'),
        certificateFingerprint: 'a' * 64,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await controller.updateFeatureSettings(
      const OrderFeatureSettings(managedOrdersEnabled: true),
    );
    await controller.saveItem(name: 'Soup');
    await controller.saveItem(name: 'Private copy', sendToServer: false);
    controller.addCatalogueItem(
      controller.items.firstWhere((item) => item.name == 'Soup'),
    );
    controller.addCatalogueItem(
      controller.items.firstWhere((item) => item.name == 'Private copy'),
    );
    final first = (await controller.saveActiveTicket(heading: 'Kitchen'))!;
    await controller.beginAddition(controller.managedOrders.single.id);
    await controller.saveItem(
      existing: controller.items.firstWhere((item) => item.name == 'Soup'),
      name: 'Soup',
      sendToServer: false,
    );
    await controller.saveItem(name: 'Water');
    controller.addCatalogueItem(
      controller.items.firstWhere((item) => item.name == 'Water'),
    );
    final second = (await controller.saveActiveTicket(heading: 'Kitchen'))!;
    final deliveries = await repository.loadClientDeliveries();
    final initial = deliveries.singleWhere(
      (delivery) => delivery.ticketId == first.id,
    );
    final addition = deliveries.singleWhere(
      (delivery) => delivery.ticketId == second.id,
    );
    expect(addition.envelope.lines.map((line) => line.name), ['Soup', 'Water']);
    expect(addition.envelope.revision, 2);
    await _transmit(repository, second.id);
    await expectLater(
      repository.markClientDeliverySending(addition.id),
      throwsA(isA<OrderStorageException>()),
    );
    await expectLater(
      repository.deleteTicket(first.id),
      throwsA(isA<OrderStorageException>()),
    );
    await _transmit(repository, first.id);
    await repository.markClientDeliverySending(initial.id);
    await repository.markClientDeliveryDelivered(
      initial.id,
      serverOrderId: 'received',
      deliveredAt: now,
    );
    expect(
      (await repository.markClientDeliverySending(addition.id)).status,
      ClientDeliveryStatus.sending,
    );
    await repository.markClientDeliveryDelivered(
      addition.id,
      serverOrderId: 'received',
      deliveredAt: now,
    );
    await repository.deleteAllTickets();
    expect((await repository.loadManagedOrders()).single.lines.length, 3);
  });

  for (final (language, compact, size, scale) in [
    ('en', false, const Size(1100, 900), 1.0),
    ('it', true, const Size(412, 915), 1.0),
    ('it', false, const Size(320, 740), 2.0),
    ('en', true, const Size(915, 412), 1.0),
  ]) {
    testWidgets(
      'active order controls and additions in $language compact $compact $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final environment = await createMemoryOrderEnvironment();
        final controller = environment.controller;
        addTearDown(environment.repository.close);
        await controller.updateFeatureSettings(
          const OrderFeatureSettings(managedOrdersEnabled: true),
        );
        await controller.saveItem(name: 'Soup');
        controller.setReference('Table 4');
        controller.addCatalogueItem(controller.items.single);
        await controller.saveActiveTicket(heading: 'Kitchen');
        final settings = SettingsController(
          MemorySettingsRepository()
            ..stored = AppSettings(
              language: language,
              compactCompose: compact,
              appTextScale: scale,
            ),
        );
        await settings.load();
        await tester.pumpWidget(
          LibreSlipApp(settings: settings, orders: controller),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('nav-2')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('active-orders')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('active-orders')));
        await tester.pumpAndSettle();
        final add = find.byKey(
          ValueKey('add-to-order-${controller.managedOrders.single.id}'),
        );
        await tester.ensureVisible(add);
        await tester.pumpAndSettle();
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(controller.editingOrder, isNotNull);
        controller.addCatalogueItem(controller.items.single);
        await tester.pumpAndSettle();
        expect(controller.activeDraft!.lines.single.quantity, 1);
        expect(controller.editingOrder!.lines.single.quantity, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

const _courses = [OrderCourse(id: 'first', name: 'First')];
SqliteOrderRepository _repository(String path) => SqliteOrderRepository(
  factory: databaseFactoryFfiNoIsolate,
  databasePath: path,
);
OrderDeliveryEnvelope _envelope(int revision, List<DeliveryLine> lines) =>
    OrderDeliveryEnvelope.create(
      clientInstallationId: 'client',
      deliveryId: 'delivery-$revision',
      ticketId: 'ticket-$revision',
      ticketNumber: 4,
      createdAt: DateTime.utc(2026, 10, 5),
      heading: 'Kitchen',
      reference: 'Table 4',
      orderNote: '',
      managedOrderId: 'managed-order',
      revision: revision,
      lines: lines,
    );
TicketDocument _document(SavedTicket ticket) => TicketDocument.fromTicket(
  ticket: ticket,
  fallbackHeading: 'Kitchen',
  ticketLabel: 'Order',
  createdAt: '5 October',
  referenceLabel: 'Table',
  orderNotesLabel: 'Notes',
  lineNotePrefix: 'Note',
  footer: '',
  revisionLabel: 'Additions · revision 2',
  ungroupedLabel: 'Ungrouped',
);
Future<void> _transmit(
  SqliteOrderRepository repository,
  String ticketId,
) async {
  final job = await repository.createPrintJob(
    requestId: 'print-$ticketId',
    ticketId: ticketId,
    payload: Uint8List.fromList([27, 64]),
  );
  await repository.markPrintJobSending(
    job.id,
    printerAddress: '00:11',
    printerName: 'Printer',
  );
  await repository.markPrintJobOutcome(
    job.id,
    status: PrintJobStatus.transmitted,
  );
}
