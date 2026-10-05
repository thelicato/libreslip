import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
import 'package:libreslip/features/networking/application/client_delivery_controller.dart';
import 'package:libreslip/features/networking/application/network_mode_controller.dart';
import 'package:libreslip/features/networking/application/server_inbox_controller.dart';
import 'package:libreslip/features/networking/domain/client_delivery_models.dart';
import 'package:libreslip/features/networking/domain/client_security.dart';
import 'package:libreslip/features/networking/domain/client_transport.dart';
import 'package:libreslip/features/networking/domain/server_security.dart';
import 'package:libreslip/features/networking/domain/server_transport.dart';
import 'package:libreslip/features/networking/domain/network_models.dart';
import 'package:libreslip/features/networking/domain/network_protocol.dart';
import 'package:libreslip/features/networking/domain/order_progress.dart';
import 'package:libreslip/features/networking/domain/server_inbox_models.dart';
import 'package:libreslip/features/portability/application/portability_controller.dart';
import 'package:libreslip/features/portability/application/portability_service.dart';
import 'package:libreslip/features/printing/application/printer_controller.dart';
import 'package:libreslip/features/printing/domain/printer_transport.dart';
import 'package:libreslip/features/printing/domain/ticket_typography.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:libreslip/features/orders/presentation/course_composer.dart';
import 'package:libreslip/features/settings/application/settings_controller.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';

import 'test_support.dart';

