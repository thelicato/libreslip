import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../networking/application/client_delivery_controller.dart';
import '../../networking/application/shared_orders_controller.dart';
import '../../networking/presentation/server_destination_selector.dart';
import '../../printing/application/ticket_output_controller.dart';
import '../../printing/domain/ticket_document.dart';
import '../../settings/domain/app_settings.dart';
import '../application/order_workspace_controller.dart';
import '../domain/order_models.dart';
import 'order_identity.dart';
import 'course_composer.dart';
import 'managed_order_composer.dart';
import 'order_estimate.dart';

class ComposePage extends StatefulWidget {
  const ComposePage({
    super.key,
    required this.controller,
    required this.settings,
    required this.printing,
    this.output,
    this.delivery,
    this.sharedOrders,
  });

  final OrderWorkspaceController controller;
  final AppSettings settings;
  final ValueNotifier<bool> printing;
  final TicketOutputController? output;
  final ClientDeliveryController? delivery;
  final SharedOrdersController? sharedOrders;

  @override
  State<ComposePage> createState() => ComposePageState();
}

class ComposePageState extends State<ComposePage> {
  String _query = '';
  String? _categoryId;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller,
      if (widget.output != null) widget.output!,
      if (widget.output != null) widget.output!.printer,
      widget.printing,
      ?widget.sharedOrders,
      if (widget.delivery != null) widget.delivery!,
    ]),
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
          else if (widget.controller.saving || widget.printing.value)
            _StatusBanner(
              icon: Icons.sync_rounded,
              message: widget.printing.value
                  ? l.preparingTicket
                  : l.savingOrders,
              error: false,
            ),
          if (widget.controller.saveFailed ||
              widget.controller.saving ||
              widget.printing.value)
            const SizedBox(height: 18),
          if (widget.controller.featureSettings.managedOrdersEnabled ||
              widget.controller.managedOrders.isNotEmpty ||
              draft.managedOrderId != null) ...[
            ManagedOrderComposer(
              completeWholeSteps: widget.settings.completeWholeSteps,
              controller: widget.controller,
              delivery: widget.delivery,
              sharedOrders: widget.sharedOrders,
              busy: widget.printing.value || widget.controller.saving,
            ),
            const SizedBox(height: 12),
          ],
          if (widget.delivery != null &&
              (widget.delivery!.servers.isNotEmpty ||
                  widget.controller.editingOrder?.destinationId != null)) ...[
            ServerDestinationSelector(
              controller: widget.delivery!,
              order: widget.controller.editingOrder,
              busy: widget.printing.value || widget.controller.saving,
            ),
            const SizedBox(height: 12),
          ],
          if (widget.controller.featureSettings.pricesEnabled) ...[
            OrderEstimate(
              lines: [
                ...?widget.controller.editingOrder?.lines,
                ...draft.lines,
              ],
            ),
            const SizedBox(height: 12),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              if (widget.settings.compactCompose) {
                return _CompactComposePanel(
                  items: widget.controller.items,
                  categories: widget.controller.categories,
                  draft: draft,
                  orderNumber: widget.controller.compositionNumber,
                  features: draft.managedOrderId == null
                      ? widget.controller.featureSettings
                      : widget.controller.featureSettings.copyWith(
                          orderReferenceEnabled: true,
                          orderNotesEnabled: true,
                        ),
                  dividerControl: widget.controller.courseControlsAvailable
                      ? CourseComposer(
                          controller: widget.controller,
                          busy:
                              widget.controller.saving || widget.printing.value,
                        )
                      : null,
                  grouped: widget.controller.courseControlsAvailable,
                  onQuantityChanged: widget.controller.setQuantity,
                  onRemoveLine: widget.controller.removeLine,
                  onLineCourseChanged: widget.controller.setLineCourse,
                  busy: widget.controller.saving || widget.printing.value,
                  query: _query,
                  categoryId: _categoryId,
                  onQueryChanged: (value) => setState(() => _query = value),
                  onCategoryChanged: (value) =>
                      setState(() => _categoryId = value),
                  onIncrement: widget.controller.addCatalogueItem,
                  onDecrement: (line) => line.quantity > 1
                      ? widget.controller.setQuantity(
                          line.id,
                          line.quantity - 1,
                        )
                      : widget.controller.removeLine(line.id),
                  onEditReference: () => _editReference(draft),
                  onEditOrderNote: () => _editOrderNote(draft),
                  onEditNote: _editPreparationNote,
                  onResetOrderNumber: _resetOrderNumber,
                );
              }
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
                orderNumber: widget.controller.compositionNumber,
                features: draft.managedOrderId == null
                    ? widget.controller.featureSettings
                    : widget.controller.featureSettings.copyWith(
                        orderReferenceEnabled: true,
                        orderNotesEnabled: true,
                      ),
                dividerControl: widget.controller.courseControlsAvailable
                    ? CourseComposer(
                        controller: widget.controller,
                        busy: widget.controller.saving || widget.printing.value,
                      )
                    : null,
                grouped: widget.controller.courseControlsAvailable,
                onLineCourseChanged: widget.controller.setLineCourse,
                busy: widget.controller.saving || widget.printing.value,
                standalone: split,
                onReferenceChanged: widget.controller.setReference,
                onOrderNoteChanged: widget.controller.setOrderNote,
                onQuantityChanged: widget.controller.setQuantity,
                onEditNote: _editPreparationNote,
                onRemoveLine: widget.controller.removeLine,
                onResetOrderNumber: _resetOrderNumber,
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

  Future<void> _editReference(OrderDraft draft) async {
    final l = AppLocalizations.of(context);
    final input = TextEditingController(text: draft.reference);
    final reference = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.orderReference),
        content: SizedBox(
          width: 420,
          child: TextField(
            key: const ValueKey('compact-reference-input'),
            controller: input,
            autofocus: true,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: l.orderReferenceHint),
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
    if (reference != null) widget.controller.setReference(reference);
  }

  Future<void> _editOrderNote(OrderDraft draft) async {
    final l = AppLocalizations.of(context);
    final input = TextEditingController(text: draft.orderNote);
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.orderNotes),
        content: SizedBox(
          width: 420,
          child: TextField(
            key: const ValueKey('compact-order-note-input'),
            controller: input,
            autofocus: true,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: l.orderNotesHint),
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
    if (note != null) widget.controller.setOrderNote(note);
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

  Future<void> printTicket() async {
    final l = AppLocalizations.of(context);
    if (widget.printing.value || widget.controller.saving) return;
    final output = widget.output;
    final connected = output?.printer.connected ?? false;
    final required = widget.settings.printerConnectionRequired;
    if (required && !connected) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.connectBeforePrinting)));
      return;
    }
    if (widget.controller.activeDraft?.lines.isEmpty ?? true) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.ticketNeedsItem)));
      return;
    }
    widget.printing.value = true;
    final ticket = await widget.controller.saveActiveTicket(
      heading: widget.settings.heading,
      requirePrintForDelivery: required,
    );
    if (!mounted) return;
    if (ticket == null) {
      widget.printing.value = false;
      return;
    }
    if (!required && widget.delivery != null) {
      unawaited(widget.delivery!.ticketReady(ticket.id));
    }
    if (!connected) {
      widget.printing.value = false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.orderSavedWithoutPrinting)));
      return;
    }
    final result = await output!.printTicket(
      ticket: ticket,
      document: _document(ticket),
    );
    if (result == TicketPrintResult.transmitted && widget.delivery != null) {
      unawaited(widget.delivery!.ticketPrinted(ticket.id));
    }
    if (!mounted) return;
    widget.printing.value = false;
    final message = switch (result) {
      TicketPrintResult.notConnected =>
        required ? l.connectBeforePrinting : l.orderSavedWithoutPrinting,
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
      ungroupedLabel: l.ungrouped,
      orderNotesLabel: l.orderNotes,
      lineNotePrefix: l.lineNoteLabel,
      footer: widget.settings.footer,
      logoPath: widget.settings.logoPath,
      logoWidthPercent: widget.settings.logoWidthPercent,
      typography: widget.settings.typography,
      revisionLabel: ticket.revision > 1
          ? l.additionsRevision(ticket.revision)
          : ticket.revision == 1
          ? l.orderRevision(1)
          : '',
    );
  }
}

