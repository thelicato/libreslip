import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/brand_mark.dart';
import '../features/orders/application/order_workspace_controller.dart';
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
    this.printer,
    this.ticketOutput,
  });

  final SettingsController settings;
  final OrderWorkspaceController orders;
  final PrinterController? printer;
  final TicketOutputController? ticketOutput;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([settings, orders]),
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      locale: settings.settings.locale,
      supportedLocales: const [Locale('en', 'GB'), Locale('it', 'IT')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: settings.settings.themeMode,
      themeAnimationDuration:
          WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .disableAnimations
          ? Duration.zero
          : kThemeAnimationDuration,
      home: settings.loaded && orders.loaded
          ? WorkspaceShell(
              settings: settings,
              orders: orders,
              printer: printer,
              ticketOutput: ticketOutput,
            )
          : _StartupScreen(settings: settings, orders: orders),
    ),
  );
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen({required this.settings, required this.orders});

  final SettingsController settings;
  final OrderWorkspaceController orders;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final failed = settings.loadFailed || orders.loadFailed;
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
                    orders.loadFailed
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
                      orders.loadFailed ? l.storageErrorBody : l.loadErrorBody,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        if (settings.loadFailed) settings.load();
                        if (orders.loadFailed) orders.load();
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
