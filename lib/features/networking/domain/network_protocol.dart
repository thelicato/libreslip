import 'dart:convert';

import 'package:crypto/crypto.dart';

class NetworkProtocol {
  const NetworkProtocol._();

  static const name = 'libreslip-order';
  static const version = 1;
  static const maxEnvelopeBytes = 64 * 1024;
  static const maxLines = 200;
  static const maxIdentifierLength = 128;
  static const maxHeadingLength = 60;
  static const maxReferenceLength = 80;
  static const maxOrderNoteLength = 500;
  static const maxItemNameLength = 80;
  static const maxPreparationNoteLength = 300;
  static const maxQuantity = 999;
}

class DeliveryLine {
  const DeliveryLine({
    required this.name,
    required this.quantity,
    this.preparationNote = '',
  });

  final String name;
  final int quantity;
  final String preparationNote;

  Map<String, Object?> toJson() => {
    'name': name,
    'quantity': quantity,
    'preparationNote': preparationNote,
  };
}

class OrderDeliveryEnvelope {
  const OrderDeliveryEnvelope._({
    required this.clientInstallationId,
    required this.deliveryId,
    required this.ticketId,
    required this.ticketNumber,
    required this.createdAt,
    required this.heading,
    required this.reference,
    required this.orderNote,
    required this.lines,
    required this.payloadChecksum,
  });

  final String clientInstallationId;
  final String deliveryId;
  final String ticketId;
  final int ticketNumber;
  final DateTime createdAt;
  final String heading;
  final String reference;
  final String orderNote;
  final List<DeliveryLine> lines;
  final String payloadChecksum;

  factory OrderDeliveryEnvelope.create({
    required String clientInstallationId,
    required String deliveryId,
    required String ticketId,
    required int ticketNumber,
    required DateTime createdAt,
    required String heading,
    required String reference,
    required String orderNote,
    required List<DeliveryLine> lines,
  }) {
    final content = _content(
      clientInstallationId: clientInstallationId,
      deliveryId: deliveryId,
      ticketId: ticketId,
      ticketNumber: ticketNumber,
      createdAt: createdAt,
      heading: heading,
      reference: reference,
      orderNote: orderNote,
      lines: lines,
    );
    _validateContent(content, lines);
    final checksum = _checksum(content);
    final envelope = OrderDeliveryEnvelope._(
      clientInstallationId: clientInstallationId,
      deliveryId: deliveryId,
      ticketId: ticketId,
      ticketNumber: ticketNumber,
      createdAt: createdAt.toUtc(),
      heading: heading,
      reference: reference,
      orderNote: orderNote,
      lines: List.unmodifiable(lines),
      payloadChecksum: checksum,
    );
    envelope._validateEncodedSize();
    return envelope;
  }

