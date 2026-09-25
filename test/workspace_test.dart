import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
import 'package:libreslip/features/networking/application/network_mode_controller.dart';
import 'package:libreslip/features/printing/application/printer_controller.dart';
import 'package:libreslip/features/printing/application/ticket_output_controller.dart';
import 'package:libreslip/features/printing/domain/printer_transport.dart';
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
  final environment = await createMemoryOrderEnvironment();
  final orders = environment.controller;
  final networking = NetworkModeController(environment.repository);
  addTearDown(controller.dispose);
  addTearDown(orders.dispose);
  addTearDown(networking.dispose);
  await controller.load();
  await networking.load();
  await tester.pumpWidget(
    LibreSlipApp(settings: controller, orders: orders, networking: networking),
  );
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

  testWidgets('navigation opens real task 3 empty states', (tester) async {
    await openApp(tester);
    expect(find.text('Your workspace'), findsOneWidget);
    for (final (index, title) in [
      (1, 'Your item shelf is ready.'),
      (2, 'Start with an item.'),
      (3, 'No saved tickets yet.'),
    ]) {
      await tester.tap(find.byKey(ValueKey('nav-$index')));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav-0')));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Italian bottom navigation labels remain on one line', (
    tester,
  ) async {
    await openApp(
      tester,
      size: const Size(320, 740),
      scale: 2,
      settings: const AppSettings(language: 'it'),
    );
    final label = find.text('Impostazioni');
    expect(label, findsOneWidget);
    expect(tester.getSize(label).height, lessThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('optional order fields can be hidden before saving a ticket', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = SettingsController(MemorySettingsRepository());
    final environment = await createMemoryOrderEnvironment();
    final orders = environment.controller;
    final printer = PrinterController(_ConnectedWorkspaceTransport());
    final output = TicketOutputController(
      store: environment.repository,
      printer: printer,
    );
    addTearDown(settings.dispose);
    addTearDown(orders.dispose);
    addTearDown(printer.dispose);
    addTearDown(output.dispose);
    await settings.load();
    await printer.refresh();
    await output.load();
    await orders.saveItem(name: 'Toastie');
    orders.addCatalogueItem(orders.items.single);
    orders.setReference('Table 9');
    orders.setOrderNote('Together');
    orders.setPreparationNote(orders.activeDraft!.lines.single.id, 'No onion');
    await orders.flushWrites();
    await tester.pumpWidget(
      LibreSlipApp(
        settings: settings,
        orders: orders,
        printer: printer,
        ticketOutput: output,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('On this phone'), findsNothing);
    expect(find.text('Yours stays yours.'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('nav-4')));
    await tester.pumpAndSettle();
    expect(find.text('Saved on this phone'), findsNothing);
    for (final key in [
      'toggle-order-reference',
      'toggle-preparation-notes',
      'toggle-order-notes',
    ]) {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }
    expect(orders.activeDraft!.reference, 'Table 9');
    expect(orders.activeDraft!.orderNote, 'Together');
    expect(orders.activeDraft!.lines.single.preparationNote, 'No onion');

    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    expect(find.text('Table or order reference'), findsNothing);
    expect(find.text('Preparation note'), findsNothing);
    expect(find.text('Order notes'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('print-ticket')));
    await tester.pumpAndSettle();
    expect(orders.tickets, hasLength(1));
    expect(orders.tickets.single.reference, isEmpty);
    expect(orders.tickets.single.orderNote, isEmpty);
    expect(orders.tickets.single.lines.single.preparationNote, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'language switches immediately while stored content stays unchanged',
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
    final largestText = find.byKey(const ValueKey('text-scale-1.3'));
    await tester.scrollUntilVisible(
      largestText,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(largestText);
    await tester.pumpAndSettle();
    expect(controller.settings.appTextScale, 1.3);
    expect(
      MediaQuery.textScalerOf(tester.element(find.byType(Scaffold).first))
          .scale(10),
      closeTo(13, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('printed ticket font controls are bounded and persist', (
    tester,
  ) async {
    final controller = await openApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-4')));
    await tester.pumpAndSettle();
    for (final key in [
      'font-size-heading',
      'font-size-details',
      'font-size-items',
      'font-size-notes',
      'font-size-footer',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }

    final headingField = find.byKey(const ValueKey('font-size-heading'));
    await tester.ensureVisible(headingField);
    await tester.tap(
      find.descendant(
        of: headingField,
        matching: find.byType(DropdownButton<int>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('20 pt').last);
    await tester.pumpAndSettle();
    expect(controller.settings.typography.heading, 20);
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

class _ConnectedWorkspaceTransport implements PrinterTransport {
  @override
  Future<void> connect(String address) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<BluetoothHostState> getState() async => const BluetoothHostState(
    status: BluetoothHostStatus.ready,
    devices: [PairedPrinter(name: 'NT-1809DD', address: '00:11:22:33:44:55')],
    connectedAddress: '00:11:22:33:44:55',
  );

  @override
  Future<void> openBluetoothSettings() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<int> send(Uint8List bytes, {int chunkSize = 256}) async =>
      bytes.length;
}
