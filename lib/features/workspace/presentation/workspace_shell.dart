import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../orders/application/order_workspace_controller.dart';
import '../../orders/presentation/compose_page.dart';
import '../../orders/presentation/items_page.dart';
import '../../orders/presentation/tickets_page.dart';
import '../../portability/application/portability_controller.dart';
import '../../printing/application/printer_controller.dart';
import '../../printing/application/ticket_output_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/presentation/settings_page.dart';
import 'overview_page.dart';

class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({
    super.key,
    required this.settings,
    required this.orders,
    this.printer,
    this.ticketOutput,
    this.portability,
  });
  final SettingsController settings;
  final OrderWorkspaceController orders;
  final PrinterController? printer;
  final TicketOutputController? ticketOutput;
  final PortabilityController? portability;

  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  int _selected = 0;

  void _select(int index) => setState(() => _selected = index);

  double _navLabelFontSize(
    BuildContext context,
    double width,
    List<String> labels,
  ) {
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final baseStyle = Theme.of(context).textTheme.labelMedium;
    final maximum = baseStyle?.fontSize ?? 12;
    final available = width / labels.length - 8;
    for (var size = maximum; size >= 4; size -= 0.25) {
      final fits = labels.every((label) {
        final painter = TextPainter(
          text: TextSpan(
            text: label,
            style: baseStyle?.copyWith(fontSize: size),
          ),
          maxLines: 1,
          textDirection: direction,
          textScaler: scaler,
        )..layout();
        return painter.width <= available;
      });
      if (fits) return size;
    }
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final labels = [l.overview, l.items, l.compose, l.tickets, l.settings];
    const icons = [
      Icons.space_dashboard_outlined,
      Icons.grid_view_rounded,
      Icons.note_add_outlined,
      Icons.receipt_long_outlined,
      Icons.tune_rounded,
    ];
    final heading = widget.settings.settings.heading;
    final title = _selected == 0
        ? (heading.isEmpty ? l.defaultHeading : heading)
        : labels[_selected];
    final page = switch (_selected) {
      0 => OverviewPage(onSelect: _select),
      1 => ItemsPage(controller: widget.orders),
      2 => ComposePage(
        controller: widget.orders,
        settings: widget.settings.settings,
        output: widget.ticketOutput,
      ),
      3 => TicketsPage(
        controller: widget.orders,
        settings: widget.settings.settings,
        output: widget.ticketOutput,
        onOpenCompose: () => _select(2),
      ),
      4 => SettingsPage(
        controller: widget.settings,
        orders: widget.orders,
        printer: widget.printer,
        portability: widget.portability,
      ),
      _ => OverviewPage(onSelect: _select),
    };
    final subtitle = switch (_selected) {
      0 => l.overviewSubtitle,
      1 => l.itemsSubtitle,
      2 => l.composeSubtitle,
      3 => l.ticketsSubtitle,
      _ => l.settingsSubtitle,
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
                : NavigationBarTheme(
                    data: NavigationBarThemeData(
                      labelTextStyle: WidgetStatePropertyAll(
                        Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontSize: _navLabelFontSize(
                            context,
                            constraints.maxWidth,
                            labels,
                          ),
                          height: 1,
                        ),
                      ),
                    ),
                    child: NavigationBar(
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
                                    const SizedBox(height: 6),
                                    Text(
                                      subtitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
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
