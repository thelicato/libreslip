import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/core/theme/app_theme.dart';
import 'package:libreslip/features/networking/application/client_delivery_controller.dart';
import 'package:libreslip/features/networking/domain/order_progress.dart';
import 'package:libreslip/features/orders/application/order_workspace_controller.dart';
import 'package:libreslip/features/orders/presentation/managed_order_composer.dart';
import 'package:libreslip/l10n/generated/app_localizations.dart';

import 'progress_sync_test.dart';

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
  for (final (language, size, scale) in [
    ('en', const Size(1100, 900), 1.0),
    ('it', const Size(320, 740), 2.0),
    ('en', const Size(915, 412), 1.0),
  ]) {
    testWidgets(
      'explicit sync and conflict choices remain usable $language $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final f = await createProgressFixture();
        final workspace = OrderWorkspaceController(f.client);
        await workspace.load();
        final delivery = ClientDeliveryController(
          f.client,
          f.secrets,
          f.transport,
        );
        addTearDown(delivery.dispose);
        addTearDown(workspace.dispose);
        addTearDown(f.server.close);
        final orderId = (await f.order()).id;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language, language == 'it' ? 'IT' : 'GB'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.build(Brightness.light),
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
                      listenable: workspace,
                      builder: (context, _) => ManagedOrderComposer(
                        controller: workspace,
                        busy: workspace.saving,
                        delivery: delivery,
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
        final expansion = find.byType(ExpansionTile).last;
        await tester.ensureVisible(expansion);
        await tester.tap(expansion);
        await tester.pumpAndSettle();
        final sync = find.byKey(ValueKey('sync-progress-$orderId'));
        await tester.ensureVisible(sync);
        await tester.pumpAndSettle();
        await tester.tap(sync);
        await tester.pumpAndSettle();
        expect(
          (await f.client.loadProgressSyncState(await f.order())).baseline,
          isNotNull,
        );
        await f.local('soup', 1);
        await f.remote('soup', 2);
        await tester.ensureVisible(sync);
        await tester.pumpAndSettle();
        await tester.tap(sync);
        await tester.pumpAndSettle();
        final useServer = find.byKey(ValueKey('progress-use-server-$orderId'));
        expect(useServer, findsOneWidget);
        expect(find.textContaining('Soup:'), findsOneWidget);
        // Cancel preserves offline changes and the next explicit action shows the conflict again.
        final cancel = find.text(language == 'it' ? 'Annulla' : 'Cancel');
        await tester.ensureVisible(cancel);
        await tester.pumpAndSettle();
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect((await f.order()).deliveredQuantity('soup'), 1);
        await tester.ensureVisible(sync);
        await tester.pumpAndSettle();
        await tester.tap(sync);
        await tester.pumpAndSettle();
        await tester.ensureVisible(useServer);
        await tester.pumpAndSettle();
        await tester.tap(useServer);
        await tester.pumpAndSettle();
        expect(workspace.managedOrders.single.deliveredQuantity('soup'), 2);
        expect(
          find.byKey(ValueKey('progress-use-client-$orderId')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'workspace holds the editor lock during the exchange and releases it after failure',
    (tester) async {
      final f = await createProgressFixture();
      final workspace = OrderWorkspaceController(f.client);
      await workspace.load();
      addTearDown(workspace.dispose);
      addTearDown(f.server.close);
      final order = await f.order();
      await expectLater(
        workspace.exchangeProgress(order.id, (value) async {
          expect(workspace.saving, isTrue);
          expect(await workspace.closeOrder(order.id), isFalse);
          throw const ProgressSyncException('unreachable');
        }),
        throwsA(isA<ProgressSyncException>()),
      );
      expect(workspace.saving, isFalse);
      expect(workspace.managedOrders.single.closedAt, isNull);
    },
  );
}
