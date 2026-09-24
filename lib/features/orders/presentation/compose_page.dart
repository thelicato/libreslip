import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../printing/application/ticket_output_controller.dart';
import '../../printing/domain/ticket_document.dart';
import '../../settings/domain/app_settings.dart';
import '../application/order_workspace_controller.dart';
import '../domain/order_models.dart';

class ComposePage extends StatefulWidget {
  const ComposePage({
    super.key,
    required this.controller,
    required this.settings,
    this.output,
  });

  final OrderWorkspaceController controller;
  final AppSettings settings;
  final TicketOutputController? output;

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  String _query = '';
  String? _categoryId;
  bool _printing = false;

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
          if (widget.controller.saveFailed)
            _StatusBanner(
              icon: Icons.sync_problem_rounded,
              message: l.draftSaveError,
              error: true,
            )
          else if (widget.controller.saving || _printing)
            _StatusBanner(
              icon: Icons.sync_rounded,
              message: _printing ? l.preparingTicket : l.savingOrders,
              error: false,
            ),
          if (widget.controller.saveFailed ||
              widget.controller.saving ||
              _printing)
            const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final split = constraints.maxWidth >= 860;
              final catalogue = _CataloguePanel(
                items: widget.controller.items,
                categories: widget.controller.categories,
                query: _query,
                categoryId: _categoryId,
                standalone: split,
                onQueryChanged: (value) => setState(() => _query = value),
                onCategoryChanged: (value) =>
                    setState(() => _categoryId = value),
                onAdd: widget.controller.addCatalogueItem,
              );
              final order = _OrderPanel(
                draft: draft,
                orderNumber: widget.controller.nextOrderNumber,
                features: widget.controller.featureSettings,
                busy: widget.controller.saving || _printing,
                standalone: split,
                onReferenceChanged: widget.controller.setReference,
                onOrderNoteChanged: widget.controller.setOrderNote,
                onQuantityChanged: widget.controller.setQuantity,
                onEditNote: _editPreparationNote,
                onRemoveLine: widget.controller.removeLine,
                onResetOrderNumber: _resetOrderNumber,
                onPrint: _printTicket,
              );
              if (split) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: catalogue),
                    const SizedBox(width: 18),
                    Expanded(child: order),
                  ],
                );
              }
              return Card(
                child: Column(
                  children: [catalogue, const Divider(height: 1), order],
                ),
              );
            },
          ),
        ],
      );
    },
  );

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

  Future<void> _resetOrderNumber() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.resetOrderNumberQuestion),
        content: Text(l.resetOrderNumberBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirm-reset-order-number'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.reset),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final reset = await widget.controller.resetOrderNumber();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(reset ? l.orderNumberReset : l.orderNumberResetFailed),
      ),
    );
  }

  Future<void> _printTicket() async {
    final l = AppLocalizations.of(context);
    if (_printing || widget.controller.saving) return;
    if (widget.controller.activeDraft?.lines.isEmpty ?? true) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.ticketNeedsItem)));
      return;
    }
    setState(() => _printing = true);
    final ticket = await widget.controller.saveActiveTicket(
      heading: widget.settings.heading,
    );
    if (!mounted) return;
    if (ticket == null) {
      setState(() => _printing = false);
      return;
    }
    final output = widget.output;
    if (output == null) {
      setState(() => _printing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.ticketSaved)));
      return;
    }
    final result = await output.printTicket(
      ticket: ticket,
      document: _document(ticket),
    );
    if (!mounted) return;
    setState(() => _printing = false);
    final message = switch (result) {
      TicketPrintResult.queued => l.printQueued,
      TicketPrintResult.transmitted => l.printTransmitted,
      TicketPrintResult.failed => l.printFailed,
      TicketPrintResult.uncertain => l.printUncertain,
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  TicketDocument _document(SavedTicket ticket) {
    final l = AppLocalizations.of(context);
    final local = ticket.createdAt.toLocal();
    final material = MaterialLocalizations.of(context);
    return TicketDocument.fromTicket(
      ticket: ticket,
      fallbackHeading: l.defaultHeading,
      ticketLabel: l.ticketLabel,
      createdAt:
          '${material.formatFullDate(local)} · '
          '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}',
      referenceLabel: l.orderReference,
      orderNotesLabel: l.orderNotes,
      lineNotePrefix: l.lineNoteLabel,
      footer: widget.settings.footer,
      logoPath: widget.settings.logoPath,
    );
  }
}

