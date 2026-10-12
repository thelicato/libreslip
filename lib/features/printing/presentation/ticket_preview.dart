import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/ticket_document.dart';
import '../domain/ticket_typography.dart';

class TicketPreview extends StatelessWidget {
  const TicketPreview({super.key, required this.document});

  final TicketDocument document;

  @override
  Widget build(BuildContext context) {
    final typography = document.typography;
    double previewSize(int points) => points * TicketTypography.previewScale;
    return Semantics(
      label: '${document.ticketLabel} ${document.ticketNumber}',
      child: Container(
        width: 360,
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEF9),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 14,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            color: const Color(0xFF111111),
            fontFamily: 'RobotoTicket',
            fontSize: previewSize(typography.details),
            height: 1.24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (document.logoPath != null) ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final widthPercent = document.logoWidthPercent.clamp(
                      1,
                      100,
                    );
                    return Center(
                      child: SizedBox(
                        key: const ValueKey('ticket-logo-preview'),
                        width: constraints.maxWidth * widthPercent / 100,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 92),
                          child: Image.file(
                            File(document.logoPath!),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
              Text(
                document.heading,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: previewSize(typography.heading),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${document.ticketLabel} #${document.ticketNumber}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: previewSize(typography.details),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (document.additionLabel.isNotEmpty)
                Text(
                  document.additionLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: previewSize(typography.details),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              Text(
                document.createdAt,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: previewSize(typography.details)),
              ),
              if (document.reference.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  '${document.referenceLabel}: ${document.reference}',
                  style: TextStyle(
                    fontSize: previewSize(typography.details),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const _Rule(),
              for (final section in document.sections) ...[
                if (document.showsSectionBoundary(section)) ...[
                  const SizedBox(height: 8),
                  if (document.sectionLabel(section).isNotEmpty)
                    Text(
                      document.sectionLabel(section),
                      style: TextStyle(
                        fontSize: previewSize(typography.details),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const _Rule(),
                ],
                for (final line in section.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (line.priceText.isNotEmpty)
                          _AmountRow(
                            label: '${line.quantity} x ${line.name}',
                            amount: line.priceText,
                            style: TextStyle(
                              fontSize: previewSize(typography.items),
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 42,
                                child: Text(
                                  '${line.quantity}x',
                                  style: TextStyle(
                                    fontSize: previewSize(typography.items),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  line.name,
                                  style: TextStyle(
                                    fontSize: previewSize(typography.items),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (line.note.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(
                              left: line.priceText.isEmpty ? 42 : 0,
                            ),
                            child: Text(
                              '${document.lineNotePrefix}: ${line.note}',
                              style: TextStyle(
                                fontSize: previewSize(typography.notes),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
              if (document.priceSummary case final summary?) ...[
                const _Rule(),
                Column(
                  key: const ValueKey('ticket-price-summary'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (summary.totals.isEmpty)
                      Text(
                        summary.label,
                        style: TextStyle(
                          fontSize: previewSize(typography.details),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    for (var i = 0; i < summary.totals.length; i++)
                      _AmountRow(
                        label: i == 0 ? summary.label : '',
                        amount: summary.totals[i],
                        style: TextStyle(
                          fontSize: previewSize(typography.details),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    for (final note in summary.notes)
                      Text(
                        note,
                        style: TextStyle(
                          fontSize: previewSize(typography.notes),
                        ),
                      ),
                  ],
                ),
              ],
              if (document.orderNote.isNotEmpty) ...[
                const _Rule(),
                Text(
                  document.orderNotesLabel,
                  style: TextStyle(
                    fontSize: previewSize(typography.notes),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  document.orderNote,
                  style: TextStyle(fontSize: previewSize(typography.notes)),
                ),
              ],
              if (document.footer.isNotEmpty) ...[
                const _Rule(),
                Text(
                  document.footer,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: previewSize(typography.footer)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 14),
    child: Divider(color: Color(0xFF333333), height: 1),
  );
}

/// Reserve the amount's natural width; only the item name wraps beside it.
class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    required this.style,
  });
  final String label;
  final String amount;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(
          text: amount,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final labelWidth = constraints.maxWidth - painter.width - 8;
      final largeAmount = painter.width > constraints.maxWidth * 0.6;
      painter.dispose();
      final words = label.split(RegExp(r'\s+'));
      var wrapsInsideWord = false;
      for (final word in words) {
        final wordPainter = TextPainter(
          text: TextSpan(
            text: word,
            style: DefaultTextStyle.of(context).style.merge(style),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        wrapsInsideWord = wrapsInsideWord || wordPainter.width > labelWidth;
        wordPainter.dispose();
      }
      final stacked = largeAmount || wrapsInsideWord;
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (label.isNotEmpty) Text(label, style: style),
            Text(amount, textAlign: TextAlign.right, style: style),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 8),
          Text(amount, textAlign: TextAlign.right, style: style),
        ],
      );
    },
  );
}
