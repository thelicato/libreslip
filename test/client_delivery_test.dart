import 'dart:io';

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
    'pinned pairing and a lost acknowledgement retry store one server order',
    () async {
      final configuration = await repository.loadNetworkConfiguration();
      final serverSecrets = _MemoryServerSecrets();
      final identity = await ServerIdentityService(serverSecrets)
          .loadOrCreate();
      final host = LocalHttpsServer(repository, serverSecrets, port: 0);
      addTearDown(host.stop);
      var pairingOpen = true;
      final running = await host.start(
        identity: identity,
        configuration: configuration,
        claimPairingCode: (code) {
          if (!pairingOpen || code != '123456') return false;
          pairingOpen = false;
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
      );
      addTearDown(controller.dispose);
      await controller.load();

      expect(
        await controller.pair(
          configuration: configuration,
          address: '127.0.0.1:${running.port}',
          fingerprint: _spaced(identity.certificateFingerprint),
          code: '123456',
          clientName: 'Front counter',
        ),
        isTrue,
      );
      expect(controller.activeServer?.id, configuration.installationId);
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
      expect(delivery.status, ClientDeliveryStatus.pending);
      expect(delivery.envelope.reference, 'Table 4');
      expect(delivery.envelope.lines.single.name, 'Soup');

      await controller.ticketFinalised(ticket.id);
      delivery = controller.deliveryForTicket(ticket.id)!;
      expect(delivery.status, ClientDeliveryStatus.failed);
      expect(delivery.errorCode, 'unreachable');
      expect(await repository.loadServerOrders(), hasLength(1));

      expect(await controller.retry(delivery.id), isTrue);
      delivery = controller.deliveryForTicket(ticket.id)!;
      expect(delivery.status, ClientDeliveryStatus.delivered);
      expect(delivery.attemptCount, 2);
      expect(delivery.serverOrderId, isNotEmpty);
      expect(await repository.loadServerOrders(), hasLength(1));

      await repository.deleteTicket(ticket.id);
      expect(await repository.loadTickets(), isEmpty);
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
        baseUrl: Uri.parse('https://192.0.2.10:42837'),
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

  test('a mismatched self-signed certificate is rejected', () async {
    final configuration = await repository.loadNetworkConfiguration();
    final serverSecrets = _MemoryServerSecrets();
    final identity = await ServerIdentityService(serverSecrets).loadOrCreate();
    final host = LocalHttpsServer(repository, serverSecrets, port: 0);
    addTearDown(host.stop);
    final running = await host.start(
      identity: identity,
      configuration: configuration,
      claimPairingCode: (_) => true,
      onOrderReceived: () {},
    );

    await expectLater(
      const PinnedHttpsClient().pair(
        PairServerRequest(
          baseUrl: Uri(scheme: 'https', host: '127.0.0.1', port: 1),
          certificateFingerprint: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          code: '123456',
          clientInstallationId: 'client-installation-1',
          clientDisplayName: 'Front counter',
          clientIdentityFingerprint: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        ).withPort(running.port),
      ),
      throwsA(
        isA<ClientTransportException>().having(
          (error) => error.code,
          'code',
          'certificate',
        ),
      ),
    );
  });
}

extension on PairServerRequest {
  PairServerRequest withPort(int port) => PairServerRequest(
    baseUrl: Uri(scheme: 'https', host: baseUrl.host, port: port),
    certificateFingerprint: certificateFingerprint,
    code: code,
    clientInstallationId: clientInstallationId,
    clientDisplayName: clientDisplayName,
    clientIdentityFingerprint: clientIdentityFingerprint,
  );
}

String _spaced(String fingerprint) {
  final groups = <String>[];
  for (var index = 0; index < fingerprint.length; index += 8) {
    groups.add(fingerprint.substring(index, index + 8).toUpperCase());
  }
  return groups.join(' ');
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
