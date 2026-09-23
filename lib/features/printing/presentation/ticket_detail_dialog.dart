import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../orders/domain/order_models.dart';
import '../../settings/domain/app_settings.dart';
import '../application/ticket_output_controller.dart';
import '../domain/print_job.dart';
import '../domain/ticket_document.dart';
import 'ticket_preview.dart';

class TicketDetailDialog extends StatelessWidget {
  const TicketDetailDialog({
    super.key,
    required this.ticket,
    required this.settings,
    this.output,
  });

  final SavedTicket ticket;
  final AppSettings settings;
  final TicketOutputController? output;

  @override
  Widget build(BuildContext context) {
    final controller = output;
    if (controller == null) return _buildDialog(context, null);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildDialog(context, controller),
    );
  }

  Widget _buildDialog(
    BuildContext context,
    TicketOutputController? controller,
  ) {
    final l = AppLocalizations.of(context);
    final document = _document(context);
    final jobs = controller?.jobsFor(ticket.id) ?? const <PrintJob>[];
    final queued = controller?.queuedJobFor(ticket.id);
    final working =
        controller != null &&
        controller.activeTicketId == ticket.id &&
        (controller.busy || controller.sharing);
    return AlertDialog(
      title: Text(l.ticketNumber(ticket.number)),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: TicketPreview(document: document)),
              if (controller != null) ...[
                const SizedBox(height: 22),
                Text(
                  l.printAttempts,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (jobs.isEmpty)
                  Text(l.noPrintAttempts)
                else
                  for (final job in jobs) _PrintJobRow(job: job),
                if (jobs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _PrintOutcomeNotice(job: jobs.first),
                ],
                if (!controller.printer.connected) ...[
                  const SizedBox(height: 12),
                  Text(
                    l.connectBeforePrinting,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (controller.lastErrorCode == 'share' ||
                    controller.lastErrorCode == 'storage') ...[
                  const SizedBox(height: 10),
                  Text(
                    controller.lastErrorCode == 'share'
                        ? l.pdfShareFailed
                        : l.printStorageError,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.start,
      actionsOverflowAlignment: OverflowBarAlignment.start,
      actionsPadding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      actions: [
        if (controller != null)
          OutlinedButton.icon(
            onPressed: working
                ? null
                : () => controller.sharePdf(
                    document: document,
                    subject: l.ticketPdfSubject(ticket.number),
                    ticketId: ticket.id,
                  ),
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(l.shareTicketPdf),
          ),
        if (controller != null)
          FilledButton.icon(
            key: ValueKey('print-ticket-${ticket.id}'),
            onPressed: working
                ? null
                : () {
                    if (queued != null) {
                      controller.sendQueued(queued);
                    } else {
                      controller.printTicket(
                        ticket: ticket,
                        document: document,
                      );
                    }
                  },
            icon: working
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_rounded),
            label: Text(
              working
                  ? l.preparingTicket
                  : queued != null
                  ? l.sendQueuedTicket
                  : jobs.isEmpty
                  ? l.printTicket
                  : l.reprintTicket,
            ),
          ),
        TextButton(
          onPressed: working ? null : () => Navigator.pop(context),
          child: Text(l.close),
        ),
      ],
    );
  }

  TicketDocument _document(BuildContext context) {
    final l = AppLocalizations.of(context);
    final local = ticket.createdAt.toLocal();
    final material = MaterialLocalizations.of(context);
    return TicketDocument.fromTicket(
      ticket: ticket,
      fallbackHeading: l.defaultHeading,
      ticketLabel: l.ticketLabel,
      createdAt:
          '${material.formatFullDate(local)} · '
          '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}',
      referenceLabel: l.orderReference,
      orderNotesLabel: l.orderNotes,
      lineNotePrefix: l.lineNoteLabel,
      footer: settings.footer,
      logoPath: settings.logoPath,
    );
  }
}

class _PrintJobRow extends StatelessWidget {
  const _PrintJobRow({required this.job});

  final PrintJob job;

  @override
  Widget build(BuildContext context) {
    final local = job.updatedAt.toLocal();
    final material = MaterialLocalizations.of(context);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(_icon(job.status)),
      title: Text(_label(context, job.status)),
      subtitle: Text(
        '${material.formatShortDate(local)} · '
        '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}',
      ),
    );
  }

  static IconData _icon(PrintJobStatus status) => switch (status) {
    PrintJobStatus.queued => Icons.schedule_rounded,
    PrintJobStatus.sending => Icons.sync_rounded,
    PrintJobStatus.transmitted => Icons.help_outline_rounded,
    PrintJobStatus.failed => Icons.error_outline_rounded,
    PrintJobStatus.uncertain => Icons.warning_amber_rounded,
  };

  static String _label(BuildContext context, PrintJobStatus status) {
    final l = AppLocalizations.of(context);
    return switch (status) {
      PrintJobStatus.queued => l.printStatusQueued,
      PrintJobStatus.sending => l.printStatusSending,
      PrintJobStatus.transmitted => l.printStatusTransmitted,
      PrintJobStatus.failed => l.printStatusFailed,
      PrintJobStatus.uncertain => l.printStatusUncertain,
    };
  }
}

class _PrintOutcomeNotice extends StatelessWidget {
  const _PrintOutcomeNotice({required this.job});

  final PrintJob job;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (title, body) = switch (job.status) {
      PrintJobStatus.queued => (l.printQueued, l.printQueuedBody),
      PrintJobStatus.transmitted => (
        l.printTransmitted,
        l.printTransmittedBody,
      ),
      PrintJobStatus.failed => (l.printFailed, l.printFailedBody),
      PrintJobStatus.uncertain => (l.printUncertain, l.printUncertainBody),
      PrintJobStatus.sending => (l.printStatusSending, l.printTransmittedBody),
    };
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(body),
          ],
        ),
      ),
    );
  }
}
