import 'dart:math';
import 'dart:convert';

import 'course_groups.dart';
export 'course_groups.dart';

String createLocalId() {
  final random = Random.secure();
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final entropy = List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  return '$time-$entropy';
}

class ItemCategory {
  const ItemCategory({required this.id, required this.name});

  final String id;
  final String name;
}

class CatalogueItem {
  const CatalogueItem({
    required this.id,
    required this.name,
    this.category,
    this.imagePath,
    this.sendToServer = true,
  });

  final String id;
  final String name;
  final ItemCategory? category;
  final String? imagePath;
  final bool sendToServer;

  CatalogueItem copyWith({
    String? name,
    ItemCategory? category,
    bool clearCategory = false,
    String? imagePath,
    bool clearImage = false,
    bool? sendToServer,
  }) => CatalogueItem(
    id: id,
    name: name ?? this.name,
    category: clearCategory ? null : category ?? this.category,
    imagePath: clearImage ? null : imagePath ?? this.imagePath,
    sendToServer: sendToServer ?? this.sendToServer,
  );
}

class OrderFeatureSettings {
  const OrderFeatureSettings({
    this.orderReferenceEnabled = true,
    this.preparationNotesEnabled = true,
    this.orderNotesEnabled = true,
    this.courseGroupsEnabled = false,
    this.managedOrdersEnabled = false,
  });

  final bool orderReferenceEnabled;
  final bool preparationNotesEnabled;
  final bool orderNotesEnabled;
  final bool courseGroupsEnabled;
  final bool managedOrdersEnabled;

  OrderFeatureSettings copyWith({
    bool? orderReferenceEnabled,
    bool? preparationNotesEnabled,
    bool? orderNotesEnabled,
    bool? courseGroupsEnabled,
    bool? managedOrdersEnabled,
  }) => OrderFeatureSettings(
    orderReferenceEnabled: orderReferenceEnabled ?? this.orderReferenceEnabled,
    preparationNotesEnabled:
        preparationNotesEnabled ?? this.preparationNotesEnabled,
    orderNotesEnabled: orderNotesEnabled ?? this.orderNotesEnabled,
    courseGroupsEnabled: courseGroupsEnabled ?? this.courseGroupsEnabled,
    managedOrdersEnabled: managedOrdersEnabled ?? this.managedOrdersEnabled,
  );
}

class TicketLine {
  const TicketLine({
    required this.id,
    required this.name,
    required this.quantity,
    this.catalogueItemId,
    this.preparationNote = '',
    this.courseId,
    this.sendToServer = true,
  });

  final String id;
  final String? catalogueItemId;
  final String name;
  final int quantity;
  final String preparationNote;
  final String? courseId;
  final bool sendToServer;

  TicketLine copyWith({
    int? quantity,
    String? preparationNote,
    String? courseId,
    bool clearCourse = false,
  }) => TicketLine(
    id: id,
    catalogueItemId: catalogueItemId,
    name: name,
    quantity: quantity ?? this.quantity,
    preparationNote: preparationNote ?? this.preparationNote,
    courseId: clearCourse ? null : courseId ?? this.courseId,
    sendToServer: sendToServer,
  );
}

