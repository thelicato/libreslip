import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/networking/data/local_https_server.dart';
import 'package:libreslip/features/networking/data/server_identity_service.dart';
import 'package:libreslip/features/networking/domain/network_protocol.dart';
import 'package:libreslip/features/networking/domain/server_inbox_models.dart';
import 'package:libreslip/features/networking/domain/server_security.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory temporaryDirectory;
  late String databasePath;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'libreslip-server-inbox-',
    );
    databasePath = '${temporaryDirectory.path}/orders.sqlite3';
  });

  tearDown(() async {
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'receipt is transactional, idempotent and Done survives restart',
    () async {
      final repository = SqliteOrderRepository(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: databasePath,
      );
      await repository.open();
      await repository.pairClient(_client);
      final envelope = _envelope();

      final first = await repository.receiveServerOrder(
        envelope,
        receivedAt: DateTime.utc(2026, 9, 24, 19),
      );
      final repeated = await repository.receiveServerOrder(
        envelope,
        receivedAt: DateTime.utc(2026, 9, 24, 19, 1),
      );

      expect(first.wasDuplicate, isFalse);
      expect(repeated.wasDuplicate, isTrue);
      expect(repeated.order.id, first.order.id);
      expect((await repository.loadServerOrders()), hasLength(1));

      final conflicting = _envelope(itemName: 'Changed after retry');
      await expectLater(
        repository.receiveServerOrder(
          conflicting,
          receivedAt: DateTime.utc(2026, 9, 24, 19, 2),
        ),
        throwsA(isA<ServerOrderConflictException>()),
      );
      await repository.markServerOrderDone(
        first.order.id,
        completedAt: DateTime.utc(2026, 9, 24, 19, 3),
      );
      await repository.close();

      final reopened = SqliteOrderRepository(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: databasePath,
      );
      await reopened.open();
      var restored = (await reopened.loadServerOrders()).single;
      expect(restored.status, ServerOrderStatus.done);
      expect(restored.lines.single.name, 'Soup');
      expect(restored.completedAt, DateTime.utc(2026, 9, 24, 19, 3));

      await reopened.markServerOrderReceived(restored.id);
      await reopened.close();
      final reopenedAgain = SqliteOrderRepository(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: databasePath,
      );
      addTearDown(reopenedAgain.close);
      await reopenedAgain.open();
      restored = (await reopenedAgain.loadServerOrders()).single;
      expect(restored.status, ServerOrderStatus.received);
      expect(restored.completedAt, isNull);
    },
  );

  test('only Completed Server orders can be deleted', () async {
    final repository = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: databasePath,
    );
    addTearDown(repository.close);
    await repository.open();
    await repository.pairClient(_client);
    final first = await repository.receiveServerOrder(
      _envelope(),
      receivedAt: DateTime.utc(2026, 9, 24, 19),
    );
    final second = await repository.receiveServerOrder(
      _envelope(
        deliveryId: 'delivery-2',
        ticketId: 'ticket-2',
        ticketNumber: 18,
      ),
      receivedAt: DateTime.utc(2026, 9, 24, 19, 1),
    );

    await expectLater(
      repository.deleteCompletedServerOrder(second.order.id),
      throwsA(isA<Exception>()),
    );
    await repository.markServerOrderDone(
      first.order.id,
      completedAt: DateTime.utc(2026, 9, 24, 19, 2),
    );
    await repository.deleteCompletedServerOrder(first.order.id);
    var remaining = await repository.loadServerOrders();
    expect(remaining.map((order) => order.id), [second.order.id]);
    expect(remaining.single.status, ServerOrderStatus.received);

    await repository.markServerOrderDone(
      second.order.id,
      completedAt: DateTime.utc(2026, 9, 24, 19, 3),
    );
    expect(await repository.deleteAllCompletedServerOrders(), 1);
    expect(await repository.loadServerOrders(), isEmpty);
    expect(await repository.deleteAllCompletedServerOrders(), 0);
  });

  test('HTTPS pairing authorises one client and duplicate delivery once', () async {
    final repository = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: databasePath,
    );
    addTearDown(repository.close);
    await repository.open();
    final configuration = await repository.loadNetworkConfiguration();
    final secrets = _MemoryServerSecrets();
    final identityService = ServerIdentityService(secrets);
    final identity = await identityService.loadOrCreate();
    expect(
      (await identityService.loadOrCreate()).certificateFingerprint,
      identity.certificateFingerprint,
    );
    final host = LocalHttpsServer(repository, secrets, port: 0);
    addTearDown(host.stop);
    var pairingAvailable = true;
    final running = await host.start(
      identity: identity,
      configuration: configuration,
      requestPairingApproval: (request) async {
        if (!pairingAvailable) return false;
        expect(request.clientInstallationId, _client.installationId);
        expect(request.sourceAddress, '127.0.0.1');
        pairingAvailable = false;
        return true;
      },
      onOrderReceived: () {},
    );
    final client = HttpClient()
      ..badCertificateCallback = (certificate, host, port) {
        expect(
          sha256.convert(certificate.der).toString(),
          identity.certificateFingerprint,
        );
        return true;
      };
    addTearDown(() => client.close(force: true));
    final base = Uri.parse('https://127.0.0.1:${running.port}');

    final pair = await _postJson(client, base.resolve('/v1/pair'), {
      'clientInstallationId': _client.installationId,
      'displayName': _client.displayName,
      'clientIdentityFingerprint': _client.identityFingerprint,
    });
    expect(pair.statusCode, HttpStatus.created);
    final token = pair.body['accessToken']! as String;
    expect(token, isNotEmpty);
    final repeatedPairing = await _postJson(client, base.resolve('/v1/pair'), {
      'clientInstallationId': 'client-installation-2',
      'displayName': 'Other client',
      'clientIdentityFingerprint':
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    });
    expect(repeatedPairing.statusCode, HttpStatus.forbidden);

    final unauthorised = await _postJson(
      client,
      base.resolve('/v1/orders'),
      _envelope().toJson(),
    );
    expect(unauthorised.statusCode, HttpStatus.unauthorized);

    final headers = {
      HttpHeaders.authorizationHeader: 'Bearer $token',
      'x-libreslip-client-id': _client.installationId,
    };
    try {
      final oversized = await _postJson(client, base.resolve('/v1/orders'), {
        'payload': List.filled(NetworkProtocol.maxEnvelopeBytes, 'x').join(),
      }, headers: headers);
      expect(oversized.statusCode, HttpStatus.requestEntityTooLarge);
    } on HttpException {
      // Closing an over-limit upload before it finishes is also a safe rejection.
    }

    final accepted = await _postJson(
      client,
      base.resolve('/v1/orders'),
      _envelope().toJson(),
      headers: headers,
    );
    final repeated = await _postJson(
      client,
      base.resolve('/v1/orders'),
      _envelope().toJson(),
      headers: headers,
    );
    expect(accepted.statusCode, HttpStatus.created);
    expect(accepted.body['duplicate'], isFalse);
    expect(repeated.statusCode, HttpStatus.ok);
    expect(repeated.body['duplicate'], isTrue);
    expect(repeated.body['serverOrderId'], accepted.body['serverOrderId']);
    expect(await repository.loadServerOrders(), hasLength(1));
    final snapshotText = jsonEncode(await repository.createPortableSnapshot());
    expect(snapshotText, isNot(contains(token)));
    expect(snapshotText, isNot(contains('Together')));
  });
}

