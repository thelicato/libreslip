import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/order_workspace_controller.dart';
import '../domain/order_models.dart';

class ComposePage extends StatefulWidget {
  const ComposePage({
    super.key,
    required this.controller,
    required this.heading,
  });

  final OrderWorkspaceController controller;
  final String heading;

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  String _query = '';
  String? _categoryId;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final draft = widget.controller.activeDraft;
      if (draft == null) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DraftToolbar(
            controller: widget.controller,
            onDelete: _confirmDeleteDraft,
          ),
          if (widget.controller.saveFailed) ...[
            const SizedBox(height: 12),
            _StatusBanner(
              icon: Icons.sync_problem_rounded,
              message: l.draftSaveError,
              error: true,
            ),
          ] else if (widget.controller.saving) ...[
            const SizedBox(height: 12),
            _StatusBanner(
              icon: Icons.sync_rounded,
              message: l.savingOrders,
              error: false,
            ),
          ],
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final catalogue = _CataloguePanel(
                items: widget.controller.items,
                categories: widget.controller.categories,
                query: _query,
                categoryId: _categoryId,
                onQueryChanged: (value) => setState(() => _query = value),
                onCategoryChanged: (value) =>
                    setState(() => _categoryId = value),
                onAdd: widget.controller.addCatalogueItem,
                onAdHoc: _addAdHoc,
              );
              final order = _DraftPanel(
                draft: draft,
                heading: widget.heading,
                onReferenceChanged: widget.controller.setReference,
                onOrderNoteChanged: widget.controller.setOrderNote,
                onQuantityChanged: widget.controller.setQuantity,
                onEditNote: _editPreparationNote,
                onRemoveLine: widget.controller.removeLine,
                onSave: _saveTicket,
              );
              if (constraints.maxWidth >= 860) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: catalogue),
                    const SizedBox(width: 18),
                    Expanded(child: order),
                  ],
                );
              }
              return Column(
                children: [catalogue, const SizedBox(height: 18), order],
              );
            },
          ),
        ],
      );
    },
  );

  Future<void> _addAdHoc() async {
    final l = AppLocalizations.of(context);
    final input = TextEditingController();
    final form = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.adHocItem),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.adHocItemBody),
              const SizedBox(height: 18),
              TextFormField(
                key: const ValueKey('ad-hoc-name'),
                controller: input,
                autofocus: true,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: l.itemName,
                  hintText: l.itemNameHint,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l.itemRequired;
                  }
                  return value.trim().length > 80 ? l.itemNameTooLong : null;
                },
                onFieldSubmitted: (_) {
                  if (form.currentState!.validate()) {
                    Navigator.pop(context, input.text.trim());
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, input.text.trim());
              }
            },
            child: Text(l.addToDraft),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    input.dispose();
    if (name != null) widget.controller.addAdHocItem(name);
  }

  Future<void> _editPreparationNote(TicketLine line) async {
    final l = AppLocalizations.of(context);
    final input = TextEditingController(text: line.preparationNote);
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(line.name),
        content: TextField(
          key: const ValueKey('preparation-note'),
          controller: input,
          autofocus: true,
          maxLength: 300,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: l.preparationNote,
            hintText: l.preparationNoteHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: Text(l.save),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    input.dispose();
    if (note != null) widget.controller.setPreparationNote(line.id, note);
  }

  Future<void> _confirmDeleteDraft() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteDraftQuestion),
        content: Text(l.deleteDraftBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.controller.deleteActiveDraft();
  }

  Future<void> _saveTicket() async {
    final l = AppLocalizations.of(context);
    if (widget.controller.activeDraft?.lines.isEmpty ?? true) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.ticketNeedsItem)));
      return;
    }
    final ticket = await widget.controller.saveActiveTicket(
      heading: widget.heading,
    );
    if (!mounted) return;
    if (ticket != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.ticketSaved)));
    }
  }
}

class _DraftToolbar extends StatelessWidget {
  const _DraftToolbar({required this.controller, required this.onDelete});

