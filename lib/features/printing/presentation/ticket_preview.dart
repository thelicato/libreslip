import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/ticket_document.dart';

class TicketPreview extends StatelessWidget {
  const TicketPreview({super.key, required this.document});

  final TicketDocument document;

  @override
  Widget build(BuildContext context) => Semantics(
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
        style: const TextStyle(
          color: Color(0xFF111111),
          fontFamily: 'RobotoTicket',
          fontSize: 15,
          height: 1.24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (document.logoPath != null) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 92),
                child: Image.file(
                  File(document.logoPath!),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              document.heading,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${document.ticketLabel} #${document.ticketNumber}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(document.createdAt, textAlign: TextAlign.center),
            if (document.reference.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                '${document.referenceLabel}: ${document.reference}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            const _Rule(),
            for (final line in document.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 42,
                      child: Text(
                        '${line.quantity}x',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (line.note.isNotEmpty)
                            Text(
                              '${document.lineNotePrefix}: ${line.note}',
                              style: const TextStyle(fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (document.orderNote.isNotEmpty) ...[
              const _Rule(),
              Text(
                document.orderNotesLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(document.orderNote),
            ],
            if (document.footer.isNotEmpty) ...[
              const _Rule(),
              Text(document.footer, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    ),
  );
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 14),
    child: Divider(color: Color(0xFF333333), height: 1),
  );
}
