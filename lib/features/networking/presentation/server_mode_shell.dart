import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_version_footer.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/network_mode_controller.dart';
import '../application/server_inbox_controller.dart';
import '../domain/server_inbox_models.dart';
import 'mode_settings_card.dart';

class ServerModeShell extends StatefulWidget {
  const ServerModeShell({
    super.key,
    required this.modeController,
    required this.inboxController,
  });

  final NetworkModeController modeController;
  final ServerInboxController inboxController;

  @override
  State<ServerModeShell> createState() => _ServerModeShellState();
}

class _ServerModeShellState extends State<ServerModeShell>
    with WidgetsBindingObserver {
  var _showCompleted = false;
  var _selectedTab = 0;
  final _ordersScrollController = ScrollController();
  final _settingsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  Future<void> _start() async {
    final configuration = widget.modeController.configuration;
    if (configuration != null) {
      await widget.inboxController.start(configuration);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_start());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(widget.inboxController.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.inboxController.stop());
    _ordersScrollController.dispose();
    _settingsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (value) => setState(() => _selectedTab = value),
        destinations: [
          NavigationDestination(
            key: const ValueKey('server-tab-orders'),
            icon: const Icon(Icons.receipt_long_outlined),
            label: l.serverOrdersTab,
          ),
          NavigationDestination(
            key: const ValueKey('server-tab-settings'),
            icon: const Icon(Icons.tune_rounded),
            label: l.serverSettingsTab,
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: widget.inboxController,
          builder: (context, _) => _selectedTab == 0
              ? _buildOrders(context)
              : _buildSettings(context),
        ),
      ),
    );
  }

  Widget _buildOrders(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = widget.inboxController;
    final orders = _showCompleted
        ? controller.completedOrders
        : controller.receivedOrders;
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: CustomScrollView(
        key: const ValueKey('server-inbox-page'),
        controller: _ordersScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PageHeader(
                        title: l.serverInboxTitle,
                        subtitle: l.serverInboxSubtitle,
                        trailing: IconButton(
                          tooltip: l.serverRefresh,
                          onPressed: controller.loading
                              ? null
                              : controller.refresh,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SegmentedButton<bool>(
                        key: const ValueKey('server-order-filter'),
                        segments: [
                          ButtonSegment(
                            value: false,
                            icon: const Icon(Icons.inbox_outlined),
                            label: Text(
                              '${l.receivedOrders} '
                              '(${controller.receivedOrders.length})',
                            ),
                          ),
                          ButtonSegment(
                            value: true,
                            icon: const Icon(Icons.task_alt_rounded),
                            label: Text(
                              '${l.completedOrders} '
                              '(${controller.completedOrders.length})',
                            ),
                          ),
                        ],
                        selected: {_showCompleted},
                        onSelectionChanged: (selection) =>
                            setState(() => _showCompleted = selection.single),
                        showSelectedIcon: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (orders.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              sliver: SliverToBoxAdapter(
                child: _EmptyOrders(completed: _showCompleted),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.crossAxisExtent >= 760 ? 2 : 1;
                  return SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: 190,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: orders.length,
                    itemBuilder: (context, index) => _OrderCard(
                      order: orders[index],
                      onTap: () => _showOrder(orders[index]),
                    ),
                  );
                },
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: _OutstandingItemsCard(
                    totals: summariseOutstandingItems(controller.orders),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettings(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = widget.inboxController;
    return CustomScrollView(
      key: const ValueKey('server-settings-page'),
      controller: _settingsScrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PageHeader(
                      title: l.serverSettingsTitle,
                      subtitle: l.serverSettingsSubtitle,
                    ),
                    const SizedBox(height: 20),
                    _ListenerCard(controller: controller, onRetry: _start),
                    const SizedBox(height: 16),
                    _PairingCard(controller: controller),
                    const SizedBox(height: 24),
                    ModeSettingsCard(controller: widget.modeController),
                    const SizedBox(height: 28),
                    const AppVersionFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showOrder(ServerOrder order) async {
    await showDialog<void>(
      context: context,
      builder: (context) =>
          _OrderDialog(order: order, controller: widget.inboxController),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const BrandMark(size: 48),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: theme.textTheme.headlineMedium)),
            ?trailing,
          ],
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _OutstandingItemsCard extends StatelessWidget {
  const _OutstandingItemsCard({required this.totals});

  final List<OutstandingItemTotal> totals;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final quantityFormat = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    return Card(
      key: const ValueKey('outstanding-items-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.outstandingItems, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              l.outstandingItemsBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (totals.isEmpty)
              Text(l.noOutstandingItems)
            else
              for (var index = 0; index < totals.length; index++) ...[
                if (index > 0) const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        totals[index].name,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      quantityFormat.format(totals[index].quantity),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _ListenerCard extends StatelessWidget {
  const _ListenerCard({required this.controller, required this.onRetry});

  final ServerInboxController controller;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final listening = controller.listening;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  listening ? Icons.lan_rounded : Icons.lan_outlined,
                  color: listening
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    controller.loading
                        ? l.serverStarting
                        : listening
                        ? l.serverListening
                        : l.serverNotListening,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (controller.failed && !listening)
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l.retry),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l.serverForegroundOnly),
            if (listening) ...[
              const SizedBox(height: 16),
              Text(l.serverAddresses, style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              if (controller.runningServer!.addresses.isEmpty)
                Text(l.noLocalAddress)
              else
                for (final address in controller.runningServer!.addresses)
                  SelectableText(address),
              const SizedBox(height: 12),
              Text(l.serverFingerprint, style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              SelectableText(
                _displayFingerprint(
                  controller.identity!.certificateFingerprint,
                ),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PairingCard extends StatelessWidget {
  const _PairingCard({required this.controller});

  final ServerInboxController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final window = controller.pairingWindow;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.clientPairing, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(l.clientPairingBody),
            const SizedBox(height: 16),
            if (window == null || window.expired)
              FilledButton.icon(
                key: const ValueKey('open-pairing'),
                onPressed: controller.listening
                    ? controller.openPairingWindow
                    : null,
                icon: const Icon(Icons.link_rounded),
                label: Text(l.allowPairing),
              )
            else ...[
              Text(l.pairingCode, style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              SelectableText(
                window.code,
                key: const ValueKey('pairing-code'),
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  letterSpacing: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.pairingExpires(
                  DateFormat.Hm(Localizations.localeOf(context).toLanguageTag())
                      .format(window.expiresAt),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: controller.closePairingWindow,
                child: Text(l.stopPairing),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                completed ? Icons.task_alt_rounded : Icons.inbox_outlined,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                completed ? l.noCompletedOrders : l.noReceivedOrders,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                completed ? l.noCompletedOrdersBody : l.noReceivedOrdersBody,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final ServerOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final itemCount = order.lines.fold<int>(
      0,
      (total, line) => total + line.quantity,
    );
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('server-order-${order.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.orderNumber(order.displayNumber),
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              if (order.reference.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  order.reference,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ],
              const Spacer(),
              Text(order.clientDisplayName),
              const SizedBox(height: 4),
              Text(
                l.itemCount(itemCount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat.yMMMd(locale)
                    .add_Hm()
                    .format(order.receivedAt.toLocal()),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDialog extends StatelessWidget {
  const _OrderDialog({required this.order, required this.controller});

  final ServerOrder order;
  final ServerInboxController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return AlertDialog(
      title: Text(l.orderNumber(order.displayNumber)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailRow(label: l.sourceDevice, value: order.clientDisplayName),
              _DetailRow(
                label: l.receivedAt,
                value: DateFormat.yMMMd(locale)
                    .add_Hm()
                    .format(order.receivedAt.toLocal()),
              ),
              _DetailRow(
                label: l.createdAt,
                value: DateFormat.yMMMd(locale)
                    .add_Hm()
                    .format(order.sourceCreatedAt.toLocal()),
              ),
              if (order.heading.isNotEmpty)
                _DetailRow(label: l.heading, value: order.heading),
              if (order.reference.isNotEmpty)
                _DetailRow(label: l.orderReference, value: order.reference),
              const Divider(height: 28),
              for (final line in order.lines) ...[
                Text(
                  '${line.quantity}×  ${line.name}',
                  style: theme.textTheme.titleMedium,
                ),
                if (line.preparationNote.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(line.preparationNote),
                ],
                const SizedBox(height: 14),
              ],
              if (order.orderNote.isNotEmpty) ...[
                const Divider(),
                Text(l.orderNotes, style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(order.orderNote),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.close),
        ),
        if (order.status == ServerOrderStatus.received)
          FilledButton.icon(
            key: const ValueKey('mark-order-done'),
            onPressed: controller.updating
                ? null
                : () async {
                    final success = await controller.markDone(order.id);
                    if (!context.mounted) return;
                    if (success) {
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(l.markDoneFailed)));
                    }
                  },
            icon: const Icon(Icons.task_alt_rounded),
            label: Text(controller.updating ? l.markingDone : l.markDone),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 2),
        Text(value),
      ],
    ),
  );
}

String _displayFingerprint(String value) {
  final groups = <String>[];
  for (var index = 0; index < value.length; index += 8) {
    groups.add(value.substring(index, index + 8).toUpperCase());
  }
  return groups.join(' ');
}
