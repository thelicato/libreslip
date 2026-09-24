import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
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
    ]) {
      tester.view.physicalSize = size;
      final controller = SettingsController(
        MemorySettingsRepository()
          ..stored = AppSettings(language: language, themeMode: mode),
      );
      await controller.load();
      final orders = await createMemoryOrders();
      if (page >= 1 && page <= 3) {
        await orders.saveItem(
          name: 'Mushroom toastie',
          categoryName: language == 'it' ? 'Cucina' : 'Kitchen',
        );
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
          child: LibreSlipApp(settings: controller, orders: orders),
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
      controller.dispose();
      orders.dispose();
    }
  });
}
