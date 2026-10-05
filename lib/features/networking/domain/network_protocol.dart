import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../orders/domain/course_groups.dart';

class NetworkProtocol {
  const NetworkProtocol._();

  static const name = 'libreslip-order';
  static const version = 1;
  static const groupedVersion = 2;
  static const managedVersion = 3;
  static const defaultPort = 5119;
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
    this.courseId,
    this.id,
  });

  final String name;
  final int quantity;
  final String preparationNote;
  final String? courseId;
  final String? id;

  Map<String, Object?> toJson({
    bool includeCourse = false,
    bool includeId = false,
  }) => {
    'name': name,
    'quantity': quantity,
    'preparationNote': preparationNote,
    if (includeCourse) 'courseId': courseId,
    if (includeId) 'id': id,
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
    required this.courses,
    required this.managedOrderId,
    required this.revision,
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
  final List<OrderCourse> courses;
  final String? managedOrderId;
  final int revision;
  int get version => managedOrderId != null
      ? NetworkProtocol.managedVersion
      : courses.isEmpty
      ? NetworkProtocol.version
      : NetworkProtocol.groupedVersion;
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
    List<OrderCourse> courses = const [],
    String? managedOrderId,
    int revision = 0,
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
      courses: courses,
      managedOrderId: managedOrderId,
      revision: revision,
    );
    if (managedOrderId == null && revision != 0) {
      throw const FormatException('Invalid revision');
    }
    _validateContent(content, lines, courses);
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
      courses: List.unmodifiable(courses),
      managedOrderId: managedOrderId,
      revision: revision,
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
        ![
          NetworkProtocol.version,
          NetworkProtocol.groupedVersion,
          NetworkProtocol.managedVersion,
        ].contains(decoded['version']) ||
        decoded['checksum'] is! String ||
        decoded['ticket'] is! Map<String, dynamic>) {
      throw const FormatException('Unsupported delivery envelope');
    }
    final managed = decoded['version'] == NetworkProtocol.managedVersion;
    final grouped =
        managed || decoded['version'] == NetworkProtocol.groupedVersion;
    final ticketKeys = {
      ..._ticketKeys,
      if (grouped) 'courses',
      if (managed) ...{'orderId', 'revision'},
    };
    final lineKeys = {..._lineKeys, if (grouped) 'courseId', if (managed) 'id'};
    final ticket = decoded['ticket']! as Map<String, dynamic>;
    if (ticket.keys.toSet().difference(ticketKeys).isNotEmpty ||
        !ticketKeys.every(ticket.containsKey) ||
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
    final courses = grouped
        ? parseCourses(ticket['courses'])
        : const <OrderCourse>[];
    if (grouped && !managed && courses.isEmpty) {
      throw const FormatException('Grouped orders need courses');
    }
    final managedOrderId = managed && ticket['orderId'] is String
        ? ticket['orderId'] as String
        : null;
    final revision = managed && ticket['revision'] is int
        ? ticket['revision'] as int
        : 0;
    if (managed && (managedOrderId == null || revision < 1)) {
      throw const FormatException('Invalid managed revision');
    }
    final lines = <DeliveryLine>[];
    for (final value in ticket['lines']! as List) {
      if (value is! Map<String, dynamic> ||
          value.keys.toSet().difference(lineKeys).isNotEmpty ||
          !lineKeys.every(value.containsKey) ||
          value['name'] is! String ||
          value['quantity'] is! int ||
          value['preparationNote'] is! String ||
          (managed && value['id'] is! String) ||
          (grouped &&
              value['courseId'] != null &&
              value['courseId'] is! String)) {
        throw const FormatException('Invalid delivery line');
      }
      lines.add(
        DeliveryLine(
          name: value['name']! as String,
          quantity: value['quantity']! as int,
          preparationNote: value['preparationNote']! as String,
          courseId: grouped ? value['courseId'] as String? : null,
          id: managed ? value['id'] as String : null,
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
      courses: courses,
      managedOrderId: managedOrderId,
      revision: revision,
    );
    _validateContent(content, lines, courses);
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
      courses: List.unmodifiable(courses),
      managedOrderId: managedOrderId,
      revision: revision,
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
      courses: courses,
      managedOrderId: managedOrderId,
      revision: revision,
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
    required List<OrderCourse> courses,
    required String? managedOrderId,
    required int revision,
  }) => {
    'protocol': NetworkProtocol.name,
    'version': managedOrderId != null
        ? NetworkProtocol.managedVersion
        : courses.isEmpty
        ? NetworkProtocol.version
        : NetworkProtocol.groupedVersion,
    'clientInstallationId': clientInstallationId,
    'deliveryId': deliveryId,
    'ticket': {
      'id': ticketId,
      'number': ticketNumber,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'heading': heading,
      'reference': reference,
      'orderNote': orderNote,
      'orderId': ?managedOrderId,
      if (managedOrderId != null) 'revision': revision,
      if (courses.isNotEmpty || managedOrderId != null)
        'courses': [for (final course in courses) course.toJson()],
      'lines': [
        for (final line in lines)
          line.toJson(
            includeCourse: courses.isNotEmpty || managedOrderId != null,
            includeId: managedOrderId != null,
          ),
      ],
    },
  };

  static void _validateContent(
    Map<String, Object?> content,
    List<DeliveryLine> lines,
    List<OrderCourse> courses,
  ) {
    validateCourses(courses, lines.map((line) => line.courseId));
    final ticket = content['ticket']! as Map<String, Object?>;
    if (content['version'] == NetworkProtocol.managedVersion) {
      if (ticket['orderId'] is! String ||
          !_identifierPattern.hasMatch(ticket['orderId'] as String) ||
          ticket['revision'] is! int ||
          (ticket['revision'] as int) < 1 ||
          (ticket['revision'] as int) > 100000 ||
          lines.any(
            (line) => line.id == null || !_identifierPattern.hasMatch(line.id!),
          ) ||
          lines.map((line) => line.id).toSet().length != lines.length) {
        throw const FormatException('Invalid managed order');
      }
    } else if (lines.any((line) => line.id != null)) {
      throw const FormatException('Line identifiers require managed orders');
    }
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
