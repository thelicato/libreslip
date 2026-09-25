import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/widgets/app_version_footer.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../networking/application/client_delivery_controller.dart';
import '../../networking/application/network_mode_controller.dart';
import '../../networking/presentation/client_server_settings_card.dart';
import '../../networking/presentation/mode_settings_card.dart';
import '../../orders/application/order_workspace_controller.dart';
import '../../portability/application/portability_controller.dart';
import '../../portability/presentation/portability_settings_card.dart';
import '../../printing/application/printer_controller.dart';
import '../../printing/domain/ticket_typography.dart';
import '../../printing/presentation/printer_setup_card.dart';
import '../application/settings_controller.dart';
import 'personalisation_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.orders,
    this.networking,
    this.delivery,
    this.printer,
    this.portability,
  });
  final SettingsController controller;
  final OrderWorkspaceController orders;
  final NetworkModeController? networking;
  final ClientDeliveryController? delivery;
  final PrinterController? printer;
  final PortabilityController? portability;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = controller.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.saveFailed || orders.saveFailed)
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
          title: l.ticketTemplate,
          subtitle: l.ticketTemplateBody,
          icon: Icons.receipt_long_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                key: const ValueKey('edit-heading'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  settings.heading.isEmpty
                      ? l.defaultHeading
                      : settings.heading,
                ),
                subtitle: Text(l.heading),
                trailing: IconButton(
                  tooltip: l.editHeading,
                  onPressed: controller.saving
                      ? null
                      : () => _editName(context),
                  icon: const Icon(Icons.edit_outlined),
                ),
                onTap: controller.saving ? null : () => _editName(context),
              ),
              const Divider(height: 28),
              ListTile(
                key: const ValueKey('edit-footer'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  settings.footer.isEmpty
                      ? l.ticketFooterHint
                      : settings.footer,
                ),
                subtitle: Text(l.ticketFooter),
                trailing: IconButton(
                  tooltip: l.editFooter,
                  onPressed: controller.saving
                      ? null
                      : () => _editFooter(context),
                  icon: const Icon(Icons.edit_outlined),
                ),
                onTap: controller.saving ? null : () => _editFooter(context),
              ),
              const Divider(height: 28),
              _LogoEditor(controller: controller),
              const Divider(height: 32),
              Text(
                l.ticketTextSizes,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(l.ticketTextSizesBody),
              const SizedBox(height: 12),
              _TicketFontSizeField(
                key: const ValueKey('font-size-heading'),
                label: l.ticketHeadingSize,
                value: settings.typography.heading,
                minimum: TicketTypography.minHeading,
                maximum: TicketTypography.maxHeading,
                enabled: !controller.saving,
                onChanged: (value) => controller.update(
                  controller.settings.copyWith(
                    typography: controller.settings.typography.copyWith(
                      heading: value,
                    ),
                  ),
                ),
              ),
              _TicketFontSizeField(
                key: const ValueKey('font-size-details'),
                label: l.orderDetailsSize,
                value: settings.typography.details,
                minimum: TicketTypography.minDetails,
                maximum: TicketTypography.maxDetails,
                enabled: !controller.saving,
                onChanged: (value) => controller.update(
                  controller.settings.copyWith(
                    typography: controller.settings.typography.copyWith(
                      details: value,
                    ),
                  ),
                ),
              ),
              _TicketFontSizeField(
                key: const ValueKey('font-size-items'),
                label: l.itemLinesSize,
                value: settings.typography.items,
                minimum: TicketTypography.minItems,
                maximum: TicketTypography.maxItems,
                enabled: !controller.saving,
                onChanged: (value) => controller.update(
                  controller.settings.copyWith(
                    typography: controller.settings.typography.copyWith(
                      items: value,
                    ),
                  ),
                ),
              ),
              _TicketFontSizeField(
                key: const ValueKey('font-size-notes'),
                label: l.notesSize,
                value: settings.typography.notes,
                minimum: TicketTypography.minNotes,
                maximum: TicketTypography.maxNotes,
                enabled: !controller.saving,
                onChanged: (value) => controller.update(
                  controller.settings.copyWith(
                    typography: controller.settings.typography.copyWith(
                      notes: value,
                    ),
                  ),
                ),
              ),
              _TicketFontSizeField(
                key: const ValueKey('font-size-footer'),
                label: l.footerSize,
                value: settings.typography.footer,
                minimum: TicketTypography.minFooter,
                maximum: TicketTypography.maxFooter,
                enabled: !controller.saving,
                onChanged: (value) => controller.update(
                  controller.settings.copyWith(
                    typography: controller.settings.typography.copyWith(
                      footer: value,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SettingsSection(
          title: l.orderFields,
          subtitle: l.orderFieldsBody,
          icon: Icons.tune_rounded,
          child: Column(
            children: [
              SwitchListTile(
                key: const ValueKey('toggle-order-reference'),
                contentPadding: EdgeInsets.zero,
                value: orders.featureSettings.orderReferenceEnabled,
                title: Text(l.orderReference),
                onChanged: orders.saving
                    ? null
                    : (value) => orders.updateFeatureSettings(
                        orders.featureSettings.copyWith(
                          orderReferenceEnabled: value,
                        ),
                      ),
              ),
              SwitchListTile(
                key: const ValueKey('toggle-preparation-notes'),
                contentPadding: EdgeInsets.zero,
                value: orders.featureSettings.preparationNotesEnabled,
                title: Text(l.preparationNotes),
                onChanged: orders.saving
                    ? null
                    : (value) => orders.updateFeatureSettings(
                        orders.featureSettings.copyWith(
                          preparationNotesEnabled: value,
                        ),
                      ),
              ),
              SwitchListTile(
                key: const ValueKey('toggle-order-notes'),
                contentPadding: EdgeInsets.zero,
                value: orders.featureSettings.orderNotesEnabled,
                title: Text(l.orderNotes),
                onChanged: orders.saving
                    ? null
                    : (value) => orders.updateFeatureSettings(
                        orders.featureSettings.copyWith(
                          orderNotesEnabled: value,
                        ),
                      ),
              ),
            ],
          ),
        ),
        if (networking != null) ...[
          const SizedBox(height: 20),
          ModeSettingsCard(controller: networking!),
        ],
        if (delivery != null && networking?.configuration != null) ...[
          const SizedBox(height: 20),
          ClientServerSettingsCard(
            controller: delivery!,
            configuration: networking!.configuration!,
          ),
        ],
        const SizedBox(height: 20),
        LanguageSettingsCard(controller: controller),
        const SizedBox(height: 20),
        AppearanceSettingsCard(controller: controller),
        const SizedBox(height: 20),
        TextSizeSettingsCard(controller: controller),
        if (printer != null) ...[
          const SizedBox(height: 20),
          PrinterSetupCard(controller: printer!),
        ],
        if (portability != null) ...[
          const SizedBox(height: 20),
          PortabilitySettingsCard(controller: portability!),
        ],
        const SizedBox(height: 28),
        const AppVersionFooter(),
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

  Future<void> _editFooter(BuildContext context) async {
    final footer = await showDialog<String>(
      context: context,
      builder: (_) => _FooterDialog(initial: controller.settings.footer),
    );
    if (footer != null && context.mounted) {
      await controller.update(controller.settings.copyWith(footer: footer));
    }
  }
}

class _LogoEditor extends StatelessWidget {
  const _LogoEditor({required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final path = controller.settings.logoPath;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: path == null
              ? const Icon(Icons.image_outlined)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(path),
                    width: 76,
                    height: 76,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.ticketLogo, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(l.ticketLogoBody),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('choose-ticket-logo'),
                    onPressed: controller.saving ? null : controller.chooseLogo,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(path == null ? l.chooseLogo : l.changeLogo),
                  ),
                  if (controller.logoFailed)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l.logoPickerError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (path != null)
                    TextButton.icon(
                      onPressed: controller.saving
                          ? null
                          : controller.removeLogo,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(l.removeLogo),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TicketFontSizeField extends StatelessWidget {
  const _TicketFontSizeField({
    super.key,
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int minimum;
  final int maximum;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: DropdownButton<int>(
      value: value,
      onChanged: enabled
          ? (next) {
              if (next != null) onChanged(next);
            }
          : null,
      items: [
        for (var size = minimum; size <= maximum; size++)
          DropdownMenuItem(value: size, child: Text('$size pt')),
      ],
    ),
  );
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

class _FooterDialog extends StatefulWidget {
  const _FooterDialog({required this.initial});

  final String initial;

  @override
  State<_FooterDialog> createState() => _FooterDialogState();
}

class _FooterDialogState extends State<_FooterDialog> {
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
      title: Text(l.editFooter),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _form,
          child: TextFormField(
            key: const ValueKey('footer-input'),
            controller: _text,
            autofocus: true,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l.ticketFooter,
              hintText: l.ticketFooterHint,
            ),
            validator: (value) {
              if ((value ?? '').characters.length > 120) {
                return l.footerTooLong;
              }
              return null;
            },
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
