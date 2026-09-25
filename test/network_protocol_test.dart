import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/networking/data/pinned_https_client.dart';
import 'package:libreslip/features/networking/domain/network_protocol.dart';

void main() {
  test('a Server address without a port uses 5119', () {
    expect(NetworkProtocol.defaultPort, 5119);
    expect(
      PinnedHttpsClient.normaliseServerAddress('192.168.1.25').port,
      NetworkProtocol.defaultPort,
    );
    expect(
      PinnedHttpsClient.normaliseServerAddress('192.168.1.25:6000').port,
      6000,
    );
  });

  OrderDeliveryEnvelope envelope() => OrderDeliveryEnvelope.create(
    clientInstallationId: 'client-7c9a',
    deliveryId: 'delivery-42',
    ticketId: 'ticket-9',
    ticketNumber: 12,
    createdAt: DateTime.utc(2026, 9, 24, 18, 30),
    heading: 'Kitchen',
    reference: 'Table 4',
    orderNote: 'Bring together',
    lines: const [
      DeliveryLine(
        name: 'Mushroom toastie',
        quantity: 2,
        preparationNote: 'One without onion',
      ),
    ],
  );

  test('version 1 delivery round trip preserves immutable content', () {
    final original = envelope();
    final encoded = original.toJsonString();
    final decoded = OrderDeliveryEnvelope.fromJsonString(encoded);

    expect(decoded.clientInstallationId, 'client-7c9a');
    expect(decoded.deliveryId, 'delivery-42');
    expect(decoded.ticketId, 'ticket-9');
    expect(decoded.ticketNumber, 12);
    expect(decoded.createdAt, DateTime.utc(2026, 9, 24, 18, 30));
    expect(decoded.heading, 'Kitchen');
    expect(decoded.reference, 'Table 4');
    expect(decoded.orderNote, 'Bring together');
    expect(decoded.lines.single.name, 'Mushroom toastie');
    expect(decoded.lines.single.quantity, 2);
    expect(decoded.lines.single.preparationNote, 'One without onion');
    expect(decoded.payloadChecksum, original.payloadChecksum);
    expect(decoded.toJsonString(), encoded);
  });

  test('checksum rejects a modified accepted envelope', () {
    final value = jsonDecode(envelope().toJsonString()) as Map<String, dynamic>;
    final ticket = value['ticket']! as Map<String, dynamic>;
    final lines = ticket['lines']! as List<dynamic>;
    (lines.single as Map<String, dynamic>)['quantity'] = 3;

    expect(
      () => OrderDeliveryEnvelope.fromJsonString(jsonEncode(value)),
      throwsA(isA<FormatException>()),
    );
  });

  test('unsupported versions, unknown fields and local times are rejected', () {
    final valid = jsonDecode(envelope().toJsonString()) as Map<String, dynamic>;
    for (final change in <void Function(Map<String, dynamic>)>[
      (value) => value['version'] = 2,
      (value) => value['unexpected'] = true,
      (value) => (value['ticket']! as Map<String, dynamic>)['createdAt'] =
          '2026-09-24T18:30:00',
    ]) {
      final changed = jsonDecode(jsonEncode(valid)) as Map<String, dynamic>;
      change(changed);
      expect(
        () => OrderDeliveryEnvelope.fromJsonString(jsonEncode(changed)),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('invalid identifiers and oversized canonical payloads are rejected', () {
    expect(
      () => OrderDeliveryEnvelope.create(
        clientInstallationId: 'client with spaces',
        deliveryId: 'delivery-1',
        ticketId: 'ticket-1',
        ticketNumber: 1,
        createdAt: DateTime.now().toUtc(),
        heading: '',
        reference: '',
        orderNote: '',
        lines: const [DeliveryLine(name: 'Tea', quantity: 1)],
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => OrderDeliveryEnvelope.create(
        clientInstallationId: 'client-1',
        deliveryId: 'delivery-1',
        ticketId: 'ticket-1',
        ticketNumber: 1,
        createdAt: DateTime.now().toUtc(),
        heading: 'x' * NetworkProtocol.maxHeadingLength,
        reference: 'x' * NetworkProtocol.maxReferenceLength,
        orderNote: 'x' * NetworkProtocol.maxOrderNoteLength,
        lines: List.generate(
          NetworkProtocol.maxLines,
          (_) => DeliveryLine(
            name: 'x' * NetworkProtocol.maxItemNameLength,
            quantity: NetworkProtocol.maxQuantity,
            preparationNote: 'x' * NetworkProtocol.maxPreparationNoteLength,
          ),
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('field, line and quantity limits are enforced before delivery', () {
    expect(
      () => OrderDeliveryEnvelope.create(
        clientInstallationId: 'client-1',
        deliveryId: 'delivery-1',
        ticketId: 'ticket-1',
        ticketNumber: 1,
        createdAt: DateTime.now().toUtc(),
        heading: '',
        reference: '',
        orderNote: '',
        lines: [
          DeliveryLine(
            name: 'x' * (NetworkProtocol.maxItemNameLength + 1),
            quantity: 1,
          ),
        ],
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => OrderDeliveryEnvelope.create(
        clientInstallationId: 'client-1',
        deliveryId: 'delivery-1',
        ticketId: 'ticket-1',
        ticketNumber: 1,
        createdAt: DateTime.now().toUtc(),
        heading: '',
        reference: '',
        orderNote: '',
        lines: const [DeliveryLine(name: 'Tea', quantity: 1000)],
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => OrderDeliveryEnvelope.create(
        clientInstallationId: 'client-1',
        deliveryId: 'delivery-1',
        ticketId: 'ticket-1',
        ticketNumber: 1,
        createdAt: DateTime.now().toUtc(),
        heading: '',
        reference: '',
        orderNote: '',
        lines: const [],
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
