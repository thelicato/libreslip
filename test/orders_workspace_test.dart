import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:libreslip/features/settings/application/settings_controller.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'shared_orders_test.dart';
import 'test_support.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  for (final (language, size, scale) in [
    ('it', const Size(320, 740), 1.0),
    ('it', const Size(320, 740), 2.0),
    ('en', const Size(915, 412), 1.0),
  ]) {
    testWidgets(
      'Orders manages additions and restores Tickets labels $language $size text $scale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final env = await createMemoryOrderEnvironment();
        addTearDown(env.controller.dispose);
        addTearDown(env.repository.close);
        await env.controller.updateFeatureSettings(
          const OrderFeatureSettings(managedOrdersEnabled: true),
        );
        await env.controller.saveItem(name: 'Soup');
        env.controller.setReference('Table 4');
        env.controller.addCatalogueItem(env.controller.items.single);
        final saved = (await env.controller.saveActiveTicket(
          heading: 'Kitchen',
        ))!;
        final id = env.controller.managedOrders.single.id;
        final settings = SettingsController(
          MemorySettingsRepository()
            ..stored = AppSettings(language: language, compactCompose: true),
        );
        await settings.load();
        addTearDown(settings.dispose);
        await tester.pumpWidget(
          LibreSlipApp(settings: settings, orders: env.controller),
        );
        await tester.pumpAndSettle();
        Future<void> tap(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        final navigation = find.byKey(const ValueKey('nav-3'));
        String navigationLabel() {
          final control = tester.widget(navigation);
          return control is NavigationDestination
              ? control.label
              : tester
                    .widget<Tooltip>(
                      find
                          .ancestor(
                            of: navigation,
                            matching: find.byType(Tooltip),
                          )
                          .first,
                    )
                    .message!;
        }

        expect(navigationLabel(), language == 'it' ? 'Ordini' : 'Orders');
        await tap(find.byKey(const ValueKey('nav-2')));
        expect(find.byKey(const ValueKey('active-orders')), findsNothing);
        expect(find.byKey(ValueKey('view-order-$id')), findsNothing);
        final reference = find.byKey(const ValueKey('compact-edit-reference'));
        final note = find.byKey(const ValueKey('compact-edit-order-note'));
        await tester.ensureVisible(reference);
        await tester.pumpAndSettle();
        final referenceRect = tester.getRect(reference);
        final noteRect = tester.getRect(note);
        expect(referenceRect.left, noteRect.left);
        expect(referenceRect.width, noteRect.width);
        final panelWidth = tester
            .getSize(find.byKey(const ValueKey('compact-compose-panel')))
            .width;
        expect(referenceRect.width, greaterThan(panelWidth - 40));
        expect(noteRect.top, greaterThanOrEqualTo(referenceRect.bottom + 8));
        expect(referenceRect.height, greaterThanOrEqualTo(48));
        await tap(reference);
        await tap(find.text(language == 'it' ? 'Annulla' : 'Cancel'));
        await tap(note);
        await tap(find.text(language == 'it' ? 'Annulla' : 'Cancel'));
        await tap(navigation);
        final view = find.byKey(ValueKey('view-order-$id'));
        expect(view, findsOneWidget);
        final historyView = find.byKey(ValueKey('view-ticket-${saved.id}'));
        expect(
          find.descendant(
            of: historyView,
            matching: find.text(
              language == 'it' ? 'Vedi ordine' : 'View order',
            ),
          ),
          findsOneWidget,
        );
        await tap(view);
        await tap(find.byKey(ValueKey('add-to-order-$id')));
        expect(env.controller.editingOrder?.id, id);
        expect(find.byKey(const ValueKey('cancel-addition')), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        env.controller.addCatalogueItem(env.controller.items.single);
        final addition = (await env.controller.saveActiveTicket(
          heading: 'Kitchen',
        ))!;
        await tester.pumpAndSettle();
        expect(env.controller.managedOrders.single.lines, hasLength(2));
        expect(
          (await env.repository.loadTickets())
              .firstWhere((ticket) => ticket.id == saved.id)
              .lines,
          hasLength(1),
        );
        expect(addition.revision, 2);
        await tap(find.byKey(const ValueKey('nav-4')));
        final toggle = find.byKey(const ValueKey('toggle-managed-orders'));
        await tester.scrollUntilVisible(
          toggle,
          250,
          scrollable: find.byType(Scrollable).last,
        );
        await tap(find.descendant(of: toggle, matching: find.byType(Switch)));
        expect(env.controller.featureSettings.managedOrdersEnabled, isFalse);
        expect(navigationLabel(), language == 'it' ? 'Comande' : 'Tickets');
        await tap(navigation);
        expect(find.byKey(ValueKey('view-order-$id')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(ValueKey('view-ticket-${saved.id}')),
            matching: find.text(
              language == 'it' ? 'Vedi comanda' : 'View ticket',
            ),
          ),
          findsOneWidget,
        );
        await tap(find.byKey(ValueKey('view-order-$id')));
        await tap(find.byKey(ValueKey('close-order-$id')));
        final confirm = find.descendant(
          of: find.byType(AlertDialog).last,
          matching: find.byType(FilledButton),
        );
        await tap(confirm);
        expect(env.controller.managedOrders, isEmpty);
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          (await env.repository.loadTickets()).map((ticket) => ticket.id),
          containsAll([saved.id, addition.id]),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Orders searches a shared mirror with no local ticket history', (
    tester,
  ) async {
    final f = await SharedFixture.create();
    addTearDown(f.dispose);
    await f.seed();
    await f.syncBoth();
    final settings = SettingsController(MemorySettingsRepository());
    await settings.load();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      LibreSlipApp(
        settings: settings,
        orders: f.b.workspace,
        networking: f.b.mode,
        clientDelivery: f.b.delivery,
        sharedOrders: f.b.sync,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    expect(f.b.workspace.tickets, isEmpty);
    final view = find.byKey(ValueKey('view-order-${f.b.order.id}'));
    expect(view, findsOneWidget);
    final search = find.byKey(const ValueKey('ticket-search'));
    await tester.enterText(search, 'does not exist');
    await tester.pumpAndSettle();
    expect(view, findsNothing);
    await tester.enterText(search, 'Table 4');
    await tester.pumpAndSettle();
    expect(view, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
