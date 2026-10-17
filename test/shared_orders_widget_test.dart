import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/core/theme/app_theme.dart';
import 'package:libreslip/features/orders/presentation/managed_order_composer.dart';
import 'package:libreslip/features/orders/presentation/compose_page.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
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
                        builder: (context, _) => OpenOrdersPanel(
                          onOpenCompose: () {},
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
        final active = find.byKey(ValueKey('view-order-${f.b.order.id}'));
        await tester.ensureVisible(active);
        await tester.tap(active);
        await tester.pumpAndSettle();
        expect(find.text('Kitchen Server'), findsOneWidget);
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

  for (final (language, size, scale, compact) in [
    ('en', const Size(1100, 900), 1.0, false),
    ('it', const Size(320, 740), 2.0, true),
    ('en', const Size(915, 412), 1.0, true),
  ]) {
    testWidgets(
      'one order editor shows all phases and moves saved and new items $language $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const capture = bool.fromEnvironment('LIBRESLIP_CAPTURE_PREVIEWS');
        if (capture) await _fonts();
        final f = await SharedFixture.create();
        addTearDown(f.dispose);
        final divider = OrderCourse.divider(id: 'widget-phase', ordinal: 1);
        await f.seed(courses: [divider], soupNote: 'No salt');
        await f.syncBoth();
        await f.a.workspace.saveItem(name: 'Juice');
        final juice = f.a.workspace.items.firstWhere((i) => i.name == 'Juice');
        final printing = ValueNotifier(false);
        addTearDown(printing.dispose);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: Locale(language, language == 'it' ? 'IT' : 'GB'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.build(
                size.width == 915 ? Brightness.dark : Brightness.light,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ListenableBuilder(
                        listenable: f.a.workspace,
                        builder: (context, _) =>
                            f.a.workspace.editingOrder == null
                            ? OpenOrdersPanel(
                                onOpenCompose: () {},
                                controller: f.a.workspace,
                                delivery: f.a.delivery,
                                sharedOrders: f.a.sync,
                              )
                            : ComposePage(
                                controller: f.a.workspace,
                                settings: AppSettings(compactCompose: compact),
                                printing: printing,
                                delivery: f.a.delivery,
                                sharedOrders: f.a.sync,
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
        final edit = find.byKey(ValueKey('edit-order-${f.a.order.id}'));
        await tester.ensureVisible(edit);
        await tester.pumpAndSettle();
        await tester.tap(edit);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('addition-phase-selector')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('previously-ordered')), findsNothing);
        expect(find.byKey(const ValueKey('order-line-soup')), findsOneWidget);
        expect(find.byKey(const ValueKey('order-line-water')), findsOneWidget);
        final down = find.byKey(const ValueKey('line-below-divider-soup'));
        await tester.ensureVisible(down);
        await tester.pumpAndSettle();
        if (capture) {
          await _capture(
            tester,
            boundary,
            'unified-order-editor-$language-${size.width.toInt()}',
          );
        }
        await tester.tap(down);
        await tester.pumpAndSettle();
        expect(f.a.order.lines.first.courseId, divider.id);
        await f.b.sync.synchronise();
        expect(f.b.order.lines.first.courseId, divider.id);
        expect(f.a.workspace.tickets.single.lines.first.courseId, divider.id);
        // A button captured before another Client's move must not overwrite it.
        final staleUp = tester
            .widget<IconButton>(
              find.byKey(const ValueKey('line-above-divider-soup')),
            )
            .onPressed!;
        expect(await f.b.workspace.beginAddition(f.b.order.id), isTrue);
        expect(f.b.workspace.addDivider(), isTrue);
        final remotePhase = f.b.workspace.activeDraft!.courses.last.id;
        await f.b.sync.moveLine(f.b.order, 'soup', remotePhase);
        await f.a.sync.synchronise();
        final writes = f.transport.phaseWrites;
        staleUp();
        await tester.pumpAndSettle();
        expect(f.transport.phaseWrites, writes);
        expect(f.a.order.lines.first.courseId, remotePhase);
        // Dismiss the expected stale-action notice before reviewing additions.
        ScaffoldMessenger.of(tester.element(find.byType(ComposePage)))
            .removeCurrentSnackBar();
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('add-in-phase-first')), findsNothing);
        final increment = find.byKey(ValueKey('compose-item-${juice.id}'));
        await tester.ensureVisible(increment);
        await tester.pumpAndSettle();
        if (capture) {
          await _capture(
            tester,
            boundary,
            'main-catalogue-$language-${size.width.toInt()}',
          );
        }
        await tester.tap(increment);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(f.a.workspace.activeDraft!.lines.single.courseId, remotePhase);
        final added = f.a.workspace.activeDraft!.lines.single;
        final up = find.byKey(ValueKey('line-above-divider-${added.id}'));
        await tester.ensureVisible(up);
        await tester.pumpAndSettle();
        await tester.tap(up);
        await tester.pumpAndSettle();
        expect(f.a.workspace.activeDraft!.lines.single.courseId, divider.id);
        await tester.ensureVisible(up);
        await tester.pumpAndSettle();
        await tester.tap(up);
        await tester.pumpAndSettle();
        expect(f.a.workspace.activeDraft!.lines.single.courseId, isNull);
        final move = find.byKey(ValueKey('line-below-divider-${added.id}'));
        await tester.ensureVisible(move);
        await tester.pumpAndSettle();
        await tester.tap(move);
        await tester.pumpAndSettle();
        expect(f.a.workspace.activeDraft!.lines.single.courseId, divider.id);
        expect(find.byKey(ValueKey('order-line-${added.id}')), findsOneWidget);
        for (final (key, count) in [
          ('line-plus-water', 3),
          ('line-minus-water', 2),
        ]) {
          final button = find.byKey(ValueKey(key));
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(
            f.a.order.lines.singleWhere((l) => l.id == 'water').quantity,
            count,
          );
        }
        final remove = find.byKey(const ValueKey('remove-line-water'));
        await tester.ensureVisible(remove);
        await tester.pumpAndSettle();
        await tester.tap(remove);
        await tester.pumpAndSettle();
        expect(f.a.order.lines.any((l) => l.id == 'water'), isFalse);
        await f.b.sync.synchronise();
        await tester.pumpAndSettle();
        expect(f.b.order.lines.any((l) => l.id == 'water'), isFalse);
        expect(f.a.workspace.activeDraft!.lines.single.id, added.id);

        if (capture) {
          await _capture(
            tester,
            boundary,
            'unified-order-additions-$language-${size.width.toInt()}',
          );
        }
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
