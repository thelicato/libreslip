import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../orders/application/order_workspace_controller.dart';
import '../../printing/application/printer_controller.dart';
import '../../printing/domain/printer_transport.dart';
import '../application/ticket_statistics.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({
    super.key,
    required this.onSelect,
    required this.orders,
    this.printer,
  });

  final ValueChanged<int> onSelect;
  final OrderWorkspaceController orders;
  final PrinterController? printer;

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPrinter());
  }

  @override
  void didUpdateWidget(covariant OverviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.printer != widget.printer) _refreshPrinter();
  }

  void _refreshPrinter() {
    final printer = widget.printer;
    if (mounted && printer != null) unawaited(printer.refresh());
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = start ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? today,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _startDate = picked;
        if (_endDate != null && picked.isAfter(_endDate!)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
        if (_startDate != null && picked.isBefore(_startDate!)) {
          _startDate = picked;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final statistics = TicketStatistics.calculate(
      widget.orders.tickets,
      startDate: _startDate,
      endDate: _endDate,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WelcomeCard(onPersonalise: () => widget.onSelect(4)),
        const SizedBox(height: 24),
        _PrinterStatusCard(
          controller: widget.printer,
          onManage: () => widget.onSelect(4),
          onRefresh: _refreshPrinter,
        ),
        const SizedBox(height: 24),
        _StatisticsCard(
          statistics: statistics,
          startDate: _startDate,
          endDate: _endDate,
          onPickStart: () => _pickDate(start: true),
          onPickEnd: () => _pickDate(start: false),
          onClear: _startDate == null && _endDate == null
              ? null
              : () => setState(() {
                  _startDate = null;
                  _endDate = null;
                }),
        ),
        const SizedBox(height: 32),
        Text(l.workspaceTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          l.workspaceSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720 ? 3 : 1;
            final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                _WorkspaceCard(
                  width: width,
                  icon: Icons.note_add_outlined,
                  title: l.compose,
                  body: l.composeCardBody,
                  onTap: () => widget.onSelect(2),
                ),
                _WorkspaceCard(
                  width: width,
                  icon: Icons.grid_view_rounded,
                  title: l.items,
                  body: l.itemsCardBody,
                  onTap: () => widget.onSelect(1),
                ),
                _WorkspaceCard(
                  width: width,
                  icon: Icons.receipt_long_outlined,
                  title: l.tickets,
                  body: l.ticketsCardBody,
                  onTap: () => widget.onSelect(3),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PrinterStatusCard extends StatelessWidget {
  const _PrinterStatusCard({
    required this.controller,
    required this.onManage,
    required this.onRefresh,
  });

  final PrinterController? controller;
  final VoidCallback onManage;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final printer = controller;
    if (printer == null) {
      return _build(context, null);
    }
    return ListenableBuilder(
      listenable: printer,
      builder: (context, _) => _build(context, printer),
    );
  }

  Widget _build(BuildContext context, PrinterController? printer) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final connected = printer?.connected ?? false;
    final (status, colour, icon) = switch (printer?.hostStatus) {
      BluetoothHostStatus.unsupported => (
        l.printerUnavailableStatus,
        theme.colorScheme.error,
        Icons.bluetooth_disabled_rounded,
      ),
      BluetoothHostStatus.permissionRequired => (
        l.printerPermissionStatus,
        theme.colorScheme.tertiary,
        Icons.lock_outline_rounded,
      ),
      BluetoothHostStatus.disabled => (
        l.printerBluetoothOffStatus,
        theme.colorScheme.tertiary,
        Icons.bluetooth_disabled_rounded,
      ),
      _ when printer?.operation == PrinterOperation.connecting => (
        l.connectingPrinter,
        theme.colorScheme.tertiary,
        Icons.bluetooth_searching_rounded,
      ),
      _ when connected => (
        l.printerConnectedStatus,
        theme.colorScheme.primary,
        Icons.bluetooth_connected_rounded,
      ),
      _ => (
        printer == null
            ? l.printerUnavailableStatus
            : l.printerDisconnectedStatus,
        theme.colorScheme.onSurfaceVariant,
        Icons.bluetooth_rounded,
      ),
    };
    final name = printer?.connectedPrinter?.name;
    final battery = printer?.batteryPercentage;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.print_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.printerOverviewTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l.printerOverviewBody,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colour.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: colour),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          status,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colour,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (connected && name != null)
                  Text(
                    l.printerConnectedDevice(name),
                    style: theme.textTheme.bodyMedium,
                  ),
              ],
            ),
            const Divider(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  battery == null
                      ? Icons.battery_unknown_rounded
                      : Icons.battery_std_rounded,
                  size: 21,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.printerBattery, style: theme.textTheme.labelLarge),
                      const SizedBox(height: 3),
                      Text(
                        battery == null
                            ? l.printerBatteryUnavailable
                            : l.printerBatteryPercentage(battery),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final manage = FilledButton.tonal(
                  onPressed: onManage,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.tune_rounded),
                      const SizedBox(width: 8),
                      Flexible(child: Text(l.managePrinter)),
                    ],
                  ),
                );
                final refresh = OutlinedButton(
                  key: const ValueKey('refresh-printer-status'),
                  onPressed: printer == null || printer.busy ? null : onRefresh,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (printer?.operation == PrinterOperation.refreshing)
                        const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(Icons.refresh_rounded),
                      const SizedBox(width: 8),
                      Flexible(child: Text(l.refreshPrinterStatus)),
                    ],
                  ),
                );
                if (constraints.maxWidth >= 480) {
                  return Row(
                    children: [
                      Expanded(child: manage),
                      const SizedBox(width: 10),
                      Expanded(child: refresh),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [manage, const SizedBox(height: 10), refresh],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({
    required this.statistics,
    required this.startDate,
    required this.endDate,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onClear,
  });

  final TicketStatistics statistics;
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final integers = NumberFormat.decimalPattern(locale);
    final average = NumberFormat('0.#', locale);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.insights_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.statisticsTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l.statisticsBody,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 620;
                final width = wide
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _DateFilterButton(
                      width: width,
                      label: l.startDate,
                      value: _formatDate(context, startDate),
                      onPressed: onPickStart,
                      valueKey: const ValueKey('statistics-start-date'),
                    ),
                    _DateFilterButton(
                      width: width,
                      label: l.endDate,
                      value: _formatDate(context, endDate),
                      onPressed: onPickEnd,
                      valueKey: const ValueKey('statistics-end-date'),
                    ),
                  ],
                );
              },
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                key: const ValueKey('clear-statistics-dates'),
                onPressed: onClear,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: Text(l.clearDateFilters),
              ),
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 720 ? 3 : 1;
                final width =
                    (constraints.maxWidth - 12 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatisticMetric(
                      key: const ValueKey('statistic-tickets'),
                      width: width,
                      value: integers.format(statistics.ticketCount),
                      label: l.savedTicketsStat,
                    ),
                    _StatisticMetric(
                      key: const ValueKey('statistic-items'),
                      width: width,
                      value: integers.format(statistics.itemQuantity),
                      label: l.ticketItemsStat,
                    ),
                    _StatisticMetric(
                      key: const ValueKey('statistic-average'),
                      width: width,
                      value: average.format(statistics.averageItemsPerTicket),
                      label: l.averageItemsStat,
                    ),
                  ],
                );
              },
            ),
            const Divider(height: 40),
            _ItemBreakdown(items: statistics.items, numberFormat: integers),
          ],
        ),
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime? value) {
    if (value == null) return AppLocalizations.of(context).noDateLimit;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMd(locale).format(value);
  }
}

