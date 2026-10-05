import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/networking/application/client_delivery_controller.dart';
import 'package:libreslip/features/networking/application/network_mode_controller.dart';
import 'package:libreslip/features/networking/application/shared_orders_controller.dart';
import 'package:libreslip/features/networking/data/local_https_server.dart';
import 'package:libreslip/features/networking/data/pinned_https_client.dart';
import 'package:libreslip/features/networking/data/server_identity_service.dart';
import 'package:libreslip/features/networking/domain/client_delivery_models.dart';
import 'package:libreslip/features/networking/domain/client_transport.dart';
import 'package:libreslip/features/networking/domain/order_progress.dart';
import 'package:libreslip/features/networking/domain/server_inbox_models.dart';
import 'package:libreslip/features/networking/domain/shared_orders.dart';
import 'package:libreslip/features/orders/application/order_workspace_controller.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'progress_sync_test.dart' show ProgressTestSecrets;
import 'shared_orders_test.dart' show SharedTestTransport, SharedServerSecrets;
import 'test_support.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('pairing retains both destinations and credentials; selection routes new orders and additions stay with their Server', () async {
    final f = await MultipleServersFixture.create();
    addTearDown(f.dispose);
    final client = f.client;
    expect(
      client.delivery.servers.map((s) => s.id).toSet(),
      f.servers.keys.toSet(),
    );
    expect(client.secrets.tokens.keys.toSet(), f.servers.keys.toSet());
    final first = await client.newOrder(f.firstId, 'Kitchen order');
    final second = await client.newOrder(f.secondId, 'Bar order');
    await client.sync.synchronise();
    expect(client.workspace.managedOrders, hasLength(2));
    await client.delivery.selectServer(f.secondId);
    final addition = await client.addTo(first.managedOrderId!, 'Tea');
    await client.delivery.ticketReady(addition.id);
    expect(
      client.delivery.deliveryForTicket(addition.id)!.destinationId,
      f.firstId,
    );
    expect(
      (await f.servers[f.firstId]!.loadServerOrders()).single.lines.last.name,
      'Tea',
    );
    expect(
      (await f.servers[f.secondId]!.loadServerOrders()).single.lines,
      hasLength(1),
    );
    expect(
      client.delivery.deliveryForTicket(second.id)!.status,
      ClientDeliveryStatus.delivered,
    );
    expect(await client.repository.loadPrintJobs(), isEmpty);
    final old = (await client.repository.loadTickets()).firstWhere(
      (t) => t.id == first.id,
    );
    expect(old.lines, hasLength(1));
    await client.delivery.unpair(f.firstId);
    expect(client.delivery.servers.single.id, f.secondId);
    expect(client.secrets.tokens.containsKey(f.firstId), isFalse);
    expect(client.secrets.tokens.containsKey(f.secondId), isTrue);
    final retained = client.workspace.managedOrders.firstWhere(
      (o) => o.id == first.managedOrderId,
    );
    expect(retained.destinationId, f.firstId);
    final newTicket = await client.newOrder(f.secondId, 'Still connected');
    expect(
      client.delivery.deliveryForTicket(newTicket.id)!.status,
      ClientDeliveryStatus.delivered,
    );
  });

  test('both shared feeds and progress stay scoped, including overlapping item identities and an unavailable order on one Server', () async {
    final f = await MultipleServersFixture.create();
    addTearDown(f.dispose);
    await f.client.newOrder(f.firstId, 'Kitchen');
    await f.client.newOrder(f.secondId, 'Bar');
    final secondClient = await MultiClient.create(f.transport, f.servers);
    addTearDown(secondClient.dispose);
    await secondClient.sync.synchronise();
    expect(secondClient.workspace.managedOrders, hasLength(2));
    expect(await secondClient.repository.loadTickets(), isEmpty);
    final kitchen = secondClient.workspace.managedOrders.firstWhere(
      (o) => o.destinationId == f.firstId,
    );
    final bar = secondClient.workspace.managedOrders.firstWhere(
      (o) => o.destinationId == f.secondId,
    );
    // Both Server orders deliberately use the same stable line identity.
    expect(kitchen.lines.single.id, bar.lines.single.id);
    await secondClient.workspace.setLineDelivered(
      kitchen.id,
      kitchen.lines.single.id,
      1,
      expectedQuantity: 0,
    );
    await secondClient.sync.synchronise();
    expect(
      (await f.servers[f.firstId]!.loadServerOrders())
          .single
          .lines
          .single
          .deliveredQuantity,
      1,
    );
    expect(
      (await f.servers[f.secondId]!.loadServerOrders())
          .single
          .lines
          .single
          .deliveredQuantity,
      0,
    );
    final deleted = (await f.servers[f.firstId]!.loadServerOrders()).single;
    await f.servers[f.firstId]!.markServerOrderDone(
      deleted.id,
      completedAt: DateTime.now(),
    );
    await f.servers[f.firstId]!.deleteCompletedServerOrder(deleted.id);
    await secondClient.sync.synchronise();
    expect(secondClient.sync.unavailableIds, contains(kitchen.id));
    expect(secondClient.sync.unavailableIds, isNot(contains(bar.id)));
    expect(secondClient.workspace.managedOrders, hasLength(2));
    await secondClient.delivery.selectServer(f.firstId);
    final addition = await secondClient.addTo(bar.id, 'Juice');
    await secondClient.delivery.ticketReady(addition.id);
    expect(
      (await f.servers[f.secondId]!.loadServerOrders()).single.lines.last.name,
      'Juice',
    );
    expect(await f.servers[f.firstId]!.loadServerOrders(), isEmpty);
  });

  test('an offline Server does not prevent healthy delivery or feed sync; queued work resumes without changing destination', () async {
    final f = await MultipleServersFixture.create();
    addTearDown(f.dispose);
    f.transport.routes[f.firstId]!.offline = true;
    final offline = await f.client.newOrder(f.firstId, 'Offline Kitchen');
    final healthy = await f.client.newOrder(f.secondId, 'Healthy Bar');
    expect(
      f.client.delivery.deliveryForTicket(offline.id)!.errorCode,
      'unreachable',
    );
    expect(
      f.client.delivery.deliveryForTicket(healthy.id)!.status,
      ClientDeliveryStatus.delivered,
    );
    await f.client.sync.synchronise();
    expect(f.client.sync.serverErrors[f.firstId], 'unreachable');
    expect(f.client.sync.serverErrors.containsKey(f.secondId), isFalse);
    expect(f.client.sync.serverSyncedAt.containsKey(f.secondId), isTrue);
    f.transport.routes[f.firstId]!.offline = false;
    expect(
      await f.client.delivery.retry(
        f.client.delivery.deliveryForTicket(offline.id)!.id,
      ),
      isTrue,
    );
    await f.client.sync.synchronise();
    expect(f.client.sync.serverErrors, isEmpty);
    expect(
      (await f.servers[f.firstId]!.loadServerOrders()).single.reference,
      'Offline Kitchen',
    );
    expect(
      (await f.servers[f.secondId]!.loadServerOrders()).single.reference,
      'Healthy Bar',
    );
  });

  test('a blocked destination drains concurrently with a healthy destination, retaining each managed revision order', () async {
    final f = await MultipleServersFixture.create();
    addTearDown(f.dispose);
    f.transport.routes[f.firstId]!.offline = true;
    f.transport.routes[f.secondId]!.offline = true;
    final first = await f.client.newOrder(f.firstId, 'Kitchen');
    final next = await f.client.addTo(first.managedOrderId!, 'Tea');
    await f.client.delivery.ticketReady(next.id);
    final second = await f.client.newOrder(f.secondId, 'Bar');
    f.transport.routes[f.firstId]!.offline = false;
    f.transport.routes[f.secondId]!.offline = false;
    f.transport.blockedDestination = f.firstId;
    f.transport.gate = Completer<void>();
    // load starts the independent durable drains.
    await f.client.delivery.load();
    await f.transport.blockStarted.future;
    for (
      var i = 0;
      i < 100 &&
          f.client.delivery.deliveryForTicket(second.id)!.status !=
              ClientDeliveryStatus.delivered;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(
      f.client.delivery.deliveryForTicket(second.id)!.status,
      ClientDeliveryStatus.delivered,
    );
    expect(await f.servers[f.firstId]!.loadServerOrders(), isEmpty);
    f.transport.gate!.complete();
    for (
      var i = 0;
      i < 100 &&
          f.client.delivery.deliveryForTicket(next.id)!.status !=
              ClientDeliveryStatus.delivered;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(
      f.client.delivery.deliveryForTicket(next.id)!.status,
      ClientDeliveryStatus.delivered,
    );
    final received = (await f.servers[f.firstId]!.loadServerOrders()).single;
    expect(received.revision, 2);
    expect(received.lines.map((l) => l.name), ['Soup', 'Tea']);
  });

  test('a slow shared feed cannot hold up another Server, and parallel merges preserve both orders', () async {
    final f = await MultipleServersFixture.create();
    addTearDown(f.dispose);
    await f.client.newOrder(f.firstId, 'Kitchen');
    await f.client.newOrder(f.secondId, 'Bar');
    final other = await MultiClient.create(f.transport, f.servers);
    addTearDown(other.dispose);
    f.transport.blockedFeed = f.firstId;
    f.transport.feedGate = Completer<void>();
    final refresh = other.sync.synchronise();
    await f.transport.feedStarted.future;
    for (
      var i = 0;
      i < 100 && !other.sync.serverSyncedAt.containsKey(f.secondId);
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(other.workspace.managedOrders.single.destinationId, f.secondId);
    expect(other.sync.serverSyncedAt.containsKey(f.secondId), isTrue);
    f.transport.feedGate!.complete();
    await refresh;
    expect(other.workspace.managedOrders, hasLength(2));
    expect(other.sync.serverErrors, isEmpty);
    expect(await other.repository.loadTickets(), isEmpty);
  });

  test('schema 16 migration and restart preserve the selected Server and all subsequent connections; backups exclude pairing', () async {
    final directory = await Directory.systemTemp.createTemp(
      'libreslip-multiple-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/client.db';
    final repository = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: path,
    );
    await repository.open();
    final server = paired('original', 5119);
    await repository.savePairedServer(server);
    await repository.close();
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await removeMultipleServerColumnsForLegacyFixture(db);
    await db.execute('PRAGMA user_version = 16');
    await db.close();
    await repository.open();
    expect((await repository.loadActiveServer())!.id, 'original');
    await repository.savePairedServer(paired('additional', 5120));
    await repository.selectServer('original');
    await repository.close();
    await repository.open();
    addTearDown(repository.close);
    expect(await repository.loadActiveServers(), hasLength(2));
    expect((await repository.loadActiveServer())!.id, 'original');
    await expectLater(
      repository.selectServer('unknown'),
      throwsA(isA<OrderStorageException>()),
    );
    expect((await repository.loadActiveServer())!.id, 'original');
    final snapshot = await repository.createPortableSnapshot();
    expect(snapshot['schemaVersion'], 17);
    expect(
      (snapshot['tables'] as Map).containsKey('network_destinations'),
      isFalse,
    );
    final restored = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    );
    await restored.open();
    addTearDown(restored.close);
    await restored.replaceWithPortableSnapshot(snapshot);
    expect(await restored.loadActiveServers(), isEmpty);
    await repository.deactivateServer('original');
    expect((await repository.loadActiveServer())!.id, 'additional');
    await repository.deactivateServer('additional');
    expect(await repository.loadActiveServer(), isNull);
  });

  test('two real pinned HTTPS Servers retain independent identities, tokens, routing and shared progress', () async {
    final serverList = <SqliteOrderRepository>[];
    final addresses = <String, String>{};
    for (final name in ['Kitchen', 'Bar']) {
      final repository = SqliteOrderRepository(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: inMemoryDatabasePath,
      );
      await repository.open();
      serverList.add(repository);
      addTearDown(repository.close);
      final secrets = SharedServerSecrets();
      final identity = await ServerIdentityService(secrets).loadOrCreate();
      final host = LocalHttpsServer(repository, secrets, port: 0);
      addTearDown(host.stop);
      final configuration = (await repository.loadNetworkConfiguration())
          .copyWith(serverName: name);
      final running = await host.start(
        identity: identity,
        configuration: configuration,
        requestPairingApproval: (_) async => true,
        onOrderReceived: () {},
      );
      addresses[configuration.installationId] =
          'https://127.0.0.1:${running.port}';
    }
    const transport = PinnedHttpsClient();
    final client = await MultiClient.create(
      transport,
      {},
      addresses: addresses,
    );
    addTearDown(client.dispose);
    final other = await MultiClient.create(transport, {}, addresses: addresses);
    addTearDown(other.dispose);
    final ids = addresses.keys.toList();
    expect(
      client.secrets.tokens[ids.first],
      isNot(client.secrets.tokens[ids.last]),
    );
    expect(
      client.delivery.serverFor(ids.first)!.certificateFingerprint,
      isNot(client.delivery.serverFor(ids.last)!.certificateFingerprint),
    );
    final kitchen = await client.newOrder(ids.first, 'Table 1');
    await client.newOrder(ids.last, 'Table 2');
    await other.sync.synchronise();
    expect(other.workspace.managedOrders, hasLength(2));
    final remoteKitchen = other.workspace.managedOrders.firstWhere(
      (o) => o.destinationId == ids.first,
    );
    await other.delivery.selectServer(ids.last);
    final addition = await other.addTo(remoteKitchen.id, 'Water');
    await other.delivery.ticketReady(addition.id);
    await client.sync.synchronise();
    expect(
      client.workspace.managedOrders
          .firstWhere((o) => o.id == kitchen.managedOrderId)
          .lines
          .last
          .name,
      'Water',
    );
    await other.workspace.setLineDelivered(
      remoteKitchen.id,
      'shared-line',
      1,
      expectedQuantity: 0,
    );
    await other.sync.synchronise();
    expect(
      (await serverList.first.loadServerOrders())
          .single
          .lines
          .first
          .deliveredQuantity,
      1,
    );
    expect(
      (await serverList.last.loadServerOrders())
          .single
          .lines
          .first
          .deliveredQuantity,
      0,
    );
    await other.delivery.unpair(ids.first);
    await other.sync.synchronise();
    expect(other.delivery.servers.single.id, ids.last);
    expect(other.sync.serverSyncedAt[ids.last], isNotNull);
  });
}

PairedServer paired(String id, int port, {String? name}) => PairedServer(
  id: id,
  displayName: name ?? id,
  baseUrl: Uri.parse('https://127.0.0.1:$port'),
  certificateFingerprint: (port == 5119 ? 'a' : 'b') * 64,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

class MultipleServersFixture {
  MultipleServersFixture(this.servers, this.transport, this.client);
  final Map<String, SqliteOrderRepository> servers;
  final MultipleServerTransport transport;
  final MultiClient client;
  String get firstId => servers.keys.first;
  String get secondId => servers.keys.last;
  static Future<MultipleServersFixture> create() async {
    final servers = <String, SqliteOrderRepository>{};
    for (var i = 0; i < 2; i++) {
      final repository = SqliteOrderRepository(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: inMemoryDatabasePath,
      );
      await repository.open();
      servers[(await repository.loadNetworkConfiguration()).installationId] =
          repository;
    }
    final transport = MultipleServerTransport(servers);
    final client = await MultiClient.create(transport, servers);
    return MultipleServersFixture(servers, transport, client);
  }

  Future<void> dispose() async {
    client.dispose();
    for (final server in servers.values) {
      await server.close();
    }
  }
}

class MultiClient {
  MultiClient(
    this.repository,
    this.workspace,
    this.delivery,
    this.mode,
    this.secrets,
    this.sync,
  );
  final SqliteOrderRepository repository;
  final OrderWorkspaceController workspace;
  final ClientDeliveryController delivery;
  final NetworkModeController mode;
  final ProgressTestSecrets secrets;
  final SharedOrdersController sync;
  static Future<MultiClient> create(
    ClientServerTransport transport,
    Map<String, SqliteOrderRepository> servers, {
    Map<String, String>? addresses,
  }) async {
    final repository = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    );
    final workspace = OrderWorkspaceController(repository);
    await workspace.load();
    await workspace.updateFeatureSettings(
      const OrderFeatureSettings(managedOrdersEnabled: true),
    );
    final mode = NetworkModeController(repository);
    await mode.load();
    final secrets = ProgressTestSecrets();
    final delivery = ClientDeliveryController(
      repository,
      secrets,
      transport,
      retryDelay: const Duration(days: 1),
    );
    await delivery.load();
    final destinations =
        addresses ??
        {
          for (final entry in servers.entries)
            entry.key:
                'https://127.0.0.1:${5119 + servers.keys.toList().indexOf(entry.key)}',
        };
    for (final address in destinations.values) {
      expect(
        await delivery.pair(
          configuration: mode.configuration!,
          address: address,
          clientName: 'Client',
        ),
        isTrue,
      );
    }
    final sync = SharedOrdersController(
      store: repository,
      workspace: workspace,
      delivery: delivery,
      mode: mode,
      secrets: secrets,
      transport: transport as SharedOrdersTransport,
    );
    return MultiClient(repository, workspace, delivery, mode, secrets, sync);
  }

  Future<SavedTicket> newOrder(String serverId, String title) async {
    expect(await delivery.selectServer(serverId), isTrue);
    final draft = workspace.activeDraft!;
    final ticket = await repository.convertDraftToTicket(
      draft.copyWith(
        reference: title,
        lines: [const TicketLine(id: 'shared-line', name: 'Soup', quantity: 3)],
      ),
      heading: 'Preparation',
      keepOpen: true,
      requirePrintForDelivery: false,
    );
    await workspace.reloadAfterRestore();
    await delivery.ticketReady(ticket.id);
    return ticket;
  }

  Future<SavedTicket> addTo(String orderId, String name) async {
    expect(await workspace.beginAddition(orderId), isTrue);
    await workspace.saveItem(name: name);
    workspace.addCatalogueItem(
      workspace.items.firstWhere((i) => i.name == name),
    );
    return (await workspace.saveActiveTicket(
      heading: 'Preparation',
      requirePrintForDelivery: false,
    ))!;
  }

  void dispose() {
    sync.dispose();
    delivery.dispose();
    mode.dispose();
    workspace.dispose();
  }
}

class MultipleServerTransport
    implements ClientServerTransport, SharedOrdersTransport {
  MultipleServerTransport(this.servers)
    : routes = {
        for (final entry in servers.entries)
          entry.key: SharedTestTransport(entry.value),
      };
  final Map<String, SqliteOrderRepository> servers;
  final Map<String, SharedTestTransport> routes;
  String? blockedDestination;
  Completer<void>? gate;
  String? blockedFeed;
  Completer<void>? feedGate;
  final feedStarted = Completer<void>();
  final blockStarted = Completer<void>();
  @override
  Future<PairServerResult> pair(PairServerRequest request) async {
    final id = servers.keys.toList()[request.baseUrl.port - 5119];
    final repository = servers[id]!;
    await repository.pairClient(
      PairedClient(
        installationId: request.clientInstallationId,
        displayName: request.clientDisplayName,
        identityFingerprint: request.clientIdentityFingerprint,
        pairedAt: DateTime.now(),
      ),
    );
    return PairServerResult(
      server: paired(
        id,
        request.baseUrl.port,
        name: request.baseUrl.port == 5119 ? 'Kitchen Server' : 'Bar Server',
      ),
      accessToken: 'token-$id',
    );
  }

  SharedTestTransport route(PairedServer server, String token) {
    if (token != 'token-${server.id}') {
      throw const ClientTransportException('credentials');
    }
    return routes[server.id]!;
  }

  @override
  Future<DeliveryAcknowledgement> deliver({
    required PairedServer server,
    required String accessToken,
    required ClientDelivery delivery,
  }) async {
    if (server.id == blockedDestination) {
      if (!blockStarted.isCompleted) blockStarted.complete();
      await gate!.future;
    }
    return route(
      server,
      accessToken,
    ).deliver(server: server, accessToken: accessToken, delivery: delivery);
  }

  @override
  Future<List<SharedOrderHead>> sharedOrderIds({
    required PairedServer server,
    required String accessToken,
    required String clientId,
    required String after,
  }) async {
    if (server.id == blockedFeed) {
      if (!feedStarted.isCompleted) feedStarted.complete();
      await feedGate!.future;
    }
    return route(server, accessToken).sharedOrderIds(
      server: server,
      accessToken: accessToken,
      clientId: clientId,
      after: after,
    );
  }

  @override
  Future<SharedOrderSnapshot> sharedOrder({
    required PairedServer server,
    required String accessToken,
    required String clientId,
    required String serverOrderId,
  }) => route(server, accessToken).sharedOrder(
    server: server,
    accessToken: accessToken,
    clientId: clientId,
    serverOrderId: serverOrderId,
  );
  @override
  Future<DeliveryAcknowledgement> appendSharedOrder({
    required PairedServer server,
    required String accessToken,
    required ClientDelivery delivery,
    required SharedDeliveryTarget target,
  }) => route(server, accessToken).appendSharedOrder(
    server: server,
    accessToken: accessToken,
    delivery: delivery,
    target: target,
  );
  @override
  Future<OrderProgressSnapshot> changeSharedProgress({
    required PairedServer server,
    required String accessToken,
    required String clientId,
    required OrderProgressChange change,
  }) => route(server, accessToken).changeSharedProgress(
    server: server,
    accessToken: accessToken,
    clientId: clientId,
    change: change,
  );
}
