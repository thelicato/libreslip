import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/item_image_store.dart';
import '../domain/order_models.dart';

class OrderWorkspaceController extends ChangeNotifier {
  OrderWorkspaceController(this._repository, {this._imageStore});

  final OrderRepository _repository;
  final ItemImageStore? _imageStore;

  bool loaded = false;
  bool loadFailed = false;
  bool saving = false;
  bool saveFailed = false;
  List<CatalogueItem> items = const [];
  List<ItemCategory> categories = const [];
  List<OrderDraft> drafts = const [];
  List<SavedTicket> tickets = const [];
  List<ManagedOrder> managedOrders = const [];
  OrderFeatureSettings featureSettings = const OrderFeatureSettings();
  int nextOrderNumber = 1;
  String? activeDraftId;
  Future<void> _writeChain = Future<void>.value();

  OrderDraft? get activeDraft {
    final id = activeDraftId;
    if (id == null) return null;
    for (final draft in drafts) {
      if (draft.id == id) return draft;
    }
    return null;
  }

  Future<void> load() async {
    if (loaded && !loadFailed) return;
    loadFailed = false;
    notifyListeners();
    try {
      await _repository.open();
      await _refresh();
      if (drafts.isEmpty) {
        final draft = await _repository.createDraft();
        drafts = [draft];
      }
      activeDraftId ??= drafts.first.id;
      loaded = true;
    } catch (_) {
      loaded = false;
      loadFailed = true;
    }
    notifyListeners();
  }

  Future<void> _refresh() async {
    items = await _repository.loadItems();
    categories = await _repository.loadCategories();
    featureSettings = await _repository.loadFeatureSettings();
    nextOrderNumber = await _repository.loadNextOrderNumber();
    drafts = await _repository.loadDrafts();
    tickets = await _repository.loadTickets();
    managedOrders = await _repository.loadManagedOrders();
  }

  ManagedOrder? get editingOrder {
    for (final order in managedOrders) {
      if (order.id == activeDraft?.managedOrderId) return order;
    }
    return null;
  }

  int get compositionNumber => editingOrder?.number ?? nextOrderNumber;
  bool get canBeginAddition =>
      !saving &&
      activeDraft != null &&
      activeDraft!.managedOrderId == null &&
      activeDraft!.lines.isEmpty &&
      activeDraft!.reference.isEmpty &&
      activeDraft!.orderNote.isEmpty;

  Future<bool> beginAddition(String id) => _perform(() async {
    await flushWrites();
    final draft = await _repository.beginOrderAddition(id, activeDraft!.id);
    drafts = [draft];
    activeDraftId = draft.id;
  });

  Future<bool> cancelAddition() => _perform(() async {
    final draft = activeDraft;
    if (draft?.managedOrderId == null) return;
    await flushWrites();
    await _repository.deleteDraft(draft!.id);
    final replacement = await _repository.createDraft();
    drafts = [replacement];
    activeDraftId = replacement.id;
  });

  Future<bool> setLineDelivered(
    String orderId,
    String lineId,
    int quantity, {
    required int expectedQuantity,
  }) => _perform(() async {
    try {
      await _repository.setManagedLineDelivered(
        orderId,
        lineId,
        quantity,
        expectedQuantity: expectedQuantity,
      );
    } finally {
      managedOrders = await _repository.loadManagedOrders();
    }
  });

  /// Holds the editor lock while an explicit progress exchange is in flight.
  Future<void> exchangeProgress(
    String orderId,
    Future<void> Function(ManagedOrder) exchange,
  ) async {
    if (saving) throw const OrderStorageException('The workspace is busy.');
    saving = true;
    notifyListeners();
    try {
      await flushWrites();
      managedOrders = await _repository.loadManagedOrders();
      final order = managedOrders.firstWhere((value) => value.id == orderId);
      await exchange(order);
    } finally {
      try {
        managedOrders = await _repository.loadManagedOrders();
      } finally {
        saving = false;
        notifyListeners();
      }
    }
  }

  Future<bool> closeOrder(String id) => _perform(() async {
    await flushWrites();
    await _repository.closeManagedOrder(id);
    managedOrders = await _repository.loadManagedOrders();
  });

  Future<bool> resetOrderNumber() => _perform(() async {
    await _repository.resetOrderNumber();
    nextOrderNumber = await _repository.loadNextOrderNumber();
  });

  Future<bool> deleteTicket(String id) => _perform(() async {
    await _repository.deleteTicket(id);
    tickets = await _repository.loadTickets();
  });

  Future<bool> deleteAllTickets() => _perform(() async {
    await _repository.deleteAllTickets();
    tickets = await _repository.loadTickets();
  });

  Future<bool> reloadAfterRestore() => _perform(() async {
    await flushWrites();
    await _refresh();
    if (drafts.isEmpty) {
      final draft = await _repository.createDraft();
      drafts = [draft];
    }
    if (!drafts.any((draft) => draft.id == activeDraftId)) {
      activeDraftId = drafts.first.id;
    }
  });

