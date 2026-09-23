import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
import 'package:libreslip/features/orders/application/order_workspace_controller.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:libreslip/features/printing/domain/print_job.dart';
import 'package:libreslip/features/settings/application/settings_controller.dart';
import 'package:libreslip/features/settings/data/settings_repository.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android stores and reloads local preferences without an account',
    (tester) async {
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
      await orders.load();
      addTearDown(() async {
        await orderRepository.close();
        await deleteDatabase(databasePath);
      });
      await controller.load();
      await tester.pumpWidget(
        LibreSlipApp(settings: controller, orders: orders),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your workspace'), findsOneWidget);
      await controller.update(
        const AppSettings(
          heading: 'Bottega Libertà',
          language: 'it',
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();
      await orders.saveItem(name: 'Pane tostato');
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
      final restored = await LocalSettingsRepository().load();
      expect(restored!.heading, 'Bottega Libertà');
      expect(restored.language, 'it');
      expect(restored.themeMode, ThemeMode.dark);
      await tester.pumpWidget(const SizedBox.shrink());
      await orderRepository.close();
      final reopenedRepository = SqliteOrderRepository(
        databasePath: databasePath,
      );
      await reopenedRepository.open();
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
      expect(await reopenedRepository.loadTickets(), hasLength(1));
      await reopenedRepository.close();
      controller.dispose();
      orders.dispose();
    },
  );
}
