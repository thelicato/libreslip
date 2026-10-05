import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/core/theme/app_theme.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:libreslip/features/orders/presentation/items_page.dart';
import 'package:libreslip/features/orders/presentation/compose_page.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';
import 'package:libreslip/l10n/generated/app_localizations.dart';

import 'test_support.dart';

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
  for (final (language, size, scale) in [
    ('en', const Size(1100, 900), 1.0),
    ('it', const Size(320, 740), 2.0),
    ('en', const Size(915, 412), 1.0),
  ]) {
    testWidgets(
      'optional price editor validates and preserves hidden prices $language $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final env = await createMemoryOrderEnvironment();
        addTearDown(env.controller.dispose);
        await env.controller.updateFeatureSettings(
          const OrderFeatureSettings(pricesEnabled: true),
        );
        await env.controller.saveItem(
          name: 'Tea',
          price: const ProductPrice(minorUnits: 125, currency: 'EUR'),
        );
        await tester.pumpWidget(
          _app(language, scale, ItemsPage(controller: env.controller)),
        );
        await tester.tap(find.text('Tea'));
        await tester.pumpAndSettle();
        final field = find.byKey(const ValueKey('item-price'));
        await tester.ensureVisible(field);
        await tester.enterText(field, '1.234');
        final save = find.text(
          language == 'it' ? 'Salva modifiche' : 'Save changes',
        );
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(env.controller.items.single.price!.minorUnits, 125);
        expect(
          find.textContaining(
            language == 'it' ? 'senza separatore' : 'no thousands separator',
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, language == 'it' ? '12,30' : '12.30');
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(
          env.controller.items.single.price,
          const ProductPrice(minorUnits: 1230, currency: 'EUR'),
        );
        await env.controller.updateFeatureSettings(
          const OrderFeatureSettings(),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Tea'));
        await tester.tap(find.text('Tea'));
        await tester.pumpAndSettle();
        expect(field, findsNothing);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(env.controller.items.single.price!.minorUnits, 1230);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'composition estimates show missing prices and separate currencies $language $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final env = await createMemoryOrderEnvironment();
        addTearDown(env.controller.dispose);
        await env.controller.updateFeatureSettings(
          const OrderFeatureSettings(pricesEnabled: true),
        );
        for (final (name, price) in [
          ('Soup', const ProductPrice(minorUnits: 125, currency: 'EUR')),
          ('Water', const ProductPrice(minorUnits: 250, currency: 'GBP')),
          ('Bread', null),
        ]) {
          final item = await env.repository.saveItem(name: name, price: price);
          env.controller.addCatalogueItem(item);
        }
        final printing = ValueNotifier(false);
        addTearDown(printing.dispose);
        await tester.pumpWidget(
          _app(
            language,
            scale,
            ComposePage(
              controller: env.controller,
              settings: const AppSettings(),
              printing: printing,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('EUR'), findsOneWidget);
        expect(find.textContaining('GBP'), findsOneWidget);
        expect(
          find.textContaining(
            language == 'it' ? 'stima è incompleta' : 'estimate is incomplete',
          ),
          findsOneWidget,
        );
        final expansion = find.byType(ExpansionTile).first;
        await tester.ensureVisible(expansion);
        await tester.tap(expansion);
        await tester.pumpAndSettle();
        expect(
          find.text(language == 'it' ? 'Nessun prezzo' : 'No price'),
          findsOneWidget,
        );
        await env.controller.updateFeatureSettings(
          const OrderFeatureSettings(),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('order-estimate')), findsNothing);
        expect(env.controller.activeDraft!.lines.first.price!.minorUnits, 125);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _app(String language, double scale, Widget page) => MaterialApp(
  locale: Locale(language, language == 'it' ? 'IT' : 'GB'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.build(Brightness.light),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        child: Padding(padding: const EdgeInsets.all(20), child: page),
      ),
    ),
  ),
);
