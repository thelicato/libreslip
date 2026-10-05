import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:libreslip/features/networking/application/client_delivery_controller.dart';
import 'package:libreslip/features/networking/application/network_mode_controller.dart';
import 'package:libreslip/features/networking/application/shared_orders_controller.dart';
import 'package:libreslip/features/networking/data/local_https_server.dart';
import 'package:libreslip/features/networking/data/pinned_https_client.dart';
import 'package:libreslip/features/networking/data/server_identity_service.dart';
import 'package:libreslip/features/networking/domain/client_delivery_models.dart';
import 'package:libreslip/features/networking/domain/client_transport.dart';
import 'package:libreslip/features/networking/domain/network_models.dart';
import 'package:libreslip/features/networking/domain/network_protocol.dart';
import 'package:libreslip/features/portability/application/portability_service.dart';
import 'package:libreslip/features/portability/domain/portability_models.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';
import 'package:libreslip/features/networking/domain/order_progress.dart';
import 'package:libreslip/features/networking/domain/server_inbox_models.dart';
import 'package:libreslip/features/networking/domain/server_security.dart';
import 'package:libreslip/features/networking/domain/shared_orders.dart';
import 'package:libreslip/features/orders/application/order_workspace_controller.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:libreslip/features/printing/domain/print_job.dart';

