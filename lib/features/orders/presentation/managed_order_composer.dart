import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/order_workspace_controller.dart';
import '../domain/order_models.dart';
import 'course_composer.dart';
import 'order_identity.dart';

class ManagedOrderComposer extends StatelessWidget {
  const ManagedOrderComposer({
    super.key,
    required this.controller,
    this.busy = false,
  });
  final OrderWorkspaceController controller;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final order = controller.editingOrder;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (order == null) ...[
              if (controller.featureSettings.managedOrdersEnabled)
                Text(l.newOrderKeptOpen),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  key: const ValueKey('active-orders'),
                  onPressed: busy
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (_) =>
                              _ActiveOrdersDialog(controller: controller),
                        ),
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: Text(l.activeOrders),
                ),
              ),
            ] else ...[
              Text(
                l.additionEditing,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              OrderIdentity(
                reference: order.reference,
                numberLabel: l.ticketNumber(order.number),
              ),
              Text(l.orderRevision(order.revision + 1)),
              if (order.destinationId == null) Text(l.activeOrderLocal),
              const SizedBox(height: 8),
              Text(l.additionBody),
              ExpansionTile(
                key: const ValueKey('previously-ordered'),
                tilePadding: EdgeInsets.zero,
                title: Text(l.previouslyOrdered),
                children: [_OrderContents(order: order)],
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const ValueKey('cancel-addition'),
                  onPressed: busy
                      ? null
                      : () async {
                          if (await _confirm(
                                context,
                                l.cancelAddition,
                                l.cancelAdditionBody,
                              ) ==
                              true) {
                            await controller.cancelAddition();
                          }
                        },
                  icon: const Icon(Icons.close_rounded),
                  label: Text(l.cancelAddition),
                ),
              ),
              Text(
                l.orderAdditions,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActiveOrdersDialog extends StatelessWidget {
  const _ActiveOrdersDialog({required this.controller});
  final OrderWorkspaceController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      return AlertDialog(
        title: Text(l.activeOrders),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (controller.managedOrders.isEmpty) Text(l.activeOrdersEmpty),
                if (!controller.canBeginAddition) ...[
                  Text(l.finishCompositionFirst),
                  const SizedBox(height: 12),
                ],
                for (final order in controller.managedOrders)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OrderIdentity(
                            reference: order.reference,
                            numberLabel: l.ticketNumber(order.number),
                          ),
                          Text(l.orderRevision(order.revision)),
                          Text(l.itemCount(order.itemCount)),
                          if (order.destinationId == null)
                            Text(l.activeOrderLocal),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(l.previouslyOrdered),
                            children: [_OrderContents(order: order)],
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                key: ValueKey('add-to-order-${order.id}'),
                                onPressed: !controller.canBeginAddition
                                    ? null
                                    : () async {
                                        final opened = await controller
                                            .beginAddition(order.id);
                                        if (opened && context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      },
                                icon: const Icon(Icons.add_rounded),
                                label: Text(l.addToOrder),
                              ),
                              TextButton(
                                key: ValueKey('close-order-${order.id}'),
                                onPressed:
                                    controller.saving ||
                                        controller
                                                .activeDraft
                                                ?.managedOrderId ==
                                            order.id
                                    ? null
                                    : () async {
                                        if (await _confirm(
                                              context,
                                              l.closeActiveOrder,
                                              l.closeActiveOrderBody,
                                            ) ==
                                            true) {
                                          await controller.closeOrder(order.id);
                                        }
                                      },
                                child: Text(l.closeActiveOrder),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (controller.saveFailed)
                  Text(
                    l.saveError,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: controller.saving ? null : () => Navigator.pop(context),
            child: Text(l.close),
          ),
        ],
      );
    },
  );
}

class _OrderContents extends StatelessWidget {
  const _OrderContents({required this.order});
  final ManagedOrder order;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in courseSections(
          order.courses,
          order.lines,
          (line) => line.courseId,
        )) ...[
          if (order.courses.isNotEmpty)
            CourseHeading(name: section.course?.name ?? l.ungrouped),
          for (final line in section.lines)
            ListTile(
              title: Text('${line.quantity} × ${line.name}'),
              subtitle: line.preparationNote.isEmpty
                  ? null
                  : Text(line.preparationNote),
            ),
        ],
      ],
    );
  }
}

Future<bool?> _confirm(BuildContext context, String title, String body) =>
    showDialog<bool>(
      context: context,
      builder: (context) {
        final l = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(title),
            ),
          ],
        );
      },
    );
