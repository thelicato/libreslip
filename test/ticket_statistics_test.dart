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
    expect(
      statistics.items
          .map((item) => (item.name, item.quantity))
          .toList(growable: false),
      [('Item 0', 7), ('Item 1', 1)],
    );
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
    expect(
      all.items
          .map((item) => (item.name, item.quantity))
          .toList(growable: false),
      [('Item 0', 4), ('Item 1', 1)],
    );

    final empty = TicketStatistics.calculate(
      tickets,
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 2),
    );
    expect(empty.ticketCount, 0);
    expect(empty.itemQuantity, 0);
    expect(empty.averageItemsPerTicket, 0);
    expect(empty.items, isEmpty);
  });

  test('item breakdown preserves renamed ticket snapshots', () {
    final tickets = [
      _namedTicket(
        id: 'old',
        createdAt: DateTime(2026, 9, 20),
        catalogueItemId: 'toastie',
        name: 'Cheese toastie',
        quantity: 2,
      ),
      _namedTicket(
        id: 'new',
        createdAt: DateTime(2026, 9, 21),
        catalogueItemId: 'toastie',
        name: 'Mature cheddar toastie',
        quantity: 3,
      ),
      _namedTicket(
        id: 'soup',
        createdAt: DateTime(2026, 9, 21),
        catalogueItemId: 'soup',
        name: 'Soup',
        quantity: 3,
      ),
    ];

    final statistics = TicketStatistics.calculate(tickets);

    expect(
      statistics.items
          .map((item) => (item.name, item.quantity))
          .toList(growable: false),
      [('Mature cheddar toastie', 3), ('Soup', 3), ('Cheese toastie', 2)],
    );
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

SavedTicket _namedTicket({
  required String id,
  required DateTime createdAt,
  required String catalogueItemId,
  required String name,
  required int quantity,
}) => SavedTicket(
  id: id,
  number: 1,
  createdAt: createdAt,
  heading: '',
  reference: '',
  orderNote: '',
  lines: [
    TicketLine(
      id: '$id-line',
      catalogueItemId: catalogueItemId,
      name: name,
      quantity: quantity,
    ),
  ],
);
