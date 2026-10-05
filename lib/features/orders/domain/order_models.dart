import 'dart:math';
import 'dart:convert';

import 'course_groups.dart';
import 'product_price.dart';
export 'product_price.dart';
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
    this.price,
  });

  final String id;
  final String name;
  final ItemCategory? category;
  final String? imagePath;
  final bool sendToServer;
  final ProductPrice? price;

  CatalogueItem copyWith({
    String? name,
    ItemCategory? category,
    bool clearCategory = false,
    String? imagePath,
    bool clearImage = false,
    bool? sendToServer,
    ProductPrice? price,
    bool clearPrice = false,
  }) => CatalogueItem(
    id: id,
    name: name ?? this.name,
    category: clearCategory ? null : category ?? this.category,
    imagePath: clearImage ? null : imagePath ?? this.imagePath,
    sendToServer: sendToServer ?? this.sendToServer,
    price: clearPrice ? null : price ?? this.price,
  );
}

class OrderFeatureSettings {
  const OrderFeatureSettings({
    this.orderReferenceEnabled = true,
    this.preparationNotesEnabled = true,
    this.orderNotesEnabled = true,
    this.courseGroupsEnabled = false,
    this.managedOrdersEnabled = false,
    this.pricesEnabled = false,
  });

  final bool orderReferenceEnabled;
  final bool preparationNotesEnabled;
  final bool orderNotesEnabled;
  final bool courseGroupsEnabled;
  final bool managedOrdersEnabled;
  final bool pricesEnabled;

  OrderFeatureSettings copyWith({
    bool? orderReferenceEnabled,
    bool? preparationNotesEnabled,
    bool? orderNotesEnabled,
    bool? courseGroupsEnabled,
    bool? managedOrdersEnabled,
    bool? pricesEnabled,
  }) => OrderFeatureSettings(
    orderReferenceEnabled: orderReferenceEnabled ?? this.orderReferenceEnabled,
    preparationNotesEnabled:
        preparationNotesEnabled ?? this.preparationNotesEnabled,
    orderNotesEnabled: orderNotesEnabled ?? this.orderNotesEnabled,
    courseGroupsEnabled: courseGroupsEnabled ?? this.courseGroupsEnabled,
    managedOrdersEnabled: managedOrdersEnabled ?? this.managedOrdersEnabled,
    pricesEnabled: pricesEnabled ?? this.pricesEnabled,
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
    this.price,
  });

  final String id;
  final String? catalogueItemId;
  final String name;
  final int quantity;
  final String preparationNote;
  final String? courseId;
  final bool sendToServer;
  final ProductPrice? price;

  TicketLine copyWith({
    int? quantity,
    String? preparationNote,
    String? courseId,
    bool clearCourse = false,
    bool clearPrice = false,
  }) => TicketLine(
    id: id,
    catalogueItemId: catalogueItemId,
    name: name,
    quantity: quantity ?? this.quantity,
    preparationNote: preparationNote ?? this.preparationNote,
    courseId: clearCourse ? null : courseId ?? this.courseId,
    sendToServer: sendToServer,
    price: clearPrice ? null : price,
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

  Future<void> setManagedLineDelivered(
    String orderId,
    String lineId,
    int quantity, {
    required int expectedQuantity,
  });

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
    ProductPrice? price,
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
    bool requirePrintForDelivery = true,
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
    this.deliveredQuantities = const {},
    this.changedDeliveryIds = const {},
    this.deliveryEditRevision = 0,
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
  final Map<String, int> deliveredQuantities;
  final Set<String> changedDeliveryIds;
  final int deliveryEditRevision;
  int deliveredQuantity(String lineId) => deliveredQuantities[lineId] ?? 0;
  int get deliveredCount => deliveredQuantities.values.fold(0, (a, b) => a + b);
  int get outstandingCount => itemCount - deliveredCount;
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
      'priceMinorUnits': line.price?.minorUnits,
      'priceCurrency': line.price?.currency,
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
          (row.length != 7 && row.length != 9) ||
          (row.length == 9 &&
              (!row.containsKey('priceMinorUnits') ||
                  !row.containsKey('priceCurrency'))) ||
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
        price: ProductPrice.fromColumns(
          row['priceMinorUnits'],
          row['priceCurrency'],
        ),
      );
    }),
  );
}

bool validOrderId(String id) =>
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$').hasMatch(id);

/// Progress is independent of immutable ticket content. Missing keys mean zero.
Map<String, int> decodeDeliveryProgress(
  Object? source,
  List<TicketLine> lines,
) {
  if (source is! String || source.length > 32768) {
    throw const FormatException('Invalid delivery progress');
  }
  final decoded = jsonDecode(source);
  if (decoded is! Map || decoded.length > lines.length) {
    throw const FormatException('Invalid delivery progress');
  }
  final quantities = {for (final line in lines) line.id: line.quantity};
  final result = <String, int>{};
  for (final entry in decoded.entries) {
    final maximum = quantities[entry.key];
    if (entry.key is! String ||
        maximum == null ||
        entry.value is! int ||
        (entry.value as int) < 1 ||
        (entry.value as int) > maximum) {
      throw const FormatException('Invalid delivered quantity');
    }
    result[entry.key as String] = entry.value as int;
  }
  return Map.unmodifiable(result);
}

Set<String> decodeChangedDeliveryIds(Object? source, List<TicketLine> lines) {
  if (source is! String || source.length > 32768) {
    throw const FormatException('Invalid changed delivery inventory');
  }
  final values = jsonDecode(source);
  final ids = lines.map((line) => line.id).toSet();
  if (values is! List ||
      values.length > ids.length ||
      values.any((id) => id is! String || !ids.contains(id)) ||
      values.toSet().length != values.length) {
    throw const FormatException('Invalid changed delivery inventory');
  }
  return Set.unmodifiable(values.cast<String>());
}

/// Separate currency subtotals never imply a conversion or a complete estimate
/// when some selected quantities have no price.
class OrderPriceEstimate {
  OrderPriceEstimate.fromLines(Iterable<TicketLine> lines) {
    final amounts = <String, int>{};
    var missing = 0;
    for (final line in lines) {
      final price = line.price;
      if (price == null) {
        missing += line.quantity;
      } else {
        amounts.update(
          price.currency,
          (amount) => amount + price.minorUnits * line.quantity,
          ifAbsent: () => price.minorUnits * line.quantity,
        );
      }
    }
    totals = Map.unmodifiable(amounts);
    unpricedQuantity = missing;
  }
  late final Map<String, int> totals;
  late final int unpricedQuantity;
}
