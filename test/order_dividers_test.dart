import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/orders/application/order_workspace_controller.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:libreslip/features/orders/presentation/course_composer.dart';
import 'package:libreslip/features/networking/domain/network_protocol.dart';
import 'package:libreslip/features/networking/domain/server_inbox_models.dart';
import 'package:libreslip/features/printing/application/esc_pos_ticket_encoder.dart';
import 'package:libreslip/features/printing/application/ticket_pdf_sharer.dart';
import 'package:libreslip/features/printing/domain/print_job.dart';
import 'package:libreslip/features/printing/domain/ticket_document.dart';
import 'package:libreslip/features/portability/application/portability_service.dart';
import 'package:libreslip/features/portability/domain/portability_models.dart';
import 'package:libreslip/l10n/generated/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_support.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('divider composition recovers, merges without loss and starts the next order empty', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'libreslip-dividers-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final repository = SqliteOrderRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: '${temporary.path}/orders.sqlite3',
    );
    var orders = OrderWorkspaceController(repository);
    addTearDown(orders.dispose);
    await orders.load();
    expect(orders.addDivider(), isFalse);
    await orders.updateFeatureSettings(
      const OrderFeatureSettings(
        courseGroupsEnabled: true,
        managedOrdersEnabled: true,
      ),
    );
    expect(orders.addDivider(), isFalse);
    await orders.saveItem(name: 'Soup');
    orders.addCatalogueItem(orders.items.single);
    final first = orders.activeDraft!.lines.single;
    orders.setPreparationNote(first.id, 'No cream');
    expect(orders.addDivider(), isTrue);
    final divider = orders.activeDraft!.courses.single;
    expect(orders.addDivider(), isFalse);
    orders.addCatalogueItem(orders.items.single);
    final second = orders.activeDraft!.lines.last;
    orders.setQuantity(second.id, 3);
    orders.setPreparationNote(second.id, 'Extra bread');
    expect(orders.addDivider(), isTrue);
    final lastDivider = orders.activeDraft!.courses.last;
    await orders.saveItem(name: 'Water');
    orders.addCatalogueItem(
      orders.items.singleWhere((item) => item.name == 'Water'),
    );
    await orders.flushWrites();
    await repository.close();
    orders = OrderWorkspaceController(repository);
    addTearDown(orders.dispose);
    await orders.load();
    expect(orders.activeDraft!.activeCourseId, lastDivider.id);
    expect(
      orders.activeDraft!.courses.every((course) => course.isDivider),
      isTrue,
    );
    orders.removeDivider(lastDivider.id);
    expect(orders.activeDraft!.courses.single.id, divider.id);
    expect(orders.activeDraft!.lines.map((line) => line.courseId), [
      null,
      divider.id,
      divider.id,
    ]);
    expect(orders.activeDraft!.lines.map((line) => line.quantity), [1, 3, 1]);
    expect(orders.activeDraft!.lines.map((line) => line.preparationNote), [
      'No cream',
      'Extra bread',
      '',
    ]);
    final ticket = (await orders.saveActiveTicket(heading: 'Kitchen'))!;
    expect(orders.activeDraft!.courses, isEmpty);
    expect(orders.activeDraft!.activeCourseId, isNull);
    final bytes = await const EscPosTicketEncoder().encode(_document(ticket));
    final text = latin1.decode(bytes);
    expect(
      text.substring(text.indexOf('1 x Soup')),
      isNot(contains(divider.name)),
    );
    expect(text, isNot(contains('Ungrouped')));
    expect(text.indexOf('1 x Soup'), lessThan(text.indexOf('3 x Soup')));
    expect(
      text.substring(text.indexOf('No cream'), text.indexOf('3 x Soup')),
      contains('----'),
    );
    final pdf = await LocalTicketPdfSharer().build(
      _document(ticket),
      subject: 'Preparation',
    );
    expect(latin1.decode(pdf.take(4).toList()), '%PDF');
    final job = await repository.createPrintJob(
      requestId: 'divider-print',
      ticketId: ticket.id,
      payload: bytes,
    );
    await repository.markPrintJobSending(
      job.id,
      printerAddress: 'preview',
      printerName: 'Preview',
    );
    await repository.close();
    orders = OrderWorkspaceController(repository);
    addTearDown(orders.dispose);
    await orders.load();
    expect(
      (await repository.loadPrintJobs()).single.status,
      PrintJobStatus.uncertain,
    );
    expect((await repository.loadPrintJobs()).single.payload, bytes);
    expect(await orders.beginAddition(orders.managedOrders.single.id), isTrue);
    expect(orders.addDivider(), isTrue);
    orders.removeDivider(divider.id);
    expect(orders.activeDraft!.courses.first.id, divider.id);
    orders.addCatalogueItem(
      orders.items.singleWhere((item) => item.name == 'Water'),
    );
    final update = (await orders.saveActiveTicket(heading: 'Kitchen'))!;
    expect(update.revision, 2);
    expect(update.courses.first.toJson(), divider.toJson());
    expect(
      (await repository.loadTickets())
          .firstWhere((saved) => saved.id == ticket.id)
          .courses
          .single
          .toJson(),
      divider.toJson(),
    );
  });

  test(
    'divider metadata round-trips through backups and Server receipt',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'libreslip-divider-backup-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final environment = await createMemoryOrderEnvironment();
      final orders = environment.controller;
      final repository = environment.repository;
      addTearDown(orders.dispose);
      await orders.updateFeatureSettings(
        const OrderFeatureSettings(courseGroupsEnabled: true),
      );
      await orders.saveItem(name: 'Tea');
      orders.addCatalogueItem(orders.items.single);
      orders.addDivider();
      orders.addCatalogueItem(orders.items.single);
      final draft = orders.activeDraft!;
      await orders.flushWrites();
      final service = PortabilityService(
        repository,
        MemorySettingsRepository(),
        supportDirectory: () async => temporary,
        temporaryDirectory: () async => temporary,
        appVersion: () => File('VERSION').readAsString(),
      );
      final archive = await service.createArchive(
        PortableArchiveKind.fullBackup,
      );
      orders.removeDivider(draft.courses.single.id);
      await orders.flushWrites();
      await service.restore(await service.inspectArchive(archive));
      final restored = (await repository.loadDrafts()).single;
      expect(restored.courses.single.isDivider, isTrue);
      expect(restored.activeCourseId, draft.activeCourseId);
      expect(
        restored.lines.map((line) => line.courseId),
        draft.lines.map((line) => line.courseId),
      );
      final envelope = OrderDeliveryEnvelope.create(
        clientInstallationId: 'client-1',
        deliveryId: 'divider-delivery',
        ticketId: 'divider-ticket',
        ticketNumber: 1,
        createdAt: DateTime.utc(2026, 10, 5),
        heading: 'Kitchen',
        reference: 'Table 4',
        orderNote: '',
        courses: draft.courses,
        lines: [
          for (final line in draft.lines)
            DeliveryLine(
              name: line.name,
              quantity: line.quantity,
              courseId: line.courseId,
            ),
        ],
      );
      final decoded = OrderDeliveryEnvelope.fromJsonString(
        envelope.toJsonString(),
      );
      expect(decoded.courses.single.isDivider, isTrue);
      expect(decoded.toJsonString(), envelope.toJsonString());
      await repository.pairClient(
        PairedClient(
          installationId: 'client-1',
          displayName: 'Counter',
          identityFingerprint: 'b' * 64,
          pairedAt: DateTime.utc(2026, 10, 5),
        ),
      );
      await repository.receiveServerOrder(
        decoded,
        receivedAt: DateTime.utc(2026, 10, 5),
      );
      final received = (await repository.loadServerOrders()).single;
      expect(received.courses.single.isDivider, isTrue);
      expect(received.lines.map((line) => line.courseId), [
        null,
        draft.courses.single.id,
      ]);
      expect(
        (await repository.receiveServerOrder(
          decoded,
          receivedAt: DateTime.utc(2026, 10, 5),
        )).wasDuplicate,
        isTrue,
      );
      expect(await repository.loadServerOrders(), hasLength(1));
    },
  );

  testWidgets('divider has a localised semantic label and no visible name', (
    tester,
  ) async {
    final divider = OrderCourse.divider(id: 'sample', ordinal: 1);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CourseHeading(course: divider, courses: [divider]),
        ),
      ),
    );
    expect(find.text('#1'), findsNothing);
    expect(find.bySemanticsLabel('Order divider'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