class _ComposeOrderHeading extends StatelessWidget {
  const _ComposeOrderHeading({
    required this.reference,
    required this.orderNumber,
    required this.onReset,
  });

  final String reference;
  final int orderNumber;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final identity = OrderIdentity(
      reference: reference,
      numberLabel: l.orderNumber(orderNumber),
    );
    final reset = TextButton.icon(
      key: const ValueKey('reset-order-number'),
      onPressed: onReset,
      icon: const Icon(Icons.restart_alt_rounded),
      label: Text(l.reset),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            (reference.isNotEmpty && constraints.maxWidth < 360) ||
            MediaQuery.textScalerOf(context).scale(14) > 20;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity,
              Align(alignment: AlignmentDirectional.centerEnd, child: reset),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: identity),
            reset,
          ],
        );
      },
    );
  }
}

class _CompactComposePanel extends StatelessWidget {
  const _CompactComposePanel({
    required this.items,
    required this.categories,
    required this.draft,
    required this.orderNumber,
    required this.features,
    this.dividerControl,
    required this.grouped,
    required this.onQuantityChanged,
    required this.onRemoveLine,
    required this.onLineCourseChanged,
    required this.busy,
    required this.query,
    required this.categoryId,
    required this.onQueryChanged,
    required this.onCategoryChanged,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEditReference,
    required this.onEditOrderNote,
    required this.onEditNote,
    required this.onResetOrderNumber,
  });

