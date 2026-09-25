import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/networking/domain/client_delivery_models.dart';
import 'package:libreslip/features/networking/domain/network_models.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory temporaryDirectory;
  late String databasePath;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'libreslip-network-',
    );
    databasePath = '${temporaryDirectory.path}/network.sqlite3';
  });

  tearDown(() async {
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('mode and stable installation identity survive restart', () async {
    final first = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: databasePath,
    );
    await first.open();
    final initial = await first.loadNetworkConfiguration();
    expect(initial.mode, LibreSlipMode.client);
    expect(initial.installationId, hasLength(32));
    expect(initial.serverName, 'LibreSlip Server');
    await first.saveItem(name: 'Tea');
    await first.saveLibreSlipMode(LibreSlipMode.server);
    await first.close();

    final reopened = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: databasePath,
    );
    addTearDown(reopened.close);
    await reopened.open();
    final restored = await reopened.loadNetworkConfiguration();
    expect(restored.mode, LibreSlipMode.server);
    expect(restored.installationId, initial.installationId);
    expect((await reopened.loadItems()).single.name, 'Tea');
  });

  test('schema 9 migrates the previous LibreSlip port only', () async {
    final first = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: databasePath,
    );
    await first.open();
    final now = DateTime.utc(2026, 9, 25);
    await first.savePairedServer(
      PairedServer(
        id: 'server-old-port',
        displayName: 'Kitchen tablet',
        baseUrl: Uri.parse('https://192.168.1.42:42837'),
        certificateFingerprint:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await first.savePairedServer(
      PairedServer(
        id: 'server-custom-port',
        displayName: 'Custom tablet',
        baseUrl: Uri.parse('https://192.168.1.43:6000'),
        certificateFingerprint:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await first.close();

    final database = await databaseFactoryFfiNoIsolate.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await database.execute('PRAGMA user_version = 8');
    await database.close();

    final migrated = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: databasePath,
    );
    await migrated.open();
    expect((await migrated.loadActiveServer())!.baseUrl.port, 6000);
    await migrated.close();

    final verification = await databaseFactoryFfiNoIsolate.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    addTearDown(verification.close);
    final destinations = await verification.query(
      'network_destinations',
      columns: ['id', 'base_url'],
    );
    final urls = {
      for (final row in destinations)
        row['id']! as String: Uri.parse(row['base_url']! as String),
    };
    expect(urls['server-old-port']!.port, 5119);
    expect(urls['server-custom-port']!.port, 6000);
  });

  test(
    'schema 10 gates an unprinted pending delivery after migration',
    () async {
      final repository = SqliteOrderRepository(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: databasePath,
      );
      await repository.open();
      final now = DateTime.utc(2026, 9, 25);
      await repository.savePairedServer(
        PairedServer(
          id: 'server-1',
          displayName: 'Kitchen tablet',
          baseUrl: Uri.parse('https://192.168.1.42:5119'),
          certificateFingerprint: 'a' * 64,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final draft = await repository.createDraft();
      await repository.convertDraftToTicket(
        draft.copyWith(
          lines: [TicketLine(id: createLocalId(), name: 'Tea', quantity: 1)],
        ),
        heading: 'Kitchen',
      );
      await repository.close();

      final legacy = await databaseFactoryFfiNoIsolate.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await legacy.update('server_delivery_outbox', {'status': 'pending'});
      await legacy.execute('PRAGMA user_version = 9');
      await legacy.close();

      final migrated = SqliteOrderRepository(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: databasePath,
      );
      addTearDown(migrated.close);
      await migrated.open();
      expect(
        (await migrated.loadClientDeliveries()).single.status,
        ClientDeliveryStatus.awaitingPrint,
      );
    },
  );

  test(
    'outbox interruption recovers and inbox delivery is idempotent',
    () async {
      final repository = SqliteOrderRepository(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: databasePath,
      );
      await repository.open();
      final configuration = await repository.loadNetworkConfiguration();
      await repository.close();

      final database = await databaseFactoryFfiNoIsolate.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          singleInstance: false,
          onConfigure: (database) =>
              database.execute('PRAGMA foreign_keys = ON'),
        ),
      );
      const timestamp = '2026-09-24T18:30:00.000Z';
      const checksum =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      await database.insert('network_destinations', {
        'id': 'destination-1',
        'display_name': 'Kitchen tablet',
        'base_url': 'https://192.0.2.1:8443',
        'certificate_fingerprint': checksum,
        'created_at': timestamp,
        'updated_at': timestamp,
      });
      await database.insert('server_delivery_outbox', {
        'id': 'delivery-1',
        'destination_id': 'destination-1',
        'client_installation_id': configuration.installationId,
        'ticket_id': 'ticket-1',
        'payload_json': '{}',
        'payload_checksum': checksum,
        'status': 'sending',
        'attempt_count': 1,
        'created_at': timestamp,
        'updated_at': timestamp,
      });
      await database.insert('server_clients', {
        'installation_id': 'client-1',
        'display_name': 'Front counter',
        'certificate_fingerprint':
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        'paired_at': timestamp,
      });
      final serverOrder = <String, Object?>{
        'id': 'server-order-1',
        'client_installation_id': 'client-1',
        'delivery_id': 'delivery-1',
        'client_ticket_id': 'ticket-1',
        'display_number': 7,
        'source_created_at': timestamp,
        'received_at': timestamp,
        'heading_snapshot': 'Kitchen',
        'reference_snapshot': 'Table 4',
        'order_note_snapshot': '',
        'payload_checksum': checksum,
        'status': 'received',
      };
      await database.insert('server_orders', serverOrder);
      await expectLater(
        database.insert('server_orders', {
          ...serverOrder,
          'id': 'server-order-duplicate',
        }),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        database.insert('server_order_lines', {
          'id': 'invalid-line',
          'order_id': 'server-order-1',
          'name_snapshot': 'Tea',
          'quantity': 1000,
          'preparation_note': '',
          'position': 0,
        }),
        throwsA(isA<DatabaseException>()),
      );
      await database.close();

      final recovered = SqliteOrderRepository(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: databasePath,
      );
      await recovered.open();
      await recovered.close();
      final verification = await databaseFactoryFfiNoIsolate.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(verification.close);
      final outbox = await verification.query('server_delivery_outbox');
      expect(outbox.single['status'], 'pending');
      expect(outbox.single['error_code'], 'interrupted');
      expect(await verification.query('server_orders'), hasLength(1));
    },
  );

  test(
    'schema 5, 6, 7 and 8 backups restore without replacing the local app mode',
    () async {
      final source = SqliteOrderRepository(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: databasePath,
      );
      await source.open();
      await source.saveItem(name: 'Tea');
      final snapshot = await source.createPortableSnapshot();
      final tables = snapshot['tables']! as Map<String, Object?>;
      for (final row in tables['items']! as List) {
        (row as Map<String, Object?>).remove('send_to_server');
      }
      await source.close();

      for (final version in [5, 6, 7, 8]) {
        snapshot['schemaVersion'] = version;
        final destination = SqliteOrderRepository(
          factory: databaseFactoryFfiNoIsolate,
          databasePath:
              '${temporaryDirectory.path}/destination-$version.sqlite3',
        );
        await destination.open();
        await destination.saveLibreSlipMode(LibreSlipMode.server);
        await destination.replaceWithPortableSnapshot(snapshot);

        final restoredItems = await destination.loadItems();
        expect(restoredItems, hasLength(1));
        expect(restoredItems.single.sendToServer, isTrue);
        expect(
          (await destination.loadNetworkConfiguration()).mode,
          LibreSlipMode.server,
        );
        await destination.close();
      }
    },
  );
}
