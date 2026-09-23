import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../printing/application/ticket_output_controller.dart';
import '../../printing/presentation/ticket_detail_dialog.dart';
import '../../settings/domain/app_settings.dart';
import '../application/order_workspace_controller.dart';
import '../domain/order_models.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({
    super.key,
    required this.controller,
    required this.settings,
    required this.onOpenCompose,
    this.output,
  });

  final OrderWorkspaceController controller;
  final AppSettings settings;
  final VoidCallback onOpenCompose;
  final TicketOutputController? output;

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final query = _query.trim().toLowerCase();
      final tickets = widget.controller.tickets
          .where(
            (ticket) =>
                query.isEmpty ||
                ticket.reference.toLowerCase().contains(query) ||
                ticket.number.toString().contains(query) ||
                ticket.lines.any(
                  (line) => line.name.toLowerCase().contains(query),
                ),
          )
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.controller.tickets.isNotEmpty) ...[
            TextField(
              key: const ValueKey('ticket-search'),
              decoration: InputDecoration(
                labelText: l.searchTickets,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 18),
          ],
          if (widget.controller.tickets.isEmpty)
            _EmptyTickets(onCompose: widget.onOpenCompose)
          else if (tickets.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Center(child: Text(l.noItemsFound)),
              ),
            )
          else
            for (final ticket in tickets)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TicketCard(
                  ticket: ticket,
                  onView: () => _showTicket(ticket),
                  onDuplicate: () => _duplicate(ticket),
                ),
              ),
          if (widget.controller.saveFailed) ...[
            const SizedBox(height: 12),
            Text(
              l.saveError,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      );
    },
  );

  Future<void> _duplicate(SavedTicket ticket) async {
    final l = AppLocalizations.of(context);
    await widget.controller.duplicateTicket(ticket);
    if (!mounted || widget.controller.saveFailed) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.duplicatedTicket)));
    widget.onOpenCompose();
  }

  Future<void> _showTicket(SavedTicket ticket) => showDialog<void>(
    context: context,
    builder: (context) => TicketDetailDialog(
      ticket: ticket,
      settings: widget.settings,
      output: widget.output,
      onDuplicate: () {
        Navigator.pop(context);
        _duplicate(ticket);
      },
    ),
  );
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.ticket,
    required this.onView,
    required this.onDuplicate,
  });

  final SavedTicket ticket;
  final VoidCallback onView;
  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final local = ticket.createdAt.toLocal();
    final material = MaterialLocalizations.of(context);
    final date = material.formatShortDate(local);
    final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.receipt_long_outlined),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.ticketNumber(ticket.number),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '$date · $time',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Chip(label: Text(l.saved)),
                    ],
                  ),
                  if (ticket.reference.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      ticket.reference,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(l.itemCount(ticket.itemCount)),
                  const SizedBox(height: 4),
                  Text(
                    ticket.lines
                        .map((line) => '${line.quantity} × ${line.name}')
                        .join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onView,
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text(l.viewTicket),
                  ),
                  TextButton.icon(
                    onPressed: onDuplicate,
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(l.duplicateTicket),
                  ),
                ],
              );
              if (constraints.maxWidth >= 680) {
                return Row(
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 18),
                    actions,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [details, const SizedBox(height: 16), actions],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyTickets extends StatelessWidget {
  const _EmptyTickets({required this.onCompose});

  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.history_rounded,
                size: 44,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l.emptyTicketsTitle,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(l.emptyTicketsBody, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onCompose,
                icon: const Icon(Icons.note_add_outlined),
                label: Text(l.compose),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
