import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/client_delivery_controller.dart';
import '../domain/network_models.dart';
import '../domain/client_delivery_models.dart';

class ClientServerSettingsCard extends StatelessWidget {
  const ClientServerSettingsCard({
    super.key,
    required this.controller,
    required this.configuration,
  });

  final ClientDeliveryController controller;
  final NetworkConfiguration configuration;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final theme = Theme.of(context);
      final server = controller.activeServer;
      return Container(
        key: const ValueKey('client-server-settings'),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.lan_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.clientServerTitle,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(l.clientServerBody),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (server == null)
              Text(l.noPairedServer, style: theme.textTheme.titleMedium),
            for (final destination in controller.servers) ...[
              Container(
                key: ValueKey('connected-server-${destination.id}'),
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: destination.id == server?.id
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      destination.displayName,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(destination.baseUrl.toString()),
                    const SizedBox(height: 8),
                    Text(
                      '${l.pendingDeliveries}: ${controller.deliveries.where((d) => d.destinationId == destination.id && d.status != ClientDeliveryStatus.delivered && d.status != ClientDeliveryStatus.failed).length} · ${l.failedDeliveries}: ${controller.deliveries.where((d) => d.destinationId == destination.id && d.status == ClientDeliveryStatus.failed).length}',
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        destination.id == server?.id
                            ? Container(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerLowest,
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(child: Text(l.serverForNewOrders)),
                                  ],
                                ),
                              )
                            : TextButton.icon(
                                key: ValueKey(
                                  'select-server-${destination.id}',
                                ),
                                onPressed:
                                    controller.pairing || controller.unpairing
                                    ? null
                                    : () async {
                                        final success = await controller
                                            .selectServer(destination.id);
                                        if (!success && context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    l.pairingStorageFailed,
                                                  ),
                                                ),
                                              );
                                        }
                                      },
                                icon: const Icon(
                                  Icons.check_circle_outline_rounded,
                                ),
                                label: Text(l.useServerForNewOrders),
                              ),
                        OutlinedButton.icon(
                          key: destination.id == server?.id
                              ? const ValueKey('unpair-server')
                              : ValueKey('unpair-server-${destination.id}'),
                          onPressed: controller.pairing || controller.unpairing
                              ? null
                              : () => _confirmUnpair(context, destination),
                          icon: const Icon(Icons.link_off_rounded),
                          label: Text(l.unpairServer),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey('pair-server'),
              onPressed: controller.pairing || controller.unpairing
                  ? null
                  : () => _showPairDialog(context),
              icon: const Icon(Icons.add_link_rounded),
              label: Text(l.pairServer),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _showPairDialog(BuildContext context) async {
    controller.clearPairingError();
    final paired = await showDialog<bool>(
      context: context,
      builder: (context) => _PairServerDialog(
        controller: controller,
        configuration: configuration,
      ),
    );
    if (paired == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).serverPaired)),
      );
    }
  }

  Future<void> _confirmUnpair(BuildContext context, PairedServer server) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(l.unpairServerTitle),
        content: Text('${server.displayName}\n\n${l.unpairServerBody}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirm-unpair-server'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.unpairServer),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final success = await controller.unpair(server.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? l.serverUnpaired : l.pairingStorageFailed),
      ),
    );
  }
}

class _PairServerDialog extends StatefulWidget {
  const _PairServerDialog({
    required this.controller,
    required this.configuration,
  });

  final ClientDeliveryController controller;
  final NetworkConfiguration configuration;

  @override
  State<_PairServerDialog> createState() => _PairServerDialogState();
}

class _PairServerDialogState extends State<_PairServerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  bool _working = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final error = widget.controller.lastPairingError;
    return AlertDialog(
      title: Text(l.pairServerTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.pairServerBody),
                const SizedBox(height: 18),
                TextFormField(
                  key: const ValueKey('server-address-field'),
                  controller: _address,
                  enabled: !_working,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l.serverAddressInput,
                    hintText: l.serverAddressHint,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l.fieldRequired
                      : null,
                ),
                if (_working) ...[
                  const SizedBox(height: 18),
                  Container(
                    key: const ValueKey('waiting-for-server-approval'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(l.pairingWaitingBody)),
                      ],
                    ),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage(l, error),
                    key: const ValueKey('server-pairing-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _working ? null : () => Navigator.pop(context, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const ValueKey('confirm-pair-server'),
          onPressed: _working ? null : _pair,
          child: Text(_working ? l.pairingServer : l.pair),
        ),
      ],
    );
  }

  Future<void> _pair() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l = AppLocalizations.of(context);
    setState(() => _working = true);
    final success = await widget.controller.pair(
      configuration: widget.configuration,
      address: _address.text,
      clientName: l.defaultClientName,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() => _working = false);
    }
  }

  static String _errorMessage(AppLocalizations l, String code) =>
      switch (code) {
        'invalid_pairing' => l.pairingInvalid,
        'certificate' || 'server_identity' => l.pairingCertificateError,
        'pairing_denied' => l.pairingDenied,
        'unreachable' => l.pairingUnreachable,
        'storage' => l.pairingStorageFailed,
        _ => l.pairingFailed,
      };
}
