import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app/libreslip_app.dart';
import 'features/orders/application/order_workspace_controller.dart';
import 'features/orders/data/item_image_store.dart';
import 'features/orders/data/sqlite_order_repository.dart';
import 'features/printing/application/printer_controller.dart';
import 'features/printing/application/ticket_output_controller.dart';
import 'features/printing/data/android_bluetooth_printer_transport.dart';
import 'features/settings/application/settings_controller.dart';
import 'features/settings/data/settings_repository.dart';
import 'features/settings/data/ticket_logo_store.dart';
import 'features/settings/domain/app_settings.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final language = binding.platformDispatcher.locale.languageCode;
  final settings = SettingsController(
    LocalSettingsRepository(),
    initial: AppSettings(language: language == 'it' ? 'it' : 'en'),
    logoStore: LocalTicketLogoStore(),
  );
  final repository = SqliteOrderRepository();
  final orders = OrderWorkspaceController(
    repository,
    imageStore: LocalItemImageStore(),
  );
  final printer = PrinterController(AndroidBluetoothPrinterTransport());
  final ticketOutput = TicketOutputController(
    store: repository,
    printer: printer,
  );
  runApp(
    LibreSlipApp(
      settings: settings,
      orders: orders,
      printer: printer,
      ticketOutput: ticketOutput,
    ),
  );
  unawaited(settings.load());
  unawaited(orders.load().then((_) => ticketOutput.load()));
}
