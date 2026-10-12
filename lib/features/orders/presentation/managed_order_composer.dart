import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../networking/application/client_delivery_controller.dart';
import '../../networking/application/shared_orders_controller.dart';
import '../../networking/domain/client_transport.dart';
import '../../networking/presentation/progress_sync_controls.dart';
import '../../networking/presentation/shared_order_controls.dart';
import '../application/order_workspace_controller.dart';
import '../domain/order_models.dart';
import 'course_composer.dart';
import 'delivery_progress.dart';
import 'order_identity.dart';
import 'order_estimate.dart';

class ManagedOrderComposer extends StatelessWidget {
  const ManagedOrderComposer({
    super.key,
    required this.controller,
    this.busy = false,
    this.delivery,
    this.sharedOrders,
    this.completeWholeSteps = false,
  });
  final OrderWorkspaceController controller;
  final bool busy;
  final ClientDeliveryController? delivery;
  final SharedOrdersController? sharedOrders;
  final bool completeWholeSteps;

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
            if (order != null) ...[
              Text(
                l.additionEditing,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              OrderIdentity(
                reference: order.reference,
                numberLabel: l.orderNumber(order.number),
              ),
              Text(l.orderRevision(order.revision + 1)),
              if (order.destinationId == null) Text(l.activeOrderLocal),
              const SizedBox(height: 8),
              Text(l.additionBody),
              ExpansionTile(
                key: const ValueKey('previously-ordered'),
                tilePadding: EdgeInsets.zero,
                title: Text(l.previouslyOrdered),
                childrenPadding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _OrderContents(
                    order: order,
                    controller: controller,
                    delivery: delivery,
                    sharedOrders: sharedOrders,
                    completeWholeSteps: completeWholeSteps,
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

Future<void> showManagedOrder(
  BuildContext context, {
  required OrderWorkspaceController controller,
  required String orderId,
  required VoidCallback onOpenCompose,
  ClientDeliveryController? delivery,
  SharedOrdersController? sharedOrders,
  bool completeWholeSteps = false,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ActiveOrdersDialog(
    controller: controller,
    orderId: orderId,
    onOpenCompose: onOpenCompose,
    delivery: delivery,
    sharedOrders: sharedOrders,
    completeWholeSteps: completeWholeSteps,
  ),
);

class OpenOrdersPanel extends StatelessWidget {
  const OpenOrdersPanel({
    super.key,
    required this.controller,
    required this.onOpenCompose,
    this.delivery,
    this.sharedOrders,
    this.completeWholeSteps = false,
    this.query = '',
  });
  final OrderWorkspaceController controller;
  final VoidCallback onOpenCompose;
  final ClientDeliveryController? delivery;
  final SharedOrdersController? sharedOrders;
  final bool completeWholeSteps;
  final String query;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final orders = controller.managedOrders.where(
      (order) =>
          query.isEmpty ||
          order.reference.toLowerCase().contains(query) ||
          order.number.toString().contains(query) ||
          order.lines.any((line) => line.name.toLowerCase().contains(query)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.activeOrders, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (sharedOrders != null)
          SharedOrderControls(controller: sharedOrders!),
        if (controller.managedOrders.isEmpty)
          Text(l.activeOrdersEmpty)
        else if (orders.isEmpty)
          Text(l.noItemsFound),
        for (final order in orders)
          Card(
            key: ValueKey('open-order-${order.id}'),
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OrderIdentity(
                    reference: order.reference,
                    numberLabel: l.orderNumber(order.number),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(l.orderRevision(order.revision)),
                      Text(l.itemCount(order.itemCount)),
                    ],
                  ),
                  if (order.destinationId != null && delivery != null)
                    Text(
                      delivery!.serverFor(order.destinationId)?.displayName ??
                          l.serverDisconnected,
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: ValueKey('view-order-${order.id}'),
                    onPressed: controller.saving
                        ? null
                        : () => showManagedOrder(
                            context,
                            controller: controller,
                            orderId: order.id,
                            onOpenCompose: onOpenCompose,
                            delivery: delivery,
                            sharedOrders: sharedOrders,
                            completeWholeSteps: completeWholeSteps,
                          ),
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text(l.viewOrder),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ActiveOrdersDialog extends StatelessWidget {
  const _ActiveOrdersDialog({
    required this.controller,
    required this.orderId,
    required this.onOpenCompose,
    this.delivery,
    this.sharedOrders,
    this.completeWholeSteps = false,
  });
  final OrderWorkspaceController controller;
  final String orderId;
  final VoidCallback onOpenCompose;
  final ClientDeliveryController? delivery;
  final SharedOrdersController? sharedOrders;
  final bool completeWholeSteps;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, ?sharedOrders, ?delivery]),
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final narrow = MediaQuery.sizeOf(context).width < 600;
      final horizontalInset = narrow ? 20.0 : 24.0;
      return AlertDialog(
        titlePadding: EdgeInsets.zero,
        contentPadding: EdgeInsets.zero,
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 40,
          vertical: 24,
        ),
        title: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalInset,
            24,
            horizontalInset,
            16,
          ),
          child: Text(l.viewOrder),
        ),
        content: Padding(
          padding: EdgeInsets.fromLTRB(horizontalInset, 0, horizontalInset, 16),
          child: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (controller.managedOrders.isEmpty)
                    Text(l.activeOrdersEmpty),
                  if (!controller.canBeginAddition) ...[
                    Text(l.finishCompositionFirst),
                    const SizedBox(height: 12),
                  ],
                  for (final order in controller.managedOrders.where(
                    (order) => order.id == orderId,
                  ))
                    Card(
                      key: ValueKey('active-order-card-${order.id}'),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: EdgeInsets.all(narrow ? 12 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OrderIdentity(
                              reference: order.reference,
                              numberLabel: l.orderNumber(order.number),
                            ),
                            const SizedBox(height: 6),
                            if (order.destinationId != null &&
                                delivery != null &&
                                (delivery!.servers.length > 1 ||
                                    order.destinationId !=
                                        delivery!.activeServer?.id))
                              Text(
                                delivery!
                                        .serverFor(order.destinationId)
                                        ?.displayName ??
                                    l.serverDisconnected,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Text(l.orderRevision(order.revision)),
                                Text(l.itemCount(order.itemCount)),
                              ],
                            ),
                            if (controller.featureSettings.pricesEnabled)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: OrderEstimate(lines: order.lines),
                              ),
                            if (order.destinationId == null)
                              Text(l.activeOrderLocal),
                            const SizedBox(height: 8),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: const EdgeInsets.only(
                                top: 8,
                                bottom: 12,
                              ),
                              title: Text(l.deliveryProgress),
                              children: [
                                _OrderContents(
                                  order: order,
                                  controller: controller,
                                  delivery: delivery,
                                  sharedOrders: sharedOrders,
                                  completeWholeSteps: completeWholeSteps,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  key: ValueKey('add-to-order-${order.id}'),
                                  onPressed:
                                      !controller.canBeginAddition ||
                                          (sharedOrders?.unavailableIds
                                                  .contains(order.id) ??
                                              false)
                                      ? null
                                      : () async {
                                          final opened = await controller
                                              .beginAddition(order.id);
                                          if (opened && context.mounted) {
                                            Navigator.pop(context);
                                            onOpenCompose();
                                          }
                                        },
                                  icon: const Icon(Icons.add_rounded),
                                  label: Text(l.addToOrder),
                                ),
                                if (order.courses.isNotEmpty)
                                  OutlinedButton.icon(
                                    key: ValueKey(
                                      'move-order-items-${order.id}',
                                    ),
                                    onPressed:
                                        controller.saving ||
                                            (sharedOrders?.busy ?? false)
                                        ? null
                                        : () => _showPhaseMoves(
                                            context,
                                            order.id,
                                            controller,
                                            sharedOrders,
                                          ),
                                    icon: const Icon(Icons.swap_vert_rounded),
                                    label: Text(l.moveOrderItems),
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
                                                sharedOrders?.sharedIds
                                                            .contains(
                                                              order.id,
                                                            ) ==
                                                        true
                                                    ? l.sharedOrdersLocalCloseBody
                                                    : l.closeActiveOrderBody,
                                              ) ==
                                              true) {
                                            final closed = await controller
                                                .closeOrder(order.id);
                                            if (closed && context.mounted) {
                                              Navigator.pop(context);
                                            }
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
    this.sharedOrders,
    this.completeWholeSteps = false,
  });
  final ManagedOrder order;
  final OrderWorkspaceController controller;
  final ClientDeliveryController? delivery;
  final SharedOrdersController? sharedOrders;
  final bool completeWholeSteps;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sharedOrders != null && sharedOrders!.sharedIds.contains(order.id))
          SharedOrderControls(controller: sharedOrders!, order: order)
        else if (order.destinationId != null && delivery != null)
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
          completeWholeSteps: completeWholeSteps,
          onStepChanged: (courseId, delivered) async {
            final success = await controller.setStepDelivered(
              order.id,
              courseId,
              delivered,
              expectedOrderRevision: order.revision,
              expectedDeliveryRevision: order.deliveryEditRevision,
              expectedQuantities: {
                for (final line in order.lines.where(
                  (line) => line.courseId == courseId,
                ))
                  line.id: order.deliveredQuantity(line.id),
              },
            );
            if (!success && context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l.deliveryProgressFailed)));
            }
          },
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
          scrollable: true,
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

Future<void> _showPhaseMoves(
  BuildContext context,
  String orderId,
  OrderWorkspaceController controller,
  SharedOrdersController? shared,
) => showDialog<void>(
  context: context,
  builder: (context) => AnimatedBuilder(
    animation: Listenable.merge([controller, ?shared]),
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final order = controller.managedOrders
          .where((o) => o.id == orderId)
          .firstOrNull;
      final numbers = NumberFormat.decimalPattern(
        Localizations.localeOf(context).toLanguageTag(),
      );
      final busy = controller.saving || (shared?.busy ?? false);
      return AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 40,
          vertical: 24,
        ),
        scrollable: true,
        title: Text(l.moveOrderItems),
        content: SizedBox(
          width: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.moveOrderItemsBody),
              const SizedBox(height: 16),
              if (order != null)
                for (final line in order.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PhaseSelector(
                          key: ValueKey(
                            'saved-phase-${line.id}-${order.revision}-$busy',
                          ),
                          courses: order.courses,
                          courseId: line.courseId,
                          label:
                              '${numbers.format(line.quantity)} × ${line.name}',
                          onChanged: busy || order.closedAt != null
                              ? null
                              : (destination) async {
                                  if (destination == line.courseId) return;
                                  String? error;
                                  try {
                                    if (order.destinationId != null &&
                                        line.sendToServer) {
                                      if (shared == null) {
                                        throw const ClientTransportException(
                                          'unsupported_phase_moves',
                                        );
                                      }
                                      await shared.moveLine(
                                        order,
                                        line.id,
                                        destination,
                                      );
                                    } else if (!await controller.moveSavedLine(
                                      order.id,
                                      line.id,
                                      destination,
                                      expectedRevision: order.revision,
                                    )) {
                                      error = l.phaseMoveFailed;
                                    }
                                  } on ClientTransportException catch (e) {
                                    error = switch (e.code) {
                                      'unsupported_phase_moves' =>
                                        l.phaseMoveUnsupported,
                                      'phase_move_pending' =>
                                        l.phaseMovePending,
                                      _ => l.phaseMoveFailed,
                                    };
                                  } catch (_) {
                                    error = l.phaseMoveFailed;
                                  }
                                  if (error != null && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error)),
                                    );
                                  }
                                },
                        ),
                        if (line.preparationNote.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(line.preparationNote),
                          ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: Text(l.close),
          ),
        ],
      );
    },
  ),
);
