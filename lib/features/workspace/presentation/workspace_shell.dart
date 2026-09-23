import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/presentation/settings_page.dart';
import 'overview_page.dart';

class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({super.key, required this.settings});
  final SettingsController settings;

  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  int _selected = 0;

  void _select(int index) => setState(() => _selected = index);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final labels = [l.overview, l.compose, l.items, l.tickets, l.settings];
    const icons = [
      Icons.space_dashboard_outlined,
      Icons.note_add_outlined,
      Icons.grid_view_rounded,
      Icons.receipt_long_outlined,
      Icons.tune_rounded,
    ];
    final heading = widget.settings.settings.heading;
    final title = _selected == 0
        ? (heading.isEmpty ? l.defaultHeading : heading)
        : labels[_selected];
    final page = switch (_selected) {
      0 => OverviewPage(onSelect: _select),
      4 => SettingsPage(controller: widget.settings),
      _ => _ComingPage(index: _selected, onBack: () => _select(0)),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final expanded = constraints.maxWidth >= 1180;
        return PopScope(
          canPop: _selected == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _select(0);
          },
          child: Scaffold(
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    animationDuration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 300),
                    selectedIndex: _selected,
                    onDestinationSelected: _select,
                    destinations: [
                      for (var i = 0; i < labels.length; i++)
                        NavigationDestination(
                          key: ValueKey('nav-$i'),
                          icon: Icon(icons[i]),
                          label: labels[i],
                          tooltip: labels[i],
                        ),
                    ],
                  ),
            body: SafeArea(
              bottom: wide,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide)
                    _Sidebar(
                      selected: _selected,
                      expanded: expanded,
                      labels: labels,
                      icons: icons,
                      onSelect: _select,
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            wide ? 36 : 22,
                            20,
                            wide ? 36 : 22,
                            16,
                          ),
                          child: Row(
                            children: [
                              if (!wide) ...[
                                const BrandMark(size: 34),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      l.appName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                  ),
                                ),
                              ] else
                                Text(
                                  l.yourWorkspace,
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(letterSpacing: 1.8),
                                ),
                              const Spacer(),
                              Tooltip(
                                message: l.onThisPhone,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surface,
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.phonelink_lock_rounded,
                                        size: 17,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      if (constraints.maxWidth > 500 &&
                                          MediaQuery.textScalerOf(context)
                                                  .scale(1) <
                                              1.6) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          l.onThisPhone,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: SingleChildScrollView(
                            key: ValueKey('page-$_selected'),
                            padding: EdgeInsets.all(wide ? 36 : 22),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1160,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineLarge,
                                    ),
                                    if (_selected == 0 || _selected == 4) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        _selected == 0
                                            ? l.overviewSubtitle
                                            : l.settingsSubtitle,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                    const SizedBox(height: 28),
                                    page,
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.expanded,
    required this.labels,
    required this.icons,
    required this.onSelect,
  });
  final int selected;
  final bool expanded;
  final List<String> labels;
  final List<IconData> icons;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      width: expanded ? 244 : 88,
      color: AppTheme.ink,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: expanded ? 20 : 12,
          vertical: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const BrandMark(),
                if (expanded) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      l.appName,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 48),
            if (expanded) ...[
              Padding(
                padding: const EdgeInsets.only(left: 14, bottom: 18),
                child: Text(
                  l.yourWorkspace,
                  style: const TextStyle(
                    color: Color(0xFFB9CFC7),
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            for (var i = 0; i < labels.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  selected: selected == i,
                  child: Tooltip(
                    message: labels[i],
                    child: Material(
                      color: selected == i ? AppTheme.lime : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        key: ValueKey('nav-$i'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => onSelect(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 17,
                            horizontal: 14,
                          ),
                          child: Row(
                            mainAxisAlignment: expanded
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.center,
                            children: [
                              Icon(
                                icons[i],
                                color: selected == i
                                    ? AppTheme.ink
                                    : const Color(0xFFD1DFD9),
                                size: 22,
                              ),
                              if (expanded) ...[
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    labels[i],
                                    style: TextStyle(
                                      color: selected == i
                                          ? AppTheme.ink
                                          : const Color(0xFFD1DFD9),
                                      fontWeight: selected == i
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (expanded) ...[
              const SizedBox(height: 60),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: AppTheme.lime,
                      size: 24,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l.localOnly,
                      style: const TextStyle(
                        color: AppTheme.lime,
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.privacyTitle,
                      style: const TextStyle(color: Colors.white, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComingPage extends StatelessWidget {
  const _ComingPage({required this.index, required this.onBack});
  final int index;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final titles = [l.composeTitle, l.itemsTitle, l.ticketsTitle];
    final bodies = [l.composeBody, l.itemsBody, l.ticketsBody];
    const icons = [
      Icons.note_add_outlined,
      Icons.inventory_2_outlined,
      Icons.receipt_long_outlined,
    ];
    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 52),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  icons[index - 1],
                  size: 48,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                l.previewLabel,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 12),
              Text(
                titles[index - 1],
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Text(
                  bodies[index - 1],
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(l.backOverview),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
