import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/settings/application/settings_controller.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';

import 'test_support.dart';

void main() {
  test('settings round trip preserves non-ASCII headings independently of language', () {
    const original = AppSettings(
      heading: 'Caffè Libertà',
      language: 'it',
      themeMode: ThemeMode.dark,
    );
    final decoded = AppSettings.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.toJson(), original.toJson());
    expect(decoded.locale, const Locale('it', 'IT'));
    expect(decoded.copyWith(language: 'en').heading, 'Caffè Libertà');
  });

  test('unknown versions and malformed settings are rejected', () {
    for (final invalid in [
      {...const AppSettings().toJson(), 'version': 2},
      {...const AppSettings().toJson(), 'language': 'fr'},
      {...const AppSettings().toJson(), 'theme': 'invalid'},
      {...const AppSettings().toJson(), 'heading': List.filled(61, 'x').join()},
      <String, dynamic>{},
    ]) {
      expect(() => AppSettings.fromJson(invalid), throwsFormatException);
    }
  });

  test(
    'first launch uses device language without creating stored data',
    () async {
      final repository = MemorySettingsRepository();
      final controller = SettingsController(
        repository,
        initial: const AppSettings(language: 'it'),
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.loaded, isTrue);
      expect(controller.settings.language, 'it');
      expect(repository.writes, 0);
    },
  );

  test('preferences survive creation of a new controller', () async {
    final repository = MemorySettingsRepository();
    final first = SettingsController(repository);
    await first.load();
    await first.update(
      first.settings.copyWith(
        heading: 'Corner & Co.',
        language: 'it',
        themeMode: ThemeMode.dark,
      ),
    );
    first.dispose();
    final next = SettingsController(repository);
    addTearDown(next.dispose);
    await next.load();
    expect(next.settings.heading, 'Corner & Co.');
    expect(next.settings.language, 'it');
    expect(next.settings.themeMode, ThemeMode.dark);
  });

  test('a failed read neither overwrites data nor enables editing, and can recover', () async {
    final repository = MemorySettingsRepository()
      ..stored = const AppSettings(heading: 'Existing shop')
      ..failLoad = true;
    final controller = SettingsController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.loadFailed, isTrue);
    expect(controller.loaded, isFalse);
    expect(await controller.update(const AppSettings()), isFalse);
    expect(repository.writes, 0);
    repository.failLoad = false;
    await controller.load();
    expect(controller.settings.heading, 'Existing shop');
    expect(controller.loadFailed, isFalse);
  });

  test('failed saves leave visible and stored preferences unchanged', () async {
    final repository = MemorySettingsRepository()
      ..stored = const AppSettings(heading: 'Caffè Libertà');
    final controller = SettingsController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    repository.failSave = true;
    expect(
      await controller.update(controller.settings.copyWith(language: 'it')),
      isFalse,
    );
    expect(controller.settings.language, 'en');
    expect(repository.stored!.language, 'en');
    expect(controller.saveFailed, isTrue);
    repository.failSave = false;
    expect(
      await controller.update(controller.settings.copyWith(language: 'it')),
      isTrue,
    );
    expect(controller.settings.heading, 'Caffè Libertà');
    expect(controller.saveFailed, isFalse);
  });

  test('overlapping saves cannot race and commit stale settings', () async {
    final repository = MemorySettingsRepository()..saveGate = Completer<void>();
    final controller = SettingsController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    final first = controller.update(
      controller.settings.copyWith(language: 'it'),
    );
    expect(controller.saving, isTrue);
    expect(
      await controller.update(
        controller.settings.copyWith(heading: 'Another heading'),
      ),
      isFalse,
    );
    repository.saveGate!.complete();
    expect(await first, isTrue);
    expect(repository.writes, 1);
    expect(controller.settings.language, 'it');
    expect(controller.settings.heading, '');
  });
}
