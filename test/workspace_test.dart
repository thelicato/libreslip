import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
import 'package:libreslip/features/settings/application/settings_controller.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';

import 'test_support.dart';

Future<SettingsController> openApp(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(),
  Size size = const Size(412, 915),
  double scale = 1,
  MemorySettingsRepository? repository,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final store = repository ?? (MemorySettingsRepository()..stored = settings);
  final controller = SettingsController(store);
  addTearDown(controller.dispose);
  await controller.load();
  await tester.pumpWidget(LibreSlipApp(settings: controller));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  test(
    'all English strings have Italian translations and matching placeholders',
    () {
      final en = jsonDecode(
        File('lib/l10n/app_en.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      final it = jsonDecode(
        File('lib/l10n/app_it.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(en.keys.toSet(), it.keys.toSet());
      for (final key in en.keys.where(
        (key) => key.startsWith('@') && key != '@@locale',
      )) {
        expect(it[key], en[key]);
      }
    },
  );

  testWidgets('navigation opens honest empty states and returns to overview', (
    tester,
  ) async {
    await openApp(tester);
    expect(find.text('Your workspace'), findsOneWidget);
    for (final (index, title) in [
      (1, 'A place for every detail.'),
      (2, 'Your favourites, close to hand.'),
      (3, 'Every order has a story.'),
    ]) {
      await tester.tap(find.byKey(ValueKey('nav-$index')));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      expect(find.text('Workspace preview'), findsOneWidget);
      await tester.tap(find.text('Back to overview'));
      await tester.pumpAndSettle();
      expect(find.text('Your workspace'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'language switches immediately while the ticket heading stays unchanged',
    (tester) async {
      final controller = await openApp(
        tester,
        settings: const AppSettings(heading: 'Caffè Libertà'),
      );
      await tester.tap(find.byKey(const ValueKey('nav-4')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('language-it')));
      await tester.tap(find.byKey(const ValueKey('language-it')));
      await tester.pumpAndSettle();
      expect(find.text('Lingua'), findsOneWidget);
      expect(controller.settings.heading, 'Caffè Libertà');
      final context = tester.element(find.byType(Scaffold).first);
      expect(Localizations.localeOf(context), const Locale('it', 'IT'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ticket heading validation, save and theme selection work', (
    tester,
  ) async {
    final controller = await openApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-heading')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('heading-input')), '   ');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a heading.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('heading-input')),
      '  Caffè Libertà  ',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(controller.settings.heading, 'Caffè Libertà');
    await tester.ensureVisible(find.byKey(const ValueKey('theme-dark')));
    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'storage failure displays retry instead of an editable workspace',
    (tester) async {
      final repository = MemorySettingsRepository()..failLoad = true;
      await openApp(tester, repository: repository);
      expect(find.text('Your workspace needs a moment'), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-4')), findsNothing);
      repository.failLoad = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Your workspace'), findsOneWidget);
    },
  );

  testWidgets('save failure is visible and preserves language', (tester) async {
    final repository = MemorySettingsRepository()..failSave = true;
    final controller = await openApp(tester, repository: repository);
    await tester.tap(find.byKey(const ValueKey('nav-4')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('language-it')));
    await tester.tap(find.byKey(const ValueKey('language-it')));
    await tester.pumpAndSettle();
    expect(controller.settings.language, 'en');
    expect(
      find.textContaining('Your changes could not be saved'),
      findsWidgets,
    );
  });

  for (final (name, size, scale) in [
    ('small phone', const Size(320, 740), 1.0),
    ('landscape', const Size(915, 412), 1.0),
    ('tablet', const Size(1280, 900), 1.0),
    ('large text', const Size(412, 915), 2.0),
  ]) {
    for (final language in ['en', 'it']) {
      testWidgets('$name in $language has no layout errors on any page', (
        tester,
      ) async {
        await openApp(
          tester,
          size: size,
          scale: scale,
          settings: AppSettings(language: language),
        );
        expect(tester.takeException(), isNull);
        for (var index = 1; index < 5; index++) {
          await tester.tap(find.byKey(ValueKey('nav-$index')));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Navigation page $index',
          );
          final scroll = find.byKey(ValueKey('page-$index'));
          await tester.drag(scroll, const Offset(0, -1800));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Scrolled page $index',
          );
        }
      });
    }
  }
}
