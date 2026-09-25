import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/printing/domain/ticket_typography.dart';
import 'package:libreslip/features/settings/application/settings_controller.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';

import 'test_support.dart';

void main() {
  test('settings round trip preserves non-ASCII headings independently of language', () {
    const original = AppSettings(
      heading: 'Caffè Libertà',
      footer: 'Preparato con cura',
      logoPath: '/private/ticket-logo.png',
      typography: TicketTypography(
        heading: 20,
        details: 10,
        items: 12,
        notes: 9,
        footer: 11,
      ),
      language: 'it',
      themeMode: ThemeMode.dark,
      appTextScale: 1.3,
      preferredPrinterAddress: '00:11:22:33:44:55',
    );
    final decoded = AppSettings.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.toJson(), original.toJson());
    expect(decoded.locale, const Locale('it', 'IT'));
    expect(decoded.copyWith(language: 'en').heading, 'Caffè Libertà');
    expect(decoded.footer, 'Preparato con cura');
    expect(decoded.logoPath, '/private/ticket-logo.png');
    expect(decoded.typography.heading, 20);
    expect(decoded.typography.details, 10);
    expect(decoded.typography.items, 12);
    expect(decoded.typography.notes, 9);
    expect(decoded.typography.footer, 11);
    expect(decoded.appTextScale, 1.3);
    expect(decoded.preferredPrinterAddress, '00:11:22:33:44:55');
    expect(
      decoded.copyWith(clearPreferredPrinter: true).preferredPrinterAddress,
      isNull,
    );
  });

  test('version 1 preferences migrate with an empty footer and no logo', () {
    final legacy = AppSettings.fromJson({
      'version': 1,
      'heading': 'Corner & Co.',
      'language': 'en',
      'theme': 'system',
    });
    expect(legacy.footer, isEmpty);
    expect(legacy.logoPath, isNull);
    expect(legacy.typography.toJson(), const TicketTypography().toJson());
  });

  test('version 2 preferences migrate with default ticket typography', () {
    final legacy = AppSettings.fromJson({
      'version': 2,
      'heading': 'Corner & Co.',
      'footer': 'Thank you',
      'logoPath': null,
      'language': 'en',
      'theme': 'system',
    });
    expect(legacy.typography.toJson(), const TicketTypography().toJson());
  });

  test('version 3 preferences migrate with the default app text size', () {
    final legacy = AppSettings.fromJson({
      'version': 3,
      'heading': 'Corner & Co.',
      'footer': 'Thank you',
      'logoPath': null,
      'typography': const TicketTypography().toJson(),
      'language': 'en',
      'theme': 'system',
    });
    expect(legacy.appTextScale, AppSettings.defaultAppTextScale);
  });

  test('version 4 preferences migrate without a preferred printer', () {
    final legacy = AppSettings.fromJson(
      {...const AppSettings().toJson(), 'version': 4}
        ..remove('preferredPrinterAddress'),
    );
    expect(legacy.preferredPrinterAddress, isNull);
  });

  test('app text scaling enforces hard minimum and maximum sizes', () {
    for (final scale in [0.99, 1.31, double.nan]) {
      expect(
        () => AppSettings.fromJson({
          ...const AppSettings().toJson(),
          'appTextScale': scale,
        }),
        throwsFormatException,
      );
    }
  });

  test('ticket typography enforces hard minimum and maximum sizes', () {
    expect(
      () => TicketTypography.fromJson({
        ...const TicketTypography().toJson(),
        'heading': TicketTypography.maxHeading + 1,
      }),
      throwsFormatException,
    );
    expect(
      () => TicketTypography.fromJson({
        ...const TicketTypography().toJson(),
        'notes': TicketTypography.minNotes - 1,
      }),
      throwsFormatException,
    );
  });

  test('unknown versions and malformed settings are rejected', () {
    for (final invalid in [
      {...const AppSettings().toJson(), 'version': 6},
      {...const AppSettings().toJson()}..remove('typography'),
      {...const AppSettings().toJson(), 'language': 'fr'},
      {...const AppSettings().toJson(), 'theme': 'invalid'},
      {...const AppSettings().toJson(), 'heading': List.filled(61, 'x').join()},
      {...const AppSettings().toJson(), 'preferredPrinterAddress': ''},
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
        appTextScale: 1.15,
      ),
    );
    first.dispose();
    final next = SettingsController(repository);
    addTearDown(next.dispose);
    await next.load();
    expect(next.settings.heading, 'Corner & Co.');
    expect(next.settings.language, 'it');
    expect(next.settings.themeMode, ThemeMode.dark);
    expect(next.settings.appTextScale, 1.15);
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
