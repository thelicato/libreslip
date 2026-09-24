import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/network_mode_controller.dart';
import '../domain/network_models.dart';

class ModeSettingsCard extends StatelessWidget {
  const ModeSettingsCard({super.key, required this.controller});

  final NetworkModeController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mode = controller.mode;
    return Container(
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
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.appMode, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(l.appModeBody),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SegmentedButton<LibreSlipMode>(
            key: const ValueKey('app-mode-selector'),
            segments: [
              ButtonSegment(
                value: LibreSlipMode.client,
                label: Text(l.clientMode),
              ),
              ButtonSegment(
                value: LibreSlipMode.server,
                label: Text(l.serverMode),
              ),
            ],
            selected: {mode},
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            onSelectionChanged: controller.saving
                ? null
                : (selection) => _confirmChange(context, selection.single),
          ),
          const SizedBox(height: 14),
          Text(
            mode == LibreSlipMode.client ? l.clientModeBody : l.serverModeBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (controller.saveFailed) ...[
            const SizedBox(height: 12),
            Text(
              l.modeSaveError,
              key: const ValueKey('mode-save-error'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmChange(BuildContext context, LibreSlipMode next) async {
    if (next == controller.mode) return;
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          next == LibreSlipMode.server
              ? l.switchToServerTitle
              : l.switchToClientTitle,
        ),
        content: Text(
          next == LibreSlipMode.server
              ? l.switchToServerBody
              : l.switchToClientBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirm-mode-switch'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.switchMode),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final saved = await controller.setMode(next);
    if (!saved && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.modeSaveError)));
    }
  }
}