  final OrderWorkspaceController controller;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey('draft-selector-${controller.activeDraftId}'),
                initialValue: controller.activeDraftId,
                decoration: InputDecoration(
                  labelText: l.drafts,
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                ),
                items: [
                  for (var index = 0; index < controller.drafts.length; index++)
                    DropdownMenuItem(
                      value: controller.drafts[index].id,
                      child: Text(
                        controller.drafts[index].reference.trim().isEmpty
                            ? '${l.draft} ${controller.drafts.length - index}'
                            : controller.drafts[index].reference,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) controller.selectDraft(value);
                },
              ),
            ),
            OutlinedButton.icon(
              onPressed: controller.saving ? null : controller.createDraft,
              icon: const Icon(Icons.note_add_outlined),
              label: Text(l.newDraft),
            ),
            IconButton.outlined(
              constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
              onPressed: controller.saving ? null : onDelete,
              tooltip: l.deleteDraft,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _CataloguePanel extends StatelessWidget {
  const _CataloguePanel({
    required this.items,
    required this.categories,
    required this.query,
    required this.categoryId,
    required this.onQueryChanged,
    required this.onCategoryChanged,
    required this.onAdd,
    required this.onAdHoc,
  });

  final List<CatalogueItem> items;
  final List<ItemCategory> categories;
  final String query;
  final String? categoryId;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<CatalogueItem> onAdd;
  final VoidCallback onAdHoc;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cleanQuery = query.trim().toLowerCase();
    final filtered = items
        .where(
          (item) =>
              (cleanQuery.isEmpty ||
                  item.name.toLowerCase().contains(cleanQuery) ||
                  (item.category?.name.toLowerCase().contains(cleanQuery) ??
                      false)) &&
              (categoryId == null || item.category?.id == categoryId),
        )
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.items, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            TextField(
              decoration: InputDecoration(
                labelText: l.searchItems,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
              onChanged: onQueryChanged,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: categoryId,
              decoration: InputDecoration(labelText: l.category),
              items: [
                DropdownMenuItem(value: null, child: Text(l.allCategories)),
                for (final category in categories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
              ],
              onChanged: onCategoryChanged,
            ),
            const SizedBox(height: 14),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Text(
                  items.isEmpty ? l.emptyItemsBody : l.noItemsFound,
                  textAlign: TextAlign.center,
                ),
              )
            else
              for (final item in filtered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      key: ValueKey('compose-item-${item.id}'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onAdd(item),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            if (item.isFavourite) ...[
                              Icon(
                                Icons.star_rounded,
                                size: 19,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  if (item.category != null)
                                    Text(
                                      item.category!.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                ],
                              ),
                            ),
                            const Icon(Icons.add_circle_outline_rounded),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            OutlinedButton.icon(
              key: const ValueKey('add-ad-hoc'),
              onPressed: onAdHoc,
              icon: const Icon(Icons.add_rounded),
              label: Text(l.adHocItem),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftPanel extends StatelessWidget {
  const _DraftPanel({
    required this.draft,
    required this.heading,
    required this.onReferenceChanged,
    required this.onOrderNoteChanged,
    required this.onQuantityChanged,
    required this.onEditNote,
    required this.onRemoveLine,
    required this.onSave,
  });

  final OrderDraft draft;
  final String heading;
  final ValueChanged<String> onReferenceChanged;
  final ValueChanged<String> onOrderNoteChanged;
  final void Function(String, int) onQuantityChanged;
  final ValueChanged<TicketLine> onEditNote;
  final ValueChanged<String> onRemoveLine;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              heading.trim().isEmpty ? l.defaultHeading : heading,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Chip(label: Text(l.itemCount(draft.itemCount))),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: ValueKey('reference-${draft.id}'),
              initialValue: draft.reference,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: l.orderReference,
                hintText: l.orderReferenceHint,
              ),
              onChanged: onReferenceChanged,
            ),
            const SizedBox(height: 8),
            if (draft.lines.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.34,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.playlist_add_rounded,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l.draftEmptyTitle,
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(l.draftEmptyBody, textAlign: TextAlign.center),
                  ],
                ),
              )
            else
              for (final line in draft.lines)
                _DraftLineCard(
                  line: line,
                  onQuantityChanged: (value) =>
                      onQuantityChanged(line.id, value),
                  onEditNote: () => onEditNote(line),
                  onRemove: () => onRemoveLine(line.id),
                ),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey('order-note-${draft.id}'),
              initialValue: draft.orderNote,
              maxLength: 500,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l.orderNotes,
                hintText: l.orderNotesHint,
              ),
              onChanged: onOrderNoteChanged,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey('save-ticket'),
              onPressed: draft.lines.isEmpty ? null : onSave,
              icon: const Icon(Icons.archive_outlined),
              label: Text(l.saveTicket),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftLineCard extends StatelessWidget {
  const _DraftLineCard({
    required this.line,
    required this.onQuantityChanged,
    required this.onEditNote,
    required this.onRemove,
  });

  final TicketLine line;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onEditNote;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: onRemove,
                tooltip: l.removeLine,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Row(
            children: [
              IconButton.outlined(
                onPressed: line.quantity > 1
                    ? () => onQuantityChanged(line.quantity - 1)
                    : null,
                tooltip: l.quantity,
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  '${line.quantity}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton.outlined(
                onPressed: line.quantity < 999
                    ? () => onQuantityChanged(line.quantity + 1)
                    : null,
                tooltip: l.quantity,
                icon: const Icon(Icons.add_rounded),
              ),
              const Spacer(),
              Flexible(
                child: TextButton.icon(
                  onPressed: onEditNote,
                  icon: const Icon(Icons.sticky_note_2_outlined),
                  label: Text(l.preparationNote),
                ),
              ),
            ],
          ),
          if (line.preparationNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              line.preparationNote,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.message,
    required this.error,
  });

  final IconData icon;
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: error ? scheme.errorContainer : scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
