import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../orders/application/order_workspace_controller.dart';
import '../../orders/domain/order_models.dart';
import '../application/client_delivery_controller.dart';
import '../domain/client_transport.dart';
import '../domain/order_progress.dart';

class ProgressSyncControls extends StatefulWidget {
  const ProgressSyncControls({
    super.key,
    required this.order,
    required this.workspace,
    required this.delivery,
  });
  final ManagedOrder order;
  final OrderWorkspaceController workspace;
  final ClientDeliveryController delivery;
  @override
  State<ProgressSyncControls> createState() => _ProgressSyncControlsState();
}

class _ProgressSyncControlsState extends State<ProgressSyncControls> {
  OrderProgressSnapshot? _conflict;
  String? _error;
  int? _syncedRevision;

  Future<void> _sync([ProgressResolution? resolution]) async {
    final observed = _conflict;
    setState(() {
      _syncedRevision = null;
    });
    try {
      await widget.workspace.exchangeProgress(
        widget.order.id,
        (order) => widget.delivery.synchroniseProgress(
          order,
          conflict: observed,
          resolution: resolution,
        ),
      );
      if (!mounted) return;
      setState(() {
        _conflict = null;
        _error = null;
        _syncedRevision = widget.workspace.managedOrders
            .firstWhere((order) => order.id == widget.order.id)
            .deliveryEditRevision;
      });
    } on ProgressConflict catch (error) {
      if (mounted) {
        setState(() {
          _conflict = error.remote;
          _error = null;
        });
      }
    } on ProgressSyncException catch (error) {
      if (mounted) {
        setState(() {
          _conflict = null;
          _error = error.code;
        });
      }
    } on ClientTransportException catch (error) {
      if (mounted) {
        setState(() {
          _conflict = null;
          _error = error.code;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _conflict = null;
          _error = 'storage';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final busy = widget.workspace.saving;
    final remote = _conflict;
    final numbers = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.deliveryProgressManual),
        if (_syncedRevision == widget.order.deliveryEditRevision)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l.progressSynced,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        const SizedBox(height: 8),
        if (remote != null) ...[
          Text(
            l.progressConflictTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(l.progressConflictBody),
          for (final line in widget.order.lines.where(
            (line) =>
                line.sendToServer &&
                remote.quantities[line.id] !=
                    widget.order.deliveredQuantity(line.id),
          ))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                l.progressDifference(
                  line.name,
                  numbers.format(widget.order.deliveredQuantity(line.id)),
                  numbers.format(remote.quantities[line.id] ?? 0),
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                key: ValueKey('progress-use-server-${widget.order.id}'),
                onPressed: busy ? null : () => _sync(ProgressResolution.server),
                child: Text(l.progressUseServer),
              ),
              OutlinedButton(
                key: ValueKey('progress-use-client-${widget.order.id}'),
                onPressed: busy ? null : () => _sync(ProgressResolution.client),
                child: Text(l.progressUseClient),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                        _conflict = null;
                      }),
                child: Text(l.cancel),
              ),
            ],
          ),
        ] else
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: ValueKey('sync-progress-${widget.order.id}'),
              onPressed: busy ? null : _sync,
              icon: const Icon(Icons.sync_rounded),
              label: Text(busy ? l.progressSyncing : l.progressSync),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(switch (_error) {
              'unsupported_progress' => l.progressUnsupported,
              'credentials' || 'unauthorised' => l.progressPairAgain,
              'order_missing' => l.progressOrderMissing,
              'pending_items' => l.progressItemsPending,
              'server_newer' => l.progressServerNewer,
              'unreachable' || 'server' => l.progressUnavailable,
              _ => l.deliveryProgressFailed,
            }, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}
