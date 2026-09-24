import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/portability_controller.dart';
import '../domain/portability_models.dart';

class PortabilitySettingsCard extends StatelessWidget {
  const PortabilitySettingsCard({super.key, required this.controller});

  final PortabilityController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final scheme = Theme.of(context).colorScheme;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.folder_zip_outlined, color: scheme.primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.portability,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.portabilityBody,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _ArchiveAction(
                icon: Icons.tune_rounded,
                title: l.exportConfiguration,
                body: l.exportConfigurationBody,
                button: l.exportConfiguration,
                buttonKey: const ValueKey('export-configuration'),
                busy: controller.busy,
                onPressed: () =>
                    _export(context, PortableArchiveKind.configuration),
              ),
              const Divider(height: 32),
              _ArchiveAction(
                icon: Icons.inventory_2_outlined,
                title: l.exportFullBackup,
                body: l.exportFullBackupBody,
                button: l.exportFullBackup,
                buttonKey: const ValueKey('export-full-backup'),
                busy: controller.busy,
                onPressed: () =>
                    _export(context, PortableArchiveKind.fullBackup),
              ),
              const Divider(height: 32),
              FilledButton.tonalIcon(
                key: const ValueKey('import-archive'),
                onPressed: controller.busy ? null : () => _import(context),
                icon: const Icon(Icons.file_open_outlined),
                label: Text(l.importArchive),
              ),
              if (controller.busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(l.archivePreparing, textAlign: TextAlign.center),
              ],
              if (controller.errorCode != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _errorMessage(l, controller.errorCode!),
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.privacy_tip_outlined, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(l.archivePrivacyWarning)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.bluetooth_disabled_outlined, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(l.archivePairingWarning)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _export(BuildContext context, PortableArchiveKind kind) async {
    final success = await controller.export(kind);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).archiveExportOpened),
        ),
      );
    }
  }

  Future<void> _import(BuildContext context) async {
    final selected = await controller.chooseImport();
    if (selected != true || !context.mounted) return;
    final preview = controller.preview;
    if (preview == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ImportPreviewDialog(preview: preview),
    );
    if (confirmed != true) {
      controller.discardPreview();
      return;
    }
    final restored = await controller.restorePreview();
    if (restored && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).archiveRestored)),
      );
    }
  }

  static String _errorMessage(AppLocalizations l, String code) =>
      switch (code) {
        'rollbackFailed' => l.archiveRollbackFailed,
        'restoreFailed' ||
        'reloadFailed' ||
        'operationFailed' ||
        'exportFailed' => l.archiveOperationFailed,
        _ => l.archiveInvalid,
      };
}

class _ArchiveAction extends StatelessWidget {
  const _ArchiveAction({
    required this.icon,
    required this.title,
    required this.body,
    required this.button,
    required this.buttonKey,
    required this.busy,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String body;
  final String button;
  final Key buttonKey;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(body),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        key: buttonKey,
        onPressed: busy ? null : onPressed,
        icon: const Icon(Icons.ios_share_outlined),
        label: Text(button),
      ),
    ],
  );
}

class _ImportPreviewDialog extends StatelessWidget {
  const _ImportPreviewDialog({required this.preview});

  final ImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final local = preview.createdAt.toLocal();
    final material = MaterialLocalizations.of(context);
    final date =
        '${material.formatMediumDate(local)} · '
        '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
    final full = preview.kind == PortableArchiveKind.fullBackup;
    return AlertDialog(
      scrollable: true,
      title: Text(l.archiveImportTitle),
      content: SizedBox(
        width: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                full ? Icons.inventory_2_outlined : Icons.tune_rounded,
              ),
              title: Text(full ? l.fullBackupArchive : l.configurationArchive),
              subtitle: Text(l.archiveCreated(date)),
            ),
            if (full) ...[
              const SizedBox(height: 8),
              Text(
                l.archiveContents(
                  preview.itemCount,
                  preview.draftCount,
                  preview.ticketCount,
                  preview.printJobCount,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                full ? l.backupReplaceWarning : l.configurationReplaceWarning,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(l.archivePairingWarning),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const ValueKey('confirm-restore-archive'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.restoreArchive),
        ),
      ],
    );
  }
}
