import '../../orders/domain/order_models.dart';

class TicketStatistics {
  const TicketStatistics({
    required this.ticketCount,
    required this.itemQuantity,
  });

  final int ticketCount;
  final int itemQuantity;

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
    var ticketCount = 0;
    var itemQuantity = 0;
    for (final ticket in tickets) {
      final createdAt = ticket.createdAt.toLocal();
      if (start != null && createdAt.isBefore(start)) continue;
      if (endExclusive != null && !createdAt.isBefore(endExclusive)) continue;
      ticketCount++;
      itemQuantity += ticket.itemCount;
    }
    return TicketStatistics(
      ticketCount: ticketCount,
      itemQuantity: itemQuantity,
    );
  }

  static DateTime _startOfDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
