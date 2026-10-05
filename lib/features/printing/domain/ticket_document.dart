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
    this.logoWidthPercent = 100,
    this.courses = const [],
    this.ungroupedLabel = '',
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
  final int logoWidthPercent;
  final TicketTypography typography;
  final List<TicketDocumentLine> lines;
  final List<OrderCourse> courses;
  final String ungroupedLabel;

  List<CourseSection<TicketDocumentLine>> get sections {
    validateCourses(courses, lines.map((line) => line.courseId));
    return courseSections(courses, lines, (line) => line.courseId);
  }

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
    int logoWidthPercent = 100,
    TicketTypography typography = const TicketTypography(),
    String ungroupedLabel = '',
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
    logoWidthPercent: logoWidthPercent,
    typography: typography,
    courses: ticket.courses,
    ungroupedLabel: ungroupedLabel,
    lines: [
      for (final line in ticket.lines)
        TicketDocumentLine(
          quantity: line.quantity,
          name: line.name,
          note: line.preparationNote,
          courseId: line.courseId,
        ),
    ],
  );
}

class TicketDocumentLine {
  const TicketDocumentLine({
    required this.quantity,
    required this.name,
    this.note = '',
    this.courseId,
  });

  final int quantity;
  final String name;
  final String note;
  final String? courseId;
}
