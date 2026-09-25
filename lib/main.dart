import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app/libreslip_app.dart';
import 'features/networking/application/client_delivery_controller.dart';
import 'features/networking/application/network_mode_controller.dart';
import 'features/networking/application/server_inbox_controller.dart';
import 'features/networking/data/android_server_runtime_service.dart';
import 'features/networking/data/local_https_server.dart';
import 'features/networking/data/pinned_https_client.dart';
import 'features/networking/data/secure_client_secret_store.dart';
import 'features/networking/data/secure_server_secret_store.dart';
import 'features/orders/application/order_workspace_controller.dart';
import 'features/orders/data/item_image_store.dart';
import 'features/orders/data/sqlite_order_repository.dart';
import 'features/portability/application/portability_controller.dart';
import 'features/portability/application/portability_service.dart';
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
  final settingsRepository = LocalSettingsRepository();
  final settings = SettingsController(
    settingsRepository,
    initial: AppSettings(language: language == 'it' ? 'it' : 'en'),
    logoStore: LocalTicketLogoStore(),
  );
  final repository = SqliteOrderRepository();
  final orders = OrderWorkspaceController(
    repository,
    imageStore: LocalItemImageStore(),
  );
  final networking = NetworkModeController(repository);
  final serverSecrets = SecureServerSecretStore();
  final serverInbox = ServerInboxController(
    repository,
    serverSecrets,
    LocalHttpsServer(repository, serverSecrets),
    runtimeService: const AndroidServerRuntimeService(),
  );
  final clientDelivery = ClientDeliveryController(
    repository,
    SecureClientSecretStore(),
    const PinnedHttpsClient(),
  );
  final printer = PrinterController(AndroidBluetoothPrinterTransport());
  final ticketOutput = TicketOutputController(
    store: repository,
    printer: printer,
  );
  final portability = PortabilityController(
    PortabilityService(repository, settingsRepository),
    settings,
    orders,
  );
  runApp(
    LibreSlipApp(
      settings: settings,
      orders: orders,
      networking: networking,
      serverInbox: serverInbox,
      clientDelivery: clientDelivery,
      printer: printer,
      ticketOutput: ticketOutput,
      portability: portability,
    ),
  );
  unawaited(() async {
    await repository.open();
    await portability.recoverAtStartup();
    await settings.load();
    await orders.load();
    await networking.load();
    await clientDelivery.load();
    await ticketOutput.load();
  }());
}
