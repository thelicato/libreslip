import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/networking/application/order_progress_synchroniser.dart';
import 'package:libreslip/features/networking/data/local_https_server.dart';
import 'package:libreslip/features/networking/data/pinned_https_client.dart';
import 'package:libreslip/features/networking/data/server_identity_service.dart';
import 'package:libreslip/features/networking/domain/client_delivery_models.dart';
import 'package:libreslip/features/networking/domain/client_security.dart';
import 'package:libreslip/features/networking/domain/client_transport.dart';
import 'package:libreslip/features/networking/domain/network_protocol.dart';
import 'package:libreslip/features/networking/domain/order_progress.dart';
import 'package:libreslip/features/networking/domain/server_inbox_models.dart';
import 'package:libreslip/features/networking/domain/server_security.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_support.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('explicit sync pulls Server deliveries and pushes offline edits without changing tickets or Local only items', () async {
    final f = await createProgressFixture();
    addTearDown(f.dispose);
    final before = await f.client.createPortableSnapshot();
    await f.local('private', 1);
    await f.remote('soup', 1);
    await f.sync();
    expect((await f.order()).deliveredQuantity('soup'), 1);
    expect((await f.order()).deliveredQuantity('private'), 1);
    expect(f.transport.operations, isEmpty);
    await f.local('water', 1);
    await f.sync();
    expect((await f.serverOrder()).lines.last.deliveredQuantity, 1);
    expect(f.transport.operations, hasLength(1));
    expect(f.transport.lastQuantities!.keys, isNot(contains('private')));
    final order = await f.serverOrder();
    await f.server.markServerOrderDone(
      order.id,
      completedAt: DateTime.now().toUtc(),
    );
    await f.sync();
    expect((await f.order()).deliveredQuantities, {
      'soup': 3,
      'water': 2,
      'private': 1,
    });
    final after = await f.client.createPortableSnapshot();
    for (final table in ['tickets', 'ticket_lines', 'print_jobs']) {
      expect((after['tables'] as Map)[table], (before['tables'] as Map)[table]);
    }
    expect(
      (await f.client.loadClientDeliveries()).single.status,
      ClientDeliveryStatus.awaitingPrint,
    );
  });

  test('Client delivery completes the Server; Server undo is pulled without closing the Client order', () async {
    final f = await createProgressFixture();
    addTearDown(f.dispose);
    await f.local('soup', 3);
    await f.local('water', 2);
    await f.sync();
    var server = await f.serverOrder();
    expect(server.status, ServerOrderStatus.done);
    await f.server.markServerOrderReceived(server.id);
    await f.sync();
    expect((await f.order()).deliveredQuantities, isEmpty);
    expect((await f.order()).closedAt, isNull);
    expect(f.transport.operations, hasLength(1));
  });

  test('concurrent edits are visible; both resolutions are explicit and use observed Server revisions', () async {
    final f = await createProgressFixture();
    addTearDown(f.dispose);
    await f.sync();
    await f.local('soup', 1);
    await f.remote('soup', 2);
    var conflict = await f.conflict();
    expect((await f.order()).deliveredQuantity('soup'), 1);
    expect((await f.serverOrder()).lines.first.deliveredQuantity, 2);
    expect(f.transport.operations, isEmpty);
    await f.sync(resolution: ProgressResolution.server, conflict: conflict);
    expect((await f.order()).deliveredQuantity('soup'), 2);
    await f.local('water', 1);
    await f.remote('soup', 3);
    conflict = await f.conflict();
    await f.remote('water', 2);
    await expectLater(
      f.sync(resolution: ProgressResolution.client, conflict: conflict),
      throwsA(isA<ProgressConflict>()),
    );
    expect(f.transport.operations, isEmpty);
    conflict = await f.conflict();
    await f.sync(resolution: ProgressResolution.client, conflict: conflict);
    expect(
      (await f.serverOrder()).lines.map((line) => line.deliveredQuantity),
      [2, 1],
    );
    expect((await f.order()).changedDeliveryIds, isEmpty);
  });

  test('lost acknowledgement survives restart; retry cannot overwrite a later Server undo', () async {
    final dir = await Directory.systemTemp.createTemp(
      'libreslip-sync-restart-',
    );
    addTearDown(() => dir.delete(recursive: true));
    final f = await createProgressFixture(clientPath: '${dir.path}/client.db');
    addTearDown(f.dispose);
    await f.local('water', 1);
    f.transport.loseNextAcknowledgement = true;
    await expectLater(f.sync(), throwsA(isA<ClientTransportException>()));
    final pending = (await f.client.loadProgressSyncState(await f.order()))
        .pending!;
    expect(pending.operationId, f.transport.operations.single);
    await f.remote('water', 0);
    final revision = (await f.serverOrder()).progressRevision;
    await f.client.close();
    await f.client.open();
    await f.sync();
    expect(f.transport.operations, [pending.operationId, pending.operationId]);
    expect((await f.serverOrder()).progressRevision, revision);
    expect((await f.order()).deliveredQuantity('water'), 0);
    expect(
      (await f.client.loadProgressSyncState(await f.order())).pending,
      isNull,
    );
  });

  test('offline edits after an interrupted acknowledgement survive recovery and sync as a new operation', () async {
    final f = await createProgressFixture();
    addTearDown(f.dispose);
    await f.local('water', 1);
    f.transport.loseNextAcknowledgement = true;
    await expectLater(f.sync(), throwsA(isA<ClientTransportException>()));
    await f.local('water', 0);
    await f.sync();
    expect(f.transport.operations, hasLength(3));
    expect(f.transport.operations[0], f.transport.operations[1]);
    expect(f.transport.operations[2], isNot(f.transport.operations[0]));
    expect((await f.serverOrder()).lines.last.deliveredQuantity, 0);
    expect((await f.order()).deliveredQuantity('water'), 0);
  });

  test('offline undo after a lost acknowledgement conflicts with a newer Server delivery', () async {
    final f = await createProgressFixture();
    addTearDown(f.dispose);
    await f.local('water', 1);
    f.transport.loseNextAcknowledgement = true;
    await expectLater(f.sync(), throwsA(isA<ClientTransportException>()));
    await f.local('water', 0);
    await f.remote('water', 2);
    final remote = await f.conflict();
    expect(remote.quantities['water'], 2);
    expect((await f.order()).deliveredQuantity('water'), 0);
    expect((await f.order()).changedDeliveryIds, contains('water'));
    expect(f.transport.operations, hasLength(2));
    await f.sync(resolution: ProgressResolution.client, conflict: remote);
    expect((await f.serverOrder()).lines.last.deliveredQuantity, 0);
  });

  test('backup replacement preserves zero-valued offline undo intent and excludes the sync baseline', () async {
    final f = await createProgressFixture();
    addTearDown(f.dispose);
    await f.sync();
    await f.local('soup', 1);
    await f.local('soup', 0);
    final snapshot = await f.client.createPortableSnapshot();
    await f.client.replaceWithPortableSnapshot(snapshot);
    expect((await f.order()).deliveredQuantities, isEmpty);
    expect((await f.order()).changedDeliveryIds, {'soup'});
    expect(
      (await f.client.loadProgressSyncState(await f.order())).baseline,
      isNull,
    );
    await f.remote('soup', 1);
    await expectLater(f.sync(), throwsA(isA<ProgressConflict>()));
  });

  test('progress protocol rejects malformed identities, versions and quantity inventories', () {
    final valid = OrderProgressSnapshot(
      clientId: 'client',
      orderId: 'order',
      orderRevision: 1,
      progressRevision: 0,
      quantities: const {'soup': 0},
    ).toJson();
    for (final (key, value) in [
      ('version', 1.0),
      ('version', 2),
      ('clientId', '../client'),
      ('orderRevision', 0),
      ('progressRevision', -1),
      ('quantities', <String, int>{}),
      ('quantities', {'soup': -1}),
      ('quantities', {'soup': 1000}),
      ('quantities', {'soup': true}),
      ('quantities', {'soup': 1.5}),
    ]) {
      expect(
        () => OrderProgressSnapshot.fromJson({...valid, key: value}),
        throwsFormatException,
      );
    }
    expect(
      () => OrderProgressSnapshot.fromJson({...valid, 'extra': 1}),
      throwsFormatException,
    );
    final change = OrderProgressChange(
      operationId: 'operation',
      orderId: 'order',
      orderRevision: 1,
      expectedRevision: 0,
      quantities: const {'soup': 1},
    ).toJson();
    expect(
      () => OrderProgressChange.fromJson({...change, 'expectedRevision': -1}),
      throwsFormatException,
    );
    expect(
      () => OrderProgressChange.fromJson({
        ...change,
        'operationId': 'invalid id',
      }),
      throwsFormatException,
    );
  });

  test(
    'Server changes during a write reject it and retain the local intent',
    () async {
      final f = await createProgressFixture();
      addTearDown(f.dispose);
      await f.sync();
      await f.local('soup', 1);
      f.transport.beforeNextWrite = () => f.remote('soup', 2);
      final conflict = await f.conflict();
      expect(conflict.quantities['soup'], 2);
      expect((await f.order()).deliveredQuantity('soup'), 1);
      expect(
        (await f.client.loadProgressSyncState(await f.order())).pending,
        isNull,
      );
      expect(f.transport.operations, hasLength(1));
    },
  );

  test('new shared additions wait for receipt; Local only additions retain independent progress', () async {
    final f = await createProgressFixture();
    addTearDown(f.dispose);
    await f.sync();
    final blank = await f.client.createDraft();
    var addition = await f.client.beginOrderAddition(
      (await f.order()).id,
      blank.id,
    );
    await f.client.convertDraftToTicket(
      addition.copyWith(
        lines: const [TicketLine(id: 'tea', name: 'Tea', quantity: 2)],
      ),
      heading: 'Ignored',
    );
    await f.local('tea', 1);
    await expectLater(
      f.sync(),
      throwsA(
        isA<ProgressSyncException>().having(
          (e) => e.code,
          'code',
          'pending_items',
        ),
      ),
    );
    expect(f.transport.operations, isEmpty);
    final deliveries = await f.client.loadClientDeliveries();
    await f.server.receiveServerOrder(
      deliveries.singleWhere((row) => row.envelope.revision == 2).envelope,
      receivedAt: DateTime.now().toUtc(),
    );
    await f.sync();
    expect((await f.serverOrder()).lines.last.deliveredQuantity, 1);
    final private = (await f.client.loadItems()).single;
    final next = await f.client.createDraft();
    addition = await f.client.beginOrderAddition((await f.order()).id, next.id);
    await f.client.convertDraftToTicket(
      addition.copyWith(
        lines: [
          TicketLine(
            id: 'private-addition',
            catalogueItemId: private.id,
            name: private.name,
            quantity: 1,
          ),
        ],
      ),
      heading: 'Ignored',
    );
    await f.local('private-addition', 1);
    await f.sync();
    expect((await f.order()).deliveredQuantity('private-addition'), 1);
    expect(
      f.transport.lastQuantities!.keys,
      isNot(contains('private-addition')),
    );
  });

  test('a newer Server order revision cannot rewind or replace local order content', () async {
    final f = await createProgressFixture();
    addTearDown(f.dispose);
    final previous = (await f.client.loadClientDeliveries()).single.envelope;
    await f.server.receiveServerOrder(
      OrderDeliveryEnvelope.create(
        clientInstallationId: previous.clientInstallationId,
        managedOrderId: previous.managedOrderId,
        deliveryId: 'newer-delivery',
        ticketId: 'newer-ticket',
        revision: 2,
        ticketNumber: previous.ticketNumber,
        createdAt: previous.createdAt,
        heading: previous.heading,
        reference: previous.reference,
        orderNote: previous.orderNote,
        courses: previous.courses,
        lines: [
          ...previous.lines,
          const DeliveryLine(id: 'newer-line', name: 'Tea', quantity: 1),
        ],
      ),
      receivedAt: DateTime.now().toUtc(),
    );
    await expectLater(
      f.sync(),
      throwsA(
        isA<ProgressSyncException>().having(
          (e) => e.code,
          'code',
          'server_newer',
        ),
      ),
    );
    expect((await f.order()).revision, 1);
    expect((await f.order()).lines, hasLength(3));
    expect(f.transport.operations, isEmpty);
  });

  test('progress stays scoped to the original Server and cannot create deliveries for local orders', () async {
    final f = await createProgressFixture();
    addTearDown(f.dispose);
    final current = await f.order();
    await f.client.savePairedServer(
      PairedServer(
        id: 'another-server',
        displayName: 'Other',
        baseUrl: Uri.parse('https://127.0.0.1:5119'),
        certificateFingerprint: 'c' * 64,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await f.local('soup', 1);
    await f.sync();
    expect(f.transport.serverIds.toSet(), {current.destinationId});
    await f.secrets.deleteServerAccessToken(current.destinationId!);
    await expectLater(
      f.sync(),
      throwsA(
        isA<ProgressSyncException>().having(
          (e) => e.code,
          'code',
          'credentials',
        ),
      ),
    );
  });

  test('local edits during acknowledgement are retained and can be synced on the next action', () async {
    final f = await createProgressFixture();
    addTearDown(f.dispose);
    await f.local('water', 1);
    f.transport.afterNextWrite = () => f.local('water', 2);
    await expectLater(
      f.sync(),
      throwsA(
        isA<ProgressSyncException>().having(
          (e) => e.code,
          'code',
          'local_changed',
        ),
      ),
    );
    expect((await f.order()).deliveredQuantity('water'), 2);
    expect((await f.serverOrder()).lines.last.deliveredQuantity, 1);
    await f.sync();
    expect((await f.serverOrder()).lines.last.deliveredQuantity, 2);
  });

  test('Server rejects reused operation identities, stale counts, unknown lines and another Client', () async {
    final f = await createProgressFixture();
    addTearDown(f.dispose);
    final order = await f.order();
    OrderProgressChange change(
      String id,
      int revision,
      Map<String, int> values,
    ) => OrderProgressChange(
      operationId: id,
      orderId: order.id,
      orderRevision: 1,
      expectedRevision: revision,
      quantities: values,
    );
    final applied = await f.server.applyServerProgress(
      order.clientInstallationId!,
      change('operation', 0, {'soup': 1, 'water': 0}),
    );
    expect(applied.progressRevision, 1);
    await f.remote('soup', 2);
    final duplicate = await f.server.applyServerProgress(
      order.clientInstallationId!,
      change('operation', 0, {'water': 0, 'soup': 1}),
    );
    expect(duplicate.quantities['soup'], 1);
    expect((await f.serverOrder()).lines.first.deliveredQuantity, 2);
    await expectLater(
      f.server.applyServerProgress(
        order.clientInstallationId!,
        change('operation', 0, {'soup': 2, 'water': 0}),
      ),
      throwsA(isA<ServerOrderConflictException>()),
    );
    await expectLater(
      f.server.applyServerProgress(
        order.clientInstallationId!,
        change('stale', 0, {'soup': 1, 'water': 0}),
      ),
      throwsA(isA<ServerOrderConflictException>()),
    );
    for (final values in [
      {'soup': 4, 'water': 0},
      {'soup': 1, 'missing': 0},
    ]) {
      await expectLater(
        f.server.applyServerProgress(
          order.clientInstallationId!,
          change('invalid', 2, values),
        ),
        throwsFormatException,
      );
    }
    await expectLater(
      f.server.loadServerProgress('another-client', order.id),
      throwsA(isA<ProgressSyncException>()),
    );
    final completed = await f.server.markServerOrderDone(
      (await f.serverOrder()).id,
      completedAt: DateTime.now().toUtc(),
    );
    await f.server.deleteCompletedServerOrder(completed.id);
    await expectLater(
      f.server.applyServerProgress(
        order.clientInstallationId!,
        change('operation', 0, {'soup': 1, 'water': 0}),
      ),
      throwsA(isA<ProgressSyncException>()),
    );
  });

  test('schema 13 migration retains dirty progress and full restore excludes pending network writes', () async {
    final dir = await Directory.systemTemp.createTemp(
      'libreslip-sync-migrate-',
    );
    addTearDown(() => dir.delete(recursive: true));
    final f = await createProgressFixture(
      clientPath: '${dir.path}/client.db',
      serverPath: '${dir.path}/server.db',
    );
    addTearDown(f.dispose);
    await f.local('soup', 1);
    await f.remote('soup', 2);
    await f.client.close();
    await f.server.close();
    for (final path in ['${dir.path}/client.db', '${dir.path}/server.db']) {
      final old = await databaseFactoryFfiNoIsolate.openDatabase(path);
      await removeProgressSyncColumnsForLegacyFixture(old);
      await old.setVersion(13);
      await old.close();
    }
    await f.client.open();
    await f.server.open();
    expect((await f.order()).changedDeliveryIds, {'soup', 'water', 'private'});
    expect((await f.serverOrder()).progressRevision, 1);
    final conflict = await f.conflict();
    await f.sync(resolution: ProgressResolution.client, conflict: conflict);
    await f.local('water', 1);
    f.transport.loseNextAcknowledgement = true;
    await expectLater(f.sync(), throwsA(isA<ClientTransportException>()));
    final snapshot = await f.client.createPortableSnapshot();
    expect(
      (snapshot['tables'] as Map).keys,
      isNot(contains('client_progress_sync')),
    );
    expect(
      (await f.client.loadProgressSyncState(await f.order())).pending,
      isNotNull,
    );
    await f.client.replaceWithPortableSnapshot(snapshot);
    expect(
      (await f.client.loadProgressSyncState(await f.order())).pending,
      isNull,
    );
    expect((await f.order()).deliveredQuantity('water'), 1);
    expect(
      await f.secrets.readServerAccessToken((await f.order()).destinationId!),
      'token',
    );
  });

  test('private recovery restores the same pending operation atomically and remains outside archives', () async {
    final f = await createProgressFixture();
    addTearDown(f.dispose);
    await f.local('water', 1);
    f.transport.loseNextAcknowledgement = true;
    await expectLater(f.sync(), throwsA(isA<ClientTransportException>()));
    final pending = (await f.client.loadProgressSyncState(await f.order()))
        .pending!;
    final recovery = await f.client.createProgressRecoverySnapshot();
    final snapshot = await f.client.createPortableSnapshot();
    expect(snapshot.keys, isNot(contains('progressSync')));
    await f.client.replaceWithPortableSnapshot(snapshot);
    expect(
      (await f.client.loadProgressSyncState(await f.order())).pending,
      isNull,
    );
    await f.client.replaceProgressRecoverySnapshot(recovery);
    expect(
      (await f.client.loadProgressSyncState(await f.order()))
          .pending!
          .operationId,
      pending.operationId,
    );
    final broken = jsonDecode(jsonEncode(recovery)) as Map<String, dynamic>;
    (broken['progressSync'] as List).single['client_id'] = 'wrong-client';
    await expectLater(
      f.client.replaceProgressRecoverySnapshot(broken),
      throwsA(isA<OrderStorageException>()),
    );
    expect(
      (await f.client.loadProgressSyncState(await f.order()))
          .pending!
          .operationId,
      pending.operationId,
    );
    await f.sync();
    expect(f.transport.operations, [pending.operationId, pending.operationId]);
  });

  test(
    'pinned HTTPS authenticates progress and updates the live Server board',
    () async {
      final f = await createProgressFixture();
      addTearDown(f.dispose);
      final secrets = _ServerSecrets();
      final identity = await ServerIdentityService(secrets).loadOrCreate();
      final clientId = (await f.order()).clientInstallationId!;
      await secrets.writeClientTokenHash(clientId, hashAccessToken('token'));
      final host = LocalHttpsServer(f.server, secrets, port: 0);
      addTearDown(host.stop);
      var notifications = 0;
      final running = await host.start(
        identity: identity,
        configuration: await f.server.loadNetworkConfiguration(),
        requestPairingApproval: (_) async => true,
        onOrderReceived: () {
          notifications++;
        },
      );
      final server = PairedServer(
        id: (await f.order()).destinationId!,
        displayName: 'Server',
        baseUrl: Uri.parse('https://127.0.0.1:${running.port}'),
        certificateFingerprint: identity.certificateFingerprint,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      await f.client.savePairedServer(server);
      const transport = PinnedHttpsClient();
      await f.local('soup', 1);
      await OrderProgressSynchroniser(
        f.client,
        f.secrets,
        transport,
      ).synchronise(await f.order());
      expect((await f.serverOrder()).lines.first.deliveredQuantity, 1);
      expect(notifications, 1);
      await expectLater(
        transport.fetchProgress(
          server: server,
          accessToken: 'wrong',
          clientId: clientId,
          orderId: (await f.order()).id,
        ),
        throwsA(
          isA<ClientTransportException>().having(
            (e) => e.code,
            'code',
            'unauthorised',
          ),
        ),
      );
      await expectLater(
        transport.fetchProgress(
          server: server,
          accessToken: 'token',
          clientId: 'another-client',
          orderId: (await f.order()).id,
        ),
        throwsA(
          isA<ClientTransportException>().having(
            (e) => e.code,
            'code',
            'unauthorised',
          ),
        ),
      );
      await f.remote('water', 1);
      await OrderProgressSynchroniser(
        f.client,
        f.secrets,
        transport,
      ).synchronise(await f.order());
      expect((await f.order()).deliveredQuantity('water'), 1);
    },
  );

  test('older pinned Servers receive no progress requests and explicit retry works after upgrading', () async {
    final f = await createProgressFixture();
    addTearDown(f.dispose);
    final identity = await ServerIdentityService(_ServerSecrets())
        .loadOrCreate();
    final tls = SecurityContext(withTrustedRoots: false)
      ..useCertificateChainBytes(utf8.encode(identity.certificatePem))
      ..usePrivateKeyBytes(utf8.encode(identity.privateKeyPem));
    final host = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      tls,
    );
    addTearDown(() => host.close(force: true));
    var supported = false;
    var progressRequests = 0;
    final id = (await f.order()).destinationId!;
    host.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/v1/status') {
        request.response.write(
          jsonEncode({
            'protocol': NetworkProtocol.name,
            'version': 1,
            'serverInstallationId': id,
            if (supported) 'progressVersions': [1],
          }),
        );
      } else {
        progressRequests++;
        request.response.write(
          jsonEncode(
            (await f.server.loadServerProgress(
              (await f.order()).clientInstallationId!,
              (await f.order()).id,
            )).toJson(),
          ),
        );
      }
      await request.response.close();
    });
    await f.client.savePairedServer(
      PairedServer(
        id: id,
        displayName: 'Server',
        baseUrl: Uri.parse('https://127.0.0.1:${host.port}'),
        certificateFingerprint: identity.certificateFingerprint,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    final sync = OrderProgressSynchroniser(
      f.client,
      f.secrets,
      const PinnedHttpsClient(),
    );
    await expectLater(
      sync.synchronise(await f.order()),
      throwsA(
        isA<ClientTransportException>().having(
          (e) => e.code,
          'code',
          'unsupported_progress',
        ),
      ),
    );
    expect(progressRequests, 0);
    supported = true;
    await sync.synchronise(await f.order());
    expect(progressRequests, 1);
  });
}

