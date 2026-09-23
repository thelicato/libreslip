import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/settings_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = controller.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.saveFailed)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  l.saveError,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ),
          ),
        _SettingsSection(
          title: l.ticketHeader,
          subtitle: l.ticketHeaderBody,
          icon: Icons.short_text_rounded,
          child: ListTile(
            key: const ValueKey('edit-heading'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              settings.heading.isEmpty ? l.defaultHeading : settings.heading,
            ),
            subtitle: Text(l.heading),
            trailing: IconButton(
              tooltip: l.editHeading,
              onPressed: controller.saving ? null : () => _editName(context),
              icon: const Icon(Icons.edit_outlined),
            ),
            onTap: controller.saving ? null : () => _editName(context),
          ),
        ),
        const SizedBox(height: 20),
        _SettingsSection(
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
                onTap: () =>
                    controller.update(settings.copyWith(language: 'en')),
              ),
              _Choice(
                key: const ValueKey('language-it'),
                title: l.italian,
                selected: settings.language == 'it',
                enabled: !controller.saving,
                onTap: () =>
                    controller.update(settings.copyWith(language: 'it')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SettingsSection(
          title: l.appearance,
          subtitle: l.appearanceBody,
          icon: Icons.palette_outlined,
          child: _ChoiceWrap(
            children: [
              for (final (mode, label, icon) in [
                (
                  ThemeMode.system,
                  l.systemTheme,
                  Icons.brightness_auto_outlined,
                ),
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
        ),
        const SizedBox(height: 24),
        Semantics(
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (controller.saving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  controller.saveFailed
                      ? Icons.error_outline
                      : Icons.check_circle_outline_rounded,
                  size: 20,
                  color: controller.saveFailed
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  controller.saving
                      ? l.saving
                      : (controller.saveFailed ? l.saveError : l.savedLocally),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(l.privacyTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          l.privacyBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _editName(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _HeadingDialog(initial: controller.settings.heading),
    );
    if (name != null && context.mounted) {
      await controller.update(controller.settings.copyWith(heading: name));
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
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

class _HeadingDialog extends StatefulWidget {
  const _HeadingDialog({required this.initial});
  final String initial;

  @override
  State<_HeadingDialog> createState() => _HeadingDialogState();
}

class _HeadingDialogState extends State<_HeadingDialog> {
  late final _text = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _text.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(l.editHeading),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _form,
          child: TextFormField(
            key: const ValueKey('heading-input'),
            controller: _text,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l.heading,
              hintText: l.headingHint,
            ),
            validator: (value) {
              final name = value?.trim() ?? '';
              if (name.isEmpty) return l.nameRequired;
              if (name.characters.length > 60) return l.nameTooLong;
              return null;
            },
            onFieldSubmitted: (_) => _save(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}