  final List<CatalogueItem> items;
  final List<ItemCategory> categories;
  final OrderDraft draft;
  final int orderNumber;
  final OrderFeatureSettings features;
  final Widget? dividerControl;
  final bool grouped;
  final void Function(String, int) onQuantityChanged;
  final ValueChanged<String> onRemoveLine;
  final void Function(String, String?) onLineCourseChanged;
  final bool busy;
  final String query;
  final String? categoryId;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<CatalogueItem> onIncrement;
  final ValueChanged<TicketLine> onDecrement;
  final VoidCallback onEditReference;
  final VoidCallback onEditOrderNote;
  final ValueChanged<TicketLine> onEditNote;
  final VoidCallback onResetOrderNumber;

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
      key: const ValueKey('compact-compose-panel'),
      child: Padding(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 400 ? 12 : 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ComposeOrderHeading(
              reference:
                  features.orderReferenceEnabled || draft.managedOrderId != null
                  ? draft.reference
                  : '',
              orderNumber: orderNumber,
              onReset: busy || draft.managedOrderId != null || orderNumber == 1
                  ? null
                  : onResetOrderNumber,
            ),
            if (features.orderReferenceEnabled ||
                features.orderNotesEnabled) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (features.orderReferenceEnabled)
                    OutlinedButton.icon(
                      key: const ValueKey('compact-edit-reference'),
                      onPressed: busy || draft.managedOrderId != null
                          ? null
                          : onEditReference,
                      icon: const Icon(Icons.tag_rounded),
                      label: Text(
                        draft.reference.isEmpty
                            ? l.orderReference
                            : draft.reference,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (features.orderNotesEnabled)
                    OutlinedButton.icon(
                      key: const ValueKey('compact-edit-order-note'),
                      onPressed: busy || draft.managedOrderId != null
                          ? null
                          : onEditOrderNote,
                      icon: const Icon(Icons.notes_rounded),
                      label: Text(
                        draft.orderNote.isEmpty
                            ? l.orderNotes
                            : draft.orderNote,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                final search = TextField(
                  decoration: InputDecoration(
                    labelText: l.searchItems,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                  onChanged: onQueryChanged,
                );
                if (categories.length <= 1) return search;
                final category = DropdownButtonFormField<String?>(
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
                );
                if (constraints.maxWidth < 700) {
                  return Column(
                    children: [search, const SizedBox(height: 8), category],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 10),
                    Expanded(child: category),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  items.isEmpty ? l.emptyItemsBody : l.noItemsFound,
                  textAlign: TextAlign.center,
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 760 ? 2 : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 10) / columns;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      for (final item in filtered)
                        SizedBox(
                          width: width,
                          child: _CompactCatalogueRow(
                            item: item,
                            lines: draft.lines
                                .where(
                                  (line) =>
                                      line.catalogueItemId == item.id &&
                                      (!grouped ||
                                          line.courseId ==
                                              draft.activeCourseId),
                                )
                                .toList(),
                            preparationNotesEnabled:
                                features.preparationNotesEnabled,
                            onIncrement: () => onIncrement(item),
                            onDecrement: onDecrement,
                            onEditNote: onEditNote,
                          ),
                        ),
                    ],
                  );
                },
              ),
            if (grouped && draft.lines.isNotEmpty) ...[
              const Divider(height: 28),
              Text(
                l.groupedOrderSummary,
                key: const ValueKey('grouped-order-summary'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _OrderLines(
                busy: busy,
                draft: draft,
                grouped: true,
                preparationNotesEnabled: features.preparationNotesEnabled,
                onQuantityChanged: onQuantityChanged,
                onEditNote: onEditNote,
                onRemoveLine: onRemoveLine,
                onLineCourseChanged: onLineCourseChanged,
              ),
            ],
            ?dividerControl,
          ],
        ),
      ),
    );
  }
}

