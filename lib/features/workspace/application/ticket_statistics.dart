import '../../orders/domain/order_models.dart';

class TicketItemStatistic {
  const TicketItemStatistic({required this.name, required this.quantity});

  final String name;
  final int quantity;
}

class TicketStatistics {
  const TicketStatistics({
    required this.ticketCount,
    required this.itemQuantity,
    required this.items,
  });

  final int ticketCount;
  final int itemQuantity;
  final List<TicketItemStatistic> items;

  double get averageItemsPerTicket =>
      ticketCount == 0 ? 0 : itemQuantity / ticketCount;

  static TicketStatistics calculate(
    Iterable<SavedTicket> tickets, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final start = startDate == null ? null : _startOfDay(startDate);
    final endExclusive = endDate == null
        ? null
        : _startOfDay(endDate).add(const Duration(days: 1));
    final quantities = <_SnapshotItemKey, int>{};
    var ticketCount = 0;
    var itemQuantity = 0;
    for (final ticket in tickets) {
      final createdAt = ticket.createdAt.toLocal();
      if (start != null && createdAt.isBefore(start)) continue;
      if (endExclusive != null && !createdAt.isBefore(endExclusive)) continue;
      ticketCount++;
      itemQuantity += ticket.itemCount;
      for (final line in ticket.lines) {
        final key = _SnapshotItemKey(line.catalogueItemId, line.name);
        quantities.update(
          key,
          (quantity) => quantity + line.quantity,
          ifAbsent: () => line.quantity,
        );
      }
    }
    final items =
        [
          for (final entry in quantities.entries)
            TicketItemStatistic(name: entry.key.name, quantity: entry.value),
        ]..sort((left, right) {
          final byQuantity = right.quantity.compareTo(left.quantity);
          if (byQuantity != 0) return byQuantity;
          return left.name.toLowerCase().compareTo(right.name.toLowerCase());
        });
    return TicketStatistics(
      ticketCount: ticketCount,
      itemQuantity: itemQuantity,
      items: List.unmodifiable(items),
    );
  }

  static DateTime _startOfDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

class _SnapshotItemKey {
  const _SnapshotItemKey(this.catalogueItemId, this.name);

  final String? catalogueItemId;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is _SnapshotItemKey &&
      other.catalogueItemId == catalogueItemId &&
      other.name == name;

  @override
  int get hashCode => Object.hash(catalogueItemId, name);
}