final _client = PairedClient(
  installationId: 'client-installation-1',
  displayName: 'Front counter',
  identityFingerprint:
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  pairedAt: _pairedAt,
);
final _pairedAt = DateTime.utc(2026, 9, 24, 18);

OrderDeliveryEnvelope _envelope({
  String itemName = 'Soup',
  String deliveryId = 'delivery-1',
  String ticketId = 'ticket-1',
  int ticketNumber = 17,
}) => OrderDeliveryEnvelope.create(
  clientInstallationId: _client.installationId,
  deliveryId: deliveryId,
  ticketId: ticketId,
  ticketNumber: ticketNumber,
  createdAt: DateTime.utc(2026, 9, 24, 18, 30),
  heading: 'Kitchen',
  reference: 'Table 4',
  orderNote: 'Together',
  lines: [
    DeliveryLine(name: itemName, quantity: 2, preparationNote: 'No cream'),
  ],
);

class _JsonResponse {
  const _JsonResponse(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;
}

Future<_JsonResponse> _postJson(
  HttpClient client,
  Uri uri,
  Map<String, Object?> body, {
  Map<String, String> headers = const {},
}) async {
  final request = await client.postUrl(uri);
  request.headers.contentType = ContentType.json;
  for (final entry in headers.entries) {
    request.headers.set(entry.key, entry.value);
  }
  request.write(jsonEncode(body));
  final response = await request.close();
  final source = await utf8.decoder.bind(response).join();
  return _JsonResponse(
    response.statusCode,
    jsonDecode(source) as Map<String, dynamic>,
  );
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