  factory OrderDeliveryEnvelope.fromJsonString(String source) {
    if (utf8.encode(source).length > NetworkProtocol.maxEnvelopeBytes) {
      throw const FormatException('Delivery envelope is too large');
    }
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        decoded.keys.toSet().difference(_rootKeys).isNotEmpty ||
        !_rootKeys.every(decoded.containsKey) ||
        decoded['protocol'] != NetworkProtocol.name ||
        decoded['version'] != NetworkProtocol.version ||
        decoded['checksum'] is! String ||
        decoded['ticket'] is! Map<String, dynamic>) {
      throw const FormatException('Unsupported delivery envelope');
    }
    final ticket = decoded['ticket']! as Map<String, dynamic>;
    if (ticket.keys.toSet().difference(_ticketKeys).isNotEmpty ||
        !_ticketKeys.every(ticket.containsKey) ||
        decoded['clientInstallationId'] is! String ||
        decoded['deliveryId'] is! String ||
        ticket['id'] is! String ||
        ticket['number'] is! int ||
        ticket['createdAt'] is! String ||
        ticket['heading'] is! String ||
        ticket['reference'] is! String ||
        ticket['orderNote'] is! String ||
        ticket['lines'] is! List) {
      throw const FormatException('Invalid delivery envelope');
    }
    final createdAtText = ticket['createdAt']! as String;
    final createdAt = DateTime.tryParse(createdAtText);
    if (createdAt == null || !createdAt.isUtc || !createdAtText.endsWith('Z')) {
      throw const FormatException('Delivery timestamp must be UTC');
    }
    final lines = <DeliveryLine>[];
    for (final value in ticket['lines']! as List) {
      if (value is! Map<String, dynamic> ||
          value.keys.toSet().difference(_lineKeys).isNotEmpty ||
          !_lineKeys.every(value.containsKey) ||
          value['name'] is! String ||
          value['quantity'] is! int ||
          value['preparationNote'] is! String) {
        throw const FormatException('Invalid delivery line');
      }
      lines.add(
        DeliveryLine(
          name: value['name']! as String,
          quantity: value['quantity']! as int,
          preparationNote: value['preparationNote']! as String,
        ),
      );
    }
    final content = _content(
      clientInstallationId: decoded['clientInstallationId']! as String,
      deliveryId: decoded['deliveryId']! as String,
      ticketId: ticket['id']! as String,
      ticketNumber: ticket['number']! as int,
      createdAt: createdAt,
      heading: ticket['heading']! as String,
      reference: ticket['reference']! as String,
      orderNote: ticket['orderNote']! as String,
      lines: lines,
    );
    _validateContent(content, lines);
    final checksum = decoded['checksum']! as String;
    if (!_checksumPattern.hasMatch(checksum) ||
        checksum != _checksum(content)) {
      throw const FormatException('Delivery checksum does not match');
    }
    return OrderDeliveryEnvelope._(
      clientInstallationId: decoded['clientInstallationId']! as String,
      deliveryId: decoded['deliveryId']! as String,
      ticketId: ticket['id']! as String,
      ticketNumber: ticket['number']! as int,
      createdAt: createdAt,
      heading: ticket['heading']! as String,
      reference: ticket['reference']! as String,
      orderNote: ticket['orderNote']! as String,
      lines: List.unmodifiable(lines),
      payloadChecksum: checksum,
    );
  }

  Map<String, Object?> toJson() => {
    ..._content(
      clientInstallationId: clientInstallationId,
      deliveryId: deliveryId,
      ticketId: ticketId,
      ticketNumber: ticketNumber,
      createdAt: createdAt,
      heading: heading,
      reference: reference,
      orderNote: orderNote,
      lines: lines,
    ),
    'checksum': payloadChecksum,
  };

  String toJsonString() => jsonEncode(toJson());

  void _validateEncodedSize() {
    if (utf8.encode(toJsonString()).length > NetworkProtocol.maxEnvelopeBytes) {
      throw const FormatException('Delivery envelope is too large');
    }
  }

  static Map<String, Object?> _content({
    required String clientInstallationId,
    required String deliveryId,
    required String ticketId,
    required int ticketNumber,
    required DateTime createdAt,
    required String heading,
    required String reference,
    required String orderNote,
    required List<DeliveryLine> lines,
  }) => {
    'protocol': NetworkProtocol.name,
    'version': NetworkProtocol.version,
    'clientInstallationId': clientInstallationId,
    'deliveryId': deliveryId,
    'ticket': {
      'id': ticketId,
      'number': ticketNumber,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'heading': heading,
      'reference': reference,
      'orderNote': orderNote,
      'lines': [for (final line in lines) line.toJson()],
    },
  };

  static void _validateContent(
    Map<String, Object?> content,
    List<DeliveryLine> lines,
  ) {
    final ticket = content['ticket']! as Map<String, Object?>;
    for (final id in [
      content['clientInstallationId'],
      content['deliveryId'],
      ticket['id'],
    ]) {
      if (id is! String || !_identifierPattern.hasMatch(id)) {
        throw const FormatException('Delivery identifier is invalid');
      }
    }
    if (ticket['number'] is! int ||
        (ticket['number']! as int) < 1 ||
        lines.isEmpty ||
        lines.length > NetworkProtocol.maxLines) {
      throw const FormatException('Delivery ticket is invalid');
    }
    _validateText(
      ticket['heading'],
      NetworkProtocol.maxHeadingLength,
      allowEmpty: true,
    );
    _validateText(
      ticket['reference'],
      NetworkProtocol.maxReferenceLength,
      allowEmpty: true,
    );
    _validateText(
      ticket['orderNote'],
      NetworkProtocol.maxOrderNoteLength,
      allowEmpty: true,
    );
    for (final line in lines) {
      _validateText(line.name, NetworkProtocol.maxItemNameLength);
      _validateText(
        line.preparationNote,
        NetworkProtocol.maxPreparationNoteLength,
        allowEmpty: true,
      );
      if (line.quantity < 1 || line.quantity > NetworkProtocol.maxQuantity) {
        throw const FormatException('Delivery quantity is invalid');
      }
    }
  }

  static void _validateText(
    Object? value,
    int maximum, {
    bool allowEmpty = false,
  }) {
    if (value is! String ||
        (!allowEmpty && value.trim().isEmpty) ||
        value.length > maximum ||
        value.contains('\u0000')) {
      throw const FormatException('Delivery text is invalid');
    }
  }

  static String _checksum(Map<String, Object?> content) =>
      sha256.convert(utf8.encode(jsonEncode(content))).toString();

  static final _identifierPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$',
  );
  static final _checksumPattern = RegExp(r'^[0-9a-f]{64}$');
  static const _rootKeys = {
    'protocol',
    'version',
    'clientInstallationId',
    'deliveryId',
    'ticket',
    'checksum',
  };
  static const _ticketKeys = {
    'id',
    'number',
    'createdAt',
    'heading',
    'reference',
    'orderNote',
    'lines',
  };
  static const _lineKeys = {'name', 'quantity', 'preparationNote'};
}
