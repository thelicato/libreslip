import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/printer_controller.dart';
import '../domain/printer_transport.dart';

class PrinterSetupCard extends StatefulWidget {
  const PrinterSetupCard({super.key, required this.controller});

  final PrinterController controller;

  @override
  State<PrinterSetupCard> createState() => _PrinterSetupCardState();
}

class _PrinterSetupCardState extends State<PrinterSetupCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.refresh();
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final controller = widget.controller;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.print_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.printerSetup,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.printerSetupBody,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (controller.operation == PrinterOperation.refreshing)
                const Center(child: CircularProgressIndicator())
              else
                _PrinterBody(controller: controller),
            ],
          ),
        ),
      );
    },
  );
}

class _PrinterBody extends StatelessWidget {
  const _PrinterBody({required this.controller});

  final PrinterController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (controller.hostStatus == BluetoothHostStatus.unsupported) {
      return _Notice(
        icon: Icons.bluetooth_disabled_rounded,
        title: l.bluetoothUnsupported,
      );
    }
    if (controller.hostStatus == BluetoothHostStatus.permissionRequired) {
      return _Notice(
        icon: Icons.phonelink_lock_rounded,
        title: l.bluetoothPermissionTitle,
        body: l.bluetoothPermissionBody,
        action: FilledButton.icon(
          key: const ValueKey('allow-bluetooth'),
          onPressed: controller.busy ? null : controller.requestPermission,
          icon: const Icon(Icons.lock_open_rounded),
          label: Text(l.allowBluetooth),
        ),
      );
    }
    if (controller.hostStatus == BluetoothHostStatus.disabled) {
      return _Notice(
        icon: Icons.bluetooth_disabled_rounded,
        title: l.bluetoothOffTitle,
        body: l.bluetoothOffBody,
        action: FilledButton.icon(
          onPressed: controller.openBluetoothSettings,
          icon: const Icon(Icons.settings_bluetooth_rounded),
          label: Text(l.openBluetoothSettings),
        ),
      );
    }
    if (controller.connected) return _Connected(controller: controller);
    return _DeviceList(controller: controller);
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.controller});

  final PrinterController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.pairedDevices, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        if (controller.devices.isEmpty)
          _Notice(
            icon: Icons.bluetooth_searching_rounded,
            title: l.noPairedPrinters,
            body: l.pairPrinterBody,
            action: OutlinedButton.icon(
              onPressed: controller.openBluetoothSettings,
              icon: const Icon(Icons.settings_bluetooth_rounded),
              label: Text(l.openBluetoothSettings),
            ),
          )
        else
          for (final device in controller.devices)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.print_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  device.name,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  device.address,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        key: ValueKey('connect-${device.address}'),
                        onPressed: controller.busy
                            ? null
                            : () => controller.connect(device),
                        child: Text(
                          controller.operation == PrinterOperation.connecting &&
                                  controller.connectingAddress == device.address
                              ? l.connectingPrinter
                              : l.connectPrinter,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        if (controller.lastErrorCode != null) ...[
          const SizedBox(height: 6),
          _ErrorText(
            text: controller.lastErrorCode == 'connectionFailed'
                ? l.printerConnectionFailed
                : l.printerOperationFailed,
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: controller.busy ? null : controller.refresh,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l.refreshPrinters),
        ),
      ],
    );
  }
}

class _Connected extends StatelessWidget {
  const _Connected({required this.controller});

  final PrinterController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    PairedPrinter? device;
    for (final entry in controller.devices) {
      if (entry.address == controller.connectedAddress) device = entry;
    }
    final name = device?.name ?? controller.connectedAddress!;
    final outcome = controller.testOutcome;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Notice(
          icon: Icons.bluetooth_connected_rounded,
          title: l.connectedPrinter(name),
          body: l.testTicketSafety,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              key: const ValueKey('print-test-ticket'),
              onPressed: controller.busy ? null : controller.printTestTicket,
              icon: const Icon(Icons.print_rounded),
              label: Text(
                controller.operation == PrinterOperation.sending
                    ? l.sendingTestTicket
                    : l.testTicket,
              ),
            ),
            OutlinedButton(
              onPressed: controller.busy ? null : controller.disconnect,
              child: Text(l.disconnectPrinter),
            ),
          ],
        ),
        if (outcome != TestPrintOutcome.none) ...[
          const SizedBox(height: 16),
          _Notice(
            icon: outcome == TestPrintOutcome.sent
                ? Icons.help_outline_rounded
                : Icons.warning_amber_rounded,
            title: outcome == TestPrintOutcome.sent
                ? l.testTicketSent
                : outcome == TestPrintOutcome.uncertain
                ? l.testTicketUncertain
                : l.testTicketFailed,
            body: outcome == TestPrintOutcome.sent
                ? l.testTicketSentBody
                : null,
          ),
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer
          .withValues(alpha: 0.34),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        if (body != null) ...[const SizedBox(height: 5), Text(body!)],
        if (action != null) ...[const SizedBox(height: 14), action!],
      ],
    ),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(color: Theme.of(context).colorScheme.error));
}
