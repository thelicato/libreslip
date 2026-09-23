import 'dart:math';

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
  });

  final String id;
  final String name;
  final ItemCategory? category;
  final String? imagePath;

  CatalogueItem copyWith({
    String? name,
    ItemCategory? category,
    bool clearCategory = false,
    String? imagePath,
    bool clearImage = false,
  }) => CatalogueItem(
    id: id,
    name: name ?? this.name,
    category: clearCategory ? null : category ?? this.category,
    imagePath: clearImage ? null : imagePath ?? this.imagePath,
  );
}

class OrderFeatureSettings {
  const OrderFeatureSettings({
    this.orderReferenceEnabled = true,
    this.preparationNotesEnabled = true,
    this.orderNotesEnabled = true,
  });

  final bool orderReferenceEnabled;
  final bool preparationNotesEnabled;
  final bool orderNotesEnabled;

  OrderFeatureSettings copyWith({
    bool? orderReferenceEnabled,
    bool? preparationNotesEnabled,
    bool? orderNotesEnabled,
  }) => OrderFeatureSettings(
    orderReferenceEnabled: orderReferenceEnabled ?? this.orderReferenceEnabled,
    preparationNotesEnabled:
        preparationNotesEnabled ?? this.preparationNotesEnabled,
    orderNotesEnabled: orderNotesEnabled ?? this.orderNotesEnabled,
  );
}

class TicketLine {
  const TicketLine({
    required this.id,
    required this.name,
    required this.quantity,
    this.catalogueItemId,
    this.preparationNote = '',
  });

  final String id;
  final String? catalogueItemId;
  final String name;
  final int quantity;
  final String preparationNote;

  TicketLine copyWith({int? quantity, String? preparationNote}) => TicketLine(
    id: id,
    catalogueItemId: catalogueItemId,
    name: name,
    quantity: quantity ?? this.quantity,
    preparationNote: preparationNote ?? this.preparationNote,
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
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String reference;
  final String orderNote;
  final List<TicketLine> lines;

  int get itemCount => lines.fold(0, (total, line) => total + line.quantity);

  OrderDraft copyWith({
    DateTime? updatedAt,
    String? reference,
    String? orderNote,
    List<TicketLine>? lines,
  }) => OrderDraft(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    reference: reference ?? this.reference,
    orderNote: orderNote ?? this.orderNote,
    lines: lines ?? this.lines,
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
  });

  final String id;
  final int number;
  final DateTime createdAt;
  final String heading;
  final String reference;
  final String orderNote;
  final List<TicketLine> lines;
  final String? sourceTicketId;

  int get itemCount => lines.fold(0, (total, line) => total + line.quantity);
}

abstract interface class OrderRepository {
  Future<void> open();

  Future<List<CatalogueItem>> loadItems();

  Future<List<ItemCategory>> loadCategories();

  Future<OrderFeatureSettings> loadFeatureSettings();

  Future<void> saveFeatureSettings(OrderFeatureSettings settings);

  Future<List<OrderDraft>> loadDrafts();

  Future<List<SavedTicket>> loadTickets();

  Future<CatalogueItem> saveItem({
    String? id,
    required String name,
    String? categoryName,
    String? imagePath,
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
