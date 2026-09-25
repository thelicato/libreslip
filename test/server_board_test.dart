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

  test('Server orders load oldest first', () async {
    final environment = await createMemoryOrderEnvironment();
    addTearDown(environment.controller.dispose);
    final repository = environment.repository;
    await repository.pairClient(
      PairedClient(
        installationId: 'client-1',
        displayName: 'Front counter',
        identityFingerprint: 'b' * 64,
        pairedAt: DateTime.utc(2026, 9, 25, 8),
      ),
    );
    Future<void> receive({
      required String id,
      required int number,
      required DateTime receivedAt,
    }) => repository
        .receiveServerOrder(
          OrderDeliveryEnvelope.create(
            clientInstallationId: 'client-1',
            deliveryId: 'delivery-$id',
            ticketId: 'ticket-$id',
            ticketNumber: number,
            createdAt: receivedAt.subtract(const Duration(minutes: 1)),
            heading: 'Kitchen',
            reference: '',
            orderNote: '',
            lines: const [DeliveryLine(name: 'Soup', quantity: 1)],
          ),
          receivedAt: receivedAt,
        )
        .then((_) {});

    await receive(
      id: 'newer',
      number: 2,
      receivedAt: DateTime.utc(2026, 9, 25, 10),
    );
    await receive(
      id: 'older',
      number: 1,
      receivedAt: DateTime.utc(2026, 9, 25, 9),
    );

    expect(
      (await repository.loadServerOrders()).map((order) => order.displayNumber),
      [1, 2],
    );
  });

  testWidgets('Server board aligns pairs and Done can be undone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 900);
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
    await repository.receiveServerOrder(
      OrderDeliveryEnvelope.create(
        clientInstallationId: 'client-1',
        deliveryId: 'delivery-2',
        ticketId: 'ticket-2',
        ticketNumber: 18,
        createdAt: DateTime.utc(2026, 9, 24, 18, 32),
        heading: 'Kitchen',
        reference: '',
        orderNote: '',
        lines: const [DeliveryLine(name: 'Tea', quantity: 1)],
      ),
      receivedAt: DateTime.utc(2026, 9, 24, 18, 33),
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
    expect(find.text('Order 18'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('outstanding-items-card')),
      findsOneWidget,
    );
    expect(find.text('Still to prepare'), findsOneWidget);
    expect(find.text('Soup'), findsWidgets);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Ready to receive'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('server-tab-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('server-settings-page')), findsOneWidget);
    expect(find.text('Ready to receive'), findsOneWidget);
    expect(find.text('Order 17'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('server-tab-orders')));
    await tester.pumpAndSettle();

    final firstOrder = inbox.receivedOrders.singleWhere(
      (order) => order.displayNumber == 17,
    );
    final secondOrder = inbox.receivedOrders.singleWhere(
      (order) => order.displayNumber == 18,
    );
    await tester.ensureVisible(find.text('Order 17'));
    await tester.pumpAndSettle();
    final orderFinder = find.byKey(ValueKey('server-order-${firstOrder.id}'));
    final secondOrderFinder = find.byKey(
      ValueKey('server-order-${secondOrder.id}'),
    );
    expect(
      find.descendant(of: orderFinder, matching: find.text('2×')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: orderFinder, matching: find.text('Soup')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: orderFinder, matching: find.text('No cream')),
      findsOneWidget,
    );
    expect(find.text('Front counter'), findsNothing);
    final firstRect = tester.getRect(orderFinder);
    final secondRect = tester.getRect(secondOrderFinder);
    final summaryRect = tester.getRect(
      find.byKey(const ValueKey('outstanding-items-card')),
    );
    expect(firstRect.top, secondRect.top);
    expect(firstRect.width, closeTo(secondRect.width, 0.1));
    expect(secondRect.right - firstRect.left, closeTo(summaryRect.width, 0.1));
    await tester.tap(orderFinder);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.getSize(find.byType(AlertDialog)).width, greaterThan(680));
    expect(find.text('2×  Soup'), findsOneWidget);
    expect(find.text('No cream'), findsWidgets);
    expect(find.text('Front counter'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('mark-order-done')));
    await tester.pumpAndSettle();
    expect(inbox.receivedOrders, hasLength(1));
    expect(inbox.completedOrders, hasLength(1));

    await tester.ensureVisible(find.text('Order 18'));
    await tester.tap(secondOrderFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mark-order-done')));
    await tester.pumpAndSettle();
    expect(inbox.receivedOrders, isEmpty);
    expect(inbox.completedOrders, hasLength(2));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('outstanding-items-card')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Nothing is waiting to be prepared.'), findsOneWidget);

    await tester.tap(find.text('Completed (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Order 17'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('server-order-${firstOrder.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mark-order-received')));
    await tester.pumpAndSettle();
    expect(inbox.receivedOrders, hasLength(1));
    expect(inbox.completedOrders, hasLength(1));
    await tester.tap(find.text('Received (1)'));
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
    required Future<bool> Function(ClientPairingRequest request)
    requestPairingApproval,
    required void Function() onOrderReceived,
  }) async =>
      const RunningServer(port: 5119, addresses: ['https://192.0.2.10:5119']);

  @override
  Future<void> stop() async {}
}
