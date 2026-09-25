import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/networking/application/client_delivery_controller.dart';
import 'package:libreslip/features/networking/data/local_https_server.dart';
import 'package:libreslip/features/networking/data/pinned_https_client.dart';
import 'package:libreslip/features/networking/data/server_identity_service.dart';
import 'package:libreslip/features/networking/domain/client_delivery_models.dart';
import 'package:libreslip/features/networking/domain/client_security.dart';
import 'package:libreslip/features/networking/domain/client_transport.dart';
import 'package:libreslip/features/networking/domain/server_security.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:libreslip/features/printing/domain/print_job.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory temporaryDirectory;
  late SqliteOrderRepository repository;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'libreslip-client-delivery-',
    );
    repository = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: '${temporaryDirectory.path}/orders.sqlite3',
    );
    await repository.open();
  });

  tearDown(() async {
    await repository.close();
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'pinned pairing automatically resends a lost acknowledgement once',
    () async {
      final configuration = await repository.loadNetworkConfiguration();
      final serverSecrets = _MemoryServerSecrets();
      final identity = await ServerIdentityService(serverSecrets)
          .loadOrCreate();
      final host = LocalHttpsServer(repository, serverSecrets, port: 0);
      addTearDown(host.stop);
      final running = await host.start(
        identity: identity,
        configuration: configuration,
        requestPairingApproval: (request) async {
          expect(request.clientInstallationId, configuration.installationId);
          expect(request.displayName, 'Front counter');
          expect(request.sourceAddress, '127.0.0.1');
          return true;
        },
        onOrderReceived: () {},
      );
      final transport = _LoseFirstAcknowledgementTransport(
        const PinnedHttpsClient(),
      );
      final clientSecrets = _MemoryClientSecrets();
      final controller = ClientDeliveryController(
        repository,
        clientSecrets,
        transport,
        retryDelay: const Duration(milliseconds: 20),
      );
      addTearDown(controller.dispose);
      await controller.load();

      expect(
        await controller.pair(
          configuration: configuration,
          address: '127.0.0.1:${running.port}',
          clientName: 'Front counter',
        ),
        isTrue,
      );
      expect(controller.activeServer?.id, configuration.installationId);
      expect(
        controller.activeServer?.certificateFingerprint,
        identity.certificateFingerprint,
      );
      expect(clientSecrets.tokens.values.single, isNotEmpty);

      final draft = await repository.createDraft();
      final completedDraft = draft.copyWith(
        reference: 'Table 4',
        orderNote: 'Together',
        lines: [
          TicketLine(
            id: createLocalId(),
            name: 'Soup',
            quantity: 2,
            preparationNote: 'No cream',
          ),
        ],
      );
      final ticket = await repository.convertDraftToTicket(
        completedDraft,
        heading: 'Kitchen',
      );

      var delivery = (await repository.loadClientDeliveries()).single;
      expect(delivery.ticketId, ticket.id);
      expect(delivery.status, ClientDeliveryStatus.awaitingPrint);
      expect(delivery.envelope.reference, 'Table 4');
      expect(delivery.envelope.lines.single.name, 'Soup');

      await controller.load();
      expect(transport.loseAcknowledgement, isTrue);
      expect(
        controller.deliveryForTicket(ticket.id)?.status,
        ClientDeliveryStatus.awaitingPrint,
      );
      final failedPrint = await repository.createPrintJob(
        requestId: 'failed-print-before-server-delivery',
        ticketId: ticket.id,
        payload: Uint8List.fromList([0x1b, 0x40]),
      );
      await repository.markPrintJobSending(
        failedPrint.id,
        printerAddress: '00:11:22:33:44:55',
        printerName: 'NETUM',
      );
      await repository.markPrintJobOutcome(
        failedPrint.id,
        status: PrintJobStatus.failed,
        errorCode: 'write_failed',
      );
      await controller.load();
      expect(transport.loseAcknowledgement, isTrue);
      expect(
        controller.deliveryForTicket(ticket.id)?.status,
        ClientDeliveryStatus.awaitingPrint,
      );

      final printJob = await repository.createPrintJob(
        requestId: 'successful-print-before-server-delivery',
        ticketId: ticket.id,
        payload: Uint8List.fromList([0x1b, 0x40]),
      );
      await repository.markPrintJobSending(
        printJob.id,
        printerAddress: '00:11:22:33:44:55',
        printerName: 'NETUM',
      );
      await repository.markPrintJobOutcome(
        printJob.id,
        status: PrintJobStatus.transmitted,
      );
      await controller.ticketPrinted(ticket.id);
      delivery = controller.deliveryForTicket(ticket.id)!;
      expect(delivery.status, ClientDeliveryStatus.failed);
      expect(delivery.errorCode, 'unreachable');
      expect(await repository.loadServerOrders(), hasLength(1));

      await _waitUntil(
        () =>
            controller.deliveryForTicket(ticket.id)?.status ==
            ClientDeliveryStatus.delivered,
      );
      delivery = controller.deliveryForTicket(ticket.id)!;
      expect(delivery.status, ClientDeliveryStatus.delivered);
      expect(delivery.attemptCount, 2);
      expect(delivery.serverOrderId, isNotEmpty);
      expect(await repository.loadServerOrders(), hasLength(1));

      final pairedServer = controller.activeServer!;
      await expectLater(
        const PinnedHttpsClient().deliver(
          server: PairedServer(
            id: pairedServer.id,
            displayName: pairedServer.displayName,
            baseUrl: pairedServer.baseUrl,
            certificateFingerprint: '0' * 64,
            createdAt: pairedServer.createdAt,
            updatedAt: pairedServer.updatedAt,
          ),
          accessToken: clientSecrets.tokens.values.single,
          delivery: delivery,
        ),
        throwsA(
          isA<ClientTransportException>().having(
            (error) => error.code,
            'code',
            'certificate',
          ),
        ),
      );

      await repository.deleteTicket(ticket.id);
      expect(await repository.loadTickets(), isEmpty);
      expect(
        (await repository.loadClientDeliveries()).single.status,
        ClientDeliveryStatus.delivered,
      );
      await repository.deleteAllTickets();
      expect(
        (await repository.loadClientDeliveries()).single.status,
        ClientDeliveryStatus.delivered,
      );
    },
  );

  test('local-only items are omitted without changing the local ticket', () async {
    final now = DateTime.utc(2026, 9, 25, 12);
    await repository.savePairedServer(
      PairedServer(
        id: 'server-1',
        displayName: 'Kitchen tablet',
        baseUrl: Uri.parse('https://192.0.2.10:5119'),
        certificateFingerprint:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final included = await repository.saveItem(name: 'Soup');
    final excluded = await repository.saveItem(
      name: 'Receipt copy',
      sendToServer: false,
    );
    final draft = await repository.createDraft();
    final ticket = await repository.convertDraftToTicket(
      draft.copyWith(
        lines: [
          TicketLine(
            id: createLocalId(),
            catalogueItemId: included.id,
            name: included.name,
            quantity: 2,
          ),
          TicketLine(
            id: createLocalId(),
            catalogueItemId: excluded.id,
            name: excluded.name,
            quantity: 1,
          ),
        ],
      ),
      heading: 'Kitchen',
    );

    expect(ticket.lines.map((line) => line.name), ['Soup', 'Receipt copy']);
    final firstDelivery = (await repository.loadClientDeliveries()).single;
    expect(firstDelivery.envelope.lines, hasLength(1));
    expect(firstDelivery.envelope.lines.single.name, 'Soup');

    await repository.saveItem(
      id: excluded.id,
      name: excluded.name,
      sendToServer: true,
    );
    expect(
      (await repository.loadClientDeliveries())
          .single
          .envelope
          .lines
          .single
          .name,
      'Soup',
    );

    final localOnly = await repository.saveItem(
      name: 'Local note',
      sendToServer: false,
    );
    final secondDraft = await repository.createDraft();
    final localTicket = await repository.convertDraftToTicket(
      secondDraft.copyWith(
        lines: [
          TicketLine(
            id: createLocalId(),
            catalogueItemId: localOnly.id,
            name: localOnly.name,
            quantity: 3,
          ),
        ],
      ),
      heading: 'Kitchen',
    );

    expect(localTicket.lines.single.name, 'Local note');
    expect(await repository.loadTickets(), hasLength(2));
    expect(await repository.loadClientDeliveries(), hasLength(1));
  });

  test(
    'an unpaired client saves the same ticket without an outbox row',
    () async {
      final draft = await repository.createDraft();
      final ticket = await repository.convertDraftToTicket(
        draft.copyWith(
          lines: [TicketLine(id: createLocalId(), name: 'Tea', quantity: 1)],
        ),
        heading: 'Kitchen',
      );

      expect(ticket.lines.single.name, 'Tea');
      expect(await repository.loadClientDeliveries(), isEmpty);
    },
  );

  test('a rejected approval does not pair the Client', () async {
    final configuration = await repository.loadNetworkConfiguration();
    final serverSecrets = _MemoryServerSecrets();
    final identity = await ServerIdentityService(serverSecrets).loadOrCreate();
    final host = LocalHttpsServer(repository, serverSecrets, port: 0);
    addTearDown(host.stop);
    final running = await host.start(
      identity: identity,
      configuration: configuration,
      requestPairingApproval: (_) async => false,
      onOrderReceived: () {},
    );

    await expectLater(
      const PinnedHttpsClient().pair(
        PairServerRequest(
          baseUrl: Uri(scheme: 'https', host: '127.0.0.1', port: running.port),
          clientInstallationId: 'client-installation-1',
          clientDisplayName: 'Front counter',
          clientIdentityFingerprint: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        ),
      ),
      throwsA(
        isA<ClientTransportException>().having(
          (error) => error.code,
          'code',
          'pairing_denied',
        ),
      ),
    );
    expect(await repository.findPairedClient('client-installation-1'), isNull);
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for automatic delivery retry.');
}

class _LoseFirstAcknowledgementTransport implements ClientServerTransport {
  _LoseFirstAcknowledgementTransport(this.delegate);

  final ClientServerTransport delegate;
  var loseAcknowledgement = true;

  @override
  Future<PairServerResult> pair(PairServerRequest request) =>
      delegate.pair(request);

  @override
  Future<DeliveryAcknowledgement> deliver({
    required PairedServer server,
    required String accessToken,
    required ClientDelivery delivery,
  }) async {
    final acknowledgement = await delegate.deliver(
      server: server,
      accessToken: accessToken,
      delivery: delivery,
    );
    if (loseAcknowledgement) {
      loseAcknowledgement = false;
      throw const ClientTransportException('unreachable');
    }
    return acknowledgement;
  }
}

class _MemoryClientSecrets implements ClientSecretStore {
  final tokens = <String, String>{};

  @override
  Future<void> deleteServerAccessToken(String serverId) async {
    tokens.remove(serverId);
  }

  @override
  Future<String?> readServerAccessToken(String serverId) async =>
      tokens[serverId];

  @override
  Future<void> writeServerAccessToken(String serverId, String token) async {
    tokens[serverId] = token;
  }
}

class _MemoryServerSecrets implements ServerSecretStore {
  String? certificate;
  String? privateKey;
  final tokens = <String, String>{};

  @override
  Future<String?> readClientTokenHash(String clientInstallationId) async =>
      tokens[clientInstallationId];

  @override
  Future<String?> readServerCertificate() async => certificate;

  @override
  Future<String?> readServerPrivateKey() async => privateKey;

  @override
  Future<void> writeClientTokenHash(
    String clientInstallationId,
    String tokenHash,
  ) async {
    tokens[clientInstallationId] = tokenHash;
  }

  @override
  Future<void> writeServerIdentity({
    required String certificatePem,
    required String privateKeyPem,
  }) async {
    certificate = certificatePem;
    privateKey = privateKeyPem;
  }
}
