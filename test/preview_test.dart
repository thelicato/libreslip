import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
import 'package:libreslip/features/portability/application/portability_controller.dart';
import 'package:libreslip/features/portability/application/portability_service.dart';
import 'package:libreslip/features/printing/application/printer_controller.dart';
import 'package:libreslip/features/printing/domain/printer_transport.dart';
import 'package:libreslip/features/printing/domain/ticket_typography.dart';
import 'package:libreslip/features/settings/application/settings_controller.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';

import 'test_support.dart';

/// Opt-in render capture for review, without committing platform-sensitive goldens.
void main() {
  const capture = bool.fromEnvironment('LIBRESLIP_CAPTURE_PREVIEWS');
  testWidgets('capture representative workspace renders', skip: !capture, (
    tester,
  ) async {
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config =
        jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    final flutter = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((package) => package['name'] == 'flutter');
    final package = configFile.uri.resolve(flutter['rootUri'] as String);
    final fonts = Directory.fromUri(package).uri
        .resolve('../../bin/cache/artifacts/material_fonts/');
    final loader = FontLoader('Roboto');
    for (final font in [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]) {
      final bytes = File.fromUri(fonts.resolve(font)).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
    final ticketLoader = FontLoader('RobotoTicket');
    for (final font in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
      final bytes = File.fromUri(fonts.resolve(font)).readAsBytesSync();
      ticketLoader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await ticketLoader.load();
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File.fromUri(fonts.resolve('MaterialIcons-Regular.otf'))
                .readAsBytesSync(),
          ),
        ),
      );
    await iconLoader.load();
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final (name, size, language, mode, page) in [
      ('phone-en', const Size(412, 915), 'en', ThemeMode.light, 0),
      (
        'overview-dashboard-phone-it',
        const Size(520, 1200),
        'it',
        ThemeMode.light,
        0,
      ),
      ('tablet-en', const Size(1440, 1000), 'en', ThemeMode.light, 0),
      ('compose-phone-en', const Size(520, 1200), 'en', ThemeMode.light, 2),
      ('items-tablet-it', const Size(1100, 1000), 'it', ThemeMode.dark, 1),
      ('tickets-tablet-en', const Size(1100, 1000), 'en', ThemeMode.light, 3),
      (
        'ticket-preview-phone-it',
        const Size(520, 1200),
        'it',
        ThemeMode.light,
        3,
      ),
      ('settings-it-dark', const Size(1000, 1300), 'it', ThemeMode.dark, 4),
      ('portability-phone-en', const Size(520, 1100), 'en', ThemeMode.light, 4),
    ]) {
      tester.view.physicalSize = size;
      final settingsStore = MemorySettingsRepository()
        ..stored = AppSettings(
          language: language,
          themeMode: mode,
          typography: name == 'ticket-preview-phone-it'
              ? const TicketTypography(
                  heading: 20,
                  details: 10,
                  items: 12,
                  notes: 9,
                  footer: 11,
                )
              : const TicketTypography(),
        );
      final controller = SettingsController(settingsStore);
      await controller.load();
      final environment = await createMemoryOrderEnvironment();
      final orders = environment.controller;
      final portability = PortabilityController(
        PortabilityService(environment.repository, settingsStore),
        controller,
        orders,
      );
      final printer = PrinterController(_PreviewPrinterTransport());
      if (page >= 1 && page <= 3) {
        await orders.saveItem(
          name: 'Mushroom toastie',
          categoryName: language == 'it' ? 'Cucina' : 'Kitchen',
        );
      }
      if (name == 'overview-dashboard-phone-it') {
        await orders.saveItem(name: 'Toast ai funghi', categoryName: 'Cucina');
        orders.addCatalogueItem(orders.items.single);
        orders.setQuantity(orders.activeDraft!.lines.single.id, 3);
        await orders.flushWrites();
        await orders.saveActiveTicket(heading: 'Bottega Libertà');
      }
      if (page == 2 || page == 3) {
        orders.addCatalogueItem(orders.items.single);
        orders.setReference(language == 'it' ? 'Tavolo 4' : 'Table 4');
        orders.setOrderNote(
          language == 'it' ? 'Portare insieme' : 'Bring together',
        );
        await orders.flushWrites();
      }
      if (page == 3) {
        await orders.saveActiveTicket(heading: 'Corner & Co.');
      }
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: LibreSlipApp(
            settings: controller,
            orders: orders,
            printer: printer,
            portability: portability,
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (page != 0) {
        await tester.tap(find.byKey(ValueKey('nav-$page')));
        await tester.pumpAndSettle();
      }
      if (name == 'ticket-preview-phone-it') {
        await tester.tap(find.text('Comanda 1'));
        await tester.pumpAndSettle();
      }
      if (name == 'overview-dashboard-phone-it') {
        await tester.drag(
          find.byKey(const ValueKey('page-0')),
          const Offset(0, -760),
        );
        await tester.pumpAndSettle();
      }
      if (name == 'portability-phone-en') {
        await tester.drag(
          find.byKey(const ValueKey('page-4')),
          const Offset(0, -2600),
        );
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/previews/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
      portability.dispose();
      printer.dispose();
      controller.dispose();
      orders.dispose();
    }
  });
}

class _PreviewPrinterTransport implements PrinterTransport {
  @override
  Future<void> connect(String address) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<BluetoothHostState> getState() async => const BluetoothHostState(
    status: BluetoothHostStatus.ready,
    devices: [
      PairedPrinter(name: 'NETUM NT-1809DD', address: '00:11:22:33:44:55'),
    ],
  );

  @override
  Future<void> openBluetoothSettings() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<int> send(Uint8List bytes, {int chunkSize = 256}) async =>
      bytes.length;
}
