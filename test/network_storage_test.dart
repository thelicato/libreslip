import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/networking/domain/network_models.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
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
    'schema 5, 6 and 7 backups restore without replacing the local app mode',
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

      for (final version in [5, 6, 7]) {
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