Future<ProgressFixture> createProgressFixture({
  String clientPath = inMemoryDatabasePath,
  String serverPath = inMemoryDatabasePath,
}) async {
  sqfliteFfiInit();
  final client = SqliteOrderRepository(
    factory: databaseFactoryFfiNoIsolate,
    databasePath: clientPath,
  );
  final server = SqliteOrderRepository(
    factory: databaseFactoryFfiNoIsolate,
    databasePath: serverPath,
  );
  await client.open();
  await server.open();
  final serverId = (await server.loadNetworkConfiguration()).installationId;
  final clientId = (await client.loadNetworkConfiguration()).installationId;
  await client.savePairedServer(
    PairedServer(
      id: serverId,
      displayName: 'Original Server',
      baseUrl: Uri.parse('https://127.0.0.1:5119'),
      certificateFingerprint: 'a' * 64,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    ),
  );
  await server.pairClient(
    PairedClient(
      installationId: clientId,
      displayName: 'Client',
      identityFingerprint: 'b' * 64,
      pairedAt: DateTime.now().toUtc(),
    ),
  );
  final private = await client.saveItem(
    name: 'Private item',
    sendToServer: false,
  );
  final draft = await client.createDraft();
  await client.convertDraftToTicket(
    draft.copyWith(
      reference: 'Table 4',
      courses: const [
        OrderCourse(id: 'first', name: 'First'),
        OrderCourse(id: 'drinks', name: 'Drinks'),
      ],
      lines: [
        const TicketLine(
          id: 'soup',
          name: 'Soup',
          quantity: 3,
          courseId: 'first',
        ),
        const TicketLine(
          id: 'water',
          name: 'Water',
          quantity: 2,
          courseId: 'drinks',
        ),
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
  );
  await server.receiveServerOrder(
    (await client.loadClientDeliveries()).single.envelope,
    receivedAt: DateTime.now().toUtc(),
  );
  final secrets = ProgressTestSecrets()..tokens[serverId] = 'token';
  return ProgressFixture(
    client,
    server,
    secrets,
    ProgressTestTransport(server),
  );
}

class ProgressFixture {
  ProgressFixture(this.client, this.server, this.secrets, this.transport);
  final SqliteOrderRepository client;
  final SqliteOrderRepository server;
  final ProgressTestSecrets secrets;
  final ProgressTestTransport transport;
  Future<ManagedOrder> order() async =>
      (await client.loadManagedOrders()).single;
  Future<ServerOrder> serverOrder() async =>
      (await server.loadServerOrders()).single;
  Future<void> local(String id, int quantity) async {
    final current = await order();
    await client.setManagedLineDelivered(
      current.id,
      id,
      quantity,
      expectedQuantity: current.deliveredQuantity(id),
    );
  }

  Future<void> remote(String id, int quantity) async {
    final current = await serverOrder();
    await server.setServerLineDelivered(
      current.id,
      id,
      quantity,
      expectedQuantity: current.lines
          .singleWhere((line) => line.id == id)
          .deliveredQuantity,
    );
  }

  Future<void> sync({
    ProgressResolution? resolution,
    OrderProgressSnapshot? conflict,
  }) async => OrderProgressSynchroniser(
    client,
    secrets,
    transport,
  ).synchronise(await order(), resolution: resolution, conflict: conflict);
  Future<OrderProgressSnapshot> conflict() async {
    try {
      await sync();
    } on ProgressConflict catch (error) {
      return error.remote;
    }
    fail('Expected a visible progress conflict');
  }

  Future<void> dispose() async {
    await client.close();
    await server.close();
  }
}

class ProgressTestTransport
    implements OrderProgressTransport, ClientServerTransport {
  ProgressTestTransport(this.store);
  final SqliteOrderRepository store;
  bool loseNextAcknowledgement = false;
  Future<void> Function()? beforeNextWrite;
  Future<void> Function()? afterNextWrite;
  final operations = <String>[];
  final serverIds = <String>[];
  Map<String, int>? lastQuantities;
  @override
  Future<OrderProgressSnapshot> fetchProgress({
    required PairedServer server,
    required String accessToken,
    required String clientId,
    required String orderId,
  }) async {
    serverIds.add(server.id);
    return store.loadServerProgress(clientId, orderId);
  }

  @override
  Future<OrderProgressSnapshot> changeProgress({
    required PairedServer server,
    required String accessToken,
    required String clientId,
    required OrderProgressChange change,
  }) async {
    serverIds.add(server.id);
    operations.add(change.operationId);
    lastQuantities = change.quantities;
    final before = beforeNextWrite;
    beforeNextWrite = null;
    await before?.call();
    OrderProgressSnapshot result;
    try {
      result = await store.applyServerProgress(clientId, change);
    } on ServerOrderConflictException {
      throw const ClientTransportException('conflict');
    }
    final after = afterNextWrite;
    afterNextWrite = null;
    await after?.call();
    if (loseNextAcknowledgement) {
      loseNextAcknowledgement = false;
      throw const ClientTransportException('unreachable');
    }
    return result;
  }

  @override
  Future<PairServerResult> pair(PairServerRequest request) =>
      throw UnimplementedError();
  @override
  Future<DeliveryAcknowledgement> deliver({
    required PairedServer server,
    required String accessToken,
    required ClientDelivery delivery,
  }) => throw UnimplementedError();
}

class ProgressTestSecrets implements ClientSecretStore {
  final tokens = <String, String>{};
  @override
  Future<String?> readServerAccessToken(String serverId) async =>
      tokens[serverId];
  @override
  Future<void> writeServerAccessToken(String serverId, String token) async {
    tokens[serverId] = token;
  }

  @override
  Future<void> deleteServerAccessToken(String serverId) async {
    tokens.remove(serverId);
  }
}

class _ServerSecrets implements ServerSecretStore {
  String? certificate;
  String? key;
  final tokens = <String, String>{};
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
