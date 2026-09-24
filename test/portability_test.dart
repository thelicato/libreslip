import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:libreslip/features/portability/application/portability_service.dart';
import 'package:libreslip/features/portability/domain/portability_models.dart';
import 'package:libreslip/features/settings/data/settings_repository.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory temporary;
  late Directory support;
  late SqliteOrderRepository orders;
  late _MemorySettings settings;
  late PortabilityService service;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('libreslip-portability-');
    support = Directory('${temporary.path}/support')..createSync();
    orders = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: '${temporary.path}/orders.sqlite3',
    );
    await orders.open();
    settings = _MemorySettings();
    service = PortabilityService(
      orders,
      settings,
      supportDirectory: () async => support,
      temporaryDirectory: () async => temporary,
      appVersion: () => File('VERSION').readAsString(),
    );
  });

  tearDown(() async {
    await orders.close();
    if (temporary.existsSync()) await temporary.delete(recursive: true);
  });

  test(
    'full backup round trip restores data, counters, settings and assets',
    () async {
      final logo = File('${temporary.path}/logo.png')
        ..writeAsBytesSync(_tinyPng);
      final image = File('${temporary.path}/item.jpg')
        ..writeAsBytesSync(_tinyJpeg);
      settings.stored = AppSettings(
        heading: 'Caffè Libertà',
        footer: 'Preparato con cura',
        logoPath: logo.path,
        language: 'it',
        themeMode: ThemeMode.dark,
      );
      await orders.saveFeatureSettings(
        const OrderFeatureSettings(orderNotesEnabled: false),
      );
      final item = await orders.saveItem(
        name: 'Toast',
        categoryName: 'Kitchen',
        imagePath: image.path,
      );
      final blank = await orders.createDraft();
      final ticket = await orders.convertDraftToTicket(
        blank.copyWith(
          reference: 'Table 8',
          updatedAt: DateTime.now().toUtc(),
          lines: [
            TicketLine(
              id: createLocalId(),
              catalogueItemId: item.id,
              name: item.name,
              quantity: 2,
            ),
          ],
        ),
        heading: 'Caffè Libertà',
      );
      await orders.createPrintJob(
        requestId: 'backup-job',
        ticketId: ticket.id,
        payload: Uint8List.fromList([0x1b, 0x40, 0x0a]),
      );
      final draft = await orders.createDraft();
      await orders.saveDraft(
        draft.copyWith(
          updatedAt: DateTime.now().toUtc(),
          lines: [TicketLine(id: createLocalId(), name: 'Tea', quantity: 1)],
        ),
      );

      final archive = await service.createArchive(
        PortableArchiveKind.fullBackup,
      );
      final preview = await service.inspectArchive(archive);
      expect(preview.itemCount, 1);
      expect(preview.draftCount, 1);
      expect(preview.ticketCount, 1);
      expect(preview.printJobCount, 1);
      expect(preview.includesLogo, isTrue);

      await orders.deleteAllTickets();
      await orders.archiveItem(item.id);
      await orders.resetOrderNumber();
      settings.stored = const AppSettings(heading: 'Changed');

      await service.restore(preview);

      expect(settings.stored!.heading, 'Caffè Libertà');
      expect(settings.stored!.language, 'it');
      expect(settings.stored!.themeMode, ThemeMode.dark);
      expect(settings.stored!.logoPath, isNot(logo.path));
      expect(File(settings.stored!.logoPath!).readAsBytesSync(), _tinyPng);
      final restoredItems = await orders.loadItems();
      expect(restoredItems.single.name, 'Toast');
      expect(restoredItems.single.imagePath, isNot(image.path));
      expect(
        File(restoredItems.single.imagePath!).readAsBytesSync(),
        _tinyJpeg,
      );
      expect((await orders.loadTickets()).single.id, ticket.id);
      expect(await orders.loadPrintJobs(), hasLength(1));
      expect(await orders.loadDrafts(), hasLength(1));
      expect(await orders.loadNextOrderNumber(), 2);
      expect((await orders.loadFeatureSettings()).orderNotesEnabled, isFalse);
    },
  );

  test(
    'configuration restore does not replace items, drafts or ticket history',
    () async {
      settings.stored = const AppSettings(
        heading: 'Exported heading',
        language: 'it',
      );
      await orders.saveFeatureSettings(
        const OrderFeatureSettings(preparationNotesEnabled: false),
      );
      final archive = await service.createArchive(
        PortableArchiveKind.configuration,
      );
      final preview = await service.inspectArchive(archive);

      final item = await orders.saveItem(name: 'Keep me');
      final draft = await orders.createDraft();
      final ticket = await orders.convertDraftToTicket(
        draft.copyWith(
          updatedAt: DateTime.now().toUtc(),
          lines: [
            TicketLine(id: createLocalId(), name: item.name, quantity: 1),
          ],
        ),
        heading: 'Current',
      );
      settings.stored = const AppSettings(heading: 'Current heading');
      await orders.saveFeatureSettings(const OrderFeatureSettings());

      await service.restore(preview);

      expect(settings.stored!.heading, 'Exported heading');
      expect(settings.stored!.language, 'it');
      expect(await orders.loadItems(), hasLength(1));
      expect((await orders.loadTickets()).single.id, ticket.id);
      expect(
        (await orders.loadFeatureSettings()).preparationNotesEnabled,
        isFalse,
      );
    },
  );

  test('full backup restores onto a fresh installation', () async {
    settings.stored = const AppSettings(heading: 'Fresh destination');
    final item = await orders.saveItem(name: 'Soup');
    final draft = await orders.createDraft();
    final ticket = await orders.convertDraftToTicket(
      draft.copyWith(
        updatedAt: DateTime.now().toUtc(),
        lines: [
          TicketLine(
            id: createLocalId(),
            catalogueItemId: item.id,
            name: item.name,
            quantity: 3,
          ),
        ],
      ),
      heading: 'Fresh destination',
    );
    final bytes = await service.createArchive(PortableArchiveKind.fullBackup);

    final destination = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: '${temporary.path}/fresh.sqlite3',
    );
    await destination.open();
    addTearDown(destination.close);
    final destinationSettings = _MemorySettings();
    final destinationSupport = Directory('${temporary.path}/fresh-support')
      ..createSync();
    final destinationService = PortabilityService(
      destination,
      destinationSettings,
      supportDirectory: () async => destinationSupport,
      temporaryDirectory: () async => temporary,
      appVersion: () => File('VERSION').readAsString(),
    );
    final preview = await destinationService.inspectArchive(bytes);
    await destinationService.restore(preview);

    expect(destinationSettings.stored!.heading, 'Fresh destination');
    expect((await destination.loadItems()).single.id, item.id);
    expect((await destination.loadTickets()).single.id, ticket.id);
    expect(await destination.loadNextOrderNumber(), 2);
  });

  test(
    'pending restore journal recovers the pre-import state on restart',
    () async {
      settings.stored = const AppSettings(heading: 'Before import');
      final draft = await orders.createDraft();
      final ticket = await orders.convertDraftToTicket(
        draft.copyWith(
          updatedAt: DateTime.now().toUtc(),
          lines: [TicketLine(id: createLocalId(), name: 'Keep', quantity: 1)],
        ),
        heading: 'Before import',
      );
      final oldSnapshot = await orders.createPortableSnapshot();
      final oldFeatures = await orders.loadFeatureSettings();
      final staged = Directory('${support.path}/restored_assets/interrupted')
        ..createSync(recursive: true);
      File('${staged.path}/partial.png').writeAsBytesSync(_tinyPng);
      final journal = File('${support.path}/portability_recovery.json');
      await journal.writeAsString(
        jsonEncode({
          'version': 1,
          'phase': 'pending',
          'settings': settings.stored!.toJson(),
          'features': {
            'orderReferenceEnabled': oldFeatures.orderReferenceEnabled,
            'preparationNotesEnabled': oldFeatures.preparationNotesEnabled,
            'orderNotesEnabled': oldFeatures.orderNotesEnabled,
          },
          'database': oldSnapshot,
          'stagedDirectory': staged.path,
        }),
        flush: true,
      );
      await orders.deleteAllTickets();
      settings.stored = const AppSettings(heading: 'Partly imported');

      await service.recoverInterruptedRestore();

      expect((await orders.loadTickets()).single.id, ticket.id);
      expect(settings.stored!.heading, 'Before import');
      expect(journal.existsSync(), isFalse);
      expect(staged.existsSync(), isFalse);
    },
  );

  test(
    'unsafe paths and checksum changes are rejected before restore',
    () async {
      final unsafe = Archive()
        ..addFile(ArchiveFile.string('../configuration.json', '{}'))
        ..addFile(ArchiveFile.string('manifest.json', '{}'));
      final unsafeBytes = ZipEncoder().encodeBytes(unsafe);
      await expectLater(
        service.inspectArchive(unsafeBytes),
        throwsA(isA<PortabilityException>()),
      );

      final duplicate = Archive()
        ..addFile(ArchiveFile.string('configuration.json', '{}'))
        ..addFile(ArchiveFile.string('configuration.json', '{}'))
        ..addFile(ArchiveFile.string('manifest.json', '{}'));
      await expectLater(
        service.inspectArchive(ZipEncoder().encodeBytes(duplicate)),
        throwsA(isA<PortabilityException>()),
      );

      final valid = await service.createArchive(
        PortableArchiveKind.configuration,
      );
      final decoded = ZipDecoder().decodeBytes(valid);
      final changed = Archive();
      for (final entry in decoded) {
        changed.addFile(
          entry.name == 'configuration.json'
              ? ArchiveFile.string(entry.name, '{"changed":true}')
              : ArchiveFile.bytes(entry.name, entry.readBytes()!),
        );
      }
      await expectLater(
        service.inspectArchive(ZipEncoder().encodeBytes(changed)),
        throwsA(isA<PortabilityException>()),
      );
    },
  );

  test('a failed settings write rolls the database replacement back', () async {
    final originalDraft = await orders.createDraft();
    final originalTicket = await orders.convertDraftToTicket(
      originalDraft.copyWith(
        updatedAt: DateTime.now().toUtc(),
        lines: [TicketLine(id: createLocalId(), name: 'Archived', quantity: 1)],
      ),
      heading: 'Backup',
    );
    final archive = await service.createArchive(PortableArchiveKind.fullBackup);
    final preview = await service.inspectArchive(archive);

    await orders.deleteAllTickets();
    final currentItem = await orders.saveItem(name: 'Current only');
    settings.failNextSave = true;

    await expectLater(
      service.restore(preview),
      throwsA(isA<PortabilityException>()),
    );

    expect(await orders.loadTickets(), isEmpty);
    expect(
      (await orders.loadItems()).any((item) => item.id == currentItem.id),
      isTrue,
    );
    expect(
      (await orders.loadTickets()).any(
        (ticket) => ticket.id == originalTicket.id,
      ),
      isFalse,
    );
  });
}

class _MemorySettings implements SettingsRepository {
  AppSettings? stored = const AppSettings();
  bool failNextSave = false;

  @override
  Future<AppSettings?> load() async => stored;

  @override
  Future<void> save(AppSettings settings) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('Simulated settings failure');
    }
    stored = settings;
  }
}

const _tinyPng = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
const _tinyJpeg = <int>[0xff, 0xd8, 0xff, 0xd9];