  Future<bool> updateFeatureSettings(OrderFeatureSettings next) =>
      _perform(() async {
        await flushWrites();
        await _repository.saveFeatureSettings(next);
        featureSettings = next;
        drafts = await _repository.loadDrafts();
        if (!drafts.any((draft) => draft.id == activeDraftId)) {
          activeDraftId = drafts.isEmpty ? null : drafts.first.id;
        }
      });

  Future<bool> saveItem({
    CatalogueItem? existing,
    required String name,
    String? categoryName,
    String? imagePath,
    bool sendToServer = true,
  }) async {
    final previousImage = existing?.imagePath;
    final success = await _perform(() async {
      await _repository.saveItem(
        id: existing?.id,
        name: name,
        categoryName: categoryName,
        imagePath: imagePath,
        sendToServer: sendToServer,
      );
      items = await _repository.loadItems();
      categories = await _repository.loadCategories();
    });
    if (success &&
        previousImage != null &&
        previousImage != imagePath &&
        _imageStore != null) {
      await _imageStore.remove(previousImage);
    }
    return success;
  }

  Future<void> archiveItem(CatalogueItem item) async {
    final success = await _perform(() async {
      await _repository.archiveItem(item.id);
      items = await _repository.loadItems();
    });
    if (success && item.imagePath != null && _imageStore != null) {
      await _imageStore.remove(item.imagePath!);
    }
  }

  Future<String?> chooseItemImage() =>
      _imageStore?.chooseAndStore() ?? Future<String?>.value();

  Future<void> discardChosenImage(String? path) async {
    if (path != null && _imageStore != null) await _imageStore.remove(path);
  }

  void addCatalogueItem(CatalogueItem item) {
    final draft = activeDraft;
    if (saving || draft == null) return;
    final lines = [...draft.lines];
    final existingIndex = lines.indexWhere(
      (line) =>
          line.catalogueItemId == item.id &&
          line.courseId == draft.activeCourseId,
    );
    if (existingIndex >= 0) {
      final existing = lines[existingIndex];
      if (existing.quantity >= 999) return;
      lines[existingIndex] = existing.copyWith(quantity: existing.quantity + 1);
    } else {
      if (lines.length + (editingOrder?.lines.length ?? 0) >= 200) return;
      lines.add(
        TicketLine(
          id: createLocalId(),
          catalogueItemId: item.id,
          name: item.name,
          quantity: 1,
          courseId: draft.activeCourseId,
        ),
      );
    }
    _replaceActive(
      draft.copyWith(lines: lines, updatedAt: DateTime.now().toUtc()),
    );
  }

  void setQuantity(String lineId, int quantity) {
    final draft = activeDraft;
    if (saving || draft == null || quantity < 1 || quantity > 999) return;
    _replaceActive(
      draft.copyWith(
        updatedAt: DateTime.now().toUtc(),
        lines: [
          for (final line in draft.lines)
            if (line.id == lineId) line.copyWith(quantity: quantity) else line,
        ],
      ),
    );
  }

  bool get courseControlsAvailable =>
      featureSettings.courseGroupsEnabled ||
      (activeDraft?.courses.isNotEmpty ?? false);

