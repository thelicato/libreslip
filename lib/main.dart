import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app/libreslip_app.dart';
import 'features/orders/application/order_workspace_controller.dart';
import 'features/orders/data/item_image_store.dart';
import 'features/orders/data/sqlite_order_repository.dart';
import 'features/settings/application/settings_controller.dart';
import 'features/settings/data/settings_repository.dart';
import 'features/settings/domain/app_settings.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final language = binding.platformDispatcher.locale.languageCode;
  final settings = SettingsController(
    LocalSettingsRepository(),
    initial: AppSettings(language: language == 'it' ? 'it' : 'en'),
  );
  final orders = OrderWorkspaceController(
    SqliteOrderRepository(),
    imageStore: LocalItemImageStore(),
  );
  runApp(LibreSlipApp(settings: settings, orders: orders));
  unawaited(settings.load());
  unawaited(orders.load());
}
