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
    this.additionLabel = '',
    this.priceSummary,
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
  final String additionLabel;
  final TicketDocumentPriceSummary? priceSummary;

  List<CourseSection<TicketDocumentLine>> get sections {
    validateCourses(courses, lines.map((line) => line.courseId));
    return courseSections(courses, lines, (line) => line.courseId);
  }

  bool get usesDividers => courses.any((course) => course.isDivider);

  bool showsSectionBoundary(CourseSection<TicketDocumentLine> section) =>
      courses.isNotEmpty && (section.course != null || !usesDividers);

  String sectionLabel(CourseSection<TicketDocumentLine> section) =>
      section.course?.isDivider == true
      ? ''
      : section.course?.name ?? ungroupedLabel;

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
    String additionLabel = '',
    TicketPriceLabels? priceLabels,
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
    additionLabel: '',
    priceSummary: priceLabels?.summary(ticket),
    lines: [
      for (final line in ticket.printLines)
        TicketDocumentLine(
          quantity: line.quantity,
          name: line.name,
          note: line.preparationNote,
          courseId: line.courseId,
          priceText: priceLabels?.lineText(line) ?? '',
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
    this.priceText = '',
  });

  final int quantity;
  final String name;
  final String note;
  final String? courseId;
  final String priceText;
}

/// Prepares localised price text before handing a document to any renderer.
class TicketPriceLabels {
  const TicketPriceLabels({
    required this.total,
    required this.additionsTotal,
    required this.subtotal,
    required this.noPrice,
    required this.missingPrices,
    required this.separateCurrencies,
    required this.formatLine,
    required this.formatAmount,
  });
  final String total;
  final String additionsTotal;
  final String subtotal;
  final String noPrice;
  final String Function(int quantity) missingPrices;
  final String separateCurrencies;
  final String Function(ProductPrice price, int quantity) formatLine;
  final String Function(int minorUnits, String currency) formatAmount;

  String lineText(TicketLine line) =>
      line.price == null ? noPrice : formatLine(line.price!, line.quantity);

  TicketDocumentPriceSummary summary(SavedTicket ticket) {
    final estimate = OrderPriceEstimate.fromLines(ticket.printLines);
    final currencies = estimate.totals.keys.toList()..sort();
    return TicketDocumentPriceSummary(
      label: estimate.unpricedQuantity > 0 ? subtotal : total,
      totals: [
        for (final currency in currencies)
          formatAmount(estimate.totals[currency]!, currency),
      ],
      notes: [
        if (estimate.unpricedQuantity > 0)
          missingPrices(estimate.unpricedQuantity),
        if (currencies.length > 1) separateCurrencies,
      ],
    );
  }
}

class TicketDocumentPriceSummary {
  const TicketDocumentPriceSummary({
    required this.label,
    required this.totals,
    this.notes = const [],
  });
  final String label;
  final List<String> totals;
  final List<String> notes;
}