class OrderDraft {
  const OrderDraft({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.reference = '',
    this.orderNote = '',
    this.lines = const [],
    this.courses = const [],
    this.activeCourseId,
    this.managedOrderId,
    this.baseRevision = 0,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String reference;
  final String orderNote;
  final List<TicketLine> lines;
  final List<OrderCourse> courses;
  final String? activeCourseId;
  final String? managedOrderId;
  final int baseRevision;

  int get itemCount => lines.fold(0, (total, line) => total + line.quantity);

  OrderDraft copyWith({
    DateTime? updatedAt,
    String? reference,
    String? orderNote,
    List<TicketLine>? lines,
    List<OrderCourse>? courses,
    String? activeCourseId,
    bool clearActiveCourse = false,
  }) => OrderDraft(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    reference: reference ?? this.reference,
    orderNote: orderNote ?? this.orderNote,
    lines: lines ?? this.lines,
    courses: courses ?? this.courses,
    managedOrderId: managedOrderId,
    baseRevision: baseRevision,
    activeCourseId: clearActiveCourse
        ? null
        : activeCourseId ?? this.activeCourseId,
  );
}

class SavedTicket {
  const SavedTicket({
    required this.id,
    required this.number,
    required this.createdAt,
    required this.heading,
    required this.reference,
    required this.orderNote,
    required this.lines,
    this.sourceTicketId,
    this.courses = const [],
    this.managedOrderId,
    this.revision = 0,
    this.additionLineIds = const [],
  });

  final String id;
  final int number;
  final DateTime createdAt;
  final String heading;
  final String reference;
  final String orderNote;
  final List<TicketLine> lines;
  final String? sourceTicketId;
  final List<OrderCourse> courses;
  final String? managedOrderId;
  final int revision;
  final List<String> additionLineIds;
  List<TicketLine> get printLines => revision > 1
      ? lines.where((line) => additionLineIds.contains(line.id)).toList()
      : lines;

  int get itemCount => lines.fold(0, (total, line) => total + line.quantity);
}

abstract interface class OrderRepository {
  Future<void> open();

  Future<List<CatalogueItem>> loadItems();

  Future<List<ItemCategory>> loadCategories();

  Future<OrderFeatureSettings> loadFeatureSettings();

  Future<void> saveFeatureSettings(OrderFeatureSettings settings);

  Future<int> loadNextOrderNumber();

  Future<void> resetOrderNumber();

  Future<List<OrderDraft>> loadDrafts();

  Future<List<SavedTicket>> loadTickets();

  Future<List<ManagedOrder>> loadManagedOrders();

  Future<OrderDraft> beginOrderAddition(String orderId, String draftId);

  Future<void> closeManagedOrder(String orderId);

  Future<void> deleteTicket(String id);

  Future<void> deleteAllTickets();

  /// Returns a consistent, versioned snapshot of all SQLite-backed data.
  Future<Map<String, Object?>> createPortableSnapshot();

  /// Atomically replaces all SQLite-backed data with [snapshot].
  Future<void> replaceWithPortableSnapshot(Map<String, Object?> snapshot);

  Future<CatalogueItem> saveItem({
    String? id,
    required String name,
    String? categoryName,
    String? imagePath,
    bool sendToServer = true,
  });

  Future<void> archiveItem(String id);

  Future<OrderDraft> createDraft();

  Future<void> saveDraft(OrderDraft draft);

  Future<void> deleteDraft(String id);

  /// Atomically snapshots and removes [draft]. Repeating the call returns the
  /// same ticket because the draft identifier is a unique idempotency key.
  Future<SavedTicket> convertDraftToTicket(
    OrderDraft draft, {
    required String heading,
    bool keepOpen = false,
  });

  Future<void> close();
}

class OrderStorageException implements Exception {
  const OrderStorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// The current order is independent of immutable ticket history and the editor.
class ManagedOrder {
  const ManagedOrder({
    required this.id,
    required this.number,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    required this.heading,
    required this.reference,
    required this.orderNote,
    required this.lines,
    required this.courses,
    this.closedAt,
    this.destinationId,
    this.clientInstallationId,
    this.serverRevision = 0,
  });
  final String id;
  final int number;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;
  final String heading;
  final String reference;
  final String orderNote;
  final List<TicketLine> lines;
  final List<OrderCourse> courses;
  final String? destinationId;
  final String? clientInstallationId;
  final int serverRevision;
  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);
}

String encodeOrderLines(List<TicketLine> lines) => jsonEncode([
  for (final line in lines)
    {
      'id': line.id,
      'catalogueItemId': line.catalogueItemId,
      'name': line.name,
      'quantity': line.quantity,
      'preparationNote': line.preparationNote,
      'courseId': line.courseId,
      'sendToServer': line.sendToServer,
    },
]);

List<TicketLine> decodeOrderLines(Object? source) {
  if (source is! String || source.length > 262144) {
    throw const FormatException('Invalid managed lines');
  }
  final rows = jsonDecode(source);
  if (rows is! List || rows.isEmpty || rows.length > 200) {
    throw const FormatException('Invalid managed lines');
  }
  final ids = <String>{};
  return List.unmodifiable(
    rows.map((row) {
      if (row is! Map ||
          row.length != 7 ||
          row['id'] is! String ||
          !validOrderId(row['id'] as String) ||
          !ids.add(row['id'] as String) ||
          (row['catalogueItemId'] != null &&
              row['catalogueItemId'] is! String) ||
          row['name'] is! String ||
          (row['name'] as String).trim().isEmpty ||
          (row['name'] as String).length > 80 ||
          (row['name'] as String).contains('\u0000') ||
          row['quantity'] is! int ||
          (row['quantity'] as int) < 1 ||
          (row['quantity'] as int) > 999 ||
          row['preparationNote'] is! String ||
          (row['preparationNote'] as String).length > 300 ||
          (row['preparationNote'] as String).contains('\u0000') ||
          (row['courseId'] != null && row['courseId'] is! String) ||
          row['sendToServer'] is! bool) {
        throw const FormatException('Invalid managed line');
      }
      return TicketLine(
        id: row['id'] as String,
        catalogueItemId: row['catalogueItemId'] as String?,
        name: row['name'] as String,
        quantity: row['quantity'] as int,
        preparationNote: row['preparationNote'] as String,
        courseId: row['courseId'] as String?,
        sendToServer: row['sendToServer'] as bool,
      );
    }),
  );
}

bool validOrderId(String id) =>
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$').hasMatch(id);
