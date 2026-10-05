import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/orders/application/order_workspace_controller.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:libreslip/features/printing/domain/print_job.dart';
import 'package:libreslip/features/printing/domain/ticket_document.dart';
import 'package:libreslip/features/printing/application/esc_pos_ticket_encoder.dart';
import 'package:libreslip/features/networking/domain/client_delivery_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_support.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  const original = ProductPrice(minorUnits: 125, currency: 'EUR');
  const revised = ProductPrice(minorUnits: 250, currency: 'GBP');

  test('prices distinguish absent from zero and validate precision, currency and bounds', () {
    expect(ProductPrice.parse('', 'EUR'), isNull);
    expect(ProductPrice.parse('0', 'EUR')!.minorUnits, 0);
    expect(
      ProductPrice.parse('12,3', 'GBP'),
      const ProductPrice(minorUnits: 1230, currency: 'GBP'),
    );
    expect(ProductPrice.parse('999999.99', 'USD')!.minorUnits, 99999999);
    for (final input in [
      '-1',
      '1.234',
      '1,234',
      '1,000.00',
      '1e3',
      'NaN',
      '1000000',
      '€2',
      '.5',
    ]) {
      expect(() => ProductPrice.parse(input, 'EUR'), throwsFormatException);
    }
    for (final (amount, currency) in [
      (1.0, 'EUR'),
      (true, 'EUR'),
      (1, 'eur'),
      (1, 'JPY'),
      (null, 'EUR'),
      (0, null),
      (-1, 'EUR'),
      (100000000, 'USD'),
    ]) {
      expect(
        () => ProductPrice.fromColumns(amount, currency),
        throwsFormatException,
      );
    }
  });

  test('estimates use exact minor units, count missing quantities and keep currencies separate', () {
    final estimate = OrderPriceEstimate.fromLines(const [
      TicketLine(id: 'a', name: 'A', quantity: 3, price: original),
      TicketLine(id: 'b', name: 'B', quantity: 2, price: revised),
      TicketLine(id: 'c', name: 'C', quantity: 7),
      TicketLine(
        id: 'z',
        name: 'Zero',
        quantity: 2,
        price: ProductPrice(minorUnits: 0, currency: 'USD'),
      ),
    ]);
    expect(estimate.totals, {'EUR': 375, 'GBP': 500, 'USD': 0});
    expect(estimate.unpricedQuantity, 7);
    final maximum = OrderPriceEstimate.fromLines(
      List.generate(
        200,
        (i) => TicketLine(
          id: '$i',
          name: 'Maximum',
          quantity: 999,
          price: const ProductPrice(minorUnits: 99999999, currency: 'EUR'),
        ),
      ),
    );
    expect(maximum.totals['EUR'], 19979999800200);
  });

  test('disabled defaults, persistent composition and immutable prices survive catalogue edits and reopen', () async {
    final dir = await Directory.systemTemp.createTemp('libreslip-prices-');
    addTearDown(() => dir.delete(recursive: true));
    final repo = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: '${dir.path}/orders.db',
    );
    final workspace = OrderWorkspaceController(repo);
    await workspace.load();
    addTearDown(workspace.dispose);
    final item = await repo.saveItem(name: 'Soup', price: original);
    expect(workspace.featureSettings.pricesEnabled, isFalse);
    workspace.addCatalogueItem(item);
    expect(workspace.activeDraft!.lines.single.price, isNull);
    workspace.removeLine(workspace.activeDraft!.lines.single.id);
    await workspace.updateFeatureSettings(
      const OrderFeatureSettings(
        pricesEnabled: true,
        managedOrdersEnabled: true,
      ),
    );
    workspace.addCatalogueItem(item);
    await workspace.saveItem(
      existing: item,
      name: 'Soup renamed',
      price: revised,
    );
    workspace.addCatalogueItem(workspace.items.single);
    expect(workspace.activeDraft!.lines.single.price, original);
    await workspace.flushWrites();
    await repo.close();
    await repo.open();
    expect((await repo.loadDrafts()).single.lines.single.price, original);
    expect((await repo.loadFeatureSettings()).pricesEnabled, isTrue);
    final first = (await workspace.saveActiveTicket(heading: 'Kitchen'))!;
    expect(first.lines.single.price, original);
    expect(await workspace.beginAddition(first.managedOrderId!), isTrue);
    workspace.addCatalogueItem(workspace.items.single);
    final second = (await workspace.saveActiveTicket(heading: 'Ignored'))!;
    expect(second.lines.map((line) => line.price), [original, revised]);
    expect(second.printLines.single.price, revised);
    expect(OrderPriceEstimate.fromLines(second.lines).totals, {
      'EUR': 250,
      'GBP': 250,
    });
    await workspace.updateFeatureSettings(
      workspace.featureSettings.copyWith(pricesEnabled: false),
    );
    expect((await repo.loadItems()).single.price, revised);
    expect(await workspace.beginAddition(first.managedOrderId!), isTrue);
    workspace.addCatalogueItem(workspace.items.single);
    final third = (await workspace.saveActiveTicket(heading: 'Ignored'))!;
    expect(third.lines.map((line) => line.price), [original, revised, null]);
    expect(
      (await repo.loadTickets())
          .firstWhere((t) => t.id == first.id)
          .lines
          .single
          .price,
      original,
    );
  });

  test('disabling prices preserves composition but omits prices from new ticket snapshots', () async {
    final env = await createMemoryOrderEnvironment();
    addTearDown(env.controller.dispose);
    await env.controller.updateFeatureSettings(
      const OrderFeatureSettings(pricesEnabled: true),
    );
    final item = await env.repository.saveItem(name: 'Tea', price: original);
    env.controller.addCatalogueItem(item);
    await env.controller.updateFeatureSettings(const OrderFeatureSettings());
    expect(env.controller.activeDraft!.lines.single.price, original);
    final ticket = (await env.controller.saveActiveTicket(heading: 'Kitchen'))!;
    expect(ticket.lines.single.price, isNull);
    expect((await env.repository.loadItems()).single.price, original);
  });

  test(
    'priced snapshots leave preparation bytes and Server envelopes unchanged',
    () async {
      final env = await createMemoryOrderEnvironment();
      addTearDown(env.controller.dispose);
      final now = DateTime.now().toUtc();
      await env.repository.savePairedServer(
        PairedServer(
          id: 'price-server',
          displayName: 'Kitchen',
          baseUrl: Uri.parse('https://127.0.0.1:5119'),
          certificateFingerprint: 'a' * 64,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await env.controller.updateFeatureSettings(
        const OrderFeatureSettings(pricesEnabled: true),
      );
      final item = await env.repository.saveItem(name: 'Tea', price: original);
      env.controller.addCatalogueItem(item);
      final ticket = (await env.controller.saveActiveTicket(
        heading: 'Kitchen',
      ))!;
      final envelope =
          (await env.repository.loadClientDeliveries()).single.envelope;
      expect(envelope.toJsonString(), isNot(contains('price')));
      expect(envelope.toJsonString(), isNot(contains('EUR')));
      final plain = SavedTicket(
        id: ticket.id,
        number: ticket.number,
        createdAt: ticket.createdAt,
        heading: ticket.heading,
        reference: ticket.reference,
        orderNote: ticket.orderNote,
        lines: [
          for (final line in ticket.lines) line.copyWith(clearPrice: true),
        ],
      );
      TicketDocument document(SavedTicket value) => TicketDocument.fromTicket(
        ticket: value,
        fallbackHeading: 'Kitchen',
        ticketLabel: 'Ticket',
        createdAt: '5 October 2026',
        referenceLabel: 'Table',
        orderNotesLabel: 'Notes',
        lineNotePrefix: 'Note',
        footer: '',
      );
      expect(
        await const EscPosTicketEncoder().encode(document(ticket)),
        await const EscPosTicketEncoder().encode(document(plain)),
      );
    },
  );

  test('schema 14 migration and legacy restore retain print attempts and explicitly absent prices', () async {
    final dir = await Directory.systemTemp.createTemp(
      'libreslip-price-migrate-',
    );
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/orders.db';
    final repo = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: path,
    );
    await repo.open();
    addTearDown(repo.close);
    await repo.saveItem(name: 'Unpriced');
    final draft = await repo.createDraft();
    final ticket = await repo.convertDraftToTicket(
      draft.copyWith(
        lines: const [TicketLine(id: 'old', name: 'Unpriced', quantity: 1)],
      ),
      heading: 'Kitchen',
      keepOpen: true,
    );
    final job = await repo.createPrintJob(
      requestId: 'price-migration-job',
      ticketId: ticket.id,
      payload: Uint8List.fromList([27, 64, 10]),
    );
    await repo.markPrintJobSending(
      job.id,
      printerAddress: '00:11:22:33:44:55',
      printerName: 'Test printer',
    );
    await repo.close();
    final old = await databaseFactoryFfiNoIsolate.openDatabase(path);
    await removePriceColumnsForLegacyFixture(old);
    await old.setVersion(14);
    final legacyTables = <String, Object?>{};
    for (final table in [
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
    ]) {
      legacyTables[table] = await old.query(table);
    }
    await old.close();
    await repo.open();
    expect((await repo.loadFeatureSettings()).pricesEnabled, isFalse);
    expect((await repo.loadItems()).single.price, isNull);
    expect((await repo.loadManagedOrders()).single.lines.single.price, isNull);
    expect((await repo.loadTickets()).single.lines.single.price, isNull);
    expect(
      (await repo.loadPrintJobs()).single.status,
      PrintJobStatus.uncertain,
    );
    expect((await repo.loadPrintJobs()).single.payload, job.payload);
    // Network-safe portable snapshot encoded by the repository retains legacy values.
    final upgraded = await repo.createPortableSnapshot();
    final tables = upgraded['tables'] as Map;
    for (final table in ['items', 'draft_lines', 'ticket_lines']) {
      for (final row in tables[table] as List) {
        (row as Map).remove('price_minor_units');
        row.remove('price_currency');
      }
    }
    ((tables['order_feature_settings'] as List).single as Map).remove(
      'prices_enabled',
    );
    (tables['managed_orders'] as List).single['lines_json'] =
        legacyTables['managed_orders'] is List
        ? (legacyTables['managed_orders'] as List).single['lines_json']
        : '';
    upgraded['schemaVersion'] = 14;
    await repo.replaceWithPortableSnapshot(upgraded);
    SqliteOrderRepository.validatePortablePrices(
      await repo.createPortableSnapshot(),
    );
    expect((await repo.loadManagedOrders()).single.lines.single.price, isNull);
  });
}
