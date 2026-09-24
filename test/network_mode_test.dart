import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/app/libreslip_app.dart';
import 'package:libreslip/features/networking/application/network_mode_controller.dart';
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
    addTearDown(settings.dispose);
    addTearDown(environment.controller.dispose);
    addTearDown(networking.dispose);
    await settings.load();
    await networking.load();

    await tester.pumpWidget(
      LibreSlipApp(
        settings: settings,
        orders: environment.controller,
        networking: networking,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-4')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('app-mode-selector')));
    await tester.tap(find.text('Server').last);
    await tester.pumpAndSettle();

    expect(find.text('Switch to Server mode?'), findsOneWidget);
    expect(networking.mode, LibreSlipMode.client);
    await tester.tap(find.byKey(const ValueKey('confirm-mode-switch')));
    await tester.pumpAndSettle();

    expect(networking.mode, LibreSlipMode.server);
    expect(
      find.byKey(const ValueKey('server-foundation-page')),
      findsOneWidget,
    );
    expect(
      find.textContaining('order receiving is not operational yet'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('nav-0')), findsNothing);

    await tester.tap(find.text('Client').last);
    await tester.pumpAndSettle();
    expect(find.text('Switch to Client mode?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-mode-switch')));
    await tester.pumpAndSettle();

    expect(networking.mode, LibreSlipMode.client);
    expect(find.byKey(const ValueKey('nav-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Italian Server foundation supports large text', (tester) async {
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
    addTearDown(settings.dispose);
    addTearDown(environment.controller.dispose);
    addTearDown(networking.dispose);
    await settings.load();
    await networking.load();
    await networking.setMode(LibreSlipMode.server);

    await tester.pumpWidget(
      LibreSlipApp(
        settings: settings,
        orders: environment.controller,
        networking: networking,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Modalità Server'), findsOneWidget);
    expect(find.text('Base pronta'), findsOneWidget);
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
