import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/brand_mark.dart';
import '../features/settings/application/settings_controller.dart';
import '../features/workspace/presentation/workspace_shell.dart';
import '../l10n/generated/app_localizations.dart';

class LibreSlipApp extends StatelessWidget {
  const LibreSlipApp({super.key, required this.settings});
  final SettingsController settings;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
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
      home: settings.loaded
          ? WorkspaceShell(settings: settings)
          : _StartupScreen(settings: settings),
    ),
  );
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen({required this.settings});
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                    settings.loadFailed ? l.loadErrorTitle : l.loading,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  if (settings.loadFailed) ...[
                    Text(l.loadErrorBody, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: settings.load,
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
