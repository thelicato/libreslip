import '../../orders/domain/order_models.dart';
import 'ticket_typography.dart';

class TicketDocument {
  const TicketDocument({
    required this.heading,
    required this.ticketNumber,
    required this.createdAt,
    required this.referenceLabel,
    required this.orderNotesLabel,
    required this.lineNotePrefix,
    required this.ticketLabel,
    required this.footer,
    required this.lines,
    this.typography = const TicketTypography(),
    this.reference = '',
    this.orderNote = '',
    this.logoPath,
  });

  final String heading;
  final String ticketLabel;
  final String ticketNumber;
  final String createdAt;
  final String referenceLabel;
  final String reference;
  final String orderNotesLabel;
  final String orderNote;
  final String lineNotePrefix;
  final String footer;
  final String? logoPath;
  final TicketTypography typography;
  final List<TicketDocumentLine> lines;

  factory TicketDocument.fromTicket({
    required SavedTicket ticket,
    required String fallbackHeading,
    required String ticketLabel,
    required String createdAt,
    required String referenceLabel,
    required String orderNotesLabel,
    required String lineNotePrefix,
    required String footer,
    String? logoPath,
    TicketTypography typography = const TicketTypography(),
  }) => TicketDocument(
    heading: ticket.heading.isEmpty ? fallbackHeading : ticket.heading,
    ticketLabel: ticketLabel,
    ticketNumber: ticket.number.toString(),
    createdAt: createdAt,
    referenceLabel: referenceLabel,
    reference: ticket.reference,
    orderNotesLabel: orderNotesLabel,
    orderNote: ticket.orderNote,
    lineNotePrefix: lineNotePrefix,
    footer: footer,
    logoPath: logoPath,
    typography: typography,
    lines: [
      for (final line in ticket.lines)
        TicketDocumentLine(
          quantity: line.quantity,
          name: line.name,
          note: line.preparationNote,
        ),
    ],
  );
}

class TicketDocumentLine {
  const TicketDocumentLine({
    required this.quantity,
    required this.name,
    this.note = '',
  });

  final int quantity;
  final String name;
  final String note;
}