class _CataloguePanel extends StatelessWidget {
  const _CataloguePanel({
    required this.items,
    required this.categories,
    required this.query,
    required this.categoryId,
    required this.standalone,
    required this.onQueryChanged,
    required this.onCategoryChanged,
    required this.onAdd,
  });

  final List<CatalogueItem> items;
  final List<ItemCategory> categories;
  final String query;
  final String? categoryId;
  final bool standalone;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<CatalogueItem> onAdd;

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
    final content = Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.addItems, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          TextField(
            decoration: InputDecoration(
              labelText: l.searchItems,
              prefixIcon: const Icon(Icons.search_rounded),
            ),
            onChanged: onQueryChanged,
          ),
          if (categories.length > 1) ...[
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
          ],
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: Theme.of(context).textTheme.titleSmall,
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
        ],
      ),
    );
    return standalone ? Card(child: content) : content;
  }
}

class _OrderPanel extends StatelessWidget {
  const _OrderPanel({
    required this.draft,
    required this.orderNumber,
    required this.features,
    required this.busy,
    required this.standalone,
    required this.onReferenceChanged,
    required this.onOrderNoteChanged,
    required this.onQuantityChanged,
    required this.onEditNote,
    required this.onRemoveLine,
    required this.onResetOrderNumber,
    required this.onPrint,
  });

  final OrderDraft draft;
  final int orderNumber;
  final OrderFeatureSettings features;
  final bool busy;
  final bool standalone;
  final ValueChanged<String> onReferenceChanged;
  final ValueChanged<String> onOrderNoteChanged;
  final void Function(String, int) onQuantityChanged;
  final ValueChanged<TicketLine> onEditNote;
  final ValueChanged<String> onRemoveLine;
  final VoidCallback onResetOrderNumber;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.orderNumber(orderNumber),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                key: const ValueKey('reset-order-number'),
                onPressed: busy || orderNumber == 1 ? null : onResetOrderNumber,
                icon: const Icon(Icons.restart_alt_rounded),
                label: Text(l.reset),
              ),
            ],
          ),
          if (features.orderReferenceEnabled) ...[
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
          ],
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
              _OrderLineCard(
                line: line,
                preparationNotesEnabled: features.preparationNotesEnabled,
                onQuantityChanged: (value) => onQuantityChanged(line.id, value),
                onEditNote: () => onEditNote(line),
                onRemove: () => onRemoveLine(line.id),
              ),
          if (features.orderNotesEnabled) ...[
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
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const ValueKey('print-ticket'),
            onPressed: draft.lines.isEmpty || busy ? null : onPrint,
            icon: const Icon(Icons.print_rounded),
            label: Text(l.printTicket),
          ),
        ],
      ),
    );
    return standalone ? Card(child: content) : content;
  }
}

class _OrderLineCard extends StatelessWidget {
  const _OrderLineCard({
    required this.line,
    required this.preparationNotesEnabled,
    required this.onQuantityChanged,
    required this.onEditNote,
    required this.onRemove,
  });

  final TicketLine line;
  final bool preparationNotesEnabled;
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
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: line.quantity > 1
                      ? () => onQuantityChanged(line.quantity - 1)
                      : null,
                  tooltip: l.decreaseQuantity,
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${line.quantity}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: line.quantity < 999
                      ? () => onQuantityChanged(line.quantity + 1)
                      : null,
                  tooltip: l.increaseQuantity,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          if (preparationNotesEnabled) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: onEditNote,
              icon: const Icon(Icons.sticky_note_2_outlined),
              label: Text(l.preparationNote),
            ),
            if (line.preparationNote.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                line.preparationNote,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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
