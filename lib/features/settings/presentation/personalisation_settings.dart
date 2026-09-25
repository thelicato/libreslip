import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/settings_controller.dart';

class LanguageSettingsCard extends StatelessWidget {
  const LanguageSettingsCard({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = controller.settings;
    return _PersonalisationCard(
      title: l.language,
      subtitle: l.languageBody,
      icon: Icons.translate_rounded,
      child: _ChoiceWrap(
        children: [
          _Choice(
            key: const ValueKey('language-en'),
            title: l.english,
            selected: settings.language == 'en',
            enabled: !controller.saving,
            onTap: () => controller.update(settings.copyWith(language: 'en')),
          ),
          _Choice(
            key: const ValueKey('language-it'),
            title: l.italian,
            selected: settings.language == 'it',
            enabled: !controller.saving,
            onTap: () => controller.update(settings.copyWith(language: 'it')),
          ),
        ],
      ),
    );
  }
}

class AppearanceSettingsCard extends StatelessWidget {
  const AppearanceSettingsCard({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = controller.settings;
    return _PersonalisationCard(
      title: l.appearance,
      subtitle: l.appearanceBody,
      icon: Icons.palette_outlined,
      child: _ChoiceWrap(
        children: [
          for (final (mode, label, icon) in [
            (ThemeMode.system, l.systemTheme, Icons.brightness_auto_outlined),
            (ThemeMode.light, l.lightTheme, Icons.light_mode_outlined),
            (ThemeMode.dark, l.darkTheme, Icons.dark_mode_outlined),
          ])
            _Choice(
              key: ValueKey('theme-${mode.name}'),
              title: label,
              icon: icon,
              selected: settings.themeMode == mode,
              enabled: !controller.saving,
              onTap: () =>
                  controller.update(settings.copyWith(themeMode: mode)),
            ),
        ],
      ),
    );
  }
}

class _PersonalisationCard extends StatelessWidget {
  const _PersonalisationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    ),
  );
}

class _ChoiceWrap extends StatelessWidget {
  const _ChoiceWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final horizontal = constraints.maxWidth >= children.length * 165 * scale;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children)
            SizedBox(
              width: horizontal
                  ? (constraints.maxWidth - (children.length - 1) * 12) /
                        children.length
                  : constraints.maxWidth,
              child: child,
            ),
        ],
      );
    },
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.title,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.icon,
  });

  final String title;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 22),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 21,
                  color: selected ? scheme.primary : scheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
