import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
import 'package:libreslip/features/settings/application/settings_controller.dart';
import 'package:libreslip/features/settings/data/settings_repository.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      await controller.load();
      await tester.pumpWidget(LibreSlipApp(settings: controller));
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
      final restored = await LocalSettingsRepository().load();
      expect(restored!.heading, 'Bottega Libertà');
      expect(restored.language, 'it');
      expect(restored.themeMode, ThemeMode.dark);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
