import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
import 'package:libreslip/features/networking/application/client_delivery_controller.dart';
import 'package:libreslip/features/networking/application/network_mode_controller.dart';
import 'package:libreslip/features/networking/domain/client_delivery_models.dart';
import 'package:libreslip/features/networking/domain/client_security.dart';
import 'package:libreslip/features/networking/domain/client_transport.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:libreslip/features/settings/application/settings_controller.dart';

import 'test_support.dart';

void main() {
  testWidgets('client pairs and retries a failed delivery from ticket detail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final environment = await createMemoryOrderEnvironment();
    final settings = SettingsController(MemorySettingsRepository());
    final networking = NetworkModeController(environment.repository);
    final transport = _FakeClientTransport();
    final delivery = ClientDeliveryController(
      environment.repository,
      _MemoryClientSecrets(),
      transport,
    );
    addTearDown(settings.dispose);
    addTearDown(environment.controller.dispose);
    addTearDown(networking.dispose);
    addTearDown(delivery.dispose);
    await settings.load();
    await networking.load();
    await delivery.load();

    await tester.pumpWidget(
      LibreSlipApp(
        settings: settings,
        orders: environment.controller,
        networking: networking,
        clientDelivery: delivery,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-4')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('client-server-settings')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('pair-server')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('server-address-field')),
      '192.168.1.25:42837',
    );
    await tester.enterText(
      find.byKey(const ValueKey('server-fingerprint-field')),
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    await tester.enterText(
      find.byKey(const ValueKey('server-pairing-code-field')),
      '123456',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-pair-server')));
    await tester.pumpAndSettle();

    expect(find.text('Kitchen Server'), findsOneWidget);
    expect(delivery.activeServer, isNotNull);

    final draft = environment.controller.activeDraft!;
    await environment.repository.saveDraft(
      draft.copyWith(
        lines: [TicketLine(id: createLocalId(), name: 'Soup', quantity: 2)],
      ),
    );
    await environment.controller.reloadAfterRestore();
    final ticket = await environment.controller.saveActiveTicket(
      heading: 'Kitchen',
    );
    expect(ticket, isNotNull);
    await delivery.ticketFinalised(ticket!.id);
    expect(
      delivery.deliveryForTicket(ticket.id)?.status,
      ClientDeliveryStatus.failed,
    );

    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('Needs attention'), findsOneWidget);
    await tester.tap(find.text('Ticket 1').first);
    await tester.pumpAndSettle();
    final deliveryId = delivery.deliveryForTicket(ticket.id)!.id;
    final retry = find.byKey(ValueKey('retry-delivery-$deliveryId'));
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(find.text('Delivered'), findsWidgets);
    expect(
      delivery.deliveryForTicket(ticket.id)?.status,
      ClientDeliveryStatus.delivered,
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeClientTransport implements ClientServerTransport {
  var shouldFailDelivery = true;

  @override
  Future<PairServerResult> pair(PairServerRequest request) async {
    final now = DateTime.utc(2026, 9, 25, 8);
    return PairServerResult(
      server: PairedServer(
        id: 'server-installation-1',
        displayName: 'Kitchen Server',
        baseUrl: request.baseUrl,
        certificateFingerprint: request.certificateFingerprint,
        createdAt: now,
        updatedAt: now,
      ),
      accessToken: 'secret-token',
    );
  }

  @override
  Future<DeliveryAcknowledgement> deliver({
    required PairedServer server,
    required String accessToken,
    required ClientDelivery delivery,
  }) async {
    if (shouldFailDelivery) {
      shouldFailDelivery = false;
      throw const ClientTransportException('unreachable');
    }
    return DeliveryAcknowledgement(
      deliveryId: delivery.id,
      serverOrderId: 'server-order-1',
      duplicate: false,
    );
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