class _CompactCatalogueRow extends StatelessWidget {
  const _CompactCatalogueRow({
    required this.item,
    required this.lines,
    required this.preparationNotesEnabled,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEditNote,
  });

  final CatalogueItem item;
  final List<TicketLine> lines;
  final bool preparationNotesEnabled;
  final VoidCallback onIncrement;
  final ValueChanged<TicketLine> onDecrement;
  final ValueChanged<TicketLine> onEditNote;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final quantity = lines.fold<int>(0, (total, line) => total + line.quantity);
    TicketLine? noteLine;
    for (final line in lines) {
      if (line.preparationNote.isNotEmpty) {
        noteLine = line;
        break;
      }
    }
    noteLine ??= lines.firstOrNull;
    final decrementLine = lines.lastOrNull;
    return Material(
      key: ValueKey('compact-item-${item.id}'),
      color: quantity == 0
          ? theme.colorScheme.surfaceContainerLow
          : theme.colorScheme.primaryContainer.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: theme.textTheme.titleSmall),
                    if (item.category != null)
                      Text(
                        item.category!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                );
                final controls = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (preparationNotesEnabled && quantity > 0)
                      IconButton(
                        key: ValueKey('compact-note-${item.id}'),
                        onPressed: noteLine == null
                            ? null
                            : () => onEditNote(noteLine!),
                        tooltip: l.preparationNote,
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: const Icon(Icons.sticky_note_2_outlined),
                      ),
                    Material(
                      key: ValueKey('quantity-stepper-${item.id}'),
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: ValueKey('compact-minus-${item.id}'),
                            onPressed: decrementLine == null
                                ? null
                                : () => onDecrement(decrementLine),
                            tooltip: l.decreaseQuantity,
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 32),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                '$quantity',
                                key: ValueKey('compact-quantity-${item.id}'),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                          ),
                          IconButton(
                            key: ValueKey('compose-item-${item.id}'),
                            onPressed: quantity >= 999 ? null : onIncrement,
                            tooltip: l.increaseQuantity,
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                if (constraints.maxWidth < 320) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      title,
                      const SizedBox(height: 4),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: controls,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 8),
                    controls,
                  ],
                );
              },
            ),
            if (noteLine?.preparationNote.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: 2,
                  end: 8,
                  bottom: 6,
                ),
                child: Text(
                  noteLine!.preparationNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
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
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 400 ? 12 : 18),
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
    this.dividerControl,
    required this.grouped,
    required this.onLineCourseChanged,
    required this.busy,
    required this.standalone,
    required this.onReferenceChanged,
    required this.onOrderNoteChanged,
    required this.onQuantityChanged,
    required this.onEditNote,
    required this.onRemoveLine,
    required this.onResetOrderNumber,
  });

  final OrderDraft draft;
  final int orderNumber;
  final OrderFeatureSettings features;
  final Widget? dividerControl;
  final bool grouped;
  final void Function(String, String?) onLineCourseChanged;
  final bool busy;
  final bool standalone;
  final ValueChanged<String> onReferenceChanged;
  final ValueChanged<String> onOrderNoteChanged;
  final void Function(String, int) onQuantityChanged;
  final ValueChanged<TicketLine> onEditNote;
  final ValueChanged<String> onRemoveLine;
  final VoidCallback onResetOrderNumber;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final content = Padding(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 400 ? 12 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ComposeOrderHeading(
            reference:
                features.orderReferenceEnabled || draft.managedOrderId != null
                ? draft.reference
                : '',
            orderNumber: orderNumber,
            onReset: busy || draft.managedOrderId != null || orderNumber == 1
                ? null
                : onResetOrderNumber,
          ),
          if (features.orderReferenceEnabled) ...[
            const SizedBox(height: 16),
            TextFormField(
              key: ValueKey('reference-${draft.id}'),
              initialValue: draft.reference,
              readOnly: busy || draft.managedOrderId != null,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
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
            _OrderLines(
              busy: busy,
              draft: draft,
              grouped: grouped,
              preparationNotesEnabled: features.preparationNotesEnabled,
              onQuantityChanged: onQuantityChanged,
              onEditNote: onEditNote,
              onRemoveLine: onRemoveLine,
              onLineCourseChanged: onLineCourseChanged,
            ),
          ?dividerControl,
          if (features.orderNotesEnabled) ...[
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey('order-note-${draft.id}'),
              initialValue: draft.orderNote,
              readOnly: busy || draft.managedOrderId != null,
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
          const SizedBox(height: 4),
        ],
      ),
    );
    return standalone ? Card(child: content) : content;
  }
}

