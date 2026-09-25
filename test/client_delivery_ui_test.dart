import 'dart:async';
import 'dart:typed_data';

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
import 'package:libreslip/features/printing/domain/print_job.dart';

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
      '192.168.1.25:5119',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-pair-server')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('waiting-for-server-approval')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('server-fingerprint-field')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('server-pairing-code-field')),
      findsNothing,
    );
    transport.acceptPairing();
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
    final printJob = await environment.repository.createPrintJob(
      requestId: 'client-ui-print',
      ticketId: ticket!.id,
      payload: Uint8List.fromList([0x1b, 0x40]),
    );
    await environment.repository.markPrintJobSending(
      printJob.id,
      printerAddress: '00:11:22:33:44:55',
      printerName: 'NETUM',
    );
    await environment.repository.markPrintJobOutcome(
      printJob.id,
      status: PrintJobStatus.transmitted,
    );
    await delivery.ticketPrinted(ticket.id);
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
  PairServerRequest? _pendingRequest;
  Completer<PairServerResult>? _pairing;

  @override
  Future<PairServerResult> pair(PairServerRequest request) {
    _pendingRequest = request;
    _pairing = Completer<PairServerResult>();
    return _pairing!.future;
  }

  void acceptPairing() {
    final request = _pendingRequest!;
    final now = DateTime.utc(2026, 9, 25, 8);
    _pairing!.complete(
      PairServerResult(
        server: PairedServer(
          id: 'server-installation-1',
          displayName: 'Kitchen Server',
          baseUrl: request.baseUrl,
          certificateFingerprint: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          createdAt: now,
          updatedAt: now,
        ),
        accessToken: 'secret-token',
      ),
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
