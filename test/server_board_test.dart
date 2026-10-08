import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
import 'package:libreslip/features/networking/application/network_mode_controller.dart';
import 'package:libreslip/features/networking/application/server_inbox_controller.dart';
import 'package:libreslip/features/networking/domain/network_models.dart';
import 'package:libreslip/features/networking/domain/network_protocol.dart';
import 'package:libreslip/features/networking/domain/server_inbox_models.dart';
import 'package:libreslip/features/networking/domain/server_security.dart';
import 'package:libreslip/features/networking/domain/server_transport.dart';
import 'package:libreslip/features/settings/application/settings_controller.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';

import 'test_support.dart';

void main() {
  test('outstanding totals aggregate Received orders and ignore Done', () {
    ServerOrder order(
      String id,
      ServerOrderStatus status,
      List<ServerOrderLine> lines,
    ) => ServerOrder(
      id: id,
      clientInstallationId: 'client-1',
      clientDisplayName: 'Front counter',
      deliveryId: 'delivery-$id',
      clientTicketId: 'ticket-$id',
      displayNumber: 1,
      sourceCreatedAt: DateTime.utc(2026, 9, 25),
      receivedAt: DateTime.utc(2026, 9, 25),
      heading: 'Kitchen',
      reference: '',
      orderNote: '',
      lines: lines,
      payloadChecksum:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      status: status,
    );

    final totals = summariseOutstandingItems([
      order('one', ServerOrderStatus.received, const [
        ServerOrderLine(name: 'Soup', quantity: 2),
        ServerOrderLine(name: 'Tea', quantity: 1),
      ]),
      order('two', ServerOrderStatus.received, const [
        ServerOrderLine(name: 'soup', quantity: 3),
      ]),
      order('done', ServerOrderStatus.done, const [
        ServerOrderLine(name: 'Soup', quantity: 9),
      ]),
    ]);

    expect(totals.map((total) => total.name), ['Soup', 'Tea']);
    expect(totals.map((total) => total.quantity), [5, 1]);
  });

  test('managed preparation advances by section, skips empty sections and returns to an earlier section after undo', () {
    final courses = [
      OrderCourse.divider(id: 'empty', ordinal: 1),
      OrderCourse.divider(id: 'vegetables', ordinal: 2),
      OrderCourse.divider(id: 'empty-later', ordinal: 3),
      OrderCourse.divider(id: 'dessert', ordinal: 4),
    ];
    for (final (delivered, expected) in <(Map<String, int>, Map<String, int>)>[
      ({'soup': 1}, {'Soup': 1}),
      ({'soup': 2}, {'Vegetables': 3}),
      ({'soup': 2, 'vegetables': 1, 'dessert': 1}, {'Vegetables': 2}),
      ({'soup': 2, 'vegetables': 3}, {'Dessert': 1}),
      ({'soup': 2, 'vegetables': 3, 'dessert': 1}, {}),
      ({'soup': 1, 'vegetables': 3, 'dessert': 1}, {'Soup': 1}),
    ]) {
      final order = _summaryOrder(
        'managed',
        courses: courses,
        lines: [
          ServerOrderLine(
            id: 'dessert',
            name: 'Dessert',
            quantity: 1,
            courseId: courses.last.id,
            deliveredQuantity: delivered['dessert'] ?? 0,
          ),
          ServerOrderLine(
            id: 'soup',
            name: 'Soup',
            quantity: 2,
            deliveredQuantity: delivered['soup'] ?? 0,
          ),
          ServerOrderLine(
            id: 'vegetables',
            name: 'Vegetables',
            quantity: 3,
            courseId: courses[1].id,
            deliveredQuantity: delivered['vegetables'] ?? 0,
          ),
        ],
      );
      expect({
        for (final total in summariseOutstandingItems([order]))
          total.name: total.quantity,
      }, expected);
    }
  });

  test('each managed order contributes its own current section while ordinary grouped orders retain every item', () {
    const courses = [
      OrderCourse(id: 'first', name: 'First'),
      OrderCourse(id: 'later', name: 'Later'),
    ];
    final totals = summariseOutstandingItems([
      _summaryOrder(
        'one',
        courses: courses,
        lines: const [
          ServerOrderLine(
            name: 'Soup',
            quantity: 3,
            deliveredQuantity: 1,
            courseId: 'first',
          ),
          ServerOrderLine(name: 'Tea', quantity: 9, courseId: 'later'),
        ],
      ),
      _summaryOrder(
        'two',
        courses: courses,
        lines: const [
          ServerOrderLine(
            name: 'Soup',
            quantity: 1,
            deliveredQuantity: 1,
            courseId: 'first',
          ),
          ServerOrderLine(
            name: 'Water',
            quantity: 2,
            deliveredQuantity: 1,
            courseId: 'later',
          ),
        ],
      ),
      _summaryOrder(
        'ordinary',
        managed: false,
        courses: courses,
        lines: const [
          ServerOrderLine(name: 'soup', quantity: 1, courseId: 'first'),
          ServerOrderLine(name: 'Tea', quantity: 2, courseId: 'later'),
        ],
      ),
      _summaryOrder(
        'ungrouped',
        lines: const [
          ServerOrderLine(name: 'Bread', quantity: 2, deliveredQuantity: 1),
        ],
      ),
      _summaryOrder(
        'done',
        status: ServerOrderStatus.done,
        lines: const [ServerOrderLine(name: 'Soup', quantity: 100)],
      ),
    ]);
    expect(
      {for (final total in totals) total.name: total.quantity},
      {'Bread': 1, 'Soup': 3, 'Tea': 2, 'Water': 1},
    );
  });

  for (final (language, size, scale, wholeSteps) in [
    ('en', const Size(1100, 900), 1.0, false),
    ('en', const Size(1100, 900), 1.0, true),
    ('it', const Size(320, 740), 2.0, false),
    ('it', const Size(320, 740), 2.0, true),
    ('en', const Size(915, 412), 1.0, false),
    ('en', const Size(915, 412), 1.0, true),
  ]) {
    testWidgets(
      'managed Server delivery and undo $language $size whole steps: $wholeSteps',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final environment = await createMemoryOrderEnvironment();
        final repository = environment.repository;
        await repository.pairClient(
          PairedClient(
            installationId: 'client',
            displayName: 'Client',
            identityFingerprint: 'b' * 64,
            pairedAt: DateTime.utc(2026, 10, 5),
          ),
        );
        final received = await repository.receiveServerOrder(
          OrderDeliveryEnvelope.create(
            clientInstallationId: 'client',
            deliveryId: 'delivery',
            ticketId: 'ticket',
            managedOrderId: 'managed',
            revision: 1,
            ticketNumber: 17,
            createdAt: DateTime.utc(2026, 10, 5),
            heading: 'Kitchen',
            reference: 'Table 4',
            orderNote: '',
            courses: const [
              OrderCourse(id: 'first', name: 'First course'),
              OrderCourse(id: 'later', name: 'Next section'),
            ],
            lines: [
              const DeliveryLine(
                id: 'soup',
                name: 'Soup',
                quantity: 2,
                courseId: 'first',
              ),
              if (wholeSteps)
                const DeliveryLine(
                  id: 'bread',
                  name: 'Bread',
                  quantity: 2,
                  courseId: 'first',
                ),
              const DeliveryLine(
                id: 'water',
                name: 'Water',
                quantity: 1,
                courseId: 'later',
              ),
            ],
          ),
          receivedAt: DateTime.utc(2026, 10, 5),
        );
        final settings = SettingsController(
          MemorySettingsRepository()..stored = AppSettings(language: language),
        );
        final networking = NetworkModeController(repository);
        final inbox = ServerInboxController(
          repository,
          _MemoryServerSecrets(),
          _FakeServerHost(),
        );
        addTearDown(settings.dispose);
        addTearDown(networking.dispose);
        addTearDown(inbox.dispose);
        addTearDown(environment.controller.dispose);
        await settings.load();
        await networking.load();
        await networking.setMode(LibreSlipMode.server);
        await tester.pumpWidget(
          LibreSlipApp(
            settings: settings,
            orders: environment.controller,
            networking: networking,
            serverInbox: inbox,
          ),
        );
        await tester.pumpAndSettle();
        if (wholeSteps) {
          await tester.tap(find.byKey(const ValueKey('server-tab-settings')));
          await tester.pumpAndSettle();
          final toggle = find.byKey(const ValueKey('toggle-whole-steps'));
          await tester.scrollUntilVisible(
            toggle,
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(toggle);
          await tester.pumpAndSettle();
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(settings.settings.completeWholeSteps, isTrue);
          await tester.tap(find.byKey(const ValueKey('server-tab-orders')));
          await tester.pumpAndSettle();
        }
        final summary = find.byKey(const ValueKey('outstanding-items-card'));
        expect(
          find.descendant(of: summary, matching: find.text('Soup')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: summary, matching: find.text('Water')),
          findsNothing,
        );
        final card = find.byKey(ValueKey('server-order-${received.order.id}'));
        await tester.scrollUntilVisible(
          card,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final cardTitle = find.descendant(
          of: card,
          matching: find.text('Table 4'),
        );
        await tester.ensureVisible(cardTitle);
        await tester.pumpAndSettle();
        await tester.tap(cardTitle);
        await tester.pumpAndSettle();
        if (wholeSteps) {
          Future<void> tapStep(String id) async {
            final target = find.byKey(ValueKey('complete-step-$id'));
            await tester.ensureVisible(target);
            await tester.pumpAndSettle();
            await tester.tap(target);
            await tester.pumpAndSettle();
          }

          expect(find.byKey(const ValueKey('deliver-one-soup')), findsNothing);
          expect(
            find.byKey(const ValueKey('undo-delivery-soup')),
            findsNothing,
          );
          expect(find.byKey(const ValueKey('deliver-all-soup')), findsNothing);
          await tapStep('first');
          expect(
            inbox.orders.single.lines
                .where((line) => line.courseId == 'first')
                .map((line) => line.deliveredQuantity),
            [2, 2],
          );
          expect(inbox.receivedOrders, hasLength(1));
          expect(summariseOutstandingItems(inbox.orders).single.name, 'Water');
          await tapStep('later');
          expect(inbox.completedOrders, hasLength(1));
          await tapStep('first');
          expect(inbox.receivedOrders, hasLength(1));
          expect(
            inbox.orders.single.lines
                .where((line) => line.courseId == 'first')
                .every((line) => line.deliveredQuantity == 0),
            isTrue,
          );
          expect(
            inbox.orders.single.lines
                .firstWhere((line) => line.id == 'water')
                .deliveredQuantity,
            1,
          );
        } else {
          final deliver = find.byKey(const ValueKey('deliver-one-soup'));
          await tester.ensureVisible(deliver);
          await tester.pumpAndSettle();
          await tester.tap(deliver);
          await tester.pumpAndSettle();
          expect(
            inbox.orders.single.lines
                .firstWhere((line) => line.id == 'soup')
                .deliveredQuantity,
            1,
          );
          expect(inbox.receivedOrders, hasLength(1));
          final all = find.byKey(const ValueKey('deliver-all-soup'));
          await tester.ensureVisible(all);
          await tester.pumpAndSettle();
          await tester.tap(all);
          await tester.pumpAndSettle();
          expect(inbox.receivedOrders, hasLength(1));
          expect(summariseOutstandingItems(inbox.orders).single.name, 'Water');
          expect(summariseOutstandingItems(inbox.orders).single.quantity, 1);
          final next = find.byKey(const ValueKey('deliver-all-water'));
          await tester.ensureVisible(next);
          await tester.pumpAndSettle();
          await tester.tap(next);
          await tester.pumpAndSettle();
          expect(inbox.completedOrders, hasLength(1));
          final undo = find.byKey(const ValueKey('undo-delivery-soup'));
          await tester.ensureVisible(undo);
          await tester.pumpAndSettle();
          await tester.tap(undo);
          await tester.pumpAndSettle();
          expect(
            inbox.orders.single.lines
                .firstWhere((line) => line.id == 'soup')
                .deliveredQuantity,
            1,
          );
          expect(inbox.receivedOrders, hasLength(1));
          expect(inbox.completedOrders, isEmpty);
        }
        final close = find.text(language == 'it' ? 'Chiudi' : 'Close');
        await tester.ensureVisible(close);
        await tester.pumpAndSettle();
        await tester.tap(close);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          summary,
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: summary, matching: find.text('Soup')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: summary, matching: find.text('Water')),
          findsNothing,
        );
        if (wholeSteps) {
          await tester.tap(find.byKey(const ValueKey('server-tab-settings')));
          await tester.pumpAndSettle();
          final toggle = find.byKey(const ValueKey('toggle-whole-steps'));
          await tester.ensureVisible(toggle);
          await tester.pumpAndSettle();
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(settings.settings.completeWholeSteps, isFalse);
          await tester.tap(find.byKey(const ValueKey('server-tab-orders')));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            card,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(cardTitle);
          await tester.pumpAndSettle();
          await tester.tap(cardTitle);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('deliver-one-soup')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('complete-step-first')),
            findsNothing,
          );
          expect(
            inbox.orders.single.lines
                .firstWhere((line) => line.id == 'water')
                .deliveredQuantity,
            1,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('Server orders load oldest first', () async {
    final environment = await createMemoryOrderEnvironment();
    addTearDown(environment.controller.dispose);
    final repository = environment.repository;
    await repository.pairClient(
      PairedClient(
        installationId: 'client-1',
        displayName: 'Front counter',
        identityFingerprint: 'b' * 64,
        pairedAt: DateTime.utc(2026, 9, 25, 8),
      ),
    );
    Future<void> receive({
      required String id,
      required int number,
      required DateTime receivedAt,
    }) => repository
        .receiveServerOrder(
          OrderDeliveryEnvelope.create(
            clientInstallationId: 'client-1',
            deliveryId: 'delivery-$id',
            ticketId: 'ticket-$id',
            ticketNumber: number,
            createdAt: receivedAt.subtract(const Duration(minutes: 1)),
            heading: 'Kitchen',
            reference: '',
            orderNote: '',
            lines: const [DeliveryLine(name: 'Soup', quantity: 1)],
          ),
          receivedAt: receivedAt,
        )
        .then((_) {});

    await receive(
      id: 'newer',
      number: 2,
      receivedAt: DateTime.utc(2026, 9, 25, 10),
    );
    await receive(
      id: 'older',
      number: 1,
      receivedAt: DateTime.utc(2026, 9, 25, 9),
    );

    expect(
      (await repository.loadServerOrders()).map((order) => order.displayNumber),
      [1, 2],
    );
  });

  testWidgets('Server board aligns pairs and Done can be undone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final environment = await createMemoryOrderEnvironment();
    final repository = environment.repository;
    await repository.pairClient(
      PairedClient(
        installationId: 'client-1',
        displayName: 'Front counter',
        identityFingerprint:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        pairedAt: DateTime.utc(2026, 9, 24, 18),
      ),
    );
    await repository.receiveServerOrder(
      OrderDeliveryEnvelope.create(
        clientInstallationId: 'client-1',
        deliveryId: 'delivery-1',
        ticketId: 'ticket-1',
        ticketNumber: 17,
        createdAt: DateTime.utc(2026, 9, 24, 18, 30),
        heading: 'Kitchen',
        reference: 'Table 4',
        orderNote: 'Together',
        courses: const [
          OrderCourse(id: 'first', name: 'First course'),
          OrderCourse(id: 'second', name: 'Second course'),
        ],
        lines: const [
          DeliveryLine(
            name: 'Soup',
            quantity: 1,
            preparationNote: 'No cream',
            courseId: 'first',
          ),
          DeliveryLine(name: 'Soup', quantity: 1, courseId: 'second'),
        ],
      ),
      receivedAt: DateTime.utc(2026, 9, 24, 18, 31),
    );
    await repository.receiveServerOrder(
      OrderDeliveryEnvelope.create(
        clientInstallationId: 'client-1',
        deliveryId: 'delivery-2',
        ticketId: 'ticket-2',
        ticketNumber: 18,
        createdAt: DateTime.utc(2026, 9, 24, 18, 32),
        heading: 'Kitchen',
        reference: '',
        orderNote: '',
        lines: const [DeliveryLine(name: 'Tea', quantity: 1)],
      ),
      receivedAt: DateTime.utc(2026, 9, 24, 18, 33),
    );
    final settings = SettingsController(MemorySettingsRepository());
    final networking = NetworkModeController(repository);
    final inbox = ServerInboxController(
      repository,
      _MemoryServerSecrets(),
      _FakeServerHost(),
    );
    addTearDown(settings.dispose);
    addTearDown(environment.controller.dispose);
    addTearDown(networking.dispose);
    addTearDown(inbox.dispose);
    await settings.load();
    await networking.load();
    await networking.setMode(LibreSlipMode.server);

    await tester.pumpWidget(
      LibreSlipApp(
        settings: settings,
        orders: environment.controller,
        networking: networking,
        serverInbox: inbox,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Order 17'), findsOneWidget);
    expect(find.text('Order 18'), findsOneWidget);
    expect(find.text('Table 4'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('outstanding-items-card')),
      findsOneWidget,
    );
    expect(find.text('Still to prepare'), findsOneWidget);
    final summaryFinder = find.byKey(const ValueKey('outstanding-items-card'));
    final firstVisibleOrder = find.byKey(
      ValueKey('server-order-${inbox.receivedOrders.first.id}'),
    );
    expect(
      tester.getTopLeft(summaryFinder).dy,
      lessThan(tester.getTopLeft(firstVisibleOrder).dy),
    );
    expect(find.text('Soup'), findsWidgets);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Ready to receive'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('server-tab-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('server-settings-page')), findsOneWidget);
    expect(find.text('Ready to receive'), findsOneWidget);
    expect(find.text('Order 17'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('server-tab-orders')));
    await tester.pumpAndSettle();

    final firstOrder = inbox.receivedOrders.singleWhere(
      (order) => order.displayNumber == 17,
    );
    final secondOrder = inbox.receivedOrders.singleWhere(
      (order) => order.displayNumber == 18,
    );
    await tester.ensureVisible(find.text('Order 17'));
    await tester.pumpAndSettle();
    final orderFinder = find.byKey(ValueKey('server-order-${firstOrder.id}'));
    final secondOrderFinder = find.byKey(
      ValueKey('server-order-${secondOrder.id}'),
    );
    expect(
      find.descendant(of: orderFinder, matching: find.text('1×')),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: orderFinder, matching: find.text('Soup')),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: orderFinder, matching: find.text('No cream')),
      findsOneWidget,
    );
    expect(find.text('Front counter'), findsNothing);
    expect(
      find.descendant(of: orderFinder, matching: find.text('First course')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: orderFinder, matching: find.text('Second course')),
      findsOneWidget,
    );
    final firstRect = tester.getRect(orderFinder);
    final secondRect = tester.getRect(secondOrderFinder);
    final summaryRect = tester.getRect(
      find.byKey(const ValueKey('outstanding-items-card')),
    );
    expect(firstRect.top, secondRect.top);
    expect(firstRect.width, closeTo(secondRect.width, 0.1));
    expect(secondRect.right - firstRect.left, closeTo(summaryRect.width, 0.1));
    final firstOutstanding = find.byKey(const ValueKey('outstanding-item-0'));
    final secondOutstanding = find.byKey(const ValueKey('outstanding-item-1'));
    expect(
      tester.getTopLeft(firstOutstanding).dy,
      tester.getTopLeft(secondOutstanding).dy,
    );
    final summarySoup = find.descendant(
      of: firstOutstanding,
      matching: find.text('Soup'),
    );
    final summaryQuantity = find.descendant(
      of: firstOutstanding,
      matching: find.text('2'),
    );
    expect(
      tester.getTopLeft(summaryQuantity).dx -
          tester.getTopRight(summarySoup).dx,
      lessThan(32),
    );
    await tester.tap(orderFinder);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Table 4'),
      ),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(AlertDialog)).width, greaterThan(680));
    expect(find.text('1×  Soup'), findsNWidgets(2));
    expect(find.text('No cream'), findsWidgets);
    expect(find.text('Front counter'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('mark-order-done')));
    await tester.pumpAndSettle();
    expect(inbox.receivedOrders, hasLength(1));
    expect(inbox.completedOrders, hasLength(1));

    await tester.ensureVisible(find.text('Order 18'));
    await tester.tap(secondOrderFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mark-order-done')));
    await tester.pumpAndSettle();
    expect(inbox.receivedOrders, isEmpty);
    expect(inbox.completedOrders, hasLength(2));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('outstanding-items-card')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Nothing is waiting to be prepared.'), findsOneWidget);

    await tester.tap(find.text('Completed (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Order 17'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('server-order-${firstOrder.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mark-order-received')));
    await tester.pumpAndSettle();
    expect(inbox.receivedOrders, hasLength(1));
    expect(inbox.completedOrders, hasLength(1));

    await tester.tap(find.byKey(ValueKey('server-order-${secondOrder.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-completed-order')));
    await tester.pumpAndSettle();
    expect(find.text('Delete completed order 18?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('confirm-delete-completed-order')),
    );
    await tester.pumpAndSettle();
    expect(inbox.completedOrders, isEmpty);
    expect(inbox.receivedOrders, hasLength(1));

    await tester.tap(find.text('Received (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Order 17'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('server-order-${firstOrder.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mark-order-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-all-completed-orders')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm-delete-all-completed-orders')),
    );
    await tester.pumpAndSettle();
    expect(inbox.completedOrders, isEmpty);
    expect(find.text('No completed orders yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryServerSecrets implements ServerSecretStore {
  String? certificate;
  String? privateKey;
  final tokens = <String, String>{};

  @override
  Future<String?> readClientTokenHash(String clientInstallationId) async =>
      tokens[clientInstallationId];

  @override
  Future<String?> readServerCertificate() async => certificate;

  @override
  Future<String?> readServerPrivateKey() async => privateKey;

  @override
  Future<void> writeClientTokenHash(
    String clientInstallationId,
    String tokenHash,
  ) async {
    tokens[clientInstallationId] = tokenHash;
  }

  @override
  Future<void> writeServerIdentity({
    required String certificatePem,
    required String privateKeyPem,
  }) async {
    certificate = certificatePem;
    privateKey = privateKeyPem;
  }
}

class _FakeServerHost implements ServerHost {
  @override
  Future<RunningServer> start({
    required ServerIdentity identity,
    required NetworkConfiguration configuration,
    required Future<bool> Function(ClientPairingRequest request)
    requestPairingApproval,
    required void Function() onOrderReceived,
  }) async =>
      const RunningServer(port: 5119, addresses: ['https://192.0.2.10:5119']);

  @override
  Future<void> stop() async {}
}

ServerOrder _summaryOrder(
  String id, {
  List<OrderCourse> courses = const [],
  required List<ServerOrderLine> lines,
  bool managed = true,
  ServerOrderStatus status = ServerOrderStatus.received,
}) => ServerOrder(
  id: id,
  clientInstallationId: 'client',
  clientDisplayName: 'Client',
  deliveryId: 'delivery-$id',
  clientTicketId: 'ticket-$id',
  displayNumber: 1,
  sourceCreatedAt: DateTime.utc(2026, 10, 5),
  receivedAt: DateTime.utc(2026, 10, 5),
  heading: 'Kitchen',
  reference: '',
  orderNote: '',
  lines: lines,
  courses: courses,
  managedOrderId: managed ? id : null,
  revision: managed ? 1 : 0,
  payloadChecksum: 'a' * 64,
  status: status,
);
