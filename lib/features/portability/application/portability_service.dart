import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../orders/data/sqlite_order_repository.dart';
import '../../orders/domain/order_models.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/portability_models.dart';

typedef SupportDirectoryProvider = Future<Directory> Function();
typedef TemporaryDirectoryProvider = Future<Directory> Function();
typedef ArchivePicker = Future<Uint8List?> Function();
typedef ArchiveSharer = Future<void> Function(File file, String fileName);

class PortabilityService {
  PortabilityService(
    this._orders,
    this._settings, {
    SupportDirectoryProvider? supportDirectory,
    TemporaryDirectoryProvider? temporaryDirectory,
    ArchivePicker? picker,
    ArchiveSharer? sharer,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _picker = picker ?? _pickArchive,
       _sharer = sharer ?? _shareArchive;

  static const formatName = 'libreslip-portability';
  static const formatVersion = 1;
  static const appVersion = '0.5.0+5';
  static const _maxArchiveBytes = 32 * 1024 * 1024;
  static const _maxExpandedBytes = 64 * 1024 * 1024;
  static const _maxEntryBytes = 12 * 1024 * 1024;
  static const _maxEntries = 1000;
  static const _maxCompressionRatio = 100;

  final OrderRepository _orders;
  final SettingsRepository _settings;
  final SupportDirectoryProvider _supportDirectory;
  final TemporaryDirectoryProvider _temporaryDirectory;
  final ArchivePicker _picker;
  final ArchiveSharer _sharer;

  Future<Uint8List> createArchive(PortableArchiveKind kind) async {
    try {
      final currentSettings = await _settings.load() ?? const AppSettings();
      final featureSettings = await _orders.loadFeatureSettings();
      final entries = <String, Uint8List>{};
      final portableSettings = Map<String, Object?>.from(
        currentSettings.toJson(),
      );
      portableSettings['logoPath'] = await _addAsset(
        entries,
        currentSettings.logoPath,
        'assets/logo',
      );
      final configuration = <String, Object?>{
        'version': 1,
        'settings': portableSettings,
        'orderFeatures': {
          'orderReferenceEnabled': featureSettings.orderReferenceEnabled,
          'preparationNotesEnabled': featureSettings.preparationNotesEnabled,
          'orderNotesEnabled': featureSettings.orderNotesEnabled,
        },
        'printer': {
          'transport': 'bluetoothClassicSpp',
          'pairingIncluded': false,
        },
      };
      entries['configuration.json'] = _jsonBytes(configuration);

      var itemCount = 0;
      var draftCount = 0;
      var ticketCount = 0;
      var printJobCount = 0;
      if (kind == PortableArchiveKind.fullBackup) {
        final snapshot = await _orders.createPortableSnapshot();
        final tables = snapshot['tables']! as Map<String, dynamic>;
        final items = tables['items']! as List;
        for (final value in items) {
          final row = value as Map<String, dynamic>;
          final path = row['image_path'];
          if (row['archived'] == 1) {
            row['image_path'] = null;
          } else if (path is String && path.isNotEmpty) {
            row['image_path'] = await _addAsset(
              entries,
              path,
              'assets/items/${row['id']}',
            );
          }
        }
        itemCount = items.length;
        draftCount = (tables['drafts']! as List).length;
        ticketCount = (tables['tickets']! as List).length;
        printJobCount = (tables['print_jobs']! as List).length;
        entries['database.json'] = _jsonBytes(snapshot);
      }

      final now = DateTime.now().toUtc();
      final manifest = <String, Object?>{
        'application': 'LibreSlip',
        'format': formatName,
        'formatVersion': formatVersion,
        'archiveKind': kind.value,
        'appVersion': appVersion,
        'databaseSchemaVersion': kind == PortableArchiveKind.fullBackup
            ? SqliteOrderRepository.databaseVersion
            : null,
        'createdAt': now.toIso8601String(),
        'counts': {
          'items': itemCount,
          'drafts': draftCount,
          'tickets': ticketCount,
          'printJobs': printJobCount,
        },
        'files': [
          for (final entry in entries.entries)
            {
              'path': entry.key,
              'size': entry.value.length,
              'sha256': sha256.convert(entry.value).toString(),
              'mediaType': _mediaType(entry.key),
            },
        ],
      };
      entries['manifest.json'] = _jsonBytes(manifest);
      return await Isolate.run(() => _encodeArchive(entries, now));
    } catch (error) {
      if (error is PortabilityException) rethrow;
      throw PortabilityException('exportFailed', error);
    }
  }

  Future<void> exportAndShare(PortableArchiveKind kind) async {
    final bytes = await createArchive(kind);
    final temporary = await _temporaryDirectory();
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final label = kind == PortableArchiveKind.configuration
        ? 'configuration'
        : 'full-backup';
    final fileName = 'LibreSlip-$label-$stamp.zip';
    final file = File(p.join(temporary.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    await _sharer(file, fileName);
  }

  Future<ImportPreview?> pickAndInspect() async {
    final bytes = await _picker();
    if (bytes == null) return null;
    return inspectArchive(bytes);
  }

  Future<ImportPreview> inspectArchive(Uint8List archiveBytes) async {
    try {
      if (archiveBytes.isEmpty || archiveBytes.length > _maxArchiveBytes) {
        throw const PortabilityException('archiveTooLarge');
      }
      final entries = await Isolate.run(
        () => _decodeAndValidateStructure(archiveBytes),
      );
      final manifest = _decodeObject(entries['manifest.json']!, 'manifest');
      if (manifest['application'] != 'LibreSlip' ||
          manifest['format'] != formatName ||
          manifest['formatVersion'] != formatVersion ||
          manifest['appVersion'] is! String ||
          manifest['createdAt'] is! String ||
          manifest['files'] is! List ||
          manifest['counts'] is! Map<String, dynamic>) {
        throw const PortabilityException('invalidManifest');
      }
      final kind = PortableArchiveKindValue.parse(
        manifest['archiveKind'] as String? ?? '',
      );
      if (kind == PortableArchiveKind.fullBackup &&
          manifest['databaseSchemaVersion'] !=
              SqliteOrderRepository.databaseVersion) {
        throw const PortabilityException('unsupportedDatabase');
      }
      _validateInventory(entries, manifest['files']! as List);
      final configuration = _decodeObject(
        entries['configuration.json']!,
        'configuration',
      );
      final settingsValue = configuration['settings'];
      final features = configuration['orderFeatures'];
      final printer = configuration['printer'];
      if (configuration['version'] != 1 ||
          settingsValue is! Map<String, dynamic> ||
          features is! Map<String, dynamic> ||
          printer is! Map<String, dynamic> ||
          printer['pairingIncluded'] != false) {
        throw const PortabilityException('invalidConfiguration');
      }
      AppSettings.fromJson(settingsValue);
      _parseFeatures(features);
      _validateAssetReference(settingsValue['logoPath'], entries);

      Map<String, dynamic>? snapshot;
      if (kind == PortableArchiveKind.fullBackup) {
        final databaseBytes = entries['database.json'];
        if (databaseBytes == null) {
          throw const PortabilityException('missingDatabase');
        }
        snapshot = _decodeObject(databaseBytes, 'database');
        _validateSnapshot(snapshot, entries);
      } else if (entries.containsKey('database.json')) {
        throw const PortabilityException('unexpectedDatabase');
      }
      final counts = manifest['counts']! as Map<String, dynamic>;
      final expected = _snapshotCounts(snapshot);
      for (final key in ['items', 'drafts', 'tickets', 'printJobs']) {
        if (counts[key] != expected[key]) {
          throw const PortabilityException('countMismatch');
        }
      }
      final createdAt = DateTime.tryParse(manifest['createdAt']! as String);
      if (createdAt == null) {
        throw const PortabilityException('invalidManifest');
      }
      return ImportPreview(
        kind: kind,
        createdAt: createdAt,
        appVersion: manifest['appVersion']! as String,
        itemCount: expected['items']!,
        draftCount: expected['drafts']!,
        ticketCount: expected['tickets']!,
        printJobCount: expected['printJobs']!,
        includesLogo: settingsValue['logoPath'] != null,
        bytes: entries,
        files: {'configuration': configuration, 'database': ?snapshot},
      );
    } catch (error) {
      if (error is PortabilityException) rethrow;
      throw PortabilityException('invalidArchive', error);
    }
  }

  Future<void> recoverInterruptedRestore() async {
    final support = await _supportDirectory();
    final journal = File(p.join(support.path, 'portability_recovery.json'));
    if (!await journal.exists()) return;
    try {
      final value = jsonDecode(await journal.readAsString());
      if (value is! Map<String, dynamic> ||
          !['pending', 'committed'].contains(value['phase'])) {
        throw const FormatException('Invalid recovery journal');
      }
      if (value['phase'] == 'pending') {
        final settings = value['settings'];
        final features = value['features'];
        if (settings is! Map<String, dynamic> ||
            features is! Map<String, dynamic>) {
          throw const FormatException('Invalid recovery data');
        }
        final snapshot = value['database'];
        if (snapshot != null) {
          if (snapshot is! Map<String, dynamic>) {
            throw const FormatException('Invalid recovery database');
          }
          await _orders.replaceWithPortableSnapshot(snapshot);
        } else {
          await _orders.saveFeatureSettings(_parseFeatures(features));
        }
        await _settings.save(AppSettings.fromJson(settings));
        final stagedPath = value['stagedDirectory'];
        if (stagedPath is String && stagedPath.isNotEmpty) {
          final staged = Directory(stagedPath);
          if (await staged.exists()) await staged.delete(recursive: true);
        }
      }
      await journal.delete();
    } catch (error) {
      throw PortabilityException('rollbackFailed', error);
    }
  }

  Future<void> restore(ImportPreview preview) async {
    final oldSettings = await _settings.load() ?? const AppSettings();
    final oldFeatures = await _orders.loadFeatureSettings();
    final oldSnapshot = preview.kind == PortableArchiveKind.fullBackup
        ? await _orders.createPortableSnapshot()
        : null;
    Directory? stagedDirectory;
    File? recoveryJournal;
    var databaseChanged = false;
    var featuresChanged = false;
    try {
      final support = await _supportDirectory();
      stagedDirectory = Directory(
        p.join(support.path, 'restored_assets', _restoreId()),
      );
      await stagedDirectory.create(recursive: true);
      recoveryJournal = await _writeRecoveryJournal(
        support,
        oldSettings: oldSettings,
        oldFeatures: oldFeatures,
        oldSnapshot: oldSnapshot,
        stagedDirectory: stagedDirectory.path,
      );
      final configuration =
          preview.files['configuration']! as Map<String, dynamic>;
      final importedSettings = Map<String, dynamic>.from(
        configuration['settings']! as Map<String, dynamic>,
      );
      importedSettings['logoPath'] = await _restoreAsset(
        importedSettings['logoPath'],
        preview.bytes,
        stagedDirectory,
      );
      final nextSettings = AppSettings.fromJson(importedSettings);
      final nextFeatures = _parseFeatures(
        configuration['orderFeatures']! as Map<String, dynamic>,
      );

      if (preview.kind == PortableArchiveKind.fullBackup) {
        final snapshot = _deepCopy(
          preview.files['database']! as Map<String, dynamic>,
        );
        final tables = snapshot['tables']! as Map<String, dynamic>;
        for (final value in tables['items']! as List) {
          final row = value as Map<String, dynamic>;
          row['image_path'] = await _restoreAsset(
            row['image_path'],
            preview.bytes,
            stagedDirectory,
          );
        }
        await _orders.replaceWithPortableSnapshot(snapshot);
        databaseChanged = true;
      } else {
        await _orders.saveFeatureSettings(nextFeatures);
        featuresChanged = true;
      }
      await _settings.save(nextSettings);
      await _markRecoveryCommitted(recoveryJournal);
      await recoveryJournal.delete();
    } catch (error) {
      try {
        if (databaseChanged && oldSnapshot != null) {
          await _orders.replaceWithPortableSnapshot(oldSnapshot);
        } else if (featuresChanged) {
          await _orders.saveFeatureSettings(oldFeatures);
        }
        await _settings.save(oldSettings);
        if (recoveryJournal != null && await recoveryJournal.exists()) {
          await recoveryJournal.delete();
        }
      } catch (_) {
        throw PortabilityException('rollbackFailed', error);
      } finally {
        if (stagedDirectory != null && await stagedDirectory.exists()) {
          await stagedDirectory.delete(recursive: true);
        }
      }
      if (error is PortabilityException) rethrow;
      throw PortabilityException('restoreFailed', error);
    }
  }

  Future<File> _writeRecoveryJournal(
    Directory support, {
    required AppSettings oldSettings,
    required OrderFeatureSettings oldFeatures,
    required Map<String, Object?>? oldSnapshot,
    required String stagedDirectory,
  }) async {
    final journal = File(p.join(support.path, 'portability_recovery.json'));
    final temporary = File('${journal.path}.tmp');
    final document = <String, Object?>{
      'version': 1,
      'phase': 'pending',
      'settings': oldSettings.toJson(),
      'features': {
        'orderReferenceEnabled': oldFeatures.orderReferenceEnabled,
        'preparationNotesEnabled': oldFeatures.preparationNotesEnabled,
        'orderNotesEnabled': oldFeatures.orderNotesEnabled,
      },
      'database': oldSnapshot,
      'stagedDirectory': stagedDirectory,
    };
    await temporary.writeAsString(jsonEncode(document), flush: true);
    await temporary.rename(journal.path);
    return journal;
  }

  static Future<void> _markRecoveryCommitted(File journal) async {
    final value =
        jsonDecode(await journal.readAsString()) as Map<String, dynamic>;
    value['phase'] = 'committed';
    final temporary = File('${journal.path}.tmp');
    await temporary.writeAsString(jsonEncode(value), flush: true);
    await temporary.rename(journal.path);
  }

  static Uint8List _encodeArchive(
    Map<String, Uint8List> entries,
    DateTime modified,
  ) {
    final archive = Archive();
    for (final entry in entries.entries) {
      archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
    }
    return ZipEncoder().encodeBytes(archive, modified: modified);
  }

  static Map<String, Uint8List> _decodeAndValidateStructure(Uint8List bytes) {
    final encodedPaths = <String>{};
    final archive = ZipDecoder().decodeBytes(
      bytes,
      verify: true,
      callback: (entry) {
        if (!encodedPaths.add(entry.name)) {
          throw const PortabilityException('unsafeArchive');
        }
      },
    );
    if (archive.length > _maxEntries) {
      throw const PortabilityException('tooManyFiles');
    }
    final result = <String, Uint8List>{};
    var expanded = 0;
    for (final file in archive) {
      final name = file.name;
      if (!file.isFile ||
          file.isSymbolicLink ||
          !_safePath(name) ||
          result.containsKey(name) ||
          !_allowedPath(name) ||
          file.size > _maxEntryBytes) {
        throw const PortabilityException('unsafeArchive');
      }
      final content = file.readBytes();
      if (content == null || content.length != file.size) {
        throw const PortabilityException('invalidArchive');
      }
      expanded += content.length;
      if (expanded > _maxExpandedBytes) {
        throw const PortabilityException('archiveTooLarge');
      }
      result[name] = content;
    }
    if (!result.containsKey('manifest.json') ||
        !result.containsKey('configuration.json') ||
        expanded > bytes.length * _maxCompressionRatio + 1024 * 1024) {
      throw const PortabilityException('unsafeArchive');
    }
    return result;
  }

  static void _validateInventory(
    Map<String, Uint8List> entries,
    List<dynamic> inventory,
  ) {
    final paths = <String>{};
    for (final value in inventory) {
      if (value is! Map<String, dynamic> ||
          value['path'] is! String ||
          value['size'] is! int ||
          value['sha256'] is! String ||
          value['mediaType'] is! String) {
        throw const PortabilityException('invalidManifest');
      }
      final path = value['path']! as String;
      final bytes = entries[path];
      if (path == 'manifest.json' ||
          bytes == null ||
          !paths.add(path) ||
          bytes.length != value['size'] ||
          sha256.convert(bytes).toString() != value['sha256'] ||
          _mediaType(path) != value['mediaType']) {
        throw const PortabilityException('checksumMismatch');
      }
    }
    final expected = entries.keys
        .where((path) => path != 'manifest.json')
        .toSet();
    if (paths.length != expected.length || !paths.containsAll(expected)) {
      throw const PortabilityException('inventoryMismatch');
    }
  }

  static void _validateSnapshot(
    Map<String, dynamic> snapshot,
    Map<String, Uint8List> entries,
  ) {
    if (snapshot['schemaVersion'] != SqliteOrderRepository.databaseVersion ||
        snapshot['tables'] is! Map<String, dynamic>) {
      throw const PortabilityException('unsupportedDatabase');
    }
    final tables = snapshot['tables']! as Map<String, dynamic>;
    const required = {
      'categories',
      'items',
      'drafts',
      'draft_lines',
      'tickets',
      'ticket_lines',
      'counters',
      'print_jobs',
      'order_feature_settings',
    };
    if (tables.keys.toSet().difference(required).isNotEmpty ||
        required.any((name) => tables[name] is! List)) {
      throw const PortabilityException('invalidDatabase');
    }
    var count = 0;
    final ids = <String, Set<Object?>>{};
    for (final name in required) {
      final rows = tables[name]! as List;
      count += rows.length;
      if (count > 100000 || rows.any((row) => row is! Map<String, dynamic>)) {
        throw const PortabilityException('invalidDatabase');
      }
      if (name != 'counters' && name != 'order_feature_settings') {
        final set = <Object?>{};
        for (final row in rows.cast<Map<String, dynamic>>()) {
          if (row['id'] is! String || !set.add(row['id'])) {
            throw const PortabilityException('invalidDatabase');
          }
        }
        ids[name] = set;
      }
    }
    bool missing(String table, Object? id) =>
        id != null && !ids[table]!.contains(id);
    for (final row in (tables['items']! as List).cast<Map<String, dynamic>>()) {
      if (missing('categories', row['category_id'])) {
        throw const PortabilityException('invalidRelationships');
      }
      _validateAssetReference(row['image_path'], entries);
    }
    for (final row
        in (tables['draft_lines']! as List).cast<Map<String, dynamic>>()) {
      if (missing('drafts', row['draft_id']) ||
          missing('items', row['catalogue_item_id'])) {
        throw const PortabilityException('invalidRelationships');
      }
    }
    for (final row
        in (tables['ticket_lines']! as List).cast<Map<String, dynamic>>()) {
      if (missing('tickets', row['ticket_id'])) {
        throw const PortabilityException('invalidRelationships');
      }
    }
    for (final row
        in (tables['print_jobs']! as List).cast<Map<String, dynamic>>()) {
      if (missing('tickets', row['ticket_id']) || row['payload'] is! String) {
        throw const PortabilityException('invalidRelationships');
      }
      try {
        if (base64Decode(row['payload']! as String).length > 2 * 1024 * 1024) {
          throw const PortabilityException('invalidDatabase');
        }
      } catch (_) {
        throw const PortabilityException('invalidDatabase');
      }
    }
    final counters = (tables['counters']! as List).cast<Map<String, dynamic>>();
    if (counters.length != 2 ||
        !counters.any(
          (row) => row['name'] == 'ticket' && row['next_value'] is int,
        ) ||
        !counters.any(
          (row) => row['name'] == 'order' && row['next_value'] is int,
        )) {
      throw const PortabilityException('invalidDatabase');
    }
  }

  static Map<String, int> _snapshotCounts(Map<String, dynamic>? snapshot) {
    if (snapshot == null) {
      return const {'items': 0, 'drafts': 0, 'tickets': 0, 'printJobs': 0};
    }
    final tables = snapshot['tables']! as Map<String, dynamic>;
    return {
      'items': (tables['items']! as List).length,
      'drafts': (tables['drafts']! as List).length,
      'tickets': (tables['tickets']! as List).length,
      'printJobs': (tables['print_jobs']! as List).length,
    };
  }

  static OrderFeatureSettings _parseFeatures(Map<String, dynamic> value) {
    if (value['orderReferenceEnabled'] is! bool ||
        value['preparationNotesEnabled'] is! bool ||
        value['orderNotesEnabled'] is! bool) {
      throw const PortabilityException('invalidConfiguration');
    }
    return OrderFeatureSettings(
      orderReferenceEnabled: value['orderReferenceEnabled']! as bool,
      preparationNotesEnabled: value['preparationNotesEnabled']! as bool,
      orderNotesEnabled: value['orderNotesEnabled']! as bool,
    );
  }

  Future<String?> _addAsset(
    Map<String, Uint8List> entries,
    String? sourcePath,
    String archiveStem,
  ) async {
    if (sourcePath == null || sourcePath.isEmpty) return null;
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw const PortabilityException('missingAsset');
    }
    final extension = p.extension(sourcePath).toLowerCase();
    if (!_assetExtensions.contains(extension)) {
      throw const PortabilityException('unsupportedAsset');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > _maxEntryBytes) {
      throw const PortabilityException('invalidAsset');
    }
    final archivePath = '$archiveStem$extension';
    entries[archivePath] = bytes;
    return archivePath;
  }

  static Future<String?> _restoreAsset(
    Object? reference,
    Map<String, Uint8List> entries,
    Directory directory,
  ) async {
    if (reference == null) return null;
    if (reference is! String || !reference.startsWith('assets/')) {
      throw const PortabilityException('invalidAsset');
    }
    final bytes = entries[reference];
    if (bytes == null) throw const PortabilityException('missingAsset');
    final destination = File(p.join(directory.path, p.basename(reference)));
    await destination.writeAsBytes(bytes, flush: true);
    return destination.path;
  }

  static void _validateAssetReference(
    Object? reference,
    Map<String, Uint8List> entries,
  ) {
    if (reference == null) return;
    if (reference is! String ||
        !reference.startsWith('assets/') ||
        !entries.containsKey(reference) ||
        !_assetExtensions.contains(p.extension(reference).toLowerCase())) {
      throw const PortabilityException('invalidAsset');
    }
  }

  static Map<String, dynamic> _decodeObject(Uint8List bytes, String name) {
    if (bytes.length > _maxEntryBytes) {
      throw PortabilityException('invalid$name');
    }
    final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
    if (decoded is! Map<String, dynamic>) {
      throw PortabilityException('invalid$name');
    }
    return decoded;
  }

  static Map<String, dynamic> _deepCopy(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  static Uint8List _jsonBytes(Object value) =>
      Uint8List.fromList(utf8.encode(jsonEncode(value)));

  static bool _safePath(String value) {
    if (value.isEmpty ||
        value.startsWith('/') ||
        value.startsWith('\\') ||
        value.contains('\\') ||
        RegExp(r'^[A-Za-z]:').hasMatch(value)) {
      return false;
    }
    final segments = value.split('/');
    return segments.every(
      (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
    );
  }

  static bool _allowedPath(String value) =>
      value == 'manifest.json' ||
      value == 'configuration.json' ||
      value == 'database.json' ||
      (value.startsWith('assets/') &&
          _assetExtensions.contains(p.extension(value).toLowerCase()));

  static String _mediaType(String path) =>
      switch (p.extension(path).toLowerCase()) {
        '.json' => 'application/json',
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        '.jpg' || '.jpeg' => 'image/jpeg',
        _ => throw const PortabilityException('unsupportedAsset'),
      };

  static const _assetExtensions = {'.jpg', '.jpeg', '.png', '.webp'};

  static String _restoreId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(16);

  static Future<Uint8List?> _pickArchive() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    return file?.readAsBytes();
  }

  static Future<void> _shareArchive(File file, String fileName) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/zip', name: fileName)],
        fileNameOverrides: [fileName],
      ),
    );
  }
}
