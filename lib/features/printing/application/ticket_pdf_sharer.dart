import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../domain/ticket_document.dart';

abstract interface class TicketPdfSharer {
  Future<void> share(TicketDocument document, {required String subject});
}

class LocalTicketPdfSharer implements TicketPdfSharer {
  LocalTicketPdfSharer({SharePlus? share})
    : _share = share ?? SharePlus.instance;

  final SharePlus _share;
  pw.Font? _regular;
  pw.Font? _bold;

  @override
  Future<void> share(TicketDocument document, {required String subject}) async {
    final bytes = await build(document, subject: subject);
    final directory = await getTemporaryDirectory();
    final file = File(
      p.join(directory.path, 'LibreSlip-ticket-${document.ticketNumber}.pdf'),
    );
    await file.writeAsBytes(bytes, flush: true);
    await _share.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: subject,
      ),
    );
  }

  Future<Uint8List> build(
    TicketDocument document, {
    required String subject,
  }) async {
    await _loadFonts();
    final pdf = pw.Document(
      title: subject,
      author: 'LibreSlip',
      creator: 'LibreSlip',
    );
    pw.MemoryImage? logo;
    final logoPath = document.logoPath;
    if (logoPath != null) {
      try {
        logo = pw.MemoryImage(await File(logoPath).readAsBytes());
      } catch (_) {
        logo = null;
      }
    }
    final base = pw.TextStyle(font: _regular, fontSize: 8);
    final bold = pw.TextStyle(font: _bold, fontSize: 8);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat(
          58 * PdfPageFormat.mm,
          200 * PdfPageFormat.mm,
          marginAll: 4 * PdfPageFormat.mm,
        ),
        theme: pw.ThemeData.withFont(base: _regular!, bold: _bold!),
        build: (_) => [
          if (logo != null)
            pw.Center(child: pw.Image(logo, height: 22 * PdfPageFormat.mm)),
          pw.Center(
            child: pw.Text(
              document.heading,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: _bold, fontSize: 14),
            ),
          ),
          pw.SizedBox(height: 2 * PdfPageFormat.mm),
          pw.Center(
            child: pw.Text(
              '${document.ticketLabel} #${document.ticketNumber}',
              style: bold,
            ),
          ),
          pw.Center(child: pw.Text(document.createdAt, style: base)),
          if (document.reference.isNotEmpty) ...[
            pw.SizedBox(height: 2 * PdfPageFormat.mm),
            pw.Text(
              '${document.referenceLabel}: ${document.reference}',
              style: bold,
            ),
          ],
          pw.Divider(),
          for (final line in document.lines)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('${line.quantity} x ${line.name}', style: bold),
                  if (line.note.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 10, top: 2),
                      child: pw.Text(
                        '${document.lineNotePrefix}: ${line.note}',
                        style: base,
                      ),
                    ),
                ],
              ),
            ),
          if (document.orderNote.isNotEmpty) ...[
            pw.Divider(),
            pw.Text(document.orderNotesLabel, style: bold),
            pw.SizedBox(height: 2),
            pw.Text(document.orderNote, style: base),
          ],
          if (document.footer.isNotEmpty) ...[
            pw.Divider(),
            pw.Center(
              child: pw.Text(
                document.footer,
                textAlign: pw.TextAlign.center,
                style: base,
              ),
            ),
          ],
        ],
      ),
    );
    return pdf.save();
  }

  Future<void> _loadFonts() async {
    if (_regular != null && _bold != null) return;
    final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    _regular = pw.Font.ttf(ByteData.sublistView(regular));
    _bold = pw.Font.ttf(ByteData.sublistView(bold));
  }
}
