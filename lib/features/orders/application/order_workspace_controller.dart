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
    drafts = await _repository.loadDrafts();
    tickets = await _repository.loadTickets();
  }

  void selectDraft(String id) {
    if (drafts.any((draft) => draft.id == id)) {
      activeDraftId = id;
      notifyListeners();
    }
  }

  Future<void> createDraft() async {
    await _perform(() async {
      final draft = await _repository.createDraft();
      drafts = [draft, ...drafts];
      activeDraftId = draft.id;
    });
  }

  Future<void> deleteActiveDraft() async {
    final draft = activeDraft;
    if (draft == null) return;
    await flushWrites();
    await _perform(() async {
      await _repository.deleteDraft(draft.id);
      drafts = drafts.where((entry) => entry.id != draft.id).toList();
      if (drafts.isEmpty) {
        final replacement = await _repository.createDraft();
        drafts = [replacement];
      }
      activeDraftId = drafts.first.id;
    });
  }

  Future<bool> saveItem({
    CatalogueItem? existing,
    required String name,
    String? categoryName,
    required bool isFavourite,
    String? imagePath,
  }) async {
    final previousImage = existing?.imagePath;
    final success = await _perform(() async {
      await _repository.saveItem(
        id: existing?.id,
        name: name,
        categoryName: categoryName,
        isFavourite: isFavourite,
        imagePath: imagePath,
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
    if (draft == null) return;
    final lines = [...draft.lines];
    final existingIndex = lines.indexWhere(
      (line) => line.catalogueItemId == item.id && line.preparationNote.isEmpty,
    );
    if (existingIndex >= 0 && lines[existingIndex].quantity < 999) {
      final existing = lines[existingIndex];
      lines[existingIndex] = existing.copyWith(quantity: existing.quantity + 1);
    } else {
      lines.add(
        TicketLine(
          id: createLocalId(),
          catalogueItemId: item.id,
          name: item.name,
          quantity: 1,
        ),
      );
    }
    _replaceActive(
      draft.copyWith(lines: lines, updatedAt: DateTime.now().toUtc()),
    );
  }

  void addAdHocItem(String name) {
    final draft = activeDraft;
    final cleanName = name.trim();
    if (draft == null || cleanName.isEmpty || cleanName.length > 80) return;
    _replaceActive(
      draft.copyWith(
        updatedAt: DateTime.now().toUtc(),
        lines: [
          ...draft.lines,
          TicketLine(id: createLocalId(), name: cleanName, quantity: 1),
        ],
      ),
    );
  }

  void setQuantity(String lineId, int quantity) {
    final draft = activeDraft;
    if (draft == null || quantity < 1 || quantity > 999) return;
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

  void setPreparationNote(String lineId, String note) {
    final draft = activeDraft;
    if (draft == null || note.length > 300) return;
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
    if (draft == null) return;
    _replaceActive(
      draft.copyWith(
        updatedAt: DateTime.now().toUtc(),
        lines: draft.lines.where((line) => line.id != lineId).toList(),
      ),
    );
  }

  void setReference(String reference) {
    final draft = activeDraft;
    if (draft == null || reference.length > 80) return;
    _replaceActive(
      draft.copyWith(reference: reference, updatedAt: DateTime.now().toUtc()),
    );
  }

  void setOrderNote(String note) {
    final draft = activeDraft;
    if (draft == null || note.length > 500) return;
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
    if (draft == null || draft.lines.isEmpty) return null;
    try {
      await flushWrites();
    } catch (_) {
      return null;
    }
    SavedTicket? ticket;
    final success = await _perform(() async {
      ticket = await _repository.convertDraftToTicket(draft, heading: heading);
      drafts = await _repository.loadDrafts();
      tickets = await _repository.loadTickets();
      if (drafts.isEmpty) {
        final replacement = await _repository.createDraft();
        drafts = [replacement];
      }
      activeDraftId = drafts.first.id;
    });
    return success ? ticket : null;
  }

  Future<void> duplicateTicket(SavedTicket ticket) async {
    await _perform(() async {
      final draft = await _repository.createDraft(fromTicket: ticket);
      drafts = [draft, ...drafts];
      activeDraftId = draft.id;
    });
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
