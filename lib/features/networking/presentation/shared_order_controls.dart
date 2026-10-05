import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../orders/domain/order_models.dart';
import '../application/shared_orders_controller.dart';
import '../domain/order_progress.dart';

class SharedOrderControls extends StatelessWidget {
  const SharedOrderControls({super.key, required this.controller, this.order});
  final SharedOrdersController controller;
  final ManagedOrder? order;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      if (!controller.enabled ||
          (order != null &&
              order!.destinationId != controller.delivery.activeServer?.id)) {
        return order != null || controller.sharedIds.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(l.sharedOrdersPaused),
              )
            : const SizedBox.shrink();
      }
      final theme = Theme.of(context);
      final remote = order == null ? null : controller.conflicts[order!.id];
      final local = order;
      final number = NumberFormat.decimalPattern(
        Localizations.localeOf(context).toLanguageTag(),
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.hub_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.sharedOrdersWith(
                      controller.delivery.activeServer!.displayName,
                    ),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (order == null) Text(l.sharedOrdersBody),
            if (controller.lastSyncedAt != null && controller.error == null)
              Text(
                l.sharedOrdersRefreshed(
                  DateFormat.Hm(Localizations.localeOf(context).toLanguageTag())
                      .format(controller.lastSyncedAt!),
                ),
              ),
            if (order != null && controller.unavailableIds.contains(order!.id))
              Text(
                l.progressOrderMissing,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            if (controller.error != null)
              Text(switch (controller.error) {
                'unsupported_shared' => l.sharedOrdersUnsupported,
                'credentials' || 'unauthorised' => l.progressPairAgain,
                'order_missing' => l.progressOrderMissing,
                'unreachable' || 'server' => l.sharedOrdersOffline,
                _ => l.deliveryProgressFailed,
              }, style: TextStyle(color: theme.colorScheme.error)),
            if (order == null && controller.conflicts.isNotEmpty)
              Text(l.sharedOrdersUnresolved),
            if (remote != null && local != null) ...[
              Text(l.progressConflictTitle, style: theme.textTheme.titleSmall),
              Text(l.sharedOrdersConflictBody),
              for (final line in local.lines.where(
                (line) =>
                    line.sendToServer &&
                    local.changedDeliveryIds.contains(line.id) &&
                    remote.progress.quantities[line.id] !=
                        local.deliveredQuantity(line.id),
              ))
                Text(
                  l.progressDifference(
                    line.name,
                    number.format(local.deliveredQuantity(line.id)),
                    number.format(remote.progress.quantities[line.id] ?? 0),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    key: ValueKey('shared-use-server-${local.id}'),
                    onPressed: controller.busy
                        ? null
                        : () => controller.synchronise(
                            resolveOrderId: local.id,
                            resolution: ProgressResolution.server,
                          ),
                    child: Text(l.progressUseServer),
                  ),
                  OutlinedButton(
                    key: ValueKey('shared-use-client-${local.id}'),
                    onPressed: controller.busy
                        ? null
                        : () => controller.synchronise(
                            resolveOrderId: local.id,
                            resolution: ProgressResolution.client,
                          ),
                    child: Text(l.progressUseClient),
                  ),
                ],
              ),
            ] else
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: ValueKey('refresh-shared-${order?.id ?? 'all'}'),
                  onPressed: controller.busy ? null : controller.synchronise,
                  icon: controller.busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(
                    controller.busy ? l.progressSyncing : l.sharedOrdersRefresh,
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
