import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
import 'package:libreslip/features/networking/domain/network_protocol.dart';
import 'package:libreslip/features/orders/application/order_workspace_controller.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:libreslip/features/orders/presentation/course_composer.dart';
import 'package:libreslip/features/printing/application/esc_pos_ticket_encoder.dart';
import 'package:libreslip/features/printing/application/ticket_pdf_sharer.dart';
import 'package:libreslip/features/printing/domain/print_job.dart';
import 'package:libreslip/features/printing/domain/ticket_document.dart';
import 'package:libreslip/features/settings/application/settings_controller.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_support.dart';

const _courses = [
  OrderCourse(id: 'first', name: 'First course'),
  OrderCourse(id: 'second', name: 'Second course'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  test(
    'schema 10 migration preserves ungrouped tickets and queued print bytes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'libreslip-course-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/orders.sqlite3';
      final first = SqliteOrderRepository(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: path,
      );
      await first.open();
      final blank = await first.createDraft();
      final ticket = await first.convertDraftToTicket(
        blank.copyWith(
          reference: 'Table 2',
          lines: const [TicketLine(id: 'tea-line', name: 'Tea', quantity: 2)],
        ),
        heading: 'Kitchen',
      );
      final job = await first.createPrintJob(
        requestId: 'legacy-job',
        ticketId: ticket.id,
        payload: Uint8List.fromList([27, 64, 84, 101, 97]),
      );
      await first.close();
      final legacy = await databaseFactoryFfiNoIsolate.openDatabase(path);
      await removeCourseColumnsForLegacyFixture(legacy);
      await legacy.setVersion(10);
      await legacy.close();
      final migrated = SqliteOrderRepository(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: path,
      );
      addTearDown(migrated.close);
      await migrated.open();
      final restored = (await migrated.loadTickets()).single;
      expect(restored.id, ticket.id);
      expect(restored.reference, 'Table 2');
      expect(restored.courses, isEmpty);
      expect(restored.lines.single.courseId, isNull);
      expect(
        (await migrated.loadFeatureSettings()).courseGroupsEnabled,
        isFalse,
      );
      expect((await migrated.loadPrintJobs()).single.payload, job.payload);
      expect(
        (await migrated.loadPrintJobs()).single.status,
        PrintJobStatus.queued,
      );
    },
  );

  test('course selection and separate same-item lines recover; saved groups remain snapshots', () async {
    final directory = await Directory.systemTemp.createTemp(
      'libreslip-course-recovery-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/orders.sqlite3';
    final first = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: path,
    );
    final orders = OrderWorkspaceController(first);
    addTearDown(orders.dispose);
    await orders.load();
    await orders.updateFeatureSettings(
      const OrderFeatureSettings(courseGroupsEnabled: true),
    );
    await orders.saveItem(name: 'Soup');
    expect(orders.saveCourse('First course'), isTrue);
    final firstCourse = orders.activeDraft!.activeCourseId!;
    orders.addCatalogueItem(orders.items.single);
    orders.setPreparationNote(orders.activeDraft!.lines.single.id, 'No cream');
    expect(orders.saveCourse('Second course'), isTrue);
    final secondCourse = orders.activeDraft!.activeCourseId!;
    orders.addCatalogueItem(orders.items.single);
    orders.addCatalogueItem(orders.items.single);
    orders.setPreparationNote(orders.activeDraft!.lines.last.id, 'Extra bread');
    await orders.flushWrites();
    await first.close();
    final second = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: path,
    );
    final recovered = OrderWorkspaceController(second);
    addTearDown(recovered.dispose);
    await recovered.load();
    expect(recovered.activeDraft!.activeCourseId, secondCourse);
    expect(recovered.activeDraft!.lines.map((line) => line.courseId), [
      firstCourse,
      secondCourse,
    ]);
    expect(recovered.activeDraft!.lines.map((line) => line.quantity), [1, 2]);
    expect(recovered.activeDraft!.lines.map((line) => line.preparationNote), [
      'No cream',
      'Extra bread',
    ]);
    recovered.moveCourse(secondCourse, -1);
    final ticket = (await recovered.saveActiveTicket(heading: 'Kitchen'))!;
    expect(ticket.courses.map((course) => course.name), [
      'Second course',
      'First course',
    ]);
    expect(recovered.activeDraft!.courses, isEmpty);
    recovered.saveCourse('Changed name');
    await recovered.flushWrites();
    expect(
      (await second.loadTickets()).single.courses.first.name,
      'Second course',
    );
    expect(
      (await second.loadTickets()).single.lines.map((line) => line.courseId),
      [firstCourse, secondCourse],
    );
    final document = _document(ticket);
    final bytes = await const EscPosTicketEncoder().encode(document);
    final job = await second.createPrintJob(
      requestId: 'grouped-job',
      ticketId: ticket.id,
      payload: bytes,
    );
    await second.markPrintJobSending(
      job.id,
      printerAddress: 'preview-printer',
      printerName: 'Preview',
    );
    await second.close();
    final third = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: path,
    );
    addTearDown(third.close);
    await third.open();
    expect(
      (await third.loadPrintJobs()).single.status,
      PrintJobStatus.uncertain,
    );
    expect((await third.loadPrintJobs()).single.payload, bytes);
    expect(await third.loadTickets(), hasLength(1));
  });

  test('moving and removing courses preserve quantities and notes; disabling affects the next order', () async {
    final orders = await createMemoryOrders();
    addTearDown(orders.dispose);
    await orders.updateFeatureSettings(
      const OrderFeatureSettings(courseGroupsEnabled: true),
    );
    await orders.saveItem(name: 'Water');
    orders.saveCourse('Drinks');
    final drinks = orders.activeDraft!.activeCourseId!;
    orders.addCatalogueItem(orders.items.single);
    final line = orders.activeDraft!.lines.single;
    orders.setQuantity(line.id, 3);
    orders.setPreparationNote(line.id, 'Still');
    orders.saveCourse('Later');
    final later = orders.activeDraft!.activeCourseId!;
    orders.setLineCourse(line.id, later);
    expect(orders.activeDraft!.lines.single.courseId, later);
    orders.removeCourse(later);
    expect(orders.activeDraft!.activeCourseId, isNull);
    expect(orders.activeDraft!.lines.single.courseId, isNull);
    expect(orders.activeDraft!.lines.single.quantity, 3);
    expect(orders.activeDraft!.lines.single.preparationNote, 'Still');
    orders.setLineCourse(line.id, drinks);
    await orders.updateFeatureSettings(const OrderFeatureSettings());
    expect(orders.courseControlsAvailable, isTrue);
    final ticket = (await orders.saveActiveTicket(heading: 'Kitchen'))!;
    expect(ticket.courses.single.id, drinks);
    expect(ticket.lines.single.courseId, drinks);
    expect(orders.activeDraft!.courses, isEmpty);
    expect(orders.courseControlsAvailable, isFalse);
  });

  test(
    'invalid course snapshots are rejected before replacing usable data',
    () async {
      final environment = await createMemoryOrderEnvironment();
      addTearDown(environment.controller.dispose);
      final orders = environment.controller;
      await orders.updateFeatureSettings(
        const OrderFeatureSettings(courseGroupsEnabled: true),
      );
      await orders.saveItem(name: 'Soup');
      orders.saveCourse('First course');
      orders.addCatalogueItem(orders.items.single);
      await orders.flushWrites();
      final valid = await environment.repository.createPortableSnapshot();
      for (final edit in <void Function(Map<String, dynamic>)>[
        (tables) =>
            (tables['draft_lines'] as List).single['course_id'] = 'missing',
        (tables) =>
            (tables['drafts'] as List).single['active_course_id'] = 'missing',
        (tables) =>
            (tables['drafts'] as List).single['courses_json'] = 'not json',
        (tables) =>
            (tables['drafts'] as List).single['courses_json'] = jsonEncode([
              {'id': 'same', 'name': 'First'},
              {'id': 'same', 'name': 'Second'},
            ]),
        (tables) =>
            (tables['order_feature_settings'] as List)
                    .single['course_groups_enabled'] =
                2,
      ]) {
        final changed = jsonDecode(jsonEncode(valid)) as Map<String, dynamic>;
        edit(changed['tables'] as Map<String, dynamic>);
        await expectLater(
          environment.repository.replaceWithPortableSnapshot(changed),
          throwsA(isA<OrderStorageException>()),
        );
        expect(
          (await environment.repository.loadDrafts()).single.lines.single.name,
          'Soup',
        );
        expect(
          (await environment.repository.loadDrafts())
              .single
              .courses
              .single
              .name,
          'First course',
        );
      }
    },
  );

  test('grouped envelopes preserve order and reject broken relationships or tampering', () {
    final envelope = OrderDeliveryEnvelope.create(
      clientInstallationId: 'client-1',
      deliveryId: 'delivery-1',
      ticketId: 'ticket-1',
      ticketNumber: 1,
      createdAt: DateTime.utc(2026, 10, 5),
      heading: 'Kitchen',
      reference: 'Table 4',
      orderNote: '',
      courses: _courses,
      lines: const [
        DeliveryLine(name: 'Soup', quantity: 2, courseId: 'second'),
        DeliveryLine(name: 'Tea', quantity: 1),
      ],
    );
    final restored = OrderDeliveryEnvelope.fromJsonString(
      envelope.toJsonString(),
    );
    expect(restored.version, 2);
    expect(restored.courses.map((course) => course.name), [
      'First course',
      'Second course',
    ]);
    expect(restored.lines.first.courseId, 'second');
    expect(restored.lines.last.courseId, isNull);
    expect(restored.toJsonString(), envelope.toJsonString());
    final changed = jsonDecode(envelope.toJsonString()) as Map<String, dynamic>;
    (changed['ticket']['courses'] as List).first['name'] = 'Changed';
    expect(
      () => OrderDeliveryEnvelope.fromJsonString(jsonEncode(changed)),
      throwsFormatException,
    );
    expect(
      () => OrderDeliveryEnvelope.create(
        clientInstallationId: 'client-1',
        deliveryId: 'delivery-1',
        ticketId: 'ticket-1',
        ticketNumber: 1,
        createdAt: DateTime.utc(2026, 10, 5),
        heading: '',
        reference: '',
        orderNote: '',
        courses: _courses,
        lines: const [
          DeliveryLine(name: 'Soup', quantity: 1, courseId: 'missing'),
        ],
      ),
      throwsFormatException,
    );
  });

  test(
    'preparation bytes and PDFs separate courses in their saved order',
    () async {
      final ticket = SavedTicket(
        id: 'ticket-1',
        number: 1,
        createdAt: DateTime.utc(2026, 10, 5),
        heading: 'Kitchen',
        reference: '',
        orderNote: '',
        courses: _courses,
        lines: const [
          TicketLine(id: 'main', name: 'Stew', quantity: 1, courseId: 'second'),
          TicketLine(
            id: 'starter',
            name: 'Soup',
            quantity: 2,
            courseId: 'first',
            preparationNote: 'No cream',
          ),
          TicketLine(id: 'drink', name: 'Water', quantity: 3),
        ],
      );
      final document = _document(ticket);
      final bytes = await const EscPosTicketEncoder().encode(document);
      final text = latin1.decode(bytes);
      expect(text.indexOf('Ungrouped'), lessThan(text.indexOf('3 x Water')));
      expect(text.indexOf('3 x Water'), lessThan(text.indexOf('First course')));
      expect(text.indexOf('First course'), lessThan(text.indexOf('2 x Soup')));
      expect(text.indexOf('2 x Soup'), lessThan(text.indexOf('Second course')));
      expect(text.indexOf('Second course'), lessThan(text.indexOf('1 x Stew')));
      expect(text, contains('No cream'));
      final pdf = await LocalTicketPdfSharer().build(
        document,
        subject: 'Preparation ticket',
      );
      expect(latin1.decode(pdf.take(4).toList()), '%PDF');
    },
  );

  for (final (language, compact, size, scale) in [
    ('en', false, const Size(1100, 900), 1.0),
    ('it', false, const Size(320, 740), 2.0),
    ('en', true, const Size(915, 412), 1.0),
    ('it', true, const Size(412, 915), 1.0),
  ]) {
    testWidgets(
      'courses compose and remain distinct in $language, compact $compact, size $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final settings = SettingsController(
          MemorySettingsRepository()
            ..stored = AppSettings(language: language, compactCompose: compact),
        );
        final orders = await createMemoryOrders();
        addTearDown(settings.dispose);
        addTearDown(orders.dispose);
        await settings.load();
        await orders.updateFeatureSettings(
          const OrderFeatureSettings(courseGroupsEnabled: true),
        );
        await orders.saveItem(name: 'Soup');
        await tester.pumpWidget(
          LibreSlipApp(settings: settings, orders: orders),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('nav-2')));
        await tester.pumpAndSettle();
        final item = find.byKey(
          ValueKey('compose-item-${orders.items.single.id}'),
        );
        await tester.ensureVisible(item);
        await tester.tap(item);
        await tester.pumpAndSettle();
        final add = find.byKey(const ValueKey('add-divider'));
        await tester.ensureVisible(add);
        await tester.pumpAndSettle();
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        final divider = orders.activeDraft!.courses.single;
        expect(divider.isDivider, isTrue);
        expect(
          find.byKey(ValueKey('order-divider-${divider.id}')),
          findsOneWidget,
        );
        expect(find.text(divider.name), findsNothing);
        await tester.ensureVisible(item);
        await tester.pumpAndSettle();
        await tester.tap(item);
        await tester.pumpAndSettle();
        expect(orders.activeDraft!.lines, hasLength(2));
        expect(orders.activeDraft!.lines.map((line) => line.quantity), [1, 1]);
        final headers = find.byType(CourseHeading);
        expect(headers, findsNWidgets(2));
        if (compact) {
          expect(
            tester
                .widget<Text>(
                  find.byKey(
                    ValueKey('compact-quantity-${orders.items.single.id}'),
                  ),
                )
                .data,
            '1',
          );
        }
        final line = orders.activeDraft!.lines.last;
        orders.setQuantity(line.id, 999);
        await tester.pumpAndSettle();
        for (final (key, quantity) in [
          ('line-minus-${line.id}', 998),
          ('line-plus-${line.id}', 999),
        ]) {
          final control = find.byKey(ValueKey(key));
          await tester.ensureVisible(control);
          await tester.pumpAndSettle();
          await tester.tap(control);
          await tester.pumpAndSettle();
          expect(orders.activeDraft!.lines.last.quantity, quantity);
        }
        for (final (key, courseId) in [
          ('line-above-divider-${line.id}', null),
          ('line-below-divider-${line.id}', divider.id),
        ]) {
          final control = find.byKey(ValueKey(key));
          await tester.ensureVisible(control);
          await tester.pumpAndSettle();
          await tester.tap(control);
          await tester.pumpAndSettle();
          expect(orders.activeDraft!.lines.last.courseId, courseId);
        }
        expect(find.byKey(const ValueKey('print-ticket')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

TicketDocument _document(SavedTicket ticket) => TicketDocument.fromTicket(
  ticket: ticket,
  fallbackHeading: 'Kitchen',
  ticketLabel: 'Ticket',
  createdAt: '5 October 2026',
  referenceLabel: 'Title',
  orderNotesLabel: 'Notes',
  lineNotePrefix: 'Note',
  footer: '',
  ungroupedLabel: 'Ungrouped',
);