import 'progress_sync_test.dart' show ProgressTestSecrets;
import 'test_support.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('paired Clients share managed snapshots without creating history, jobs, catalogue or prices', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    final before = await f.a.repository.createPortableSnapshot();
    await f.syncBoth();
    expect(f.b.workspace.managedOrders.single.reference, 'Table 4');
    expect(f.b.workspace.managedOrders.single.lines.map((l) => l.id), [
      'soup',
      'water',
    ]);
    expect(
      f.b.workspace.managedOrders.single.lines.every(
        (l) => l.price == null && l.catalogueItemId == null,
      ),
      isTrue,
    );
    expect(f.b.workspace.tickets, isEmpty);
    expect(await f.b.repository.loadPrintJobs(), isEmpty);
    expect(f.b.workspace.items, isEmpty);
    final after = await f.a.repository.createPortableSnapshot();
    for (final table in ['tickets', 'ticket_lines', 'print_jobs']) {
      expect((after['tables'] as Map)[table], (before['tables'] as Map)[table]);
    }
    expect(f.a.workspace.managedOrders.single.lines.first.price, isNotNull);
    expect(
      jsonEncode(
        (await f.server.sharedOrder(
          (await f.server.loadServerOrders()).single.id,
        )).toJson(),
      ),
      isNot(contains('price')),
    );
  });

  test('concurrent additions and dividers merge once; each Client retains its own immutable printed snapshot', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    await f.syncBoth();
    final ticketA = await f.a.add('Coffee', divider: true);
    final ticketB = await f.b.add('Dessert', divider: true);
    await Future.wait([
      f.a.delivery.ticketReady(ticketA.id),
      f.b.delivery.ticketReady(ticketB.id),
    ]);
    expect(
      (await f.server.loadServerOrders()).single.lines.map((l) => l.name),
      containsAll(['Soup', 'Water', 'Coffee', 'Dessert']),
    );
    expect((await f.server.loadServerOrders()).single.revision, 3);
    await f.syncBoth();
    for (final client in [f.a, f.b]) {
      expect(
        client.workspace.managedOrders.single.lines.map((l) => l.name),
        containsAll(['Soup', 'Water', 'Coffee', 'Dessert']),
      );
      expect(
        client.workspace.managedOrders.single.lines
            .where((line) => line.sendToServer)
            .map((line) => line.id)
            .toList(),
        (await f.server.loadServerOrders()).single.lines
            .map((line) => line.id)
            .toList(),
      );
      expect(
        client.workspace.managedOrders.single.courses
            .map((course) => course.id)
            .toList(),
        (await f.server.loadServerOrders()).single.courses
            .map((course) => course.id)
            .toList(),
      );
      final courses = client.workspace.managedOrders.single.courses;
      expect(courses, hasLength(2));
      expect(courses.every((c) => c.isDivider), isTrue);
      expect(courses.map((c) => c.name).toSet(), hasLength(2));
      final snapshot = await client.repository.createPortableSnapshot();
      await client.repository.replaceWithPortableSnapshot(snapshot);
      expect(
        (await client.repository.loadTickets()).last.lines.map((l) => l.name),
        isNot(contains(client == f.a ? 'Dessert' : 'Coffee')),
      );
    }
    expect((await f.server.loadServerOrders()), hasLength(1));
  });

  test('progress merges unrelated edits, keeps same-line conflicts through polling and resolves explicitly', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    await f.syncBoth();
    await f.a.local('soup', 1);
    await f.b.local('water', 1);
    await f.a.sync.synchronise();
    await f.b.sync.synchronise();
    await f.a.sync.synchronise();
    expect(f.a.workspace.managedOrders.single.deliveredQuantity('water'), 1);
    expect(f.b.sync.conflicts, isEmpty);
    await f.a.local('soup', 2);
    await f.b.local('soup', 3);
    await f.a.sync.synchronise();
    await f.b.sync.synchronise();
    expect(f.b.sync.conflicts, hasLength(1));
    await f.b.sync.synchronise();
    await f.b.sync.synchronise();
    expect(f.b.sync.conflicts, hasLength(1));
    expect(
      (await f.server.loadServerOrders()).single.lines.first.deliveredQuantity,
      2,
    );
    await f.b.sync.synchronise(
      resolveOrderId: f.b.order.id,
      resolution: ProgressResolution.server,
    );
    expect(f.b.order.deliveredQuantity('soup'), 2);
    expect(f.b.sync.conflicts, isEmpty);
    await f.b.local('soup', 1);
    await f.a.local('soup', 3);
    await f.a.sync.synchronise();
    await f.b.sync.synchronise();
    await f.b.sync.synchronise(
      resolveOrderId: f.b.order.id,
      resolution: ProgressResolution.client,
    );
    await f.a.sync.synchronise();
    expect(f.a.order.deliveredQuantity('soup'), 1);
  });

  test('lost progress acknowledgement survives restart and does not overwrite a later Server undo', () async {
    final dir = await Directory.systemTemp.createTemp('shared-restart-');
    addTearDown(() => dir.delete(recursive: true));
    final f = await SharedFixture.create(directory: dir.path);
    addTearDown(f.dispose);
    await f.seed();
    await f.syncBoth();
    await f.b.local('soup', 1);
    f.transport.loseProgressAck = true;
    await f.b.sync.synchronise();
    expect(f.b.sync.error, 'unreachable');
    final operation = (await f.b.repository.loadSharedLink(f.b.order.id))!
        .pending!
        .operationId;
    final server = (await f.server.loadServerOrders()).single;
    await f.server.setServerLineDelivered(
      server.id,
      'soup',
      0,
      expectedQuantity: 1,
    );
    f.b.sync.dispose();
    await f.b.repository.close();
    await f.b.repository.open();
    await f.b.workspace.reloadAfterRestore();
    f.b.newSynchroniser(f.transport);
    await f.b.sync.synchronise();
    expect(f.transport.progressOperations, [operation, operation]);
    expect(f.b.order.deliveredQuantity('soup'), 0);
    expect(
      (await f.b.repository.loadSharedLink(f.b.order.id))!.pending,
      isNull,
    );
  });

  test('lost addition acknowledgement retries the same operation without a second order or duplicate line', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    await f.syncBoth();
    final ticket = await f.b.add('Tea');
    f.transport.loseAppendAck = true;
    await f.b.delivery.ticketReady(ticket.id);
    final pending = f.b.delivery.deliveryForTicket(ticket.id)!;
    expect(pending.status, ClientDeliveryStatus.failed);
    expect(await f.b.delivery.retry(pending.id), isTrue);
    await f.syncBoth();
    final order = (await f.server.loadServerOrders()).single;
    expect(order.revision, 2);
    expect(order.lines.where((l) => l.name == 'Tea'), hasLength(1));
    expect(f.b.workspace.tickets, hasLength(1));
  });

  test('offline edits and additions remain durable and printer-gated additions cannot reach other Clients early', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    await f.syncBoth();
    f.transport.offline = true;
    await f.b.local('water', 1);
    await f.b.sync.synchronise();
    expect(f.b.sync.error, 'unreachable');
    final ticket = await f.b.add('Beer', requirePrint: true);
    await f.b.delivery.ticketReady(ticket.id);
    expect(
      f.b.delivery.deliveryForTicket(ticket.id)!.status,
      ClientDeliveryStatus.awaitingPrint,
    );
    f.transport.offline = false;
    await f.syncBoth();
    expect(f.a.order.lines.any((l) => l.name == 'Beer'), isFalse);
    expect(
      (await f.server.loadServerOrders()).single.lines.last.deliveredQuantity,
      0,
    );
    // Explicit successful byte transmission is simulated by the existing durable print job API.
    final job = await f.b.repository.createPrintJob(
      requestId: 'beer-job',
      ticketId: ticket.id,
      payload: Uint8List.fromList([27, 64]),
    );
    await f.b.repository.markPrintJobSending(
      job.id,
      printerAddress: '00:11:22:33:44:55',
      printerName: 'Test printer',
    );
    await f.b.repository.markPrintJobOutcome(
      job.id,
      status: PrintJobStatus.transmitted,
    );
    await f.b.delivery.ticketReady(ticket.id);
    await f.syncBoth();
    expect(f.a.order.lines.any((l) => l.name == 'Beer'), isTrue);
    expect(f.a.order.deliveredQuantity('water'), 1);
  });

  test('incoming additions rebase a persistent composition without changing its items or current divider', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    await f.syncBoth();
    expect(await f.b.workspace.beginAddition(f.b.order.id), isTrue);
    await f.b.workspace.saveItem(name: 'Unsent drink');
    f.b.workspace.addDivider();
    f.b.workspace.addCatalogueItem(f.b.workspace.items.single);
    await f.b.workspace.flushWrites();
    final before = f.b.workspace.activeDraft!;
    final addition = await f.a.add('Rice', divider: true);
    await f.a.delivery.ticketReady(addition.id);
    await f.b.sync.synchronise();
    expect(f.b.workspace.activeDraft!.lines.single.id, before.lines.single.id);
    expect(f.b.workspace.activeDraft!.activeCourseId, before.activeCourseId);
    expect(f.b.workspace.activeDraft!.baseRevision, f.b.order.revision);
    final saved = await f.b.workspace.saveActiveTicket(
      heading: 'Kitchen',
      requirePrintForDelivery: false,
    );
    expect(saved, isNotNull);
    await f.b.delivery.ticketReady(saved!.id);
    await f.syncBoth();
    expect(
      f.a.order.lines.map((l) => l.name),
      containsAll(['Rice', 'Unsent drink']),
    );
  });

  test('shared recovery rolls back pending identities atomically; archives and successful restore discard network state', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    await f.syncBoth();
    await f.b.local('soup', 1);
    f.transport.loseProgressAck = true;
    await f.b.sync.synchronise();
    final id = f.b.order.id;
    final pending = (await f.b.repository.loadSharedLink(id))!
        .pending!
        .operationId;
    final recovery = await f.b.repository.createProgressRecoverySnapshot();
    final portable = await f.b.repository.createPortableSnapshot();
    expect(
      (portable['tables'] as Map).keys,
      isNot(contains('shared_order_links')),
    );
    await f.b.repository.replaceWithPortableSnapshot(portable);
    expect(await f.b.repository.loadSharedLink(id), isNull);
    await f.b.repository.replaceProgressRecoverySnapshot(recovery);
    expect(
      (await f.b.repository.loadSharedLink(id))!.pending!.operationId,
      pending,
    );
    final corrupt = jsonDecode(jsonEncode(recovery)) as Map<String, dynamic>;
    (corrupt['sharedSync'] as List).single['server_order_id'] = 'wrong-order';
    await expectLater(
      f.b.repository.replaceProgressRecoverySnapshot(corrupt),
      throwsA(isA<OrderStorageException>()),
    );
    expect(
      (await f.b.repository.loadSharedLink(id))!.pending!.operationId,
      pending,
    );
  });

  test('schema 15 migration preserves saved content and print gates', () async {
    final dir = await Directory.systemTemp.createTemp('shared-migration-');
    addTearDown(() => dir.delete(recursive: true));
    final repository = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: '${dir.path}/orders.db',
    );
    await repository.open();
    final draft = await repository.createDraft();
    final ticket = await repository.convertDraftToTicket(
      draft.copyWith(
        lines: const [TicketLine(id: 'line', name: 'Soup', quantity: 1)],
      ),
      heading: 'Kitchen',
      keepOpen: true,
    );
    await repository.close();
    final old = await databaseFactoryFfiNoIsolate.openDatabase(
      '${dir.path}/orders.db',
    );
    await removeSharedTablesForLegacyFixture(old);
    await old.setVersion(15);
    await old.close();
    await repository.open();
    addTearDown(repository.close);
    expect((await repository.loadTickets()).single.id, ticket.id);
    expect(await repository.loadSharedLink(draft.id), isNull);
    expect(
      (await repository.createPortableSnapshot())['schemaVersion'],
      SqliteOrderRepository.databaseVersion,
    );
  });

  test('automatic sync is opt-in, pauses in Server mode and never blocks offline composition', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    await f.b.workspace.updateFeatureSettings(
      f.b.workspace.featureSettings.copyWith(managedOrdersEnabled: false),
    );
    await f.b.sync.synchronise();
    expect(f.b.workspace.managedOrders, isEmpty);
    await f.b.workspace.updateFeatureSettings(
      f.b.workspace.featureSettings.copyWith(managedOrdersEnabled: true),
    );
    await f.b.mode.setMode(LibreSlipMode.server);
    await f.b.sync.synchronise();
    expect(f.b.workspace.managedOrders, isEmpty);
    await f.b.mode.setMode(LibreSlipMode.client);
    f.transport.offline = true;
    await f.b.sync.synchronise();
    expect(f.b.workspace.activeDraft, isNotNull);
    expect(f.b.workspace.loaded, isTrue);
  });

  test('local hiding survives polling without closing the Server order or another Client view', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    await f.syncBoth();
    expect(await f.b.workspace.closeOrder(f.b.order.id), isTrue);
    await f.syncBoth();
    await f.syncBoth();
    expect(f.b.workspace.managedOrders, isEmpty);
    expect(f.a.workspace.managedOrders, hasLength(1));
    expect(
      (await f.server.loadServerOrders()).single.status,
      ServerOrderStatus.received,
    );
  });

  test('pinned HTTPS allows paired shared edits, rejects unauthorised Clients and excludes ordinary tickets', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    final secret = SharedServerSecrets();
    final identity = await ServerIdentityService(secret).loadOrCreate();
    final host = LocalHttpsServer(f.server, secret, port: 0);
    addTearDown(host.stop);
    final running = await host.start(
      identity: identity,
      configuration: await f.server.loadNetworkConfiguration(),
      requestPairingApproval: (_) async => true,
      onOrderReceived: () {},
    );
    const pinned = PinnedHttpsClient();
    for (final client in [f.a, f.b]) {
      final paired = await pinned.pair(
        PairServerRequest(
          baseUrl: Uri.parse('https://127.0.0.1:${running.port}'),
          clientInstallationId: client.mode.configuration!.installationId,
          clientDisplayName: 'Client',
          clientIdentityFingerprint: sha256
              .convert(utf8.encode(client.mode.configuration!.installationId))
              .toString(),
        ),
      );
      await client.repository.savePairedServer(paired.server);
      await client.secrets.writeServerAccessToken(
        paired.server.id,
        paired.accessToken,
      );
      client.delivery.dispose();
      client.delivery = ClientDeliveryController(
        client.repository,
        client.secrets,
        pinned,
      );
      await client.delivery.load();
      client.sync.dispose();
      client.newSynchroniser(pinned);
    }
    await f.syncBoth();
    final ticket = await f.b.add('Juice');
    await f.b.delivery.ticketReady(ticket.id);
    await f.syncBoth();
    expect(
      f.a.order.lines.where((line) => line.sendToServer).last.name,
      'Juice',
    );
    await f.b.local('soup', 1);
    await f.b.sync.synchronise();
    await f.a.sync.synchronise();
    expect(f.a.order.deliveredQuantity('soup'), 1);
    await expectLater(
      pinned.sharedOrderIds(
        server: f.b.delivery.activeServer!,
        accessToken: 'wrong',
        clientId: f.b.mode.configuration!.installationId,
        after: '',
      ),
      throwsA(
        isA<ClientTransportException>().having(
          (e) => e.code,
          'code',
          'unauthorised',
        ),
      ),
    );
    final paired = f.b.delivery.activeServer!;
    final wrong = PairedServer(
      id: 'different-server',
      displayName: 'Other',
      baseUrl: paired.baseUrl,
      certificateFingerprint: paired.certificateFingerprint,
      createdAt: paired.createdAt,
      updatedAt: paired.updatedAt,
    );
    await expectLater(
      pinned.sharedOrderIds(
        server: wrong,
        accessToken: 'wrong',
        clientId: f.b.mode.configuration!.installationId,
        after: '',
      ),
      throwsA(
        isA<ClientTransportException>().having(
          (e) => e.code,
          'code',
          'server_identity',
        ),
      ),
    );
    await f.server.markServerOrderDone(
      (await f.server.loadServerOrders()).single.id,
      completedAt: DateTime.now(),
    );
    await f.syncBoth();
    expect(f.b.order.deliveredQuantity('soup'), 3);
    await f.server.markServerOrderReceived(
      (await f.server.loadServerOrders()).single.id,
    );
    await f.syncBoth();
    expect(f.a.order.deliveredQuantities.containsKey('soup'), isFalse);
    final ordinary = OrderDeliveryEnvelope.create(
      clientInstallationId: f.a.mode.configuration!.installationId,
      deliveryId: 'ordinary-delivery',
      ticketId: 'ordinary-ticket',
      ticketNumber: 9,
      createdAt: DateTime.now().toUtc(),
      heading: 'Kitchen',
      reference: '',
      orderNote: '',
      lines: const [DeliveryLine(name: 'Ordinary soup', quantity: 1)],
    );
    final receipt = await f.server.receiveServerOrder(
      ordinary,
      receivedAt: DateTime.now().toUtc(),
    );
    final heads = await pinned.sharedOrderIds(
      server: paired,
      accessToken: (await f.b.secrets.readServerAccessToken(paired.id))!,
      clientId: f.b.mode.configuration!.installationId,
      after: '',
    );
    expect(heads, hasLength(1));
    await expectLater(
      pinned.sharedOrder(
        server: paired,
        accessToken: (await f.b.secrets.readServerAccessToken(paired.id))!,
        clientId: f.b.mode.configuration!.installationId,
        serverOrderId: receipt.order.id,
      ),
      throwsA(
        isA<ClientTransportException>().having(
          (e) => e.code,
          'code',
          'order_missing',
        ),
      ),
    );
  });
  test('unchanged refresh reads revision headers only; deleted Server orders remain visibly unavailable without losing work', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    await f.syncBoth();
    final reads = f.transport.snapshotReads;
    await f.syncBoth();
    expect(f.transport.snapshotReads, reads);
    final order = (await f.server.loadServerOrders()).single;
    await f.server.markServerOrderDone(order.id, completedAt: DateTime.now());
    await f.server.deleteCompletedServerOrder(order.id);
    await f.syncBoth();
    expect(f.b.sync.unavailableIds, contains(f.b.order.id));
    expect(f.b.workspace.activeDraft, isNotNull);
    final addition = await f.b.add('Tea');
    await f.b.delivery.ticketReady(addition.id);
    expect(
      f.b.delivery.deliveryForTicket(addition.id)!.status,
      ClientDeliveryStatus.failed,
    );
    expect(await f.server.loadServerOrders(), isEmpty);
    expect(f.b.workspace.tickets, hasLength(1));
  });

  test('malformed snapshots and reused append identities roll back without changing orders or progress', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    await f.syncBoth();
    final before = await f.b.repository.createPortableSnapshot();
    final remote = await f.server.sharedOrder(
      (await f.server.loadServerOrders()).single.id,
    );
    final malformed =
        jsonDecode(jsonEncode(remote.toJson())) as Map<String, dynamic>;
    (malformed['progress']['quantities'] as Map)['soup'] = 999;
    expect(
      () => SharedOrderSnapshot.fromJson(malformed),
      throwsFormatException,
    );
    expect(await f.b.repository.createPortableSnapshot(), before);
    final ticket = await f.b.add('Tea');
    await f.b.delivery.ticketReady(ticket.id);
    final delivery = f.b.delivery.deliveryForTicket(ticket.id)!;
    final target = (await f.b.repository.sharedDeliveryTarget(delivery))!;
    final e = delivery.envelope;
    final altered = OrderDeliveryEnvelope.create(
      clientInstallationId: e.clientInstallationId,
      deliveryId: e.deliveryId,
      ticketId: e.ticketId,
      ticketNumber: e.ticketNumber,
      createdAt: e.createdAt,
      heading: e.heading,
      reference: e.reference,
      orderNote: e.orderNote,
      managedOrderId: e.managedOrderId,
      revision: e.revision,
      courses: e.courses,
      lines: [
        for (final line in e.lines)
          DeliveryLine(
            id: line.id,
            name: line.name,
            quantity:
                line.quantity + (target.additionIds.contains(line.id) ? 1 : 0),
            preparationNote: line.preparationNote,
            courseId: line.courseId,
          ),
      ],
    );
    await expectLater(
      f.server.appendSharedOrder(
        delivery.clientInstallationId,
        target.serverOrderId,
        altered,
        target.additionIds,
      ),
      throwsA(isA<ServerOrderConflictException>()),
    );
    expect((await f.server.loadServerOrders()).single.lines.last.quantity, 1);
  });

  test('failed and interrupted archive replacement recover the exact shared operation and successful restore reconnects one mirror', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    await f.syncBoth();
    final dir = await Directory.systemTemp.createTemp('shared-restore-');
    addTearDown(() => dir.delete(recursive: true));
    final support = Directory('${dir.path}/support')..createSync();
    final settings = SharedSettings();
    final service = PortabilityService(
      f.b.repository,
      settings,
      supportDirectory: () async => support,
      temporaryDirectory: () async => dir,
      appVersion: () => File('VERSION').readAsString(),
    );
    final archive = await service.createArchive(PortableArchiveKind.fullBackup);
    final preview = await service.inspectArchive(archive);
    await f.b.local('soup', 1);
    f.transport.loseProgressAck = true;
    await f.b.sync.synchronise();
    final pending = (await f.b.repository.loadSharedLink(f.b.order.id))!
        .pending!
        .operationId;
    settings.failNext = true;
    await expectLater(
      service.restore(preview),
      throwsA(isA<PortabilityException>()),
    );
    expect(
      (await f.b.repository.loadSharedLink(f.b.order.id))!.pending!.operationId,
      pending,
    );
    final recovery = await f.b.repository.createProgressRecoverySnapshot();
    final old = await settings.load();
    final features = f.b.workspace.featureSettings;
    await f.b.repository.replaceWithPortableSnapshot(
      recovery['database'] as Map<String, Object?>,
    );
    final staged = Directory(
      '${support.path}/restored_assets/shared-interrupted',
    )..createSync(recursive: true);
    final journal = File('${support.path}/portability_recovery.json');
    await journal.writeAsString(
      jsonEncode({
        'version': 1,
        'phase': 'pending',
        'settings': old!.toJson(),
        'features': {
          'orderReferenceEnabled': features.orderReferenceEnabled,
          'preparationNotesEnabled': features.preparationNotesEnabled,
          'orderNotesEnabled': features.orderNotesEnabled,
          'courseGroupsEnabled': features.courseGroupsEnabled,
          'managedOrdersEnabled': features.managedOrdersEnabled,
          'pricesEnabled': features.pricesEnabled,
        },
        ...recovery,
        'stagedDirectory': staged.path,
      }),
      flush: true,
    );
    await service.recoverInterruptedRestore();
    expect(
      (await f.b.repository.loadSharedLink(f.b.order.id))!.pending!.operationId,
      pending,
    );
    expect(journal.existsSync(), isFalse);
    await f.b.sync.synchronise();
    expect(f.transport.progressOperations, [pending, pending]);
    final fresh = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    );
    await fresh.open();
    addTearDown(fresh.close);
    final freshService = PortabilityService(
      fresh,
      MemorySettingsRepository(),
      supportDirectory: () async =>
          Directory('${dir.path}/fresh')..createSync(),
      temporaryDirectory: () async => dir,
      appVersion: () => File('VERSION').readAsString(),
    );
    final freshPreview = await freshService.inspectArchive(archive);
    await freshService.restore(freshPreview);
    expect((await fresh.loadManagedOrders()).single.destinationId, isNull);
    expect(await fresh.loadSharedLinks(), isEmpty);
    await service.restore(preview);
    await f.b.workspace.reloadAfterRestore();
    await f.b.sync.synchronise();
    expect(f.b.workspace.managedOrders, hasLength(1));
    expect(await f.b.repository.loadSharedLinks(), hasLength(1));
  });

  test('older pinned Servers receive no shared requests until capability is advertised', () async {
    final secret = SharedServerSecrets();
    final identity = await ServerIdentityService(secret).loadOrCreate();
    final context = SecurityContext(withTrustedRoots: false)
      ..useCertificateChainBytes(utf8.encode(identity.certificatePem))
      ..usePrivateKeyBytes(utf8.encode(identity.privateKeyPem));
    final host = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      context,
    );
    addTearDown(() => host.close(force: true));
    var supported = false, requests = 0;
    host.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/v1/status') {
        request.response.write(
          jsonEncode({
            'protocol': NetworkProtocol.name,
            'version': 1,
            'serverInstallationId': 'old-server',
            'sharedOrderVersions': [if (supported) 1],
          }),
        );
      } else {
        requests++;
        request.response.write(jsonEncode({'orders': []}));
      }
      await request.response.close();
    });
    final server = PairedServer(
      id: 'old-server',
      displayName: 'Old',
      baseUrl: Uri.parse('https://127.0.0.1:${host.port}'),
      certificateFingerprint: identity.certificateFingerprint,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    const transport = PinnedHttpsClient();
    await expectLater(
      transport.sharedOrderIds(
        server: server,
        accessToken: 'token',
        clientId: 'client',
        after: '',
      ),
      throwsA(
        isA<ClientTransportException>().having(
          (e) => e.code,
          'code',
          'unsupported_shared',
        ),
      ),
    );
    expect(requests, 0);
    supported = true;
    expect(
      await transport.sharedOrderIds(
        server: server,
        accessToken: 'token',
        clientId: 'client',
        after: '',
      ),
      isEmpty,
    );
    expect(requests, 1);
  });
  test('shared revision inventory paginates and only a changed order needs a snapshot on later refresh', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    final actor = f.a.mode.configuration!.installationId;
    for (var i = 0; i < 51; i++) {
      await f.server.receiveServerOrder(
        OrderDeliveryEnvelope.create(
          clientInstallationId: actor,
          deliveryId: 'page-delivery-$i',
          ticketId: 'page-ticket-$i',
          ticketNumber: i + 2,
          createdAt: DateTime.now().toUtc(),
          heading: 'Kitchen',
          reference: 'Table $i',
          orderNote: '',
          managedOrderId: 'page-order-$i',
          revision: 1,
          lines: [DeliveryLine(id: 'page-line-$i', name: 'Soup', quantity: 1)],
        ),
        receivedAt: DateTime.now().toUtc(),
      );
    }
    final first = await f.server.sharedOrderIds('');
    final last = await f.server.sharedOrderIds(first.last.id);
    expect(first, hasLength(50));
    expect(last, hasLength(2));
    await f.b.sync.synchronise();
    expect(f.b.workspace.managedOrders, hasLength(52));
    final reads = f.transport.snapshotReads;
    await f.b.sync.synchronise();
    expect(f.transport.snapshotReads, reads);
    final root = (await f.server.loadServerOrders()).firstWhere(
      (order) => order.reference == 'Table 4' && order.lines.first.id == 'soup',
    );
    await f.server.setServerLineDelivered(
      root.id,
      'soup',
      1,
      expectedQuantity: 0,
    );
    await f.b.sync.synchronise();
    expect(f.transport.snapshotReads, reads + 1);
    expect(
      f.b.workspace.managedOrders
          .firstWhere((order) => order.lines.first.id == 'soup')
          .deliveredQuantity('soup'),
      1,
    );
  });
  test('an edit made while progress is pending cannot turn lost-ack recovery into an overwrite of a later Server undo', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    await f.syncBoth();
    await f.a.local('soup', 1);
    f.transport.afterProgressWrite = () => f.a.local('private', 1);
    f.transport.loseProgressAck = true;
    await f.a.sync.synchronise();
    expect(f.a.sync.error, 'unreachable');
    final server = (await f.server.loadServerOrders()).single;
    await f.server.setServerLineDelivered(
      server.id,
      'soup',
      0,
      expectedQuantity: 1,
    );
    await f.a.sync.synchronise();
    expect(f.a.sync.conflicts, hasLength(1));
    expect(f.a.order.deliveredQuantity('private'), 1);
    await f.a.sync.synchronise();
    expect(
      (await f.server.loadServerOrders()).single.lines.first.deliveredQuantity,
      0,
    );
    await f.a.sync.synchronise(
      resolveOrderId: f.a.order.id,
      resolution: ProgressResolution.server,
    );
    expect(f.a.order.deliveredQuantity('soup'), 0);
    expect(f.a.order.deliveredQuantity('private'), 1);
  });
  test('the originating Client can append before its first feed refresh after another Client changes the order', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    expect(await f.a.repository.loadSharedLink(f.a.order.id), isNull);
    await f.b.sync.synchronise();
    final dessert = await f.b.add('Dessert');
    await f.b.delivery.ticketReady(dessert.id);
    final coffee = await f.a.add('Coffee');
    await f.a.delivery.ticketReady(coffee.id);
    expect(
      f.a.delivery.deliveryForTicket(coffee.id)!.status,
      ClientDeliveryStatus.delivered,
    );
    await f.syncBoth();
    final server = (await f.server.loadServerOrders()).single;
    expect(server.revision, 3);
    expect(server.lines.map((l) => l.name), containsAll(['Dessert', 'Coffee']));
    expect(
      f.a.order.lines.map((l) => l.name),
      containsAll(['Dessert', 'Coffee', 'Private']),
    );
  });
  test('unmapped original orders retain legacy delivery on older Servers while shared mirrors never switch protocols', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    f.transport.supportsShared = false;
    final coffee = await f.a.add('Coffee');
    await f.a.delivery.ticketReady(coffee.id);
    expect(
      f.a.delivery.deliveryForTicket(coffee.id)!.status,
      ClientDeliveryStatus.delivered,
    );
    expect((await f.server.loadServerOrders()).single.revision, 2);
    f.transport.supportsShared = true;
    await f.syncBoth();
    f.transport.supportsShared = false;
    final beer = await f.b.add('Beer');
    await f.b.delivery.ticketReady(beer.id);
    expect(
      f.b.delivery.deliveryForTicket(beer.id)!.errorCode,
      'unsupported_shared',
    );
    expect(
      (await f.server.loadServerOrders()).single.lines.any(
        (l) => l.name == 'Beer',
      ),
      isFalse,
    );
  });
  test('a queued shared addition keeps its exact destination and delta after a restore removes its history ticket', () async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    await f.syncBoth();
    final before = await f.b.repository.createPortableSnapshot();
    final ticket = await f.b.add('Tea');
    f.transport.loseAppendAck = true;
    await f.b.delivery.ticketReady(ticket.id);
    final delivery = f.b.delivery.deliveryForTicket(ticket.id)!;
    final original = (await f.b.repository.sharedDeliveryTarget(delivery))!;
    await f.b.repository.replaceWithPortableSnapshot(before);
    expect(await f.b.repository.loadTickets(), isEmpty);
    expect(await f.b.repository.loadSharedLinks(), isEmpty);
    final recovered = (await f.b.repository.sharedDeliveryTarget(delivery))!;
    expect(recovered.serverOrderId, original.serverOrderId);
    expect(recovered.additionIds, original.additionIds);
    expect(recovered.requiresSharing, isTrue);
    expect(await f.b.delivery.retry(delivery.id), isTrue);
    expect(
      (await f.server.loadServerOrders()).single.lines.where(
        (line) => line.name == 'Tea',
      ),
      hasLength(1),
    );
    expect((await f.server.loadServerOrders()).single.revision, 2);
  });
}