/// Opt-in render capture for review, without committing platform-sensitive goldens.
void main() {
  const capture = bool.fromEnvironment('LIBRESLIP_CAPTURE_PREVIEWS');
  testWidgets('capture representative workspace renders', skip: !capture, (
    tester,
  ) async {
    final previousHitTestSetting = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(
      () =>
          WidgetController.hitTestWarningShouldBeFatal = previousHitTestSetting,
    );
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config =
        jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    final flutter = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((package) => package['name'] == 'flutter');
    final package = configFile.uri.resolve(flutter['rootUri'] as String);
    final fonts = Directory.fromUri(package).uri
        .resolve('../../bin/cache/artifacts/material_fonts/');
    final loader = FontLoader('Roboto');
    for (final font in [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]) {
      final bytes = File.fromUri(fonts.resolve(font)).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
    final ticketLoader = FontLoader('RobotoTicket');
    for (final font in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
      final bytes = File.fromUri(fonts.resolve(font)).readAsBytesSync();
      ticketLoader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await ticketLoader.load();
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File.fromUri(fonts.resolve('MaterialIcons-Regular.otf'))
                .readAsBytesSync(),
          ),
        ),
      );
    await iconLoader.load();
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    for (final (name, size, language, mode, page) in [
      (
        'printer-optional-compose-tablet-en',
        const Size(1100, 900),
        'en',
        ThemeMode.light,
        2,
      ),
      (
        'printer-optional-compose-phone-it-large-text',
        const Size(320, 740),
        'it',
        ThemeMode.light,
        2,
      ),
      (
        'printer-optional-compose-landscape-en',
        const Size(915, 412),
        'en',
        ThemeMode.light,
        2,
      ),
      (
        'printer-optional-settings-phone-it-large-text',
        const Size(320, 740),
        'it',
        ThemeMode.light,
        4,
      ),
      (
        'printer-required-settings-tablet-en',
        const Size(1100, 1300),
        'en',
        ThemeMode.light,
        4,
      ),
      (
        'managed-printer-optional-compose-phone-it',
        const Size(520, 1300),
        'it',
        ThemeMode.light,
        2,
      ),
      ('phone-en', const Size(412, 915), 'en', ThemeMode.light, 0),
      (
        'overview-dashboard-phone-it',
        const Size(520, 1200),
        'it',
        ThemeMode.light,
        0,
      ),
      ('item-totals-phone-en', const Size(520, 1200), 'en', ThemeMode.light, 0),
      ('tablet-en', const Size(1440, 1000), 'en', ThemeMode.light, 0),
      ('compose-phone-en', const Size(520, 1200), 'en', ThemeMode.light, 2),
      ('compose-landscape-en', const Size(915, 412), 'en', ThemeMode.light, 2),
      (
        'compose-title-phone-it-large-text',
        const Size(320, 740),
        'it',
        ThemeMode.light,
        2,
      ),
      (
        'compose-compact-phone-it',
        const Size(412, 915),
        'it',
        ThemeMode.light,
        2,
      ),
      (
        'courses-compose-tablet-en',
        const Size(1440, 1200),
        'en',
        ThemeMode.light,
        2,
      ),
      (
        'courses-compose-phone-it',
        const Size(520, 1300),
        'it',
        ThemeMode.light,
        2,
      ),
      (
        'courses-compact-phone-it',
        const Size(520, 1300),
        'it',
        ThemeMode.light,
        2,
      ),
      (
        'courses-manage-phone-it-large-text',
        const Size(320, 740),
        'it',
        ThemeMode.light,
        2,
      ),
      (
        'courses-ticket-preview-phone-it',
        const Size(520, 1400),
        'it',
        ThemeMode.light,
        3,
      ),
      (
        'courses-server-phone-it',
        const Size(520, 1400),
        'it',
        ThemeMode.light,
        5,
      ),
      (
        'courses-server-tablet-en',
        const Size(1100, 1100),
        'en',
        ThemeMode.light,
        5,
      ),
      (
        'courses-server-dialog-tablet-en',
        const Size(1100, 1000),
        'en',
        ThemeMode.light,
        5,
      ),
      (
        'managed-compose-tablet-en',
        const Size(1440, 1200),
        'en',
        ThemeMode.light,
        2,
      ),
      (
        'managed-compact-phone-it',
        const Size(520, 1400),
        'it',
        ThemeMode.light,
        2,
      ),
      (
        'managed-compose-landscape-en',
        const Size(915, 412),
        'en',
        ThemeMode.light,
        2,
      ),
      (
        'managed-active-phone-it-large-text',
        const Size(320, 740),
        'it',
        ThemeMode.light,
        2,
      ),
      (
        'managed-ticket-preview-phone-it',
        const Size(520, 1400),
        'it',
        ThemeMode.light,
        3,
      ),
      (
        'managed-server-phone-it',
        const Size(520, 1400),
        'it',
        ThemeMode.light,
        5,
      ),
      (
        'managed-server-dialog-tablet-en',
        const Size(1100, 1200),
        'en',
        ThemeMode.light,
        5,
      ),
      (
        'managed-delivery-active-tablet-en',
        const Size(1100, 1100),
        'en',
        ThemeMode.light,
        2,
      ),
      (
        'managed-delivery-active-phone-it',
        const Size(520, 1300),
        'it',
        ThemeMode.light,
        2,
      ),
      (
        'managed-delivery-active-phone-it-large-text',
        const Size(320, 740),
        'it',
        ThemeMode.light,
        2,
      ),
      (
        'managed-delivery-active-landscape-en',
        const Size(915, 412),
        'en',
        ThemeMode.light,
        2,
      ),
      (
        'managed-delivery-server-dialog-tablet-en',
        const Size(1100, 1200),
        'en',
        ThemeMode.light,
        5,
      ),
      (
        'managed-delivery-server-dialog-phone-it',
        const Size(520, 1400),
        'it',
        ThemeMode.light,
        5,
      ),
      (
        'managed-delivery-server-dialog-landscape-en',
        const Size(915, 412),
        'en',
        ThemeMode.light,
        5,
      ),
      (
        'managed-progress-sync-tablet-en',
        const Size(1100, 1300),
        'en',
        ThemeMode.light,
        2,
      ),
      (
        'managed-progress-sync-conflict-phone-it',
        const Size(520, 1500),
        'it',
        ThemeMode.light,
        2,
      ),
      (
        'managed-progress-sync-conflict-phone-it-large-text',
        const Size(320, 740),
        'it',
        ThemeMode.light,
        2,
      ),
      (
        'managed-progress-sync-conflict-landscape-en',
        const Size(915, 412),
        'en',
        ThemeMode.light,
        2,
      ),
      (
        'managed-progress-sync-unsupported-phone-it',
        const Size(520, 1300),
        'it',
        ThemeMode.light,
        2,
      ),
      (
        'managed-progress-sync-success-tablet-en',
        const Size(1100, 1300),
        'en',
        ThemeMode.light,
        2,
      ),
      (
        'prices-compose-tablet-en',
        const Size(1100, 1300),
        'en',
        ThemeMode.light,
        2,
      ),
      (
        'prices-compose-phone-it',
        const Size(520, 1500),
        'it',
        ThemeMode.light,
        2,
      ),
      (
        'prices-compose-phone-it-large-text',
        const Size(320, 740),
        'it',
        ThemeMode.light,
        2,
      ),
      (
        'prices-compose-landscape-en',
        const Size(915, 412),
        'en',
        ThemeMode.light,
        2,
      ),
      (
        'prices-compact-phone-it',
        const Size(520, 1500),
        'it',
        ThemeMode.light,
        2,
      ),
      (
        'prices-editor-phone-it-large-text',
        const Size(320, 740),
        'it',
        ThemeMode.light,
        1,
      ),
      (
        'prices-history-tablet-en',
        const Size(1100, 1500),
        'en',
        ThemeMode.light,
        3,
      ),
      (
        'prices-compose-complete-tablet-en',
        const Size(1100, 1300),
        'en',
        ThemeMode.light,
        2,
      ),
      (
        'prices-editor-phone-it',
        const Size(520, 1300),
        'it',
        ThemeMode.light,
        1,
      ),
      ('items-tablet-it', const Size(1100, 1000), 'it', ThemeMode.dark, 1),
      ('tickets-tablet-en', const Size(1100, 1000), 'en', ThemeMode.light, 3),
      (
        'ticket-preview-phone-it',
        const Size(520, 1200),
        'it',
        ThemeMode.light,
        3,
      ),
      ('settings-it-dark', const Size(1000, 1300), 'it', ThemeMode.dark, 4),
      ('portability-phone-en', const Size(520, 1100), 'en', ThemeMode.light, 4),
      (
        'client-server-settings-phone-en',
        const Size(520, 1100),
        'en',
        ThemeMode.light,
        4,
      ),
      (
        'pair-server-dialog-phone-en',
        const Size(520, 1100),
        'en',
        ThemeMode.light,
        4,
      ),
      (
        'server-inbox-phone-it',
        const Size(520, 1100),
        'it',
        ThemeMode.light,
        5,
      ),
      (
        'server-inbox-tablet-en',
        const Size(1100, 900),
        'en',
        ThemeMode.light,
        5,
      ),
      (
        'server-order-dialog-tablet-en',
        const Size(1100, 900),
        'en',
        ThemeMode.light,
        5,
      ),
      (
        'server-completed-dialog-tablet-en',
        const Size(1100, 900),
        'en',
        ThemeMode.light,
        5,
      ),
      (
        'server-settings-phone-en',
        const Size(520, 1100),
        'en',
        ThemeMode.light,
        5,
      ),
    ]) {
      final managedPreview = name.startsWith('managed-');
      final pricePreview = name.startsWith('prices-');
      final groupedPreview = name.startsWith('courses-') || managedPreview;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue =
          name.endsWith('large-text') ? 2 : 1;
      final settingsStore = MemorySettingsRepository()
        ..stored = AppSettings(
          language: language,
          printerConnectionRequired: !name.contains('printer-optional'),
          themeMode: mode,
          typography: name == 'ticket-preview-phone-it'
              ? const TicketTypography(
                  heading: 20,
                  details: 10,
                  items: 12,
                  notes: 9,
                  footer: 11,
                )
              : const TicketTypography(),
          compactCompose:
              name == 'prices-compact-phone-it' ||
              name == 'compose-compact-phone-it' ||
              name == 'courses-compact-phone-it' ||
              name == 'managed-compact-phone-it',
        );
      final controller = SettingsController(settingsStore);
      await controller.load();
      final environment = await createMemoryOrderEnvironment();
      final orders = environment.controller;
      final networking = NetworkModeController(environment.repository);
      ServerInboxController? inbox;
      await networking.load();
      final progressTransport = _FakeClientTransport();
      final clientDelivery = ClientDeliveryController(
        environment.repository,
        _MemoryClientSecrets(),
        progressTransport,
      );
      await clientDelivery.load();
      if (name == 'client-server-settings-phone-en' ||
          name.contains('progress-sync')) {
        await clientDelivery.pair(
          configuration: networking.configuration!,
          address: '192.168.1.42:5119',
          clientName: 'Front counter',
        );
      }
      if (page == 5) {
        await networking.setMode(LibreSlipMode.server);
        await environment.repository.pairClient(
          PairedClient(
            installationId: 'preview-client',
            displayName: 'Banco principale',
            identityFingerprint: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            pairedAt: DateTime.utc(2026, 9, 24, 18),
          ),
        );
        await environment.repository.receiveServerOrder(
          OrderDeliveryEnvelope.create(
            clientInstallationId: 'preview-client',
            deliveryId: 'preview-delivery',
            managedOrderId: managedPreview ? 'preview-managed' : null,
            revision: managedPreview ? 1 : 0,
            ticketId: 'preview-ticket',
            ticketNumber: 12,
            createdAt: DateTime.utc(2026, 9, 24, 18, 30),
            heading: 'Cucina',
            reference: 'Tavolo 4',
            orderNote: 'Portare insieme',
            courses: groupedPreview
                ? const [
                    OrderCourse(id: 'first', name: 'Primo'),
                    OrderCourse(id: 'second', name: 'Secondo'),
                  ]
                : const [],
            lines: [
              DeliveryLine(
                id: managedPreview ? 'toast-line' : null,
                name: 'Toast ai funghi',
                quantity: 2,
                preparationNote: 'Senza cipolla',
                courseId: groupedPreview ? 'first' : null,
              ),
              if (groupedPreview)
                DeliveryLine(
                  id: managedPreview ? 'vegetables-line' : null,
                  name: 'Verdure arrosto',
                  quantity: 1,
                  courseId: 'second',
                ),
            ],
          ),
          receivedAt: DateTime.utc(2026, 9, 24, 18, 31),
        );
        if (managedPreview) {
          final previous =
              (await environment.repository.loadServerOrders()).single;
          await environment.repository.markServerOrderDone(
            previous.id,
            completedAt: DateTime.utc(2026, 9, 24, 18, 34),
          );
          await environment.repository.receiveServerOrder(
            OrderDeliveryEnvelope.create(
              clientInstallationId: 'preview-client',
              deliveryId: 'preview-managed-addition',
              ticketId: 'preview-ticket-addition',
              ticketNumber: 12,
              createdAt: DateTime.utc(2026, 9, 24, 18, 30),
              heading: 'Cucina',
              reference: 'Tavolo 4',
              orderNote: 'Portare insieme',
              managedOrderId: 'preview-managed',
              revision: 2,
              courses: const [
                OrderCourse(id: 'first', name: 'Primo'),
                OrderCourse(id: 'second', name: 'Secondo'),
                OrderCourse(id: 'drinks', name: 'Bevande'),
              ],
              lines: const [
                DeliveryLine(
                  id: 'toast-line',
                  name: 'Toast ai funghi',
                  quantity: 2,
                  preparationNote: 'Senza cipolla',
                  courseId: 'first',
                ),
                DeliveryLine(
                  id: 'vegetables-line',
                  name: 'Verdure arrosto',
                  quantity: 1,
                  courseId: 'second',
                ),
                DeliveryLine(
                  id: 'water-line',
                  name: 'Acqua naturale',
                  quantity: 2,
                  courseId: 'drinks',
                ),
              ],
            ),
            receivedAt: DateTime.utc(2026, 9, 24, 18, 35),
          );
        }
        await environment.repository.receiveServerOrder(
          OrderDeliveryEnvelope.create(
            clientInstallationId: 'preview-client',
            deliveryId: 'preview-delivery-2',
            ticketId: 'preview-ticket-2',
            ticketNumber: 13,
            createdAt: DateTime.utc(2026, 9, 24, 18, 32),
            heading: 'Cucina',
            reference: 'Tavolo 7',
            orderNote: '',
            lines: const [
              DeliveryLine(name: 'Soup', quantity: 1),
              DeliveryLine(name: 'Tea', quantity: 3),
            ],
          ),
          receivedAt: DateTime.utc(2026, 9, 24, 18, 33),
        );
        if (name == 'server-completed-dialog-tablet-en') {
          final order = (await environment.repository.loadServerOrders())
              .firstWhere((order) => order.displayNumber == 12);
          await environment.repository.markServerOrderDone(
            order.id,
            completedAt: DateTime.utc(2026, 9, 24, 18, 40),
          );
        }
        final secrets = _MemoryServerSecrets();
        inbox = ServerInboxController(
          environment.repository,
          secrets,
          _FakeServerHost(),
        );
      }
      final portability = PortabilityController(
        PortabilityService(environment.repository, settingsStore),
        controller,
        orders,
      );
      final printer = PrinterController(_PreviewPrinterTransport());
      if (pricePreview) {
        await orders.updateFeatureSettings(
          const OrderFeatureSettings(pricesEnabled: true),
        );
      }
      if (page >= 1 && page <= 3) {
        await orders.saveItem(
          name: groupedPreview ? 'Tomato soup' : 'Mushroom toastie',
          categoryName: language == 'it' ? 'Cucina' : 'Kitchen',
          sendToServer: name != 'items-tablet-it',
          price: pricePreview
              ? const ProductPrice(minorUnits: 850, currency: 'EUR')
              : null,
        );
      }
      if (name == 'item-totals-phone-en') {
        for (final (itemName, quantity) in [
          ('Mushroom toastie', 5),
          ('Tomato soup', 3),
          ('Tea', 2),
          ('Still water', 1),
        ]) {
          await orders.saveItem(name: itemName);
          final item = orders.items.singleWhere(
            (item) => item.name == itemName,
          );
          orders.addCatalogueItem(item);
          orders.setQuantity(orders.activeDraft!.lines.last.id, quantity);
        }
        await orders.flushWrites();
        await orders.saveActiveTicket(heading: 'Corner & Co.');
      }
      if (name == 'overview-dashboard-phone-it') {
        await orders.saveItem(name: 'Toast ai funghi', categoryName: 'Cucina');
        orders.addCatalogueItem(orders.items.single);
        orders.setQuantity(orders.activeDraft!.lines.single.id, 3);
        await orders.flushWrites();
        await orders.saveActiveTicket(heading: 'Bottega Libertà');
      }
      if (page == 2 || page == 3) {
        if (groupedPreview) {
          await orders.updateFeatureSettings(
            OrderFeatureSettings(
              courseGroupsEnabled: true,
              managedOrdersEnabled: managedPreview,
            ),
          );
          orders.saveCourse(language == 'it' ? 'Primo' : 'First course');
        }
        orders.addCatalogueItem(orders.items.single);
        if (pricePreview) {
          orders.setQuantity(orders.activeDraft!.lines.single.id, 2);
          await orders.saveItem(
            name: language == 'it' ? 'Acqua naturale' : 'Still water',
            price: const ProductPrice(minorUnits: 0, currency: 'EUR'),
          );
          orders.addCatalogueItem(
            orders.items.singleWhere((item) => item.price?.minorUnits == 0),
          );
          await orders.saveItem(
            name: language == 'it' ? 'Pane' : 'Bread',
            price: name.contains('complete')
                ? const ProductPrice(minorUnits: 300, currency: 'GBP')
                : null,
          );
          orders.addCatalogueItem(
            orders.items.singleWhere(
              (item) => item.name == (language == 'it' ? 'Pane' : 'Bread'),
            ),
          );
        }
        orders.setReference(
          name == 'compose-title-phone-it-large-text'
              ? 'Tavolo 4, giardino vicino alla terrazza'
              : language == 'it'
              ? 'Tavolo 4'
              : 'Table 4',
        );
        orders.setOrderNote(
          language == 'it' ? 'Portare insieme' : 'Bring together',
        );
        if (groupedPreview) {
          orders.setQuantity(orders.activeDraft!.lines.single.id, 2);
          orders.setPreparationNote(
            orders.activeDraft!.lines.single.id,
            language == 'it' ? 'Uno senza pane' : 'One without bread',
          );
          orders.saveCourse(language == 'it' ? 'Secondo' : 'Second course');
          await orders.saveItem(
            name: language == 'it' ? 'Verdure arrosto' : 'Roast vegetables',
          );
          orders.addCatalogueItem(
            orders.items.singleWhere((item) => item.name != 'Tomato soup'),
          );
        }

        await orders.flushWrites();
      }
      if (managedPreview && (page == 2 || page == 3)) {
        await orders.saveActiveTicket(heading: 'Corner & Co.');
        if (name != 'managed-active-phone-it-large-text' &&
            !name.contains('delivery-active') &&
            !name.contains('progress-sync')) {
          await orders.beginAddition(orders.managedOrders.single.id);
          orders.saveCourse(language == 'it' ? 'Bevande' : 'Drinks');
          await orders.saveItem(
            name: language == 'it' ? 'Acqua naturale' : 'Still water',
          );
          orders.addCatalogueItem(
            orders.items.singleWhere(
              (item) =>
                  item.name ==
                  (language == 'it' ? 'Acqua naturale' : 'Still water'),
            ),
          );
          orders.setQuantity(orders.activeDraft!.lines.single.id, 2);
          await orders.flushWrites();
        }
      }
      if (page == 3) {
        await orders.saveActiveTicket(heading: 'Corner & Co.');
      }
      if (name.contains('delivery-active')) {
        final order = orders.managedOrders.single;
        await orders.setLineDelivered(
          order.id,
          order.lines.first.id,
          1,
          expectedQuantity: 0,
        );
        await orders.setLineDelivered(
          order.id,
          order.lines.last.id,
          1,
          expectedQuantity: 0,
        );
      }
      if (name.contains('delivery-server')) {
        final order = (await environment.repository.loadServerOrders())
            .firstWhere((order) => order.managedOrderId != null);
        await environment.repository.setServerLineDelivered(
          order.id,
          'toast-line',
          1,
          expectedQuantity: 2,
        );
      }
      if (name.contains('progress-sync')) {
        final order = orders.managedOrders.single;
        progressTransport.progressOrder = order;
        progressTransport.unsupportedProgress = name.contains('unsupported');
        if (name.contains('conflict')) {
          progressTransport.progressRevision = 1;
          progressTransport.progressQuantities = {
            for (final line in order.lines)
              line.id: line == order.lines.first ? 2 : 0,
          };
          await orders.setLineDelivered(
            order.id,
            order.lines.first.id,
            1,
            expectedQuantity: 0,
          );
        } else if (name.contains('success')) {
          await orders.setLineDelivered(
            order.id,
            order.lines.first.id,
            1,
            expectedQuantity: 0,
          );
        }
      }
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: LibreSlipApp(
            settings: controller,
            orders: orders,
            networking: networking,
            serverInbox: inbox,
            clientDelivery: clientDelivery,
            printer: printer,
            portability: portability,
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (page >= 1 && page <= 4) {
        await tester.tap(find.byKey(ValueKey('nav-$page')));
        await tester.pumpAndSettle();
      }
      if (name.startsWith('printer-') && page == 4) {
        await tester.ensureVisible(
          find.byKey(const ValueKey('toggle-printer-required')),
        );
        await tester.pumpAndSettle();
      }
      if (pricePreview && page == 1) {
        await tester.tap(find.text('Mushroom toastie'));
        await tester.pumpAndSettle();
        final field = find.byKey(const ValueKey('item-price'));
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
      }
      if (pricePreview && page == 2) {
        await tester.ensureVisible(
          find.byKey(const ValueKey('order-estimate')),
        );
        await tester.pumpAndSettle();
      }
      if (pricePreview && page == 3) {
        await tester.tap(find.text('View ticket'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('order-estimate')),
        );
        await tester.pumpAndSettle();
      }
      if (name == 'compose-title-phone-it-large-text' ||
          name == 'compose-landscape-en') {
        await tester.ensureVisible(
          find.text(orders.activeDraft!.reference).first,
        );
        await tester.pumpAndSettle();
      }
      if (managedPreview && page == 2) {
        if (name == 'managed-active-phone-it-large-text' ||
            name.contains('delivery-active') ||
            name.contains('progress-sync')) {
          final active = find.byKey(const ValueKey('active-orders'));
          await tester.ensureVisible(active);
          await tester.pumpAndSettle();
          await tester.tap(active);
          await tester.pumpAndSettle();
          if (name.contains('delivery-active') ||
              name.contains('progress-sync')) {
            final expansion = find.byType(ExpansionTile).last;
            await tester.ensureVisible(expansion);
            await tester.tap(expansion);
            await tester.pumpAndSettle();
            if (name.contains('progress-sync') &&
                (name.contains('conflict') ||
                    name.contains('unsupported') ||
                    name.contains('success'))) {
              final sync = find.byKey(
                ValueKey('sync-progress-${orders.managedOrders.single.id}'),
              );
              await tester.ensureVisible(sync);
              await tester.pumpAndSettle();
              await tester.tap(sync);
              await tester.pumpAndSettle();
            }
            if (name.contains('progress-sync') &&
                (size.width < 760 || size.height < 600)) {
              final target = name.contains('conflict')
                  ? find.byKey(
                      ValueKey(
                        'progress-use-server-${orders.managedOrders.single.id}',
                      ),
                    )
                  : find.byKey(
                      ValueKey(
                        'sync-progress-${orders.managedOrders.single.id}',
                      ),
                    );
              await tester.ensureVisible(target);
              await tester.pumpAndSettle();
            }
            if (!name.contains('progress-sync') &&
                (size.width < 760 || size.height < 600)) {
              await tester.ensureVisible(
                find.byKey(
                  ValueKey(
                    'delivery-line-${orders.managedOrders.single.lines.first.id}',
                  ),
                ),
              );
              await tester.pumpAndSettle();
            }
          }
        }
      } else if (groupedPreview && page == 2) {
        if (name == 'courses-manage-phone-it-large-text') {
          final manage = find.byKey(const ValueKey('manage-courses'));
          await tester.ensureVisible(manage);
          await tester.tap(manage);
          await tester.pumpAndSettle();
        } else if (size.width < 760) {
          await tester.ensureVisible(find.byType(CourseHeading).first);
          await tester.pumpAndSettle();
        }
      }
      if (name == 'item-totals-phone-en') {
        final totalsButton = find.byKey(const ValueKey('view-item-totals'));
        await tester.ensureVisible(totalsButton);
        await tester.tap(totalsButton);
        await tester.pumpAndSettle();
      }
      if (name == 'server-order-dialog-tablet-en' ||
          name == 'courses-server-dialog-tablet-en' ||
          name == 'managed-server-dialog-tablet-en' ||
          name.contains('delivery-server-dialog')) {
        final identity = find.text(language == 'it' ? 'Ordine 12' : 'Order 12');
        // Use the stored title because the Italian order-number label differs.
        if (name.contains('delivery-server-dialog')) {
          final card = find.byKey(
            ValueKey(
              'server-order-${inbox!.orders.firstWhere((order) => order.displayNumber == 12).id}',
            ),
          );
          await tester.scrollUntilVisible(
            card,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          final title = find.descendant(
            of: card,
            matching: find.text('Tavolo 4'),
          );
          await tester.ensureVisible(title);
          await tester.pumpAndSettle();
          await tester.tap(title);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          if (size.width < 760 || size.height < 600) {
            await tester.ensureVisible(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.byKey(
                  const ValueKey('delivery-line-toast-line'),
                ),
              ),
            );
            await tester.pumpAndSettle();
          }
        } else {
          await tester.tap(identity);
          await tester.pumpAndSettle();
        }
      }
      if (name == 'server-completed-dialog-tablet-en') {
        await tester.tap(find.text('Completed (1)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Order 12'));
        await tester.pumpAndSettle();
      }
      if (name == 'server-settings-phone-en') {
        await tester.tap(find.byKey(const ValueKey('server-tab-settings')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('app-version')),
          500,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      }
      if (name == 'ticket-preview-phone-it' ||
          name == 'courses-ticket-preview-phone-it' ||
          name == 'managed-ticket-preview-phone-it') {
        await tester.tap(find.text('Comanda 1').first);
        await tester.pumpAndSettle();
      }
      if (name == 'overview-dashboard-phone-it') {
        await tester.drag(
          find.byKey(const ValueKey('page-0')),
          const Offset(0, -1250),
        );
        await tester.pumpAndSettle();
      }
      if (name == 'portability-phone-en') {
        await tester.drag(
          find.byKey(const ValueKey('page-4')),
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
      }
      if (name == 'client-server-settings-phone-en') {
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('client-server-settings')),
          500,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      }
      if (name == 'pair-server-dialog-phone-en') {
        final pairButton = find.byKey(const ValueKey('pair-server'));
        await tester.scrollUntilVisible(
          pairButton,
          500,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(pairButton);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/previews/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
      portability.dispose();
      printer.dispose();
      clientDelivery.dispose();
      networking.dispose();
      inbox?.dispose();
      controller.dispose();
      orders.dispose();
    }
  });
}

class _PreviewPrinterTransport implements PrinterTransport {
  @override
  Future<void> connect(String address) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<BluetoothHostState> getState() async => const BluetoothHostState(
    status: BluetoothHostStatus.ready,
    devices: [
      PairedPrinter(name: 'NETUM NT-1809DD', address: '00:11:22:33:44:55'),
    ],
  );

  @override
  Future<void> openBluetoothSettings() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<int> send(Uint8List bytes, {int chunkSize = 256}) async =>
      bytes.length;
}

class _MemoryClientSecrets implements ClientSecretStore {
  final tokens = <String, String>{};

  @override
  Future<void> deleteServerAccessToken(String serverId) async {
    tokens.remove(serverId);
  }

  @override
  Future<String?> readServerAccessToken(String serverId) async =>
      tokens[serverId];

  @override
  Future<void> writeServerAccessToken(String serverId, String token) async {
    tokens[serverId] = token;
  }
}

class _FakeClientTransport
    implements ClientServerTransport, OrderProgressTransport {
  ManagedOrder? progressOrder;
  bool unsupportedProgress = false;
  int progressRevision = 0;
  Map<String, int> progressQuantities = {};
  final _progressReceipts = <String, OrderProgressSnapshot>{};

  OrderProgressSnapshot get _progressSnapshot {
    final order = progressOrder!;
    return OrderProgressSnapshot(
      clientId: order.clientInstallationId!,
      orderId: order.id,
      orderRevision: order.serverRevision,
      progressRevision: progressRevision,
      quantities: {
        for (final line in order.lines.where((line) => line.sendToServer))
          line.id: progressQuantities[line.id] ?? 0,
      },
    );
  }

  @override
  Future<OrderProgressSnapshot> fetchProgress({
    required PairedServer server,
    required String accessToken,
    required String clientId,
    required String orderId,
  }) async {
    if (unsupportedProgress) {
      throw const ClientTransportException('unsupported_progress');
    }
    return _progressSnapshot;
  }

  @override
  Future<OrderProgressSnapshot> changeProgress({
    required PairedServer server,
    required String accessToken,
    required String clientId,
    required OrderProgressChange change,
  }) async {
    final previous = _progressReceipts[change.operationId];
    if (previous != null) return previous;
    progressQuantities = change.quantities;
    progressRevision++;
    final result = _progressSnapshot;
    _progressReceipts[change.operationId] = result;
    return result;
  }

  @override
  Future<PairServerResult> pair(PairServerRequest request) async {
    final now = DateTime.utc(2026, 9, 25, 8);
    return PairServerResult(
      server: PairedServer(
        id: 'preview-server',
        displayName: 'Kitchen tablet',
        baseUrl: request.baseUrl,
        certificateFingerprint:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        createdAt: now,
        updatedAt: now,
      ),
      accessToken: 'preview-token',
    );
  }

  @override
  Future<DeliveryAcknowledgement> deliver({
    required PairedServer server,
    required String accessToken,
    required ClientDelivery delivery,
  }) async => DeliveryAcknowledgement(
    deliveryId: delivery.id,
    serverOrderId: 'preview-order',
    duplicate: false,
  );
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
      const RunningServer(port: 5119, addresses: ['https://192.168.1.42:5119']);

  @override
  Future<void> stop() async {}
}
