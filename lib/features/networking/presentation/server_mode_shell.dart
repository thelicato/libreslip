import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_version_footer.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/presentation/personalisation_settings.dart';
import '../application/network_mode_controller.dart';
import '../application/server_inbox_controller.dart';
import '../domain/server_inbox_models.dart';
import 'mode_settings_card.dart';

class ServerModeShell extends StatefulWidget {
  const ServerModeShell({
    super.key,
    required this.settingsController,
    required this.modeController,
    required this.inboxController,
  });

  final SettingsController settingsController;
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
      unawaited(widget.inboxController.refresh());
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
                      if (_showCompleted &&
                          controller.completedOrders.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                            key: const ValueKey('delete-all-completed-orders'),
                            onPressed: controller.updating
                                ? null
                                : _deleteAllCompleted,
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context)
                                  .colorScheme
                                  .error,
                            ),
                            icon: const Icon(Icons.delete_sweep_outlined),
                            label: Text(l.deleteAllCompletedOrders),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
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
                  final columns = constraints.crossAxisExtent >= 720 ? 2 : 1;
                  final rowCount = (orders.length / columns).ceil();
                  return SliverList.builder(
                    itemCount: rowCount,
                    itemBuilder: (context, rowIndex) {
                      final firstIndex = rowIndex * columns;
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1000),
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: rowIndex == rowCount - 1 ? 0 : 16,
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: _OrderCard(
                                      order: orders[firstIndex],
                                      onTap: () =>
                                          _showOrder(orders[firstIndex]),
                                    ),
                                  ),
                                  if (columns == 2) ...[
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: firstIndex + 1 < orders.length
                                          ? _OrderCard(
                                              order: orders[firstIndex + 1],
                                              onTap: () => _showOrder(
                                                orders[firstIndex + 1],
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
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
                    const SizedBox(height: 20),
                    LanguageSettingsCard(controller: widget.settingsController),
                    const SizedBox(height: 20),
                    AppearanceSettingsCard(
                      controller: widget.settingsController,
                    ),
                    const SizedBox(height: 20),
                    TextSizeSettingsCard(controller: widget.settingsController),
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

  Future<void> _deleteAllCompleted() async {
    final l = AppLocalizations.of(context);
    final count = widget.inboxController.completedOrders.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteAllCompletedOrdersQuestion),
        content: Text(l.deleteAllCompletedOrdersBody(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-all-completed-orders'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await widget.inboxController.deleteAllCompleted();
    if (!mounted || deleted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.deleteCompletedOrdersFailed)));
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 680 ? 2 : 1;
                  const spacing = 12.0;
                  final tileWidth = columns == 2
                      ? (constraints.maxWidth - spacing) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (var index = 0; index < totals.length; index++)
                        SizedBox(
                          key: ValueKey('outstanding-item-$index'),
                          width: tileWidth,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    fit: FlexFit.loose,
                                    child: Text(
                                      totals[index].name,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      quantityFormat.format(
                                        totals[index].quantity,
                                      ),
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onPrimaryContainer,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
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
    final request = controller.pendingPairingRequest;
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
            if (request == null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.hourglass_empty_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.waitingForPairingRequest,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(l.waitingForPairingRequestBody),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                key: const ValueKey('pending-pairing-request'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.pairingRequest, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Text(
                      l.pairingRequestBody(
                        request.displayName,
                        request.sourceAddress,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('reject-pairing-request'),
                      onPressed: controller.rejectPairingRequest,
                      child: Text(l.rejectPairing),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('accept-pairing-request'),
                      onPressed: controller.acceptPairingRequest,
                      child: Text(l.acceptPairing),
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
                Text(order.reference, style: theme.textTheme.titleMedium),
              ],
              const SizedBox(height: 16),
              for (var index = 0; index < order.lines.length; index++) ...[
                if (index > 0) const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${order.lines[index].quantity}×',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        order.lines[index].name,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                if (order.lines[index].preparationNote.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 48, top: 3),
                    child: Text(
                      order.lines[index].preparationNote,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              Text(
                DateFormat.yMMMd(locale)
                    .add_Hm()
                    .format(order.receivedAt.toLocal()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 760;
    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: wide ? 48 : 20,
        vertical: 24,
      ),
      constraints: BoxConstraints(
        minWidth: wide ? (size.width - 96).clamp(560, 720) : 0,
        maxWidth: 760,
        maxHeight: size.height - 48,
      ),
      title: Text(l.orderNumber(order.displayNumber)),
      content: SizedBox(
        width: wide ? 680 : null,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
        if (order.status == ServerOrderStatus.done)
          TextButton.icon(
            key: const ValueKey('delete-completed-order'),
            onPressed: controller.updating
                ? null
                : () => _deleteCompleted(context),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(l.deleteCompletedOrder),
          ),
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
          )
        else
          FilledButton.tonalIcon(
            key: const ValueKey('mark-order-received'),
            onPressed: controller.updating
                ? null
                : () async {
                    final success = await controller.markReceived(order.id);
                    if (!context.mounted) return;
                    if (success) {
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.markReceivedFailed)),
                      );
                    }
                  },
            icon: const Icon(Icons.undo_rounded),
            label: Text(
              controller.updating ? l.markingReceived : l.markReceived,
            ),
          ),
      ],
    );
  }

  Future<void> _deleteCompleted(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.deleteCompletedOrderQuestion(order.displayNumber)),
        content: Text(l.deleteCompletedOrderBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-completed-order'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await controller.deleteCompleted(order.id);
    if (!context.mounted) return;
    if (deleted) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.deleteCompletedOrdersFailed)));
    }
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