class SharedFixture {
  SharedFixture(this.server, this.transport, this.a, this.b);
  final SqliteOrderRepository server;
  final SharedTestTransport transport;
  final SharedClient a, b;
  static Future<SharedFixture> create({String? directory}) async {
    final server = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: directory == null
          ? inMemoryDatabasePath
          : '$directory/server.db',
    );
    await server.open();
    final transport = SharedTestTransport(server);
    final a = await SharedClient.create(
      server,
      transport,
      databasePath: directory == null
          ? inMemoryDatabasePath
          : '$directory/a.db',
    );
    final b = await SharedClient.create(
      server,
      transport,
      databasePath: directory == null
          ? inMemoryDatabasePath
          : '$directory/b.db',
    );
    return SharedFixture(server, transport, a, b);
  }

  Future<void> seed() async {
    final private = await a.repository.saveItem(
      name: 'Private',
      sendToServer: false,
    );
    final draft = a.workspace.activeDraft!;
    final ticket = await a.repository.convertDraftToTicket(
      draft.copyWith(
        reference: 'Table 4',
        lines: [
          const TicketLine(
            id: 'soup',
            name: 'Soup',
            quantity: 3,
            price: ProductPrice(minorUnits: 650, currency: 'EUR'),
          ),
          const TicketLine(id: 'water', name: 'Water', quantity: 2),
          TicketLine(
            id: 'private',
            catalogueItemId: private.id,
            name: private.name,
            quantity: 1,
          ),
        ],
      ),
      heading: 'Kitchen',
      keepOpen: true,
      requirePrintForDelivery: false,
    );
    await a.workspace.reloadAfterRestore();
    await a.delivery.ticketReady(ticket.id);
  }

  Future<void> syncBoth() async {
    await a.sync.synchronise();
    await b.sync.synchronise();
    await a.sync.synchronise();
    expect(a.sync.error, isNull);
    expect(b.sync.error, isNull);
  }

  Future<void> dispose() async {
    a.dispose();
    b.dispose();
    await server.close();
  }
}

