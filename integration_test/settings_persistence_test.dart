import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
import 'package:libreslip/features/networking/application/network_mode_controller.dart';
import 'package:libreslip/features/networking/domain/network_models.dart';
import 'package:libreslip/features/orders/application/order_workspace_controller.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:libreslip/features/printing/domain/print_job.dart';
import 'package:libreslip/features/printing/domain/ticket_typography.dart';
import 'package:libreslip/features/portability/application/portability_service.dart';
import 'package:libreslip/features/portability/domain/portability_models.dart';
import 'package:libreslip/features/settings/application/settings_controller.dart';
import 'package:libreslip/features/settings/data/settings_repository.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android recovers local state and restores a full backup', (
    tester,
  ) async {
    final preferences = SharedPreferencesAsync();
    final original = await preferences.getString(
      LocalSettingsRepository.storageKey,
    );
    addTearDown(() async {
      if (original == null) {
        await preferences.remove(LocalSettingsRepository.storageKey);
      } else {
        await preferences.setString(
          LocalSettingsRepository.storageKey,
          original,
        );
      }
    });
    await preferences.remove(LocalSettingsRepository.storageKey);
    final controller = SettingsController(LocalSettingsRepository());
    final databasePath = p.join(
      await getDatabasesPath(),
      'libreslip-settings-integration.sqlite3',
    );
    await deleteDatabase(databasePath);
    final orderRepository = SqliteOrderRepository(databasePath: databasePath);
    final orders = OrderWorkspaceController(orderRepository);
    final networking = NetworkModeController(orderRepository);
    await orders.load();
    await networking.load();
    addTearDown(() async {
      await orderRepository.close();
      await deleteDatabase(databasePath);
    });
    await controller.load();
    await tester.pumpWidget(
      LibreSlipApp(
        settings: controller,
        orders: orders,
        networking: networking,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your workspace'), findsOneWidget);
    await controller.update(
      const AppSettings(
        heading: 'Bottega Libertà',
        language: 'it',
        themeMode: ThemeMode.dark,
        typography: TicketTypography(
          heading: 20,
          details: 10,
          items: 12,
          notes: 9,
          footer: 11,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await orders.saveItem(name: 'Pane tostato');
    await orders.updateFeatureSettings(
      const OrderFeatureSettings(preparationNotesEnabled: false),
    );
    orders.addCatalogueItem(orders.items.single);
    orders.setReference('Tavolo 9');
    orders.setOrderNote('Senza cipolla');
    await orders.flushWrites();
    final draftId = orders.activeDraft!.id;
    final printDraft = await orderRepository.createDraft();
    final printable = printDraft.copyWith(
      updatedAt: DateTime.now().toUtc(),
      lines: [
        TicketLine(id: createLocalId(), name: 'Caffè lungo', quantity: 2),
      ],
    );
    final ticket = await orderRepository.convertDraftToTicket(
      printable,
      heading: 'Bottega Libertà',
    );
    expect(ticket.number, 1);
    expect(await orderRepository.loadNextOrderNumber(), 2);
    await orderRepository.resetOrderNumber();
    final restartedDraft = await orderRepository.createDraft();
    final restartedTicket = await orderRepository.convertDraftToTicket(
      restartedDraft.copyWith(
        updatedAt: DateTime.now().toUtc(),
        lines: [TicketLine(id: createLocalId(), name: 'Tè verde', quantity: 1)],
      ),
      heading: 'Bottega Libertà',
    );
    expect(restartedTicket.number, 1);
    expect(restartedTicket.id, isNot(ticket.id));
    final job = await orderRepository.createPrintJob(
      requestId: 'android-interrupted-print',
      ticketId: ticket.id,
      payload: Uint8List.fromList([0x1B, 0x40, 0x0A]),
    );
    await orderRepository.markPrintJobSending(
      job.id,
      printerAddress: '00:11:22:33:44:55',
      printerName: 'NT-1809DD',
    );
    expect(await networking.setMode(LibreSlipMode.server), isTrue);
    final restored = await LocalSettingsRepository().load();
    expect(restored!.heading, 'Bottega Libertà');
    expect(restored.language, 'it');
    expect(restored.themeMode, ThemeMode.dark);
    expect(restored.typography.heading, 20);
    expect(restored.typography.details, 10);
    expect(restored.typography.items, 12);
    expect(restored.typography.notes, 9);
    expect(restored.typography.footer, 11);
    await tester.pumpWidget(const SizedBox.shrink());
    await orderRepository.close();
    final reopenedRepository = SqliteOrderRepository(
      databasePath: databasePath,
    );
    await reopenedRepository.open();
    final reopenedNetworking = NetworkModeController(reopenedRepository);
    await reopenedNetworking.load();
    expect(reopenedNetworking.mode, LibreSlipMode.server);
    expect(
      reopenedNetworking.configuration!.installationId,
      networking.configuration!.installationId,
    );
    final recoveredDrafts = await reopenedRepository.loadDrafts();
    expect(recoveredDrafts.single.id, draftId);
    expect(recoveredDrafts.single.reference, 'Tavolo 9');
    expect(recoveredDrafts.single.orderNote, 'Senza cipolla');
    expect(recoveredDrafts.single.lines.single.name, 'Pane tostato');
    final recoveredJobs = await reopenedRepository.loadPrintJobs(
      ticketId: ticket.id,
    );
    expect(recoveredJobs.single.status, PrintJobStatus.uncertain);
    expect(recoveredJobs.single.errorCode, 'interrupted');
    expect(await reopenedRepository.loadTickets(), hasLength(2));
    expect(await reopenedRepository.loadNextOrderNumber(), 2);

    final temporaryRoot = Directory(
      p.join(
        (await getTemporaryDirectory()).path,
        'libreslip-android-backup-integration',
      ),
    );
    if (await temporaryRoot.exists()) {
      await temporaryRoot.delete(recursive: true);
    }
    await temporaryRoot.create(recursive: true);
    addTearDown(() async {
      if (await temporaryRoot.exists()) {
        await temporaryRoot.delete(recursive: true);
      }
    });
    final sourceService = PortabilityService(
      reopenedRepository,
      LocalSettingsRepository(),
      supportDirectory: () async =>
          Directory(p.join(temporaryRoot.path, 'source-support'))
            ..createSync(recursive: true),
      temporaryDirectory: () async => temporaryRoot,
    );
    final archive = await sourceService.createArchive(
      PortableArchiveKind.fullBackup,
    );
    final preview = await sourceService.inspectArchive(archive);
    expect(preview.appVersion, (await rootBundle.loadString('VERSION')).trim());
    expect(preview.itemCount, 1);
    expect(preview.draftCount, 1);
    expect(preview.ticketCount, 2);
    expect(preview.printJobCount, 1);

    final freshPath = p.join(temporaryRoot.path, 'fresh.sqlite3');
    final freshRepository = SqliteOrderRepository(databasePath: freshPath);
    await freshRepository.open();
    addTearDown(freshRepository.close);
    final freshSettings = _MemorySettingsRepository();
    final destinationService = PortabilityService(
      freshRepository,
      freshSettings,
      supportDirectory: () async =>
          Directory(p.join(temporaryRoot.path, 'destination-support'))
            ..createSync(recursive: true),
      temporaryDirectory: () async => temporaryRoot,
    );
    await destinationService.restore(preview);

    expect(freshSettings.stored!.heading, 'Bottega Libertà');
    expect(freshSettings.stored!.language, 'it');
    expect(freshSettings.stored!.themeMode, ThemeMode.dark);
    expect(freshSettings.stored!.typography.heading, 20);
    expect(await freshRepository.loadItems(), hasLength(1));
    expect(await freshRepository.loadDrafts(), hasLength(1));
    expect(await freshRepository.loadTickets(), hasLength(2));
    expect(await freshRepository.loadPrintJobs(), hasLength(1));
    expect(await freshRepository.loadNextOrderNumber(), 2);
    expect(
      (await freshRepository.loadNetworkConfiguration()).mode,
      LibreSlipMode.client,
    );
    expect(
      (await freshRepository.loadFeatureSettings()).preparationNotesEnabled,
      isFalse,
    );
    await reopenedRepository.close();
    reopenedNetworking.dispose();
    networking.dispose();
    controller.dispose();
    orders.dispose();
  });
}

class _MemorySettingsRepository implements SettingsRepository {
  AppSettings? stored = const AppSettings();

  @override
  Future<AppSettings?> load() async => stored;

  @override
  Future<void> save(AppSettings settings) async {
    stored = settings;
  }
}
