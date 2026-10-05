import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/networking/application/client_delivery_controller.dart';
import 'package:libreslip/features/networking/data/local_https_server.dart';
import 'package:libreslip/features/networking/data/pinned_https_client.dart';
import 'package:libreslip/features/networking/data/server_identity_service.dart';
import 'package:libreslip/features/networking/domain/client_delivery_models.dart';
import 'package:libreslip/features/networking/domain/network_protocol.dart';
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
        courses: const [OrderCourse(id: 'first-course', name: 'First course')],
        orderNote: 'Together',
        lines: [
          TicketLine(
            id: createLocalId(),
            name: 'Soup',
            quantity: 2,
            preparationNote: 'No cream',
            courseId: 'first-course',
          ),
        ],
      );
      final ticket = await repository.convertDraftToTicket(
        completedDraft,
        heading: 'Kitchen',
        keepOpen: true,
      );

      var delivery = (await repository.loadClientDeliveries()).single;
      expect(delivery.ticketId, ticket.id);
      expect(delivery.status, ClientDeliveryStatus.awaitingPrint);
      await repository.convertDraftToTicket(
        completedDraft,
        heading: 'Kitchen',
        requirePrintForDelivery: false,
      );
      expect(
        (await repository.loadClientDeliveries()).single.status,
        ClientDeliveryStatus.awaitingPrint,
      );
      expect(delivery.envelope.reference, 'Table 4');
      expect(delivery.envelope.lines.single.name, 'Soup');
      expect(delivery.envelope.version, 3);
      expect(delivery.envelope.courses.single.name, 'First course');

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
      expect(
        (await repository.loadServerOrders()).single.courses.single.name,
        'First course',
      );
      expect(
        (await repository.loadServerOrders()).single.lines.single.courseId,
        'first-course',
      );

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

      final managed = (await repository.loadManagedOrders()).single;
      final received = (await repository.loadServerOrders()).single;
      await repository.markServerOrderDone(
        received.id,
        completedAt: DateTime.now().toUtc(),
      );
      final blankAddition = await repository.createDraft();
      final addition = await repository.beginOrderAddition(
        managed.id,
        blankAddition.id,
      );
      final additionsTicket = await repository.convertDraftToTicket(
        addition.copyWith(
          lines: const [
            TicketLine(
              id: 'water-addition',
              name: 'Water',
              quantity: 2,
              courseId: 'first-course',
            ),
          ],
        ),
        heading: 'Kitchen',
      );
      final addedPrint = await repository.createPrintJob(
        requestId: 'additions-print',
        ticketId: additionsTicket.id,
        payload: Uint8List.fromList([27, 64]),
      );
      await repository.markPrintJobSending(
        addedPrint.id,
        printerAddress: '00:11',
        printerName: 'NETUM',
      );
      await repository.markPrintJobOutcome(
        addedPrint.id,
        status: PrintJobStatus.transmitted,
      );
      await controller.ticketPrinted(additionsTicket.id);
      expect(
        controller.deliveryForTicket(additionsTicket.id)!.serverOrderId,
        received.id,
      );
      final updatedOrder = (await repository.loadServerOrders()).single;
      expect(updatedOrder.id, received.id);
      expect(updatedOrder.revision, 2);
      expect(updatedOrder.lines.map((line) => line.name), ['Soup', 'Water']);
      expect(updatedOrder.lines.last.addedRevision, 2);

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
      expect(await repository.loadTickets(), hasLength(1));
      expect(
        (await repository.loadClientDeliveries()).first.status,
        ClientDeliveryStatus.delivered,
      );
      await repository.deleteAllTickets();
      expect(
        (await repository.loadClientDeliveries()).first.status,
        ClientDeliveryStatus.delivered,
      );
    },
  );

  test('optional orders recover after restart and lost acknowledgement without any print job', () async {
    final configuration = await repository.loadNetworkConfiguration();
    final secrets = _MemoryServerSecrets();
    final identity = await ServerIdentityService(secrets).loadOrCreate();
    final host = LocalHttpsServer(repository, secrets, port: 0);
    addTearDown(host.stop);
    final running = await host.start(
      identity: identity,
      configuration: configuration,
      requestPairingApproval: (_) async => true,
      onOrderReceived: () {},
    );
    final transport = _LoseFirstAcknowledgementTransport(
      const PinnedHttpsClient(),
    );
    final clientSecrets = _MemoryClientSecrets();
    final firstController = ClientDeliveryController(
      repository,
      clientSecrets,
      transport,
    );
    await firstController.load();
    expect(
      await firstController.pair(
        configuration: configuration,
        address: '127.0.0.1:${running.port}',
        clientName: 'Client',
      ),
      isTrue,
    );
    firstController.dispose();
    final draft = (await repository.createDraft()).copyWith(
      reference: 'Table 4',
      lines: const [TicketLine(id: 'soup', name: 'Soup', quantity: 1)],
    );
    final first = await repository.convertDraftToTicket(
      draft,
      heading: 'Kitchen',
      keepOpen: true,
      requirePrintForDelivery: false,
    );
    expect(
      (await repository.loadClientDeliveries()).single.status,
      ClientDeliveryStatus.pending,
    );
    // Repeating creation with the default policy keeps the original readiness.
    final repeat = await repository.convertDraftToTicket(
      draft,
      heading: 'Kitchen',
    );
    expect(repeat.id, first.id);
    expect(await repository.loadClientDeliveries(), hasLength(1));
    await repository.close();
    await repository.open();
    final restarted = ClientDeliveryController(
      repository,
      clientSecrets,
      transport,
      retryDelay: const Duration(milliseconds: 20),
    );
    addTearDown(restarted.dispose);
    await restarted.load();
    await _waitUntil(
      () =>
          restarted.deliveryForTicket(first.id)?.status ==
          ClientDeliveryStatus.delivered,
    );
    expect(transport.attemptedRevisions, [1, 1]);
    expect(await repository.loadServerOrders(), hasLength(1));
    final blank = await repository.createDraft();
    final addition = await repository.beginOrderAddition(
      (await repository.loadManagedOrders()).single.id,
      blank.id,
    );
    final second = await repository.convertDraftToTicket(
      addition.copyWith(
        lines: const [TicketLine(id: 'water', name: 'Water', quantity: 2)],
      ),
      heading: 'Kitchen',
      requirePrintForDelivery: false,
    );
    await restarted.ticketReady(second.id);
    expect(transport.attemptedRevisions, [1, 1, 2]);
    expect(
      restarted.deliveryForTicket(second.id)!.status,
      ClientDeliveryStatus.delivered,
    );
    final received = (await repository.loadServerOrders()).single;
    expect(received.revision, 2);
    expect(received.lines.map((line) => line.name), ['Soup', 'Water']);
    expect(await repository.loadPrintJobs(), isEmpty);
    expect(await repository.loadTickets(), hasLength(2));
  });

  for (final optionalAddition in [false, true]) {
    test(
      'later revisions (optional printer: $optionalAddition) wait for uncertain earlier printing and lost acknowledgements, then drain in order',
      () async {
        final configuration = await repository.loadNetworkConfiguration();
        final secrets = _MemoryServerSecrets();
        final identity = await ServerIdentityService(secrets).loadOrCreate();
        final host = LocalHttpsServer(repository, secrets, port: 0);
        addTearDown(host.stop);
        final running = await host.start(
          identity: identity,
          configuration: configuration,
          requestPairingApproval: (_) async => true,
          onOrderReceived: () {},
        );
        final transport = _LoseFirstAcknowledgementTransport(
          const PinnedHttpsClient(),
        );
        final controller = ClientDeliveryController(
          repository,
          _MemoryClientSecrets(),
          transport,
          retryDelay: const Duration(days: 1),
        );
        addTearDown(controller.dispose);
        await controller.load();
        expect(
          await controller.pair(
            configuration: configuration,
            address: '127.0.0.1:${running.port}',
            clientName: 'Client',
          ),
          isTrue,
        );
        final draft = await repository.createDraft();
        final first = await repository.convertDraftToTicket(
          draft.copyWith(
            lines: const [TicketLine(id: 'soup', name: 'Soup', quantity: 1)],
          ),
          heading: 'Kitchen',
          keepOpen: true,
        );
        final blank = await repository.createDraft();
        final addition = await repository.beginOrderAddition(
          (await repository.loadManagedOrders()).single.id,
          blank.id,
        );
        final second = await repository.convertDraftToTicket(
          addition.copyWith(
            lines: const [TicketLine(id: 'water', name: 'Water', quantity: 2)],
          ),
          heading: 'Kitchen',
          requirePrintForDelivery: !optionalAddition,
        );
        Future<void> finishPrint(
          SavedTicket ticket,
          String requestId,
          PrintJobStatus status,
        ) async {
          final job = await repository.createPrintJob(
            requestId: requestId,
            ticketId: ticket.id,
            payload: Uint8List.fromList([27, 64]),
          );
          await repository.markPrintJobSending(
            job.id,
            printerAddress: '00:11',
            printerName: 'NETUM',
          );
          await repository.markPrintJobOutcome(job.id, status: status);
          await controller.ticketPrinted(ticket.id);
        }

        if (optionalAddition) {
          await controller.ticketReady(second.id);
          expect(await repository.loadPrintJobs(), isEmpty);
          expect(
            controller.deliveryForTicket(second.id)!.status,
            ClientDeliveryStatus.pending,
          );
        } else {
          await finishPrint(second, 'print-second', PrintJobStatus.transmitted);
        }
        expect(transport.attemptedRevisions, isEmpty);
        await finishPrint(
          first,
          'print-first-uncertain',
          PrintJobStatus.uncertain,
        );
        expect(transport.attemptedRevisions, isEmpty);
        await finishPrint(
          first,
          'explicit-reprint-first',
          PrintJobStatus.transmitted,
        );
        expect(transport.attemptedRevisions, [1]);
        expect(
          controller.deliveryForTicket(first.id)!.errorCode,
          'unreachable',
        );
        expect(
          await controller.retry(controller.deliveryForTicket(second.id)!.id),
          isFalse,
        );
        expect(transport.attemptedRevisions, [1]);
        expect(
          await controller.retry(controller.deliveryForTicket(first.id)!.id),
          isTrue,
        );
        expect(transport.attemptedRevisions, [1, 1, 2]);
        expect(
          controller.deliveryForTicket(second.id)!.status,
          ClientDeliveryStatus.delivered,
        );
        expect((await repository.loadServerOrders()).single.revision, 2);
        expect(
          controller.deliveryForTicket(second.id)!.serverOrderId,
          controller.deliveryForTicket(first.id)!.serverOrderId,
        );
      },
    );
  }

  for (final managed in [false, true]) {
    test(
      'version ${managed ? 3 : 2} delivery sends nothing to an older Server and succeeds after explicit retry',
      () async {
        final identity = await ServerIdentityService(_MemoryServerSecrets())
            .loadOrCreate();
        final context = SecurityContext(withTrustedRoots: false)
          ..useCertificateChainBytes(utf8.encode(identity.certificatePem))
          ..usePrivateKeyBytes(utf8.encode(identity.privateKeyPem));
        final host = await HttpServer.bindSecure(
          InternetAddress.loopbackIPv4,
          0,
          context,
        );
        addTearDown(() => host.close(force: true));
        var supportsCourses = false;
        var posts = 0;
        OrderDeliveryEnvelope? accepted;
        host.listen((request) async {
          request.response.headers.contentType = ContentType.json;
          if (request.uri.path == '/v1/status') {
            request.response.write(
              jsonEncode({
                'protocol': NetworkProtocol.name,
                'version': 1,
                'serverInstallationId': 'server-1',
                'orderVersions': supportsCourses
                    ? [1, 2, 3]
                    : managed
                    ? [1, 2]
                    : [1],
              }),
            );
          } else {
            posts++;
            accepted = OrderDeliveryEnvelope.fromJsonString(
              await utf8.decoder.bind(request).join(),
            );
            request.response.statusCode = HttpStatus.created;
            request.response.write(
              jsonEncode({
                'protocol': NetworkProtocol.name,
                'version': accepted!.version,
                'deliveryId': accepted!.deliveryId,
                'serverOrderId': 'received-1',
                'duplicate': false,
              }),
            );
          }
          await request.response.close();
        });
        final now = DateTime.utc(2026, 10, 5);
        final envelope = OrderDeliveryEnvelope.create(
          managedOrderId: managed ? 'active-order' : null,
          revision: managed ? 1 : 0,
          clientInstallationId: 'client-1',
          deliveryId: 'delivery-1',
          ticketId: 'ticket-1',
          ticketNumber: 1,
          createdAt: now,
          heading: 'Kitchen',
          reference: 'Table 4',
          orderNote: '',
          courses: const [
            OrderCourse(id: 'first', name: 'First course'),
            OrderCourse(id: 'second', name: 'Second course'),
          ],
          lines: [
            DeliveryLine(
              id: managed ? 'soup-line' : null,
              name: 'Soup',
              quantity: 2,
              courseId: 'first',
            ),
          ],
        );
        final delivery = ClientDelivery(
          id: 'delivery-1',
          destinationId: 'server-1',
          clientInstallationId: 'client-1',
          ticketId: 'ticket-1',
          ticketNumber: 1,
          envelope: envelope,
          status: ClientDeliveryStatus.pending,
          attemptCount: 0,
          createdAt: now,
          updatedAt: now,
        );
        final server = PairedServer(
          id: 'server-1',
          displayName: 'Kitchen',
          baseUrl: Uri.parse('https://127.0.0.1:${host.port}'),
          certificateFingerprint: identity.certificateFingerprint,
          createdAt: now,
          updatedAt: now,
        );
        const transport = PinnedHttpsClient();
        await expectLater(
          transport.deliver(
            server: server,
            accessToken: 'preview-token',
            delivery: delivery,
          ),
          throwsA(
            isA<ClientTransportException>().having(
              (error) => error.code,
              'code',
              managed ? 'unsupported_updates' : 'unsupported_courses',
            ),
          ),
        );
        expect(posts, 0);
        expect(delivery.envelope.courses, hasLength(2));
        supportsCourses = true;
        final result = await transport.deliver(
          server: server,
          accessToken: 'preview-token',
          delivery: delivery,
        );
        expect(result.serverOrderId, 'received-1');
        expect(posts, 1);
        expect(accepted!.lines.single.courseId, 'first');
        expect(accepted!.courses.map((course) => course.name), [
          'First course',
          'Second course',
        ]);
      },
    );
  }

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
        courses: const [
          OrderCourse(id: 'first', name: 'First course'),
          OrderCourse(id: 'local', name: 'Private local group'),
        ],
        lines: [
          TicketLine(
            id: createLocalId(),
            catalogueItemId: included.id,
            name: included.name,
            quantity: 2,
            courseId: 'first',
          ),
          TicketLine(
            id: createLocalId(),
            catalogueItemId: excluded.id,
            name: excluded.name,
            quantity: 1,
            courseId: 'local',
          ),
        ],
      ),
      heading: 'Kitchen',
    );

    expect(ticket.lines.map((line) => line.name), ['Soup', 'Receipt copy']);
    final firstDelivery = (await repository.loadClientDeliveries()).single;
    expect(firstDelivery.envelope.lines, hasLength(1));
    expect(firstDelivery.envelope.lines.single.name, 'Soup');
    expect(firstDelivery.envelope.courses.map((course) => course.name), [
      'First course',
    ]);
    expect(ticket.courses, hasLength(2));

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
  final attemptedRevisions = <int>[];

  @override
  Future<PairServerResult> pair(PairServerRequest request) =>
      delegate.pair(request);

  @override
  Future<DeliveryAcknowledgement> deliver({
    required PairedServer server,
    required String accessToken,
    required ClientDelivery delivery,
  }) async {
    attemptedRevisions.add(delivery.envelope.revision);
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
