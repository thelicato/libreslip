import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
import 'package:libreslip/features/networking/application/network_mode_controller.dart';
import 'package:libreslip/features/networking/application/server_inbox_controller.dart';
import 'package:libreslip/features/networking/domain/server_security.dart';
import 'package:libreslip/features/networking/domain/server_transport.dart';
import 'package:libreslip/features/orders/data/sqlite_order_repository.dart';
import 'package:libreslip/features/networking/domain/network_models.dart';
import 'package:libreslip/features/settings/application/settings_controller.dart';
import 'package:libreslip/features/settings/domain/app_settings.dart';

import 'test_support.dart';

void main() {
  test('mode controller persists an explicit mode change', () async {
    final store = _MemoryNetworkStore();
    final first = NetworkModeController(store);
    addTearDown(first.dispose);
    await first.load();

    expect(first.mode, LibreSlipMode.client);
    expect(await first.setMode(LibreSlipMode.server), isTrue);

    final reopened = NetworkModeController(store);
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.mode, LibreSlipMode.server);
    expect(reopened.configuration!.installationId, 'installation-test');
  });

  test('failed mode persistence keeps the current mode', () async {
    final store = _MemoryNetworkStore()..failSave = true;
    final controller = NetworkModeController(store);
    addTearDown(controller.dispose);
    await controller.load();

    expect(await controller.setMode(LibreSlipMode.server), isFalse);
    expect(controller.mode, LibreSlipMode.client);
    expect(controller.saveFailed, isTrue);
  });

  test('foreground stop wins a concurrent listener start', () async {
    final environment = await createMemoryOrderEnvironment();
    final networking = NetworkModeController(environment.repository);
    final host = _DelayedServerHost();
    final inbox = ServerInboxController(
      environment.repository,
      _MemoryServerSecrets(),
      host,
    );
    addTearDown(environment.controller.dispose);
    addTearDown(networking.dispose);
    addTearDown(inbox.dispose);
    await networking.load();

    final starting = inbox.start(networking.configuration!);
    await host.entered.future;
    await inbox.stop();
    host.release.complete();
    await starting;

    expect(inbox.listening, isFalse);
    expect(host.stopCalls, 2);
  });

  testWidgets('confirmed mode changes replace and restore the client shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = SettingsController(MemorySettingsRepository());
    final environment = await createMemoryOrderEnvironment();
    final networking = NetworkModeController(environment.repository);
    final inbox = _memoryInbox(environment.repository);
    addTearDown(settings.dispose);
    addTearDown(environment.controller.dispose);
    addTearDown(networking.dispose);
    addTearDown(inbox.dispose);
    await settings.load();
    await networking.load();

    await tester.pumpWidget(
      LibreSlipApp(
        settings: settings,
        orders: environment.controller,
        networking: networking,
        serverInbox: inbox,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-4')));
    await tester.pumpAndSettle();
    final version = File('VERSION').readAsStringSync().trim();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('app-version')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Version $version'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('app-mode-selector')));
    await tester.tap(find.text('Server').last);
    await tester.pumpAndSettle();

    expect(find.text('Switch to Server mode?'), findsOneWidget);
    expect(networking.mode, LibreSlipMode.client);
    await tester.tap(find.byKey(const ValueKey('confirm-mode-switch')));
    await tester.pumpAndSettle();

    expect(networking.mode, LibreSlipMode.server);
    expect(find.byKey(const ValueKey('server-inbox-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('server-tab-orders')), findsOneWidget);
    expect(find.byKey(const ValueKey('server-tab-settings')), findsOneWidget);
    expect(find.text('Ready to receive'), findsNothing);
    expect(find.byKey(const ValueKey('nav-0')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('server-tab-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('server-settings-page')), findsOneWidget);
    expect(find.text('Ready to receive'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('app-version')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Version $version'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Client'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Client').last);
    await tester.pumpAndSettle();
    expect(find.text('Switch to Client mode?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-mode-switch')));
    await tester.pumpAndSettle();

    expect(networking.mode, LibreSlipMode.client);
    expect(find.byKey(const ValueKey('nav-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Italian Server inbox supports large text', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final settingsStore = MemorySettingsRepository()
      ..stored = const AppSettings(language: 'it');
    final settings = SettingsController(settingsStore);
    final environment = await createMemoryOrderEnvironment();
    final networking = NetworkModeController(environment.repository);
    final inbox = _memoryInbox(environment.repository);
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

    expect(find.text('Ordini del Server'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('outstanding-items-card')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Ancora da preparare'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('server-tab-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Impostazioni Server'), findsOneWidget);
    expect(find.text('Pronto a ricevere'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryNetworkStore implements NetworkConfigurationStore {
  bool failSave = false;
  NetworkConfiguration stored = const NetworkConfiguration(
    mode: LibreSlipMode.client,
    installationId: 'installation-test',
    serverName: 'LibreSlip Server',
  );

  @override
  Future<NetworkConfiguration> loadNetworkConfiguration() async => stored;

  @override
  Future<void> saveLibreSlipMode(LibreSlipMode mode) async {
    if (failSave) throw StateError('Storage unavailable');
    stored = stored.copyWith(mode: mode);
  }
}

ServerInboxController _memoryInbox(SqliteOrderRepository repository) {
  final secrets = _MemoryServerSecrets();
  return ServerInboxController(repository, secrets, _FakeServerHost());
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
    required bool Function(String code) claimPairingCode,
    required void Function() onOrderReceived,
  }) async =>
      const RunningServer(port: 5119, addresses: ['https://192.0.2.10:5119']);

  @override
  Future<void> stop() async {}
}

class _DelayedServerHost implements ServerHost {
  final entered = Completer<void>();
  final release = Completer<void>();
  var stopCalls = 0;

  @override
  Future<RunningServer> start({
    required ServerIdentity identity,
    required NetworkConfiguration configuration,
    required bool Function(String code) claimPairingCode,
    required void Function() onOrderReceived,
  }) async {
    entered.complete();
    await release.future;
    return const RunningServer(port: 5119, addresses: []);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }
}
