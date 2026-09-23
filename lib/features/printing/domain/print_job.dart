import 'dart:typed_data';

enum PrintJobStatus { queued, sending, transmitted, failed, uncertain }

class PrintJob {
  const PrintJob({
    required this.id,
    required this.requestId,
    required this.ticketId,
    required this.ticketNumber,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.payload,
    this.printerAddress,
    this.printerName,
    this.errorCode,
  });

  final String id;
  final String requestId;
  final String ticketId;
  final int ticketNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PrintJobStatus status;
  final Uint8List payload;
  final String? printerAddress;
  final String? printerName;
  final String? errorCode;

  bool get mayHavePrinted =>
      status == PrintJobStatus.transmitted ||
      status == PrintJobStatus.uncertain;
}

abstract interface class PrintJobStore {
  Future<List<PrintJob>> loadPrintJobs({String? ticketId});

  Future<PrintJob> createPrintJob({
    required String requestId,
    required String ticketId,
    required Uint8List payload,
  });

  Future<PrintJob> markPrintJobSending(
    String id, {
    required String printerAddress,
    required String printerName,
  });

  Future<PrintJob> markPrintJobOutcome(
    String id, {
    required PrintJobStatus status,
    String? errorCode,
  });
}

String printJobStatusValue(PrintJobStatus status) => status.name;

PrintJobStatus parsePrintJobStatus(String value) =>
    PrintJobStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => throw const FormatException('Unknown print job status'),
    );
