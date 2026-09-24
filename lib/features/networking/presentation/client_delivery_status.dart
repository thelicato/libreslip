import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/client_delivery_controller.dart';
import '../domain/client_delivery_models.dart';

class ClientDeliveryStatusChip extends StatelessWidget {
  const ClientDeliveryStatusChip({super.key, required this.delivery});

  final ClientDelivery delivery;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (icon, label) = switch (delivery.status) {
      ClientDeliveryStatus.pending => (
        Icons.schedule_rounded,
        l.deliveryPending,
      ),
      ClientDeliveryStatus.sending => (Icons.sync_rounded, l.deliverySending),
      ClientDeliveryStatus.delivered => (
        Icons.cloud_done_outlined,
        l.deliveryDelivered,
      ),
      ClientDeliveryStatus.failed => (
        Icons.error_outline_rounded,
        l.deliveryFailed,
      ),
    };
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

class ClientDeliveryStatusPanel extends StatelessWidget {
  const ClientDeliveryStatusPanel({
    super.key,
    required this.controller,
    required this.ticketId,
  });

  final ClientDeliveryController controller;
  final String ticketId;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final delivery = controller.deliveryForTicket(ticketId);
      if (delivery == null) return const SizedBox.shrink();
      final l = AppLocalizations.of(context);
      final working =
          delivery.status == ClientDeliveryStatus.sending ||
          controller.isSending(delivery.id);
      final body = switch (delivery.status) {
        ClientDeliveryStatus.delivered => l.deliveryDeliveredBody,
        ClientDeliveryStatus.failed => l.deliveryFailedBody,
        _ => l.deliveryPendingBody,
      };
      final local = delivery.updatedAt.toLocal();
      final material = MaterialLocalizations.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 22),
          Text(
            l.serverDelivery,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ClientDeliveryStatusChip(delivery: delivery),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${material.formatShortDate(local)} · '
                  '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body),
          if (delivery.status == ClientDeliveryStatus.failed ||
              delivery.status == ClientDeliveryStatus.pending) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: ValueKey('retry-delivery-${delivery.id}'),
              onPressed: working ? null : () => controller.retry(delivery.id),
              icon: working
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(working ? l.retryingDelivery : l.retryDelivery),
            ),
          ],
        ],
      );
    },
  );
}
