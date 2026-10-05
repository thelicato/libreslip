import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/core/theme/app_theme.dart';
import 'package:libreslip/features/orders/presentation/managed_order_composer.dart';
import 'package:libreslip/l10n/generated/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'shared_orders_test.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
  for (final (language, size, scale, brightness) in [
    ('en', const Size(1100, 900), 1.0, Brightness.light),
    ('it', const Size(320, 740), 2.0, Brightness.light),
    ('en', const Size(915, 412), 1.0, Brightness.dark),
  ]) {
    testWidgets(
      'shared Active orders and conflict recovery remain reachable $language $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const capture = bool.fromEnvironment('LIBRESLIP_CAPTURE_PREVIEWS');
        if (capture) await _fonts();
        final f = await SharedFixture.create();
        addTearDown(f.dispose);
        await f.seed();
        await f.syncBoth();
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: Locale(language, language == 'it' ? 'IT' : 'GB'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.build(brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: ListenableBuilder(
                        listenable: f.b.workspace,
                        builder: (context, _) => ManagedOrderComposer(
                          controller: f.b.workspace,
                          delivery: f.b.delivery,
                          sharedOrders: f.b.sync,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final active = find.byKey(const ValueKey('active-orders'));
        await tester.ensureVisible(active);
        await tester.tap(active);
        await tester.pumpAndSettle();
        expect(find.textContaining('Kitchen Server'), findsOneWidget);
        if (capture) {
          await _capture(
            tester,
            boundary,
            'shared-orders-$language-${size.width.toInt()}',
          );
        }
        await f.b.local('soup', 1);
        await f.a.local('soup', 2);
        await f.a.sync.synchronise();
        await f.b.sync.synchronise();
        await tester.pumpAndSettle();
        final expansion = find.byType(ExpansionTile).last;
        await tester.ensureVisible(expansion);
        await tester.tap(expansion);
        await tester.pumpAndSettle();
        final choice = find.byKey(
          ValueKey('shared-use-server-${f.b.order.id}'),
        );
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        expect(choice, findsOneWidget);
        expect(find.textContaining('Soup:'), findsOneWidget);
        if (capture) {
          await _capture(
            tester,
            boundary,
            'shared-conflict-$language-${size.width.toInt()}',
          );
        }
        await tester.tap(choice);
        await tester.pumpAndSettle();
        expect(f.b.order.deliveredQuantity('soup'), 2);
        expect(f.b.sync.conflicts, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'foreground automatic sharing pauses on background and resumes without a manual action',
    (tester) async {
      final f = await SharedFixture.create();
      addTearDown(f.dispose);
      await f.seed();
      f.b.sync.dispose();
      f.b.newSynchroniser(f.transport, interval: const Duration(seconds: 5));
      await f.b.sync.start();
      f.b.sync.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 1));
      expect(f.b.workspace.managedOrders, isEmpty);
      f.b.sync.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(f.b.workspace.managedOrders, hasLength(1));
      final remote = (await f.server.loadServerOrders()).single;
      await f.server.setServerLineDelivered(
        remote.id,
        'soup',
        2,
        expectedQuantity: 0,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(f.b.order.deliveredQuantity('soup'), 2);
      await f.b.local('soup', 1);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(
        (await f.server.loadServerOrders())
            .single
            .lines
            .first
            .deliveredQuantity,
        1,
      );
      expect(tester.takeException(), isNull);
      f.b.sync.dispose();
      f.b.newSynchroniser(f.transport);
    },
  );
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  expect(tester.takeException(), isNull);
  await tester.runAsync(() async {
    final render =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/previews/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _fonts() async {
  final configFile = File('.dart_tool/package_config.json').absolute;
  final config =
      jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final package = (config['packages'] as List)
      .cast<Map<String, dynamic>>()
      .singleWhere((p) => p['name'] == 'flutter');
  final root = configFile.uri.resolve(package['rootUri'] as String);
  final fonts = Directory.fromUri(root).uri
      .resolve('../../bin/cache/artifacts/material_fonts/');
  final loader = FontLoader('Roboto');
  for (final name in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    loader.addFont(
      Future.value(
        ByteData.sublistView(
          File.fromUri(fonts.resolve(name)).readAsBytesSync(),
        ),
      ),
    );
  }
  await loader.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File.fromUri(fonts.resolve('MaterialIcons-Regular.otf'))
              .readAsBytesSync(),
        ),
      ),
    );
  await icons.load();
}
