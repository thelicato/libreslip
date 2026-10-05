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
      final server = controller.delivery.serverFor(order?.destinationId);
      final syncError = order == null
          ? controller.error
          : controller.serverErrors[server?.id];
      final syncedAt = order == null
          ? controller.lastSyncedAt
          : controller.serverSyncedAt[server?.id];
      if (!controller.enabled || (order != null && server == null)) {
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
                    order != null
                        ? l.sharedOrdersWith(server!.displayName)
                        : controller.delivery.servers.length == 1
                        ? l.sharedOrdersWith(
                            controller.delivery.servers.single.displayName,
                          )
                        : l.sharedOrdersServers(
                            controller.delivery.servers.length,
                          ),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (order == null) Text(l.sharedOrdersBody),
            if (syncedAt != null && syncError == null)
              Text(
                l.sharedOrdersRefreshed(
                  DateFormat.Hm(Localizations.localeOf(context).toLanguageTag())
                      .format(syncedAt),
                ),
              ),
            if (order != null && controller.unavailableIds.contains(order!.id))
              Text(
                l.progressOrderMissing,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            if (syncError != null)
              Text(
                _errorText(l, syncError),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            if (order == null && controller.delivery.servers.length > 1)
              for (final destination in controller.delivery.servers)
                Text(
                  '${destination.displayName}: ${controller.serverErrors.containsKey(destination.id)
                      ? _errorText(l, controller.serverErrors[destination.id]!)
                      : controller.serverSyncedAt.containsKey(destination.id)
                      ? l.sharedOrdersRefreshed(DateFormat.Hm(Localizations.localeOf(context).toLanguageTag()).format(controller.serverSyncedAt[destination.id]!))
                      : l.progressSyncing}',
                ),
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
                  onPressed: controller.busy
                      ? null
                      : () => controller.synchronise(
                          serverId: order?.destinationId,
                        ),
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
  static String _errorText(AppLocalizations l, String code) => switch (code) {
    'unsupported_shared' => l.sharedOrdersUnsupported,
    'credentials' || 'unauthorised' => l.progressPairAgain,
    'order_missing' => l.progressOrderMissing,
    'unreachable' || 'server' => l.sharedOrdersOffline,
    _ => l.deliveryProgressFailed,
  };
}
