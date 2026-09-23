import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app/libreslip_app.dart';
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
  runApp(LibreSlipApp(settings: settings));
  unawaited(settings.load());
}
