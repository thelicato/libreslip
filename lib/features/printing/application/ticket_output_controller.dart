import 'package:flutter/foundation.dart';

import '../../orders/domain/order_models.dart';
import '../domain/print_job.dart';
import '../domain/ticket_document.dart';
import 'esc_pos_ticket_encoder.dart';
import 'printer_controller.dart';
import 'ticket_pdf_sharer.dart';

enum TicketPrintResult { queued, transmitted, failed, uncertain }

class TicketOutputController extends ChangeNotifier {
  TicketOutputController({
    required this._store,
    required this._printer,
    this._encoder = const EscPosTicketEncoder(),
    TicketPdfSharer? pdfSharer,
  }) : _pdfSharer = pdfSharer ?? LocalTicketPdfSharer();

  final PrintJobStore _store;
  final PrinterController _printer;
  final EscPosTicketEncoder _encoder;
  final TicketPdfSharer _pdfSharer;

  List<PrintJob> jobs = const [];
  bool loaded = false;
  bool busy = false;
  bool sharing = false;
  String? activeTicketId;
  String? lastErrorCode;

  PrinterController get printer => _printer;

  List<PrintJob> jobsFor(String ticketId) =>
      jobs.where((job) => job.ticketId == ticketId).toList(growable: false);

  PrintJob? queuedJobFor(String ticketId) {
    for (final job in jobs) {
      if (job.ticketId == ticketId && job.status == PrintJobStatus.queued) {
        return job;
      }
    }
    return null;
  }

  Future<void> load() async {
    try {
      jobs = await _store.loadPrintJobs();
      loaded = true;
      lastErrorCode = null;
    } catch (_) {
      lastErrorCode = 'storage';
    }
    notifyListeners();
  }

  Future<TicketPrintResult> printTicket({
    required SavedTicket ticket,
    required TicketDocument document,
  }) async {
    if (busy) return TicketPrintResult.failed;
    busy = true;
    activeTicketId = ticket.id;
    lastErrorCode = null;
    notifyListeners();
    try {
      final payload = await _encoder.encode(document);
      final job = await _store.createPrintJob(
        requestId: createLocalId(),
        ticketId: ticket.id,
        payload: payload,
      );
      await _refresh();
      if (!_printer.connected) return TicketPrintResult.queued;
      return await _send(job);
    } catch (_) {
      lastErrorCode = 'storage';
      return TicketPrintResult.failed;
    } finally {
      busy = false;
      activeTicketId = null;
      notifyListeners();
    }
  }

  Future<TicketPrintResult> sendQueued(PrintJob job) async {
    if (busy || job.status != PrintJobStatus.queued) {
      return TicketPrintResult.failed;
    }
    busy = true;
    activeTicketId = job.ticketId;
    lastErrorCode = null;
    notifyListeners();
    try {
      if (!_printer.connected) return TicketPrintResult.queued;
      return await _send(job);
    } catch (_) {
      lastErrorCode = 'storage';
      return TicketPrintResult.failed;
    } finally {
      busy = false;
      activeTicketId = null;
      notifyListeners();
    }
  }

  Future<TicketPrintResult> _send(PrintJob job) async {
    final device = _printer.connectedPrinter;
    if (device == null) return TicketPrintResult.queued;
    await _store.markPrintJobSending(
      job.id,
      printerAddress: device.address,
      printerName: device.name,
    );
    await _refresh();
    final transmission = await _printer.transmit(job.payload);
    final (status, result) = switch (transmission) {
      PrinterTransmissionOutcome.transmitted => (
        PrintJobStatus.transmitted,
        TicketPrintResult.transmitted,
      ),
      PrinterTransmissionOutcome.failed => (
        PrintJobStatus.failed,
        TicketPrintResult.failed,
      ),
      PrinterTransmissionOutcome.uncertain => (
        PrintJobStatus.uncertain,
        TicketPrintResult.uncertain,
      ),
    };
    await _store.markPrintJobOutcome(
      job.id,
      status: status,
      errorCode: result == TicketPrintResult.transmitted
          ? null
          : _printer.lastErrorCode,
    );
    await _refresh();
    return result;
  }

  Future<bool> sharePdf({
    required TicketDocument document,
    required String subject,
    required String ticketId,
  }) async {
    if (sharing) return false;
    sharing = true;
    activeTicketId = ticketId;
    lastErrorCode = null;
    notifyListeners();
    try {
      await _pdfSharer.share(document, subject: subject);
      return true;
    } catch (_) {
      lastErrorCode = 'share';
      return false;
    } finally {
      sharing = false;
      activeTicketId = null;
      notifyListeners();
    }
  }

  Future<void> _refresh() async {
    jobs = await _store.loadPrintJobs();
    loaded = true;
    notifyListeners();
  }
}
