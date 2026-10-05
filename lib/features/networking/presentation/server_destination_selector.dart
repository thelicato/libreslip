import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../orders/domain/order_models.dart';
import '../application/client_delivery_controller.dart';

class ServerDestinationSelector extends StatelessWidget {
  const ServerDestinationSelector({
    super.key,
    required this.controller,
    this.order,
    this.busy = false,
  });
  final ClientDeliveryController controller;
  final ManagedOrder? order;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final target = order == null
        ? controller.activeServer
        : controller.serverFor(order!.destinationId);
    if (order != null || controller.servers.length < 2) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.lan_outlined),
        title: Text(l.orderDestination),
        subtitle: Text(
          order != null && order!.destinationId == null
              ? l.activeOrderLocal
              : target?.displayName ?? l.serverDisconnected,
        ),
        trailing: order == null ? null : const Icon(Icons.lock_outline_rounded),
      );
    }
    return DropdownButtonFormField<String>(
      key: ValueKey('order-server-${target?.id}'),
      initialValue: target?.id,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l.orderDestination,
        prefixIcon: const Icon(Icons.lan_outlined),
        helperText: l.orderDestinationBody,
        helperMaxLines: 6,
      ),
      items: [
        for (final server in controller.servers)
          DropdownMenuItem(
            value: server.id,
            child: Text(server.displayName, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: busy || controller.pairing || controller.unpairing
          ? null
          : (id) async {
              if (id == null) return;
              final success = await controller.selectServer(id);
              if (!success && context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l.pairingStorageFailed)));
              }
            },
    );
  }
}
