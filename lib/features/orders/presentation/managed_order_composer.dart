import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../networking/application/client_delivery_controller.dart';
import '../../networking/presentation/progress_sync_controls.dart';
import '../application/order_workspace_controller.dart';
import '../domain/order_models.dart';
import 'delivery_progress.dart';
import 'order_identity.dart';

class ManagedOrderComposer extends StatelessWidget {
  const ManagedOrderComposer({
    super.key,
    required this.controller,
    this.busy = false,
    this.delivery,
  });
  final OrderWorkspaceController controller;
  final bool busy;
  final ClientDeliveryController? delivery;

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
                          builder: (_) => _ActiveOrdersDialog(
                            controller: controller,
                            delivery: delivery,
                          ),
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
                children: [
                  _OrderContents(
                    order: order,
                    controller: controller,
                    delivery: delivery,
                  ),
                ],
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
  const _ActiveOrdersDialog({required this.controller, this.delivery});
  final OrderWorkspaceController controller;
  final ClientDeliveryController? delivery;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      return AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 40,
          vertical: 24,
        ),
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
                            title: Text(l.deliveryProgress),
                            children: [
                              _OrderContents(
                                order: order,
                                controller: controller,
                                delivery: delivery,
                              ),
                            ],
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
  const _OrderContents({
    required this.order,
    required this.controller,
    this.delivery,
  });
  final ManagedOrder order;
  final OrderWorkspaceController controller;
  final ClientDeliveryController? delivery;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (order.destinationId != null && delivery != null)
          ProgressSyncControls(
            key: ValueKey('progress-sync-controls-${order.id}'),
            order: order,
            workspace: controller,
            delivery: delivery!,
          )
        else
          Text(l.deliveryProgressOffline),
        const SizedBox(height: 8),
        Text(l.clientDeliveryRules),
        const SizedBox(height: 12),
        DeliveryProgress(
          showHelp: false,
          courses: order.courses,
          lines: [
            for (final line in order.lines)
              DeliveryProgressLine(
                id: line.id,
                name: line.name,
                quantity: line.quantity,
                delivered: order.deliveredQuantity(line.id),
                note: line.preparationNote,
                courseId: line.courseId,
              ),
          ],
          busy: controller.saving,
          onChanged: (id, quantity, expected) async {
            final success = await controller.setLineDelivered(
              order.id,
              id,
              quantity,
              expectedQuantity: expected,
            );
            if (!success && context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l.deliveryProgressFailed)));
            }
          },
        ),
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