class SharedClient {
  SharedClient(
    this.repository,
    this.workspace,
    this.delivery,
    this.mode,
    this.secrets,
  );
  final SqliteOrderRepository repository;
  final OrderWorkspaceController workspace;
  ClientDeliveryController delivery;
  final NetworkModeController mode;
  final ProgressTestSecrets secrets;
  late SharedOrdersController sync;
  ManagedOrder get order => workspace.managedOrders.single;
  static Future<SharedClient> create(
    SqliteOrderRepository server,
    SharedTestTransport transport, {
    String databasePath = inMemoryDatabasePath,
  }) async {
    final repository = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: databasePath,
    );
    final workspace = OrderWorkspaceController(repository);
    await workspace.load();
    final env = (repository: repository, controller: workspace);
    final mode = NetworkModeController(env.repository);
    await mode.load();
    await env.controller.updateFeatureSettings(
      const OrderFeatureSettings(
        managedOrdersEnabled: true,
        courseGroupsEnabled: true,
        orderReferenceEnabled: true,
        pricesEnabled: true,
      ),
    );
    final id = (await server.loadNetworkConfiguration()).installationId;
    await env.repository.savePairedServer(
      PairedServer(
        id: id,
        displayName: 'Kitchen Server',
        baseUrl: Uri.parse('https://127.0.0.1:5119'),
        certificateFingerprint: 'a' * 64,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await server.pairClient(
      PairedClient(
        installationId: mode.configuration!.installationId,
        displayName: 'Client',
        identityFingerprint: sha256
            .convert(utf8.encode(mode.configuration!.installationId))
            .toString(),
        pairedAt: DateTime.now(),
      ),
    );
    final secrets = ProgressTestSecrets()..tokens[id] = 'token';
    final delivery = ClientDeliveryController(
      env.repository,
      secrets,
      transport,
      retryDelay: const Duration(days: 1),
    );
    await delivery.load();
    final client = SharedClient(
      env.repository,
      env.controller,
      delivery,
      mode,
      secrets,
    );
    client.newSynchroniser(transport);
    return client;
  }

  void newSynchroniser(
    SharedOrdersTransport transport, {
    Duration interval = const Duration(days: 1),
  }) {
    sync = SharedOrdersController(
      store: repository,
      workspace: workspace,
      delivery: delivery,
      mode: mode,
      secrets: secrets,
      transport: transport,
      interval: interval,
    );
  }

  Future<SavedTicket> add(
    String name, {
    bool divider = false,
    bool requirePrint = false,
  }) async {
    expect(await workspace.beginAddition(order.id), isTrue);
    await workspace.saveItem(name: name);
    if (divider) workspace.addDivider();
    workspace.addCatalogueItem(
      workspace.items.firstWhere((i) => i.name == name),
    );
    return (await workspace.saveActiveTicket(
      heading: 'Kitchen',
      requirePrintForDelivery: requirePrint,
    ))!;
  }

  Future<void> local(String id, int count) async {
    expect(
      await workspace.setLineDelivered(
        order.id,
        id,
        count,
        expectedQuantity: order.deliveredQuantity(id),
      ),
      isTrue,
    );
  }

  void dispose() {
    sync.dispose();
    delivery.dispose();
    mode.dispose();
    workspace.dispose();
  }
}

class SharedTestTransport
    implements ClientServerTransport, SharedOrdersTransport {
  SharedTestTransport(this.repository);
  final SqliteOrderRepository repository;
  bool offline = false, loseProgressAck = false, loseAppendAck = false;
  bool supportsShared = true;
  final List<String> progressOperations = [];
  int snapshotReads = 0;
  Future<void> Function()? afterProgressWrite;
  void check() {
    if (offline) throw const ClientTransportException('unreachable');
  }

  @override
  Future<PairServerResult> pair(PairServerRequest request) =>
      throw UnimplementedError();
  @override
  Future<DeliveryAcknowledgement> deliver({
    required PairedServer server,
    required String accessToken,
    required ClientDelivery delivery,
  }) async {
    check();
    final receipt = await repository.receiveServerOrder(
      delivery.envelope,
      receivedAt: DateTime.now(),
    );
    return DeliveryAcknowledgement(
      deliveryId: delivery.id,
      serverOrderId: receipt.order.id,
      duplicate: receipt.wasDuplicate,
    );
  }

  @override
  Future<List<SharedOrderHead>> sharedOrderIds({
    required PairedServer server,
    required String accessToken,
    required String clientId,
    required String after,
  }) async {
    check();
    if (!supportsShared) {
      throw const ClientTransportException('unsupported_shared');
    }
    return repository.sharedOrderIds(after);
  }

  @override
  Future<SharedOrderSnapshot> sharedOrder({
    required PairedServer server,
    required String accessToken,
    required String clientId,
    required String serverOrderId,
  }) async {
    check();
    snapshotReads++;
    return repository.sharedOrder(serverOrderId);
  }

  @override
  Future<DeliveryAcknowledgement> appendSharedOrder({
    required PairedServer server,
    required String accessToken,
    required ClientDelivery delivery,
    required SharedDeliveryTarget target,
  }) async {
    check();
    if (!supportsShared) {
      throw const ClientTransportException('unsupported_shared');
    }
    ServerOrderReceipt receipt;
    try {
      receipt = await repository.appendSharedOrder(
        delivery.clientInstallationId,
        target.serverOrderId,
        delivery.envelope,
        target.additionIds,
      );
    } on ProgressSyncException {
      throw const ClientTransportException('order_missing');
    }
    if (loseAppendAck) {
      loseAppendAck = false;
      throw const ClientTransportException('unreachable');
    }
    return DeliveryAcknowledgement(
      deliveryId: delivery.id,
      serverOrderId: receipt.order.id,
      duplicate: receipt.wasDuplicate,
    );
  }

  @override
  Future<OrderProgressSnapshot> changeSharedProgress({
    required PairedServer server,
    required String accessToken,
    required String clientId,
    required OrderProgressChange change,
  }) async {
    check();
    progressOperations.add(change.operationId);
    OrderProgressSnapshot applied;
    try {
      applied = await repository.changeSharedProgress(clientId, change);
    } on ServerOrderConflictException {
      throw const ClientTransportException('conflict');
    }
    final hook = afterProgressWrite;
    afterProgressWrite = null;
    await hook?.call();
    if (loseProgressAck) {
      loseProgressAck = false;
      throw const ClientTransportException('unreachable');
    }
    return applied;
  }
}

class SharedServerSecrets implements ServerSecretStore {
  String? certificate, key;
  final Map<String, String> tokens = {};
  @override
  Future<String?> readServerCertificate() async => certificate;
  @override
  Future<String?> readServerPrivateKey() async => key;
  @override
  Future<void> writeServerIdentity({
    required String certificatePem,
    required String privateKeyPem,
  }) async {
    certificate = certificatePem;
    key = privateKeyPem;
  }

  @override
  Future<String?> readClientTokenHash(String clientInstallationId) async =>
      tokens[clientInstallationId];
  @override
  Future<void> writeClientTokenHash(
    String clientInstallationId,
    String tokenHash,
  ) async {
    tokens[clientInstallationId] = tokenHash;
  }
}

class SharedSettings extends MemorySettingsRepository {
  bool failNext = false;
  @override
  Future<void> save(AppSettings settings) async {
    if (failNext) {
      failNext = false;
      throw StateError('Settings unavailable');
    }
    await super.save(settings);
  }
}
