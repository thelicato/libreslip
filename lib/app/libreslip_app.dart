import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/brand_mark.dart';
import '../features/networking/application/client_delivery_controller.dart';
import '../features/networking/application/network_mode_controller.dart';
import '../features/networking/application/server_inbox_controller.dart';
import '../features/networking/domain/network_models.dart';
import '../features/networking/presentation/server_mode_shell.dart';
import '../features/orders/application/order_workspace_controller.dart';
import '../features/portability/application/portability_controller.dart';
import '../features/printing/application/printer_controller.dart';
import '../features/printing/application/ticket_output_controller.dart';
import '../features/settings/application/settings_controller.dart';
import '../features/workspace/presentation/workspace_shell.dart';
import '../l10n/generated/app_localizations.dart';

class LibreSlipApp extends StatelessWidget {
  const LibreSlipApp({
    super.key,
    required this.settings,
    required this.orders,
    this.networking,
    this.serverInbox,
    this.clientDelivery,
    this.printer,
    this.ticketOutput,
    this.portability,
  });

  final SettingsController settings;
  final OrderWorkspaceController orders;
  final NetworkModeController? networking;
  final ServerInboxController? serverInbox;
  final ClientDeliveryController? clientDelivery;
  final PrinterController? printer;
  final TicketOutputController? ticketOutput;
  final PortabilityController? portability;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      settings,
      orders,
      ?networking,
      ?clientDelivery,
    ]),
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      locale: settings.settings.locale,
      supportedLocales: const [Locale('en', 'GB'), Locale('it', 'IT')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: settings.settings.themeMode,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: _AppTextScaler(
              mediaQuery.textScaler,
              settings.settings.appTextScale,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      themeAnimationDuration:
          WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .disableAnimations
          ? Duration.zero
          : kThemeAnimationDuration,
      home:
          settings.loaded &&
              orders.loaded &&
              (networking == null || networking!.loaded) &&
              (clientDelivery == null || clientDelivery!.loaded)
          ? networking?.mode == LibreSlipMode.server
                ? ServerModeShell(
                    settingsController: settings,
                    modeController: networking!,
                    inboxController: serverInbox!,
                  )
                : WorkspaceShell(
                    settings: settings,
                    orders: orders,
                    networking: networking,
                    clientDelivery: clientDelivery,
                    printer: printer,
                    ticketOutput: ticketOutput,
                    portability: portability,
                  )
          : _StartupScreen(
              settings: settings,
              orders: orders,
              networking: networking,
              clientDelivery: clientDelivery,
            ),
    ),
  );
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen({
    required this.settings,
    required this.orders,
    required this.networking,
    required this.clientDelivery,
  });

  final SettingsController settings;
  final OrderWorkspaceController orders;
  final NetworkModeController? networking;
  final ClientDeliveryController? clientDelivery;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final storageFailed =
        orders.loadFailed ||
        (networking?.loadFailed ?? false) ||
        (clientDelivery?.loadFailed ?? false);
    final failed = settings.loadFailed || storageFailed;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(size: 64),
                  const SizedBox(height: 32),
                  Text(
                    storageFailed
                        ? l.storageErrorTitle
                        : settings.loadFailed
                        ? l.loadErrorTitle
                        : l.loading,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  if (failed) ...[
                    Text(
                      storageFailed ? l.storageErrorBody : l.loadErrorBody,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        if (settings.loadFailed) settings.load();
                        if (orders.loadFailed) orders.load();
                        if (networking?.loadFailed ?? false) {
                          networking!.load();
                        }
                        if (clientDelivery?.loadFailed ?? false) {
                          clientDelivery!.load();
                        }
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l.retry),
                    ),
                  ] else
                    const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppTextScaler extends TextScaler {
  const _AppTextScaler(this.systemScaler, this.appScale);

  final TextScaler systemScaler;
  final double appScale;

  @override
  double scale(double fontSize) => systemScaler.scale(fontSize) * appScale;

  @override
  double get textScaleFactor => systemScaler.scale(1) * appScale;

  @override
  bool operator ==(Object other) =>
      other is _AppTextScaler &&
      other.systemScaler == systemScaler &&
      other.appScale == appScale;

  @override
  int get hashCode => Object.hash(systemScaler, appScale);
}
