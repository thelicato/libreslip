import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/core/theme/app_theme.dart';
import 'package:libreslip/features/networking/presentation/client_server_settings_card.dart';
import 'package:libreslip/features/networking/presentation/server_destination_selector.dart';
import 'package:libreslip/features/networking/presentation/shared_order_controls.dart';
import 'package:libreslip/l10n/generated/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'multiple_servers_test.dart';

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
      'multiple Server settings, destination selection and independent disconnect are reachable $language $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const capture = bool.fromEnvironment('LIBRESLIP_CAPTURE_PREVIEWS');
        if (capture) await _fonts();
        final f = await MultipleServersFixture.create();
        addTearDown(f.dispose);
        final ticket = await f.client.newOrder(f.firstId, 'Table 4');
        await f.client.delivery.selectServer(f.secondId);
        await f.client.sync.synchronise();
        final order = f.client.workspace.managedOrders.singleWhere(
          (o) => o.id == ticket.managedOrderId,
        );
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
                        listenable: f.client.delivery,
                        builder: (context, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ServerDestinationSelector(
                              controller: f.client.delivery,
                            ),
                            const SizedBox(height: 20),
                            ClientServerSettingsCard(
                              controller: f.client.delivery,
                              configuration: f.client.mode.configuration!,
                            ),
                            const SizedBox(height: 20),
                            ServerDestinationSelector(
                              controller: f.client.delivery,
                              order: order,
                            ),
                            SharedOrderControls(
                              controller: f.client.sync,
                              order: order,
                            ),
                          ],
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
        expect(
          find.byKey(ValueKey('connected-server-${f.firstId}')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('connected-server-${f.secondId}')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('pair-server')), findsOneWidget);
        final useFirst = find.byKey(ValueKey('select-server-${f.firstId}'));
        await tester.ensureVisible(useFirst);
        await tester.pumpAndSettle();
        await tester.tap(useFirst);
        await tester.pumpAndSettle();
        expect(f.client.delivery.activeServer!.id, f.firstId);
        final selector = find.byKey(ValueKey('order-server-${f.firstId}'));
        await tester.ensureVisible(selector);
        await tester.pumpAndSettle();
        await tester.tap(selector);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bar Server').last);
        await tester.pumpAndSettle();
        expect(f.client.delivery.activeServer!.id, f.secondId);
        expect(order.destinationId, f.firstId);
        expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
        if (capture) {
          await tester.ensureVisible(
            find.byKey(ValueKey('connected-server-${f.secondId}')),
          );
          await tester.pumpAndSettle();
          await _capture(
            tester,
            boundary,
            'multiple-servers-$language-${size.width.toInt()}',
          );
        }
        final unpair = find.byKey(const ValueKey('unpair-server'));
        await tester.ensureVisible(unpair);
        await tester.pumpAndSettle();
        await tester.tap(unpair);
        await tester.pumpAndSettle();
        final confirm = find.byKey(const ValueKey('confirm-unpair-server'));
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(f.client.delivery.servers.single.id, f.firstId);
        expect(f.client.delivery.activeServer!.id, f.firstId);
        expect(f.client.secrets.tokens.containsKey(f.firstId), isTrue);
        expect(f.client.secrets.tokens.containsKey(f.secondId), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
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
