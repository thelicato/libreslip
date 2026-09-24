import 'dart:typed_data';

enum PortableArchiveKind { configuration, fullBackup }

extension PortableArchiveKindValue on PortableArchiveKind {
  String get value => switch (this) {
    PortableArchiveKind.configuration => 'configuration',
    PortableArchiveKind.fullBackup => 'fullBackup',
  };

  static PortableArchiveKind parse(String value) => switch (value) {
    'configuration' => PortableArchiveKind.configuration,
    'fullBackup' => PortableArchiveKind.fullBackup,
    _ => throw const FormatException('Unsupported archive kind'),
  };
}

class ImportPreview {
  const ImportPreview({
    required this.kind,
    required this.createdAt,
    required this.appVersion,
    required this.itemCount,
    required this.draftCount,
    required this.ticketCount,
    required this.printJobCount,
    required this.includesLogo,
    required this.bytes,
    required this.files,
  });

  final PortableArchiveKind kind;
  final DateTime createdAt;
  final String appVersion;
  final int itemCount;
  final int draftCount;
  final int ticketCount;
  final int printJobCount;
  final bool includesLogo;

  /// Validated entry content retained in memory until explicit confirmation.
  final Map<String, Uint8List> bytes;
  final Map<String, dynamic> files;
}

class PortabilityException implements Exception {
  const PortabilityException(this.code, [this.cause]);

  final String code;
  final Object? cause;

  @override
  String toString() => code;
}
