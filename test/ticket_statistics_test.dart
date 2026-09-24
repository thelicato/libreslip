import 'package:flutter_test/flutter_test.dart';
import 'package:libreslip/features/orders/domain/order_models.dart';
import 'package:libreslip/features/workspace/application/ticket_statistics.dart';

void main() {
  test('ticket statistics use an inclusive local date range', () {
    final tickets = [
      _ticket('before', DateTime(2026, 9, 19, 23, 59), [4]),
      _ticket('start', DateTime(2026, 9, 20), [2, 1]),
      _ticket('end', DateTime(2026, 9, 22, 23, 59, 59), [5]),
      _ticket('after', DateTime(2026, 9, 23), [7]),
    ];

    final statistics = TicketStatistics.calculate(
      tickets,
      startDate: DateTime(2026, 9, 20),
      endDate: DateTime(2026, 9, 22),
    );

    expect(statistics.ticketCount, 2);
    expect(statistics.itemQuantity, 8);
    expect(statistics.averageItemsPerTicket, 4);
  });

  test('ticket statistics support all history and an empty result', () {
    final tickets = [
      _ticket('one', DateTime(2026, 9, 20), [2, 1]),
      _ticket('two', DateTime(2026, 9, 21), [2]),
    ];

    final all = TicketStatistics.calculate(tickets);
    expect(all.ticketCount, 2);
    expect(all.itemQuantity, 5);
    expect(all.averageItemsPerTicket, 2.5);

    final empty = TicketStatistics.calculate(
      tickets,
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 2),
    );
    expect(empty.ticketCount, 0);
    expect(empty.itemQuantity, 0);
    expect(empty.averageItemsPerTicket, 0);
  });
}

SavedTicket _ticket(String id, DateTime createdAt, List<int> quantities) =>
    SavedTicket(
      id: id,
      number: 1,
      createdAt: createdAt,
      heading: '',
      reference: '',
      orderNote: '',
      lines: [
        for (var index = 0; index < quantities.length; index++)
          TicketLine(
            id: '$id-$index',
            name: 'Item $index',
            quantity: quantities[index],
          ),
      ],
    );
