part of 'sqlite_order_repository.dart';

/// One saved copy per order. Print attempts keep their outcomes, never a
/// recoverable queue for content which has since changed.
abstract final class _LatestOrders {
  static Future<void> supersedeQueued(DatabaseExecutor tx, String id) =>
      tx.update(
        'print_jobs',
        {'status': 'failed', 'error_code': 'superseded'},
        where: "ticket_id = ? AND status = 'queued'",
        whereArgs: [id],
      );

  static Future<void> consolidate(
    DatabaseExecutor tx, {
    bool legacy = false,
  }) async {
    for (final row in await tx.query('managed_orders')) {
      await write(
        tx,
        SqliteOrderRepository._managedFromRow(row),
        legacy: legacy,
      );
    }
    await tx.execute(
      'INSERT OR IGNORE INTO order_save_receipts SELECT origin_draft_id, id FROM tickets',
    );
  }

  static Future<void> write(
    DatabaseExecutor tx,
    ManagedOrder order, {
    bool legacy = false,
  }) async {
    final rows = await tx.query(
      'tickets',
      where: 'managed_order_id = ?',
      whereArgs: [order.id],
      orderBy: 'revision DESC, created_at DESC',
    );
    final id = rows.isEmpty ? createLocalId() : rows.first['id'] as String;
    if (rows.isEmpty) {
      final counter = (await tx.query(
        'counters',
        where: 'name = ?',
        whereArgs: ['ticket'],
      )).single;
      await tx.insert('tickets', {
        'id': id,
        'ticket_number': counter['next_value'],
        'display_number': order.number,
        'origin_draft_id': 'saved-$id',
        'heading_snapshot': order.heading,
        'reference_snapshot': order.reference,
        'order_note_snapshot': order.orderNote,
        'created_at': SqliteOrderRepository._timestamp(order.createdAt),
        'courses_json': jsonEncode(
          order.courses.map((c) => c.toJson()).toList(),
        ),
        'managed_order_id': order.id,
        'revision': order.revision,
        'addition_line_ids': jsonEncode(order.lines.map((l) => l.id).toList()),
      });
      await tx.update(
        'counters',
        {'next_value': (counter['next_value'] as int) + 1},
        where: 'name = ?',
        whereArgs: ['ticket'],
      );
    } else {
      final old = await SqliteOrderRepository._ticketFromRow(tx, rows.first);
      final changed =
          old.revision != order.revision ||
          jsonEncode(old.courses.map((c) => c.toJson()).toList()) !=
              jsonEncode(order.courses.map((c) => c.toJson()).toList()) ||
          jsonEncode(
                old.lines
                    .map(
                      (l) => [
                        l.id,
                        l.name,
                        l.quantity,
                        l.preparationNote,
                        l.courseId,
                      ],
                    )
                    .toList(),
              ) !=
              jsonEncode(
                order.lines
                    .map(
                      (l) => [
                        l.id,
                        l.name,
                        l.quantity,
                        l.preparationNote,
                        l.courseId,
                      ],
                    )
                    .toList(),
              );
      if (changed || (legacy && old.revision > 1)) {
        await supersedeQueued(tx, id);
      }
      await tx.update(
        'tickets',
        {
          'revision': order.revision,
          'heading_snapshot': order.heading,
          'reference_snapshot': order.reference,
          'order_note_snapshot': order.orderNote,
          'courses_json': jsonEncode(
            order.courses.map((c) => c.toJson()).toList(),
          ),
          'addition_line_ids': jsonEncode(
            order.lines.map((l) => l.id).toList(),
          ),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    for (final old in rows.skip(1)) {
      await supersedeQueued(tx, old['id'] as String);
      await tx.update(
        'print_jobs',
        {'ticket_id': id},
        where: 'ticket_id = ?',
        whereArgs: [old['id']],
      );
      // Delivery payloads and operation identities remain frozen for retry.
      await tx.update(
        'server_delivery_outbox',
        {'ticket_id': id},
        where: 'ticket_id = ?',
        whereArgs: [old['id']],
      );
      await tx.update(
        'order_save_receipts',
        {'ticket_id': id},
        where: 'ticket_id = ?',
        whereArgs: [old['id']],
      );
      await tx.delete(
        'ticket_lines',
        where: 'ticket_id = ?',
        whereArgs: [old['id']],
      );
      await tx.delete('tickets', where: 'id = ?', whereArgs: [old['id']]);
    }
    await tx.delete('ticket_lines', where: 'ticket_id = ?', whereArgs: [id]);
    for (var i = 0; i < order.lines.length; i++) {
      final l = order.lines[i];
      await tx.insert('ticket_lines', {
        'id': createLocalId(),
        'ticket_id': id,
        'order_line_id': l.id,
        'catalogue_item_id': l.catalogueItemId,
        'name_snapshot': l.name,
        'quantity': l.quantity,
        'preparation_note': l.preparationNote,
        'course_id': l.courseId,
        'price_minor_units': l.price?.minorUnits,
        'price_currency': l.price?.currency,
        'position': i,
      });
    }
  }

  static Future<void> changeItem(
    SqliteOrderRepository repo,
    String orderId,
    String lineId,
    int quantity,
    int expected,
    String? note,
  ) async {
    if (quantity < 0 || quantity > 999 || (note?.length ?? 0) > 300) {
      throw const OrderStorageException('Invalid item edit.');
    }
    await (await repo._db).transaction((tx) async {
      final row = (await tx.query(
        'managed_orders',
        where: 'id = ? AND closed_at IS NULL',
        whereArgs: [orderId],
      )).single;
      final order = SqliteOrderRepository._managedFromRow(row);
      final line = order.lines.singleWhere((l) => l.id == lineId);
      if (order.revision != expected ||
          (order.destinationId != null && line.sendToServer)) {
        throw const OrderStorageException('Invalid or stale item edit.');
      }
      final lines = [
        for (final l in order.lines)
          if (l.id != lineId)
            l
          else if (quantity > 0)
            l.copyWith(
              quantity: quantity,
              preparationNote: note ?? l.preparationNote,
            ),
      ];
      final progress = {...order.deliveredQuantities};
      if (quantity == 0) {
        progress.remove(lineId);
      } else if ((progress[lineId] ?? 0) > quantity) {
        progress[lineId] = quantity;
      }
      final dirty = order.changedDeliveryIds
          .where((id) => lines.any((l) => l.id == id))
          .toList();
      await tx.update(
        'managed_orders',
        {
          'lines_json': encodeOrderLines(lines),
          'revision': order.revision + 1,
          'delivery_progress_json': jsonEncode(progress),
          'delivery_changed_ids': jsonEncode(dirty),
          'updated_at': SqliteOrderRepository._timestamp(
            DateTime.now().toUtc(),
          ),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
      await tx.update(
        'drafts',
        {'base_revision': order.revision + 1},
        where: 'managed_order_id = ?',
        whereArgs: [orderId],
      );
      await write(
        tx,
        SqliteOrderRepository._managedFromRow(
          (await tx.query(
            'managed_orders',
            where: 'id = ?',
            whereArgs: [orderId],
          )).single,
        ),
      );
    });
  }
}
