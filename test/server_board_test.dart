import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
import 'package:libreslip/features/networking/application/network_mode_controller.dart';
import 'package:libreslip/features/networking/application/server_inbox_controller.dart';
import 'package:libreslip/features/networking/domain/network_models.dart';
import 'package:libreslip/features/networking/domain/network_protocol.dart';
import 'package:libreslip/features/networking/domain/server_inbox_models.dart';
import 'package:libreslip/features/networking/domain/server_security.dart';
import 'package:libreslip/features/networking/domain/server_transport.dart';
import 'package:libreslip/features/settings/application/settings_controller.dart';

import 'test_support.dart';

void main() {
  test('outstanding totals aggregate Received orders and ignore Done', () {
    ServerOrder order(
      String id,
      ServerOrderStatus status,
      List<ServerOrderLine> lines,
    ) => ServerOrder(
      id: id,
      clientInstallationId: 'client-1',
      clientDisplayName: 'Front counter',
      deliveryId: 'delivery-$id',
      clientTicketId: 'ticket-$id',
      displayNumber: 1,
      sourceCreatedAt: DateTime.utc(2026, 9, 25),
      receivedAt: DateTime.utc(2026, 9, 25),
      heading: 'Kitchen',
      reference: '',
      orderNote: '',
      lines: lines,
      payloadChecksum:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      status: status,
    );

    final totals = summariseOutstandingItems([
      order('one', ServerOrderStatus.received, const [
        ServerOrderLine(name: 'Soup', quantity: 2),
        ServerOrderLine(name: 'Tea', quantity: 1),
      ]),
      order('two', ServerOrderStatus.received, const [
        ServerOrderLine(name: 'soup', quantity: 3),
      ]),
      order('done', ServerOrderStatus.done, const [
        ServerOrderLine(name: 'Soup', quantity: 9),
      ]),
    ]);

    expect(totals.map((total) => total.name), ['Soup', 'Tea']);
    expect(totals.map((total) => total.quantity), [5, 1]);
  });

  testWidgets('received order detail can be marked Done', (tester) async {
    tester.view.physicalSize = const Size(520, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final environment = await createMemoryOrderEnvironment();
    final repository = environment.repository;
    await repository.pairClient(
      PairedClient(
        installationId: 'client-1',
        displayName: 'Front counter',
        identityFingerprint:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        pairedAt: DateTime.utc(2026, 9, 24, 18),
      ),
    );
    await repository.receiveServerOrder(
      OrderDeliveryEnvelope.create(
        clientInstallationId: 'client-1',
        deliveryId: 'delivery-1',
        ticketId: 'ticket-1',
        ticketNumber: 17,
        createdAt: DateTime.utc(2026, 9, 24, 18, 30),
        heading: 'Kitchen',
        reference: 'Table 4',
        orderNote: 'Together',
        lines: const [
          DeliveryLine(name: 'Soup', quantity: 2, preparationNote: 'No cream'),
        ],
      ),
      receivedAt: DateTime.utc(2026, 9, 24, 18, 31),
    );
    final settings = SettingsController(MemorySettingsRepository());
    final networking = NetworkModeController(repository);
    final inbox = ServerInboxController(
      repository,
      _MemoryServerSecrets(),
      _FakeServerHost(),
    );
    addTearDown(settings.dispose);
    addTearDown(environment.controller.dispose);
    addTearDown(networking.dispose);
    addTearDown(inbox.dispose);
    await settings.load();
    await networking.load();
    await networking.setMode(LibreSlipMode.server);

    await tester.pumpWidget(
      LibreSlipApp(
        settings: settings,
        orders: environment.controller,
        networking: networking,
        serverInbox: inbox,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Order 17'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('outstanding-items-card')),
      findsOneWidget,
    );
    expect(find.text('Still to prepare'), findsOneWidget);
    expect(find.text('Soup'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Ready to receive'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('server-tab-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('server-settings-page')), findsOneWidget);
    expect(find.text('Ready to receive'), findsOneWidget);
    expect(find.text('Order 17'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('server-tab-orders')));
    await tester.pumpAndSettle();

    final receivedId = inbox.receivedOrders.single.id;
    await tester.ensureVisible(find.text('Order 17'));
    await tester.pumpAndSettle();
    final orderFinder = find.byKey(ValueKey('server-order-$receivedId'));
    await tester.tap(orderFinder);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('2×  Soup'), findsOneWidget);
    expect(find.text('No cream'), findsOneWidget);
    expect(find.text('Front counter'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('mark-order-done')));
    await tester.pumpAndSettle();
    expect(inbox.receivedOrders, isEmpty);
    expect(inbox.completedOrders, hasLength(1));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('outstanding-items-card')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Nothing is waiting to be prepared.'), findsOneWidget);

    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Order 17'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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

class _FakeServerHost implements ServerHost {
  @override
  Future<RunningServer> start({
    required ServerIdentity identity,
    required NetworkConfiguration configuration,
    required bool Function(String code) claimPairingCode,
    required void Function() onOrderReceived,
  }) async =>
      const RunningServer(port: 5119, addresses: ['https://192.0.2.10:5119']);

  @override
  Future<void> stop() async {}
}