class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({
    required this.width,
    required this.label,
    required this.value,
    required this.onPressed,
    required this.valueKey,
  });

  final double width;
  final String label;
  final String value;
  final VoidCallback onPressed;
  final Key valueKey;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: OutlinedButton(
      key: valueKey,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatisticMetric extends StatelessWidget {
  const _StatisticMetric({
    super.key,
    required this.width,
    required this.value,
    required this.label,
  });

  final double width;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: theme.textTheme.headlineMedium),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemBreakdown extends StatefulWidget {
  const _ItemBreakdown({required this.items, required this.numberFormat});

  final List<TicketItemStatistic> items;
  final NumberFormat numberFormat;

  @override
  State<_ItemBreakdown> createState() => _ItemBreakdownState();
}

class _ItemBreakdownState extends State<_ItemBreakdown> {
  static const _collapsedCount = 8;
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = _expanded
        ? widget.items
        : widget.items.take(_collapsedCount).toList(growable: false);
    return Column(
      key: const ValueKey('item-statistics-breakdown'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.itemBreakdownTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 3),
        Text(
          l.itemBreakdownBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              l.noItemsInPeriod,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final (index, item) in items.indexed) ...[
            Semantics(
              label: l.itemQuantitySummary(item.name, item.quantity),
              child: ExcludeSemantics(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 64),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          widget.numberFormat.format(item.quantity),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (index != items.length - 1) const SizedBox(height: 8),
          ],
        if (widget.items.length > _collapsedCount) ...[
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              key: const ValueKey('toggle-item-statistics'),
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              label: Text(
                _expanded
                    ? l.showFewerItemStatistics
                    : l.showAllItemStatistics(widget.items.length),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.onPersonalise});
  final VoidCallback onPersonalise;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        color: AppTheme.ink,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showArtwork =
                constraints.maxWidth >= 650 &&
                MediaQuery.textScalerOf(context).scale(1) < 1.6;
            return Stack(
              children: [
                if (showArtwork)
                  const Positioned(
                    right: -12,
                    top: 0,
                    bottom: 0,
                    width: 280,
                    child: ExcludeSemantics(
                      child: CustomPaint(painter: _TicketArtwork()),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(constraints.maxWidth > 500 ? 36 : 26),
                  child: SizedBox(
                    width: showArtwork
                        ? constraints.maxWidth - 330
                        : double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.heroEyebrow,
                          style: const TextStyle(
                            color: AppTheme.lime,
                            fontSize: 10,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          l.heroTitle,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: constraints.maxWidth > 900 ? 44 : 34,
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -1.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l.heroBody,
                          style: const TextStyle(
                            color: Color(0xFFD1DFD9),
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 26),
                        FilledButton(
                          key: const ValueKey('personalise'),
                          onPressed: onPersonalise,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.lime,
                            foregroundColor: AppTheme.ink,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  l.personaliseWorkspace,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });
  final double width;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        icon,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.north_east_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 19,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Decorative ticket artwork, not a saved or printed order.
class _TicketArtwork extends CustomPainter {
  const _TicketArtwork();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.12);
    final outline = Paint()
      ..color = const Color(0xFF31564A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset.zero, 128, outline);
    canvas.drawCircle(Offset.zero, 104, outline);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-78, -95, 165, 206),
        const Radius.circular(18),
      ),
      Paint()..color = const Color(0xFF102F29),
    );
    final slip = Path()
      ..moveTo(-82, -110)
      ..lineTo(68, -110)
      ..lineTo(68, 102);
    for (var x = 68.0; x > -82; x -= 25) {
      slip
        ..lineTo(x - 12.5, 92)
        ..lineTo(x - 25, 102);
    }
    slip
      ..lineTo(-82, -110)
      ..close();
    canvas.drawPath(slip, Paint()..color = const Color(0xFFF7F7EE));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-58, -82, 78, 13),
        const Radius.circular(4),
      ),
      Paint()..color = AppTheme.ink,
    );
    for (var row = 0; row < 3; row++) {
      final y = -30.0 + row * 31;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-58, y, 12, 12),
          const Radius.circular(3),
        ),
        Paint()..color = AppTheme.teal,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-34, y + 2, row == 1 ? 54 : 72, 8),
          const Radius.circular(4),
        ),
        Paint()..color = AppTheme.ink.withValues(alpha: 0.28),
      );
    }
    canvas.drawCircle(const Offset(64, 83), 32, Paint()..color = AppTheme.lime);
    final arrow = Path()
      ..moveTo(51, 83)
      ..lineTo(77, 83)
      ..moveTo(66, 72)
      ..lineTo(77, 83)
      ..lineTo(66, 94);
    canvas.drawPath(
      arrow,
      Paint()
        ..color = AppTheme.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(const Offset(90, -97), 7, Paint()..color = AppTheme.lime);
    canvas.drawCircle(
      const Offset(-105, 77),
      4,
      Paint()..color = const Color(0xFFBCD7CA),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TicketArtwork oldDelegate) => false;
}
