import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/networking/domain/client_delivery_models.dart';
import 'package:libreslip/features/networking/domain/client_transport.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:libreslip/features/portability/application/portability_service.dart';
import 'package:libreslip/features/portability/domain/portability_models.dart';
import 'package:libreslip/features/settings/data/settings_repository.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'progress_sync_test.dart';

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
        logoWidthPercent: 50,
        language: 'it',
        themeMode: ThemeMode.dark,
        preferredPrinterAddress: '00:11:22:33:44:55',
        printerConnectionRequired: false,
      );
      await orders.saveFeatureSettings(
        const OrderFeatureSettings(
          orderNotesEnabled: false,
          courseGroupsEnabled: true,
          managedOrdersEnabled: true,
          pricesEnabled: true,
        ),
      );
      final item = await orders.saveItem(
        name: 'Toast',
        categoryName: 'Kitchen',
        imagePath: image.path,
        sendToServer: false,
        price: const ProductPrice(minorUnits: 0, currency: 'EUR'),
      );
      final blank = await orders.createDraft();
      final ticket = await orders.convertDraftToTicket(
        blank.copyWith(
          reference: 'Table 8',
          courses: const [OrderCourse(id: 'drinks', name: 'Bevande')],
          updatedAt: DateTime.now().toUtc(),
          lines: [
            TicketLine(
              id: createLocalId(),
              catalogueItemId: item.id,
              name: item.name,
              quantity: 2,
              courseId: 'drinks',
              price: item.price,
            ),
          ],
        ),
        heading: 'Caffè Libertà',
        keepOpen: true,
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
          lines: [
            TicketLine(
              id: createLocalId(),
              name: 'Tea',
              quantity: 1,
              price: const ProductPrice(minorUnits: 375, currency: 'USD'),
            ),
          ],
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
      expect(settings.stored!.printerConnectionRequired, isFalse);
      expect(settings.stored!.language, 'it');
      expect(settings.stored!.themeMode, ThemeMode.dark);
      expect(settings.stored!.logoWidthPercent, 50);
      expect(settings.stored!.preferredPrinterAddress, '00:11:22:33:44:55');
      expect(settings.stored!.logoPath, isNot(logo.path));
      expect(File(settings.stored!.logoPath!).readAsBytesSync(), _tinyPng);
      final restoredItems = await orders.loadItems();
      expect(restoredItems.single.name, 'Toast');
      expect(restoredItems.single.sendToServer, isFalse);
      expect(
        restoredItems.single.price,
        const ProductPrice(minorUnits: 0, currency: 'EUR'),
      );
      expect((await orders.loadFeatureSettings()).pricesEnabled, isTrue);
      expect(
        (await orders.loadTickets()).single.lines.single.price,
        restoredItems.single.price,
      );
      expect(restoredItems.single.imagePath, isNot(image.path));
      expect(
        File(restoredItems.single.imagePath!).readAsBytesSync(),
        _tinyJpeg,
      );
      expect((await orders.loadTickets()).single.id, ticket.id);
      expect((await orders.loadTickets()).single.reference, 'Table 8');
      expect(
        (await orders.loadTickets()).single.courses.single.name,
        'Bevande',
      );
      expect(
        (await orders.loadTickets()).single.lines.single.courseId,
        'drinks',
      );
      expect(await orders.loadPrintJobs(), hasLength(1));
      expect(await orders.loadDrafts(), hasLength(1));
      expect(
        (await orders.loadDrafts()).single.lines.single.price,
        const ProductPrice(minorUnits: 375, currency: 'USD'),
      );
      expect(await orders.loadNextOrderNumber(), 2);
      expect((await orders.loadFeatureSettings()).orderNotesEnabled, isFalse);
      expect((await orders.loadFeatureSettings()).courseGroupsEnabled, isTrue);
      expect((await orders.loadFeatureSettings()).managedOrdersEnabled, isTrue);
    },
  );

  test(
    'configuration restore does not replace items, drafts or ticket history',
    () async {
      settings.stored = const AppSettings(
        heading: 'Exported heading',
        language: 'it',
        printerConnectionRequired: false,
      );
      await orders.saveFeatureSettings(
        const OrderFeatureSettings(
          preparationNotesEnabled: false,
          courseGroupsEnabled: true,
          managedOrdersEnabled: true,
          pricesEnabled: true,
        ),
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
      expect(settings.stored!.printerConnectionRequired, isFalse);
      expect(settings.stored!.language, 'it');
      expect(await orders.loadItems(), hasLength(1));
      expect((await orders.loadTickets()).single.id, ticket.id);
      expect(
        (await orders.loadFeatureSettings()).preparationNotesEnabled,
        isFalse,
      );
      expect((await orders.loadFeatureSettings()).courseGroupsEnabled, isTrue);
      expect((await orders.loadFeatureSettings()).managedOrdersEnabled, isTrue);
      expect((await orders.loadFeatureSettings()).pricesEnabled, isTrue);
    },
  );

  test('full backup restores onto a fresh installation', () async {
    settings.stored = const AppSettings(
      heading: 'Fresh destination',
      printerConnectionRequired: false,
    );
    final pairedAt = DateTime.now().toUtc();
    await orders.savePairedServer(
      PairedServer(
        id: 'original-server',
        displayName: 'Kitchen',
        baseUrl: Uri.parse('https://127.0.0.1:5119'),
        certificateFingerprint: 'a' * 64,
        createdAt: pairedAt,
        updatedAt: pairedAt,
      ),
    );
    await orders.saveFeatureSettings(
      const OrderFeatureSettings(pricesEnabled: true),
    );
    final item = await orders.saveItem(
      name: 'Soup',
      price: const ProductPrice(minorUnits: 99999999, currency: 'GBP'),
    );
    final draft = await orders.createDraft();
    final ticket = await orders.convertDraftToTicket(
      draft.copyWith(
        courses: const [OrderCourse(id: 'first', name: 'Primo')],
        updatedAt: DateTime.now().toUtc(),
        lines: [
          TicketLine(
            id: createLocalId(),
            catalogueItemId: item.id,
            name: item.name,
            quantity: 3,
            courseId: 'first',
            price: item.price,
          ),
        ],
      ),
      heading: 'Fresh destination',
      keepOpen: true,
    );
    final managed = (await orders.loadManagedOrders()).single;
    await orders.setManagedLineDelivered(
      managed.id,
      managed.lines.single.id,
      2,
      expectedQuantity: 0,
    );
    final blankAddition = await orders.createDraft();
    final addition = await orders.beginOrderAddition(
      managed.id,
      blankAddition.id,
    );
    await orders.saveDraft(
      addition.copyWith(
        lines: const [
          TicketLine(id: 'fresh-water', name: 'Water', quantity: 1),
        ],
      ),
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
    expect(destinationSettings.stored!.printerConnectionRequired, isFalse);
    expect((await destination.loadItems()).single.id, item.id);
    expect((await destination.loadTickets()).single.id, ticket.id);
    expect(
      (await destination.loadTickets()).single.courses.single.name,
      'Primo',
    );
    expect(
      (await destination.loadTickets()).single.lines.single.courseId,
      'first',
    );
    expect((await destination.loadItems()).single.price, item.price);
    expect(
      (await destination.loadTickets()).single.lines.single.price,
      item.price,
    );
    expect(
      (await destination.loadManagedOrders()).single.lines.single.price,
      item.price,
    );
    expect((await destination.loadFeatureSettings()).pricesEnabled, isTrue);
    expect(await destination.loadNextOrderNumber(), 2);
    expect((await destination.loadManagedOrders()).single.id, managed.id);
    expect((await destination.loadManagedOrders()).single.deliveredCount, 2);
    expect((await destination.loadManagedOrders()).single.changedDeliveryIds, {
      managed.lines.single.id,
    });
    expect(
      (await destination.loadManagedOrders()).single.destinationId,
      isNull,
    );
    expect(await destination.loadClientDeliveries(), isEmpty);
    expect((await destination.loadDrafts()).single.managedOrderId, managed.id);
    final restoredAddition = (await destination.loadDrafts()).single;
    final revised = await destination.convertDraftToTicket(
      restoredAddition,
      heading: 'Ignored',
    );
    expect(revised.revision, 2);
    expect(revised.number, ticket.number);
    expect(revised.printLines.single.name, 'Water');
    expect(await destination.loadClientDeliveries(), isEmpty);
  });

  test(
    'pending restore journal recovers the pre-import state on restart',
    () async {
      settings.stored = const AppSettings(heading: 'Before import');
      final draft = await orders.createDraft();
      final ticket = await orders.convertDraftToTicket(
        draft.copyWith(
          updatedAt: DateTime.now().toUtc(),
          lines: [
            TicketLine(
              id: createLocalId(),
              name: 'Keep',
              quantity: 1,
              price: const ProductPrice(minorUnits: 275, currency: 'EUR'),
            ),
          ],
        ),
        heading: 'Before import',
        keepOpen: true,
      );
      await orders.setManagedLineDelivered(
        ticket.managedOrderId!,
        ticket.lines.single.id,
        1,
        expectedQuantity: 0,
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
      expect(
        (await orders.loadManagedOrders()).single.lines.single.price,
        const ProductPrice(minorUnits: 275, currency: 'EUR'),
      );
      expect(settings.stored!.heading, 'Before import');
      expect((await orders.loadManagedOrders()).single.deliveredCount, 1);
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

  test('failed and interrupted restores retain the same pending progress operation', () async {
    final fixture = await createProgressFixture();
    addTearDown(fixture.dispose);
    final progressService = PortabilityService(
      fixture.client,
      settings,
      supportDirectory: () async => support,
      temporaryDirectory: () async => temporary,
      appVersion: () => File('VERSION').readAsString(),
    );
    final archive = await progressService.createArchive(
      PortableArchiveKind.fullBackup,
    );
    final preview = await progressService.inspectArchive(archive);
    final archivedDatabase = await fixture.client.createPortableSnapshot();
    await fixture.local('water', 1);
    fixture.transport.loseNextAcknowledgement = true;
    await expectLater(fixture.sync(), throwsA(isA<ClientTransportException>()));
    final pending = (await fixture.client.loadProgressSyncState(
      await fixture.order(),
    )).pending!;
    settings.failNextSave = true;
    await expectLater(
      progressService.restore(preview),
      throwsA(isA<PortabilityException>()),
    );
    expect((await fixture.order()).deliveredQuantity('water'), 1);
    expect(
      (await fixture.client.loadProgressSyncState(await fixture.order()))
          .pending!
          .operationId,
      pending.operationId,
    );

    final recovery = await fixture.client.createProgressRecoverySnapshot();
    final features = await fixture.client.loadFeatureSettings();
    final oldSettings = await settings.load() ?? const AppSettings();
    await fixture.client.replaceWithPortableSnapshot(archivedDatabase);
    expect(
      (await fixture.client.loadProgressSyncState(await fixture.order()))
          .pending,
      isNull,
    );
    final staged = Directory(
      '${support.path}/restored_assets/progress-interrupted',
    )..createSync(recursive: true);
    final journal = File('${support.path}/portability_recovery.json');
    await journal.writeAsString(
      jsonEncode({
        'version': 1,
        'phase': 'pending',
        'settings': oldSettings.toJson(),
        'features': {
          'orderReferenceEnabled': features.orderReferenceEnabled,
          'preparationNotesEnabled': features.preparationNotesEnabled,
          'orderNotesEnabled': features.orderNotesEnabled,
          'courseGroupsEnabled': features.courseGroupsEnabled,
          'managedOrdersEnabled': features.managedOrdersEnabled,
        },
        ...recovery,
        'stagedDirectory': staged.path,
      }),
      flush: true,
    );
    await progressService.recoverInterruptedRestore();
    expect((await fixture.order()).deliveredQuantity('water'), 1);
    expect(
      (await fixture.client.loadProgressSyncState(await fixture.order()))
          .pending!
          .operationId,
      pending.operationId,
    );
    expect(journal.existsSync(), isFalse);
    expect(staged.existsSync(), isFalse);
    await fixture.sync();
    expect(fixture.transport.operations, [
      pending.operationId,
      pending.operationId,
    ]);
  });

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
    final currentDraft = await orders.createDraft();
    final currentTicket = await orders.convertDraftToTicket(
      currentDraft.copyWith(
        lines: const [
          TicketLine(
            id: 'current-progress',
            name: 'Current only',
            quantity: 2,
            price: ProductPrice(minorUnits: 275, currency: 'USD'),
          ),
        ],
      ),
      heading: 'Current',
      keepOpen: true,
    );
    await orders.setManagedLineDelivered(
      currentTicket.managedOrderId!,
      'current-progress',
      1,
      expectedQuantity: 0,
    );
    settings.failNextSave = true;

    await expectLater(
      service.restore(preview),
      throwsA(isA<PortabilityException>()),
    );

    expect((await orders.loadTickets()).single.id, currentTicket.id);
    expect((await orders.loadManagedOrders()).single.deliveredCount, 1);
    expect(
      (await orders.loadTickets()).single.lines.single.price,
      const ProductPrice(minorUnits: 275, currency: 'USD'),
    );
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
  test(
    'invalid sync edit metadata fails preview without changing local progress',
    () async {
      final draft = await orders.createDraft();
      final ticket = await orders.convertDraftToTicket(
        draft.copyWith(
          lines: const [TicketLine(id: 'sync-soup', name: 'Soup', quantity: 2)],
        ),
        heading: 'Kitchen',
        keepOpen: true,
      );
      await orders.setManagedLineDelivered(
        ticket.managedOrderId!,
        'sync-soup',
        1,
        expectedQuantity: 0,
      );
      final archive = await service.createArchive(
        PortableArchiveKind.fullBackup,
      );
      for (final (key, value) in [
        ('delivery_changed_ids', '["missing"]'),
        ('delivery_changed_ids', '["sync-soup","sync-soup"]'),
        ('delivery_changed_ids', '{}'),
        ('delivery_changed_ids', null),
        ('delivery_edit_revision', -1),
        ('delivery_edit_revision', '1'),
        ('delivery_edit_revision', 9007199254740992),
      ]) {
        final broken = _rewriteDatabase(archive, (snapshot) {
          ((snapshot['tables'] as Map)['managed_orders'] as List).single[key] =
              value;
        });
        await expectLater(
          service.inspectArchive(broken),
          throwsA(isA<PortabilityException>()),
        );
        expect((await orders.loadManagedOrders()).single.deliveredCount, 1);
      }
    },
  );

  test('legacy printer settings restore required and invalid modern values leave data intact', () async {
    settings.stored = const AppSettings(printerConnectionRequired: false);
    final bytes = await service.createArchive(
      PortableArchiveKind.configuration,
    );
    final legacy = _rewriteEntry(bytes, 'configuration.json', (configuration) {
      final preferences = configuration['settings'] as Map;
      preferences['version'] = 7;
      preferences.remove('printerConnectionRequired');
    });
    await service.restore(await service.inspectArchive(legacy));
    expect(settings.stored!.printerConnectionRequired, isTrue);
    for (final value in [null, 'false', 0]) {
      final invalid = _rewriteEntry(bytes, 'configuration.json', (
        configuration,
      ) {
        (configuration['settings'] as Map)['printerConnectionRequired'] = value;
      });
      await expectLater(
        service.inspectArchive(invalid),
        throwsA(isA<PortabilityException>()),
      );
      expect(settings.stored!.printerConnectionRequired, isTrue);
    }
  });

  test('legacy configurations default to hidden prices and invalid price switches are rejected', () async {
    await orders.saveFeatureSettings(
      const OrderFeatureSettings(pricesEnabled: true),
    );
    final bytes = await service.createArchive(
      PortableArchiveKind.configuration,
    );
    for (final version in [1, 2, 3]) {
      final old = _rewriteEntry(bytes, 'configuration.json', (configuration) {
        configuration['version'] = version;
        (configuration['orderFeatures'] as Map).remove('pricesEnabled');
      });
      await service.restore(await service.inspectArchive(old));
      expect((await orders.loadFeatureSettings()).pricesEnabled, isFalse);
    }
    for (final value in [null, 1, 'true']) {
      final invalid = _rewriteEntry(bytes, 'configuration.json', (
        configuration,
      ) {
        (configuration['orderFeatures'] as Map)['pricesEnabled'] = value;
      });
      await expectLater(
        service.inspectArchive(invalid),
        throwsA(isA<PortabilityException>()),
      );
    }
    final invalidLegacy = _rewriteEntry(bytes, 'configuration.json', (
      configuration,
    ) {
      configuration['version'] = 3;
    });
    await expectLater(
      service.inspectArchive(invalidLegacy),
      throwsA(isA<PortabilityException>()),
    );
  });

  test('invalid catalogue, line and managed prices fail preview without changing data', () async {
    final item = await orders.saveItem(
      name: 'Priced',
      price: const ProductPrice(minorUnits: 125, currency: 'EUR'),
    );
    final draft = await orders.createDraft();
    await orders.convertDraftToTicket(
      draft.copyWith(
        lines: [
          TicketLine(
            id: 'price-line',
            catalogueItemId: item.id,
            name: item.name,
            quantity: 2,
            price: item.price,
          ),
        ],
      ),
      heading: 'Kitchen',
      keepOpen: true,
    );
    final composition = await orders.createDraft();
    await orders.saveDraft(
      composition.copyWith(
        lines: [
          TicketLine(
            id: 'draft-price',
            catalogueItemId: item.id,
            name: item.name,
            quantity: 1,
            price: item.price,
          ),
        ],
      ),
    );
    final archive = await service.createArchive(PortableArchiveKind.fullBackup);
    for (final table in [
      'items',
      'draft_lines',
      'ticket_lines',
      'managed_orders',
    ]) {
      for (final (amount, currency) in [
        (-1, 'EUR'),
        (100000000, 'EUR'),
        (1.5, 'EUR'),
        ('125', 'EUR'),
        (125, 'eur'),
        (125, 'JPY'),
        (null, 'EUR'),
        (125, null),
      ]) {
        final broken = _rewriteDatabase(archive, (snapshot) {
          final row =
              ((snapshot['tables'] as Map)[table] as List).single as Map;
          if (table == 'managed_orders') {
            final lines = jsonDecode(row['lines_json'] as String) as List;
            lines.single['priceMinorUnits'] = amount;
            lines.single['priceCurrency'] = currency;
            row['lines_json'] = jsonEncode(lines);
          } else {
            row['price_minor_units'] = amount;
            row['price_currency'] = currency;
          }
        });
        await expectLater(
          service.inspectArchive(broken),
          throwsA(isA<PortabilityException>()),
        );
        expect((await orders.loadItems()).single.price, item.price);
      }
    }
    final mismatched = _rewriteDatabase(archive, (snapshot) {
      (((snapshot['tables'] as Map)['ticket_lines'] as List).single
              as Map)['price_minor_units'] =
          126;
    });
    await expectLater(
      service.inspectArchive(mismatched),
      throwsA(isA<PortabilityException>()),
    );
  });

  test('invalid delivered quantities fail archive preview with current progress intact', () async {
    final draft = await orders.createDraft();
    final ticket = await orders.convertDraftToTicket(
      draft.copyWith(
        lines: const [
          TicketLine(id: 'progress-soup', name: 'Soup', quantity: 2),
        ],
      ),
      heading: 'Kitchen',
      keepOpen: true,
    );
    await orders.setManagedLineDelivered(
      ticket.managedOrderId!,
      'progress-soup',
      1,
      expectedQuantity: 0,
    );
    final bytes = await service.createArchive(PortableArchiveKind.fullBackup);
    final broken = _rewriteDatabase(bytes, (snapshot) {
      ((snapshot['tables'] as Map)['managed_orders'] as List)
              .single['delivery_progress_json'] =
          '{"progress-soup":3}';
    });
    await expectLater(
      service.inspectArchive(broken),
      throwsA(isA<PortabilityException>()),
    );
    expect((await orders.loadManagedOrders()).single.deliveredCount, 1);
    expect((await orders.loadTickets()).single.id, ticket.id);
  });

  test('invalid managed revision metadata fails preview before replacing current data', () async {
    final draft = await orders.createDraft();
    await orders.convertDraftToTicket(
      draft.copyWith(
        lines: const [
          TicketLine(id: 'managed-soup', name: 'Soup', quantity: 1),
        ],
      ),
      heading: 'Kitchen',
      keepOpen: true,
    );
    final bytes = await service.createArchive(PortableArchiveKind.fullBackup);
    final broken = _rewriteDatabase(bytes, (snapshot) {
      ((snapshot['tables'] as Map)['tickets'] as List)
              .single['addition_line_ids'] =
          '["missing"]';
    });
    await expectLater(
      service.inspectArchive(broken),
      throwsA(isA<PortabilityException>()),
    );
    expect((await orders.loadManagedOrders()).single.lines.single.quantity, 1);
    expect((await orders.loadTickets()).single.revision, 1);
  });

  test('invalid course metadata fails archive preview without replacing current data', () async {
    final draft = await orders.createDraft();
    await orders.saveDraft(
      draft.copyWith(
        courses: const [OrderCourse(id: 'first', name: 'First course')],
        activeCourseId: 'first',
        lines: const [
          TicketLine(
            id: 'soup-line',
            name: 'Soup',
            quantity: 2,
            courseId: 'first',
          ),
        ],
      ),
    );
    final bytes = await service.createArchive(PortableArchiveKind.fullBackup);
    final broken = _rewriteDatabase(bytes, (snapshot) {
      final tables = snapshot['tables'] as Map<String, dynamic>;
      (tables['draft_lines'] as List).single['course_id'] = 'missing';
    });
    await expectLater(
      service.inspectArchive(broken),
      throwsA(isA<PortabilityException>()),
    );
    expect((await orders.loadDrafts()).single.lines.single.quantity, 2);
    expect(
      (await orders.loadDrafts()).single.courses.single.name,
      'First course',
    );
    expect((await orders.loadDrafts()).single.activeCourseId, 'first');
  });
}

Uint8List _rewriteDatabase(
  Uint8List bytes,
  void Function(Map<String, dynamic>) update,
) => _rewriteEntry(bytes, 'database.json', update);

Uint8List _rewriteEntry(
  Uint8List bytes,
  String path,
  void Function(Map<String, dynamic>) update,
) {
  final entries = {
    for (final entry in ZipDecoder().decodeBytes(bytes))
      entry.name: entry.content as List<int>,
  };
  final snapshot =
      jsonDecode(utf8.decode(entries[path]!)) as Map<String, dynamic>;
  update(snapshot);
  entries[path] = utf8.encode(jsonEncode(snapshot));
  final manifest = jsonDecode(
    utf8.decode(entries['manifest.json']!),
  ) as Map<String, dynamic>;
  for (final row in (manifest['files'] as List).cast<Map<String, dynamic>>()) {
    final content = entries[row['path']]!;
    row['size'] = content.length;
    row['sha256'] = sha256.convert(content).toString();
  }
  entries['manifest.json'] = utf8.encode(jsonEncode(manifest));
  final archive = Archive();
  for (final entry in entries.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
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