class _OrderLines extends StatelessWidget {
  const _OrderLines({
    required this.draft,
    required this.busy,
    required this.grouped,
    required this.preparationNotesEnabled,
    required this.onQuantityChanged,
    required this.onEditNote,
    required this.onRemoveLine,
    required this.onLineCourseChanged,
  });
  final OrderDraft draft;
  final bool busy;
  final bool grouped;
  final bool preparationNotesEnabled;
  final void Function(String, int) onQuantityChanged;
  final ValueChanged<TicketLine> onEditNote;
  final ValueChanged<String> onRemoveLine;
  final void Function(String, String?) onLineCourseChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final section in courseSections(
        draft.courses,
        draft.lines,
        (line) => line.courseId,
      )) ...[
        if (grouped)
          CourseHeading(course: section.course, courses: draft.courses),
        for (final line in section.lines)
          _OrderLineCard(
            line: line,
            preparationNotesEnabled: preparationNotesEnabled,
            coursePicker: grouped && draft.courses.isNotEmpty
                ? _LineDividerMoves(
                    draft: draft,
                    line: line,
                    busy: busy,
                    onMove: onLineCourseChanged,
                  )
                : null,
            onQuantityChanged: (value) => onQuantityChanged(line.id, value),
            onEditNote: () => onEditNote(line),
            onRemove: () => onRemoveLine(line.id),
          ),
      ],
      if (grouped &&
          draft.courses.lastOrNull?.isDivider == true &&
          !draft.lines.any(
            (line) => line.courseId == draft.courses.last.id,
          )) ...[
        CourseHeading(course: draft.courses.last, courses: draft.courses),
        Text(
          AppLocalizations.of(context).dividerEmptyBody,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ],
  );
}

class _LineDividerMoves extends StatelessWidget {
  const _LineDividerMoves({
    required this.draft,
    required this.line,
    required this.busy,
    required this.onMove,
  });
  final OrderDraft draft;
  final TicketLine line;
  final bool busy;
  final void Function(String, String?) onMove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ids = <String?>[null, ...draft.courses.map((course) => course.id)];
    final index = ids.indexOf(line.courseId);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: ValueKey('line-above-divider-${line.id}'),
          tooltip: l.moveAboveDivider,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: busy || index <= 0
              ? null
              : () => onMove(line.id, ids[index - 1]),
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
        ),
        IconButton(
          key: ValueKey('line-below-divider-${line.id}'),
          tooltip: l.moveBelowDivider,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: busy || index < 0 || index >= ids.length - 1
              ? null
              : () => onMove(line.id, ids[index + 1]),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
      ],
    );
  }
}

class _OrderLineCard extends StatelessWidget {
  const _OrderLineCard({
    required this.line,
    required this.preparationNotesEnabled,
    required this.onQuantityChanged,
    required this.onEditNote,
    required this.onRemove,
    this.coursePicker,
  });

  final TicketLine line;
  final bool preparationNotesEnabled;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onEditNote;
  final VoidCallback onRemove;
  final Widget? coursePicker;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('order-line-${line.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(line.name, style: theme.textTheme.titleMedium),
              ),
              IconButton(
                onPressed: onRemove,
                tooltip: l.removeLine,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final style = theme.textTheme.titleMedium!;
              final counter = TextPainter(
                text: TextSpan(text: '${line.quantity}', style: style),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout();
              final counterWidth = counter.width + 8;
              counter.dispose();
              final stepper = Material(
                key: ValueKey('quantity-stepper-${line.id}'),
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    IconButton(
                      key: ValueKey('line-minus-${line.id}'),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: line.quantity > 1
                          ? () => onQuantityChanged(line.quantity - 1)
                          : null,
                      tooltip: l.decreaseQuantity,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Expanded(
                      child: Text(
                        '${line.quantity}',
                        textAlign: TextAlign.center,
                        style: style,
                      ),
                    ),
                    IconButton(
                      key: ValueKey('line-plus-${line.id}'),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: line.quantity < 999
                          ? () => onQuantityChanged(line.quantity + 1)
                          : null,
                      tooltip: l.increaseQuantity,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              );
              if (coursePicker == null) return stepper;
              if (constraints.maxWidth >= 192 + 4 + counterWidth) {
                return Row(
                  children: [
                    SizedBox(width: 96, child: coursePicker),
                    const SizedBox(width: 4),
                    Expanded(child: stepper),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: coursePicker,
                  ),
                  const SizedBox(height: 4),
                  stepper,
                ],
              );
            },
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
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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
