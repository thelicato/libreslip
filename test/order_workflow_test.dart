import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
import 'package:libreslip/features/settings/application/settings_controller.dart';

import 'test_support.dart';

void main() {
  testWidgets('item to saved ticket to duplicate draft works end to end', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = SettingsController(MemorySettingsRepository());
    final orders = await createMemoryOrders();
    addTearDown(settings.dispose);
    addTearDown(orders.dispose);
    await settings.load();
    await tester.pumpWidget(LibreSlipApp(settings: settings, orders: orders));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-item')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('item-name')),
      'Mushroom toastie',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(orders.items.single.name, 'Mushroom toastie');
    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('compose-item-${orders.items.single.id}')),
    );
    await tester.pump();
    final draftId = orders.activeDraft!.id;
    await tester.enterText(
      find.byKey(ValueKey('reference-$draftId')),
      'Table 4',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-ticket')));
    await tester.pumpAndSettle();

    expect(orders.tickets, hasLength(1));
    expect(orders.tickets.single.reference, 'Table 4');
    expect(orders.tickets.single.lines.single.name, 'Mushroom toastie');

    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('Ticket 1'), findsOneWidget);
    expect(find.textContaining('Mushroom toastie'), findsOneWidget);
    await tester.tap(find.text('Duplicate as draft'));
    await tester.pumpAndSettle();

    expect(orders.drafts, hasLength(2));
    expect(orders.activeDraft!.reference, 'Table 4');
    expect(orders.activeDraft!.lines.single.name, 'Mushroom toastie');
    expect(find.text('Compose'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