  void selectCourse(String? id) {
    final draft = activeDraft;
    if (saving ||
        draft == null ||
        !courseControlsAvailable ||
        (id != null && !draft.courses.any((course) => course.id == id))) {
      return;
    }
    _replaceActive(
      draft.copyWith(
        activeCourseId: id,
        clearActiveCourse: id == null,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  bool saveCourse(String name, {String? id}) {
    final draft = activeDraft;
    if (saving || draft == null || !courseControlsAvailable) return false;
    final course = OrderCourse(id: id ?? createLocalId(), name: name.trim());
    if (id != null &&
        editingOrder?.courses.any((value) => value.id == id) == true) {
      return false;
    }
    if (id != null && !draft.courses.any((value) => value.id == id)) {
      return false;
    }
    final courses = id == null
        ? [...draft.courses, course]
        : [
            for (final value in draft.courses)
              if (value.id == id) course else value,
          ];
    try {
      validateCourses(courses, draft.lines.map((line) => line.courseId));
    } on FormatException {
      return false;
    }
    _replaceActive(
      draft.copyWith(
        courses: courses,
        activeCourseId: id == null ? course.id : draft.activeCourseId,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    return true;
  }

  void moveCourse(String id, int direction) {
    final draft = activeDraft;
    if (saving ||
        draft == null ||
        !courseControlsAvailable ||
        ![-1, 1].contains(direction)) {
      return;
    }
    if (editingOrder != null) return;
    final courses = [...draft.courses];
    final index = courses.indexWhere((course) => course.id == id);
    final destination = index + direction;
    if (index < 0 || destination < 0 || destination >= courses.length) return;
    final course = courses.removeAt(index);
    courses.insert(destination, course);
    _replaceActive(
      draft.copyWith(courses: courses, updatedAt: DateTime.now().toUtc()),
    );
  }

  void removeCourse(String id) {
    if (editingOrder?.courses.any((course) => course.id == id) == true) return;
    final draft = activeDraft;
    if (saving || draft == null || !courseControlsAvailable) return;
    _replaceActive(
      draft.copyWith(
        courses: draft.courses.where((course) => course.id != id).toList(),
        clearActiveCourse: draft.activeCourseId == id,
        lines: [
          for (final line in draft.lines)
            if (line.courseId == id) line.copyWith(clearCourse: true) else line,
        ],
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  void setLineCourse(String lineId, String? courseId) {
    final draft = activeDraft;
    if (saving ||
        draft == null ||
        !courseControlsAvailable ||
        (courseId != null &&
            !draft.courses.any((course) => course.id == courseId))) {
      return;
    }
    _replaceActive(
      draft.copyWith(
        lines: [
          for (final line in draft.lines)
            if (line.id == lineId)
              line.copyWith(courseId: courseId, clearCourse: courseId == null)
            else
              line,
        ],
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  void setPreparationNote(String lineId, String note) {
    final draft = activeDraft;
    if (saving ||
        draft == null ||
        !featureSettings.preparationNotesEnabled ||
        note.length > 300) {
      return;
    }
    _replaceActive(
      draft.copyWith(
        updatedAt: DateTime.now().toUtc(),
        lines: [
          for (final line in draft.lines)
            if (line.id == lineId)
              line.copyWith(preparationNote: note)
            else
              line,
        ],
      ),
    );
  }

  void removeLine(String lineId) {
    final draft = activeDraft;
    if (saving || draft == null) return;
    _replaceActive(
      draft.copyWith(
        updatedAt: DateTime.now().toUtc(),
        lines: draft.lines.where((line) => line.id != lineId).toList(),
      ),
    );
  }

  void setReference(String reference) {
    if (editingOrder != null) return;
    final draft = activeDraft;
    if (saving ||
        draft == null ||
        !featureSettings.orderReferenceEnabled ||
        reference.length > 80) {
      return;
    }
    _replaceActive(
      draft.copyWith(reference: reference, updatedAt: DateTime.now().toUtc()),
    );
  }

  void setOrderNote(String note) {
    if (editingOrder != null) return;
    final draft = activeDraft;
    if (saving ||
        draft == null ||
        !featureSettings.orderNotesEnabled ||
        note.length > 500) {
      return;
    }
    _replaceActive(
      draft.copyWith(orderNote: note, updatedAt: DateTime.now().toUtc()),
    );
  }

  void _replaceActive(OrderDraft replacement) {
    drafts = [
      replacement,
      for (final draft in drafts)
        if (draft.id != replacement.id) draft,
    ];
    saveFailed = false;
    notifyListeners();
    _writeChain = _writeChain
        .then((_) => _repository.saveDraft(replacement))
        .catchError((Object _) {
          saveFailed = true;
          notifyListeners();
        });
  }

  Future<void> flushWrites() async {
    await _writeChain;
    if (saveFailed) {
      final draft = activeDraft;
      if (draft == null) return;
      try {
        await _repository.saveDraft(draft);
        saveFailed = false;
        notifyListeners();
      } catch (_) {
        saveFailed = true;
        notifyListeners();
        rethrow;
      }
    }
  }

  Future<SavedTicket?> saveActiveTicket({required String heading}) async {
    final draft = activeDraft;
    if (saving || draft == null || draft.lines.isEmpty) return null;
    SavedTicket? ticket;
    final success = await _perform(() async {
      await flushWrites();
      final features = featureSettings;
      final ticketDraft = draft.copyWith(
        clearActiveCourse: true,
        reference:
            draft.managedOrderId != null || features.orderReferenceEnabled
            ? draft.reference
            : '',
        orderNote: draft.managedOrderId != null || features.orderNotesEnabled
            ? draft.orderNote
            : '',
        lines: [
          for (final line in draft.lines)
            features.preparationNotesEnabled
                ? line
                : line.copyWith(preparationNote: ''),
        ],
      );
      ticket = await _repository.convertDraftToTicket(
        ticketDraft,
        heading: heading,
        keepOpen: features.managedOrdersEnabled,
      );
      drafts = await _repository.loadDrafts();
      tickets = await _repository.loadTickets();
      managedOrders = await _repository.loadManagedOrders();
      nextOrderNumber = await _repository.loadNextOrderNumber();
      if (drafts.isEmpty) {
        var replacement = await _repository.createDraft();
        if (features.courseGroupsEnabled && draft.courses.isNotEmpty) {
          replacement = replacement.copyWith(courses: draft.courses);
          await _repository.saveDraft(replacement);
        }
        drafts = [replacement];
      }
      activeDraftId = drafts.first.id;
    });
    return success ? ticket : null;
  }

  Future<bool> _perform(Future<void> Function() operation) async {
    if (saving) return false;
    saving = true;
    saveFailed = false;
    notifyListeners();
    try {
      await operation();
      saving = false;
      notifyListeners();
      return true;
    } catch (_) {
      saving = false;
      saveFailed = true;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    unawaited(_repository.close());
    super.dispose();
  }
}
