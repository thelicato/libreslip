part of 'sqlite_order_repository.dart';

/// Network state is private to this installation and excluded from archives.
class _SharedPersistence {
  const _SharedPersistence(this.repository);
  final SqliteOrderRepository repository;

  Future<List<SharedOrderHead>> ids(String after) async => [
    for (final row in await (await repository._db).query(
      'server_orders',
      columns: ['id', 'revision', 'progress_revision'],
      where: 'managed_order_id IS NOT NULL AND id > ?',
      whereArgs: [after],
      orderBy: 'id',
      limit: 50,
    ))
      SharedOrderHead(
        row['id'] as String,
        row['revision'] as int,
        row['progress_revision'] as int,
      ),
  ];

  Future<SharedOrderSnapshot> snapshot(String id) async {
    final db = await repository._db;
    return db.transaction((tx) async {
      final rows = await tx.query(
        'server_orders',
        where: 'id = ? AND managed_order_id IS NOT NULL',
        whereArgs: [id],
      );
      if (rows.isEmpty) throw const ProgressSyncException('missing');
      return SharedOrderSnapshot.fromOrder(
        await SqliteOrderRepository._loadServerOrder(tx, id),
      );
    });
  }

  Future<OrderProgressSnapshot> progress(
    String actor,
    OrderProgressChange change,
  ) async => (await repository._db).transaction((tx) async {
    await _requireActor(tx, actor);
    final rows = await tx.query(
      'server_orders',
      where: 'id = ? AND managed_order_id IS NOT NULL',
      whereArgs: [change.orderId],
    );
    if (rows.length != 1) throw const ProgressSyncException('missing');
    return SqliteOrderRepository._applyProgress(
      tx,
      actor,
      change,
      serverOrderId: change.orderId,
    );
  });

  static Future<void> _requireActor(DatabaseExecutor tx, String actor) async {
    if ((await tx.query(
          'server_clients',
          where: 'installation_id = ?',
          whereArgs: [actor],
        )).length !=
        1) {
      throw const OrderStorageException('The client is not paired.');
    }
  }

  Future<ServerOrderReceipt> append(
    String actor,
    String id,
    OrderDeliveryEnvelope envelope,
    List<String> additionIds,
  ) async {
    final db = await repository._db;
    return db.transaction((tx) async {
      await _requireActor(tx, actor);
      if (envelope.clientInstallationId != actor ||
          envelope.managedOrderId == null ||
          additionIds.isEmpty ||
          additionIds.length > 200 ||
          additionIds.toSet().length != additionIds.length ||
          additionIds.any(
            (id) => !envelope.lines.any((line) => line.id == id),
          )) {
        throw const FormatException('Invalid shared additions');
      }
      final rows = await tx.query(
        'server_orders',
        where: 'id = ? AND managed_order_id IS NOT NULL',
        whereArgs: [id],
      );
      if (rows.length != 1) throw const ProgressSyncException('missing');
      final current = await SqliteOrderRepository._loadServerOrder(tx, id);
      final receipts = await tx.query(
        'server_shared_receipts',
        where: 'client_id = ? AND operation_id = ?',
        whereArgs: [actor, envelope.deliveryId],
      );
      final encodedIds = jsonEncode(additionIds);
      if (receipts.isNotEmpty) {
        final row = receipts.single;
        if (row['order_id'] != id ||
            row['payload_checksum'] != envelope.payloadChecksum ||
            row['addition_ids'] != encodedIds) {
          throw const ServerOrderConflictException();
        }
        return ServerOrderReceipt(order: current, wasDuplicate: true);
      }
      if (current.displayNumber != envelope.ticketNumber ||
          current.heading != envelope.heading ||
          current.reference != envelope.reference ||
          current.orderNote != envelope.orderNote ||
          current.sourceCreatedAt.toUtc() != envelope.createdAt ||
          current.lines.length + additionIds.length >
              NetworkProtocol.maxLines) {
        throw const ServerOrderConflictException();
      }
      // Requests carry immutable local ticket snapshots. Only their new stable
      // line identifiers are appended, so concurrent Clients cannot erase items.
      for (final line in envelope.lines) {
        final previous = current.lines
            .where((old) => old.id == line.id)
            .toList();
        if (additionIds.contains(line.id)) {
          if (previous.isNotEmpty) throw const ServerOrderConflictException();
        } else if (previous.length != 1 ||
            previous.single.name != line.name ||
            previous.single.quantity != line.quantity ||
            previous.single.preparationNote != line.preparationNote ||
            previous.single.courseId != line.courseId) {
          throw const ServerOrderConflictException();
        }
      }
      final newLines = envelope.lines
          .where((line) => additionIds.contains(line.id))
          .toList();
      final courses = [...current.courses];
      for (final course in envelope.courses) {
        final previous = courses.where((old) => old.id == course.id).toList();
        if (previous.isNotEmpty) {
          if (!course.isDivider && previous.single.name != course.name) {
            throw const ServerOrderConflictException();
          }
        } else if (newLines.any((line) => line.courseId == course.id)) {
          courses.add(_uniqueCourse(course, courses));
        }
      }
      final merged = OrderDeliveryEnvelope.create(
        clientInstallationId: current.clientInstallationId,
        deliveryId: envelope.deliveryId,
        ticketId: envelope.ticketId,
        ticketNumber: current.displayNumber,
        createdAt: current.sourceCreatedAt,
        heading: current.heading,
        reference: current.reference,
        orderNote: current.orderNote,
        managedOrderId: current.managedOrderId,
        revision: current.revision + 1,
        courses: courses,
        lines: [
          for (final line in current.lines)
            DeliveryLine(
              id: line.id,
              name: line.name,
              quantity: line.quantity,
              preparationNote: line.preparationNote,
              courseId: line.courseId,
            ),
          ...newLines,
        ],
      );
      for (var i = 0; i < newLines.length; i++) {
        final line = newLines[i];
        await tx.insert('server_order_lines', {
          'id': createLocalId(),
          'order_id': id,
          'order_line_id': line.id,
          'added_revision': merged.revision,
          'delivered_quantity': 0,
          'name_snapshot': line.name,
          'quantity': line.quantity,
          'preparation_note': line.preparationNote,
          'course_id': line.courseId,
          'position': current.lines.length + i,
        });
      }
      await tx.update(
        'server_orders',
        {
          'delivery_id': merged.deliveryId,
          'client_ticket_id': merged.ticketId,
          'revision': merged.revision,
          'courses_json': jsonEncode(courses.map((c) => c.toJson()).toList()),
          'payload_checksum': merged.payloadChecksum,
          'status': 'received',
          'completed_at': null,
          'received_at': SqliteOrderRepository._timestamp(
            DateTime.now().toUtc(),
          ),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await tx.insert('server_shared_receipts', {
        'client_id': actor,
        'operation_id': envelope.deliveryId,
        'order_id': id,
        'payload_checksum': envelope.payloadChecksum,
        'addition_ids': encodedIds,
      });
      return ServerOrderReceipt(
        order: await SqliteOrderRepository._loadServerOrder(tx, id),
        wasDuplicate: false,
      );
    });
  }

  static OrderCourse _uniqueCourse(
    OrderCourse course,
    List<OrderCourse> courses,
  ) {
    if (!courses.any(
      (old) => old.name.toLowerCase() == course.name.toLowerCase(),
    )) {
      return course;
    }
    if (!course.isDivider) throw const ServerOrderConflictException();
    var ordinal = 1;
    while (courses.any((old) => old.name == '#$ordinal')) {
      ordinal++;
    }
    return OrderCourse(id: course.id, name: '#$ordinal');
  }

  static SharedOrderLink _link(Map<String, Object?> row) => SharedOrderLink(
    orderId: row['order_id'] as String,
    destinationId: row['destination_id'] as String,
    baseline: SharedOrderSnapshot.fromJson(
      jsonDecode(row['baseline_json'] as String),
    ),
    pending: row['pending_json'] == null
        ? null
        : OrderProgressChange.fromJson(
            jsonDecode(row['pending_json'] as String),
          ),
    pendingLocalRevision: row['pending_local_revision'] as int?,
  );

  Future<List<SharedOrderLink>> links() async =>
      (await (await repository._db).query('shared_order_links'))
          .map(_link)
          .toList();

  Future<SharedOrderLink?> link(String id) async {
    final rows = await (await repository._db).query(
      'shared_order_links',
      where: 'order_id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : _link(rows.single);
  }

  Future<SharedDeliveryTarget?> target(ClientDelivery delivery) async {
    final id = delivery.envelope.managedOrderId;
    if (id == null) return null;
    final db = await repository._db;
    final rows = await db.query(
      'server_delivery_outbox',
      where: 'id = ?',
      whereArgs: [delivery.id],
    );
    if (rows.length != 1 ||
        rows.single['payload_checksum'] != delivery.envelope.payloadChecksum ||
        rows.single['destination_id'] != delivery.destinationId ||
        rows.single['client_installation_id'] !=
            delivery.clientInstallationId) {
      throw const OrderStorageException('Invalid shared delivery scope.');
    }
    final row = rows.single;
    final mapping = await link(id);
    if (mapping != null && mapping.destinationId != delivery.destinationId) {
      return null;
    }
    final frozenTarget = row['shared_server_order_id'] as String?;
    String? serverOrderId = frozenTarget ?? mapping?.baseline.serverOrderId;
    OrderDeliveryEnvelope? earlierEnvelope;
    // An addition may precede the first feed refresh. Existing receipts already
    // identify its Server order, including after successful backup replacement.
    for (final receipt in await db.query(
      'server_delivery_outbox',
      where: "destination_id = ? AND client_installation_id = ? AND status = 'delivered' AND server_order_id IS NOT NULL",
      whereArgs: [delivery.destinationId, delivery.clientInstallationId],
      orderBy: 'created_at DESC',
    )) {
      final earlier = OrderDeliveryEnvelope.fromJsonString(
        receipt['payload_json'] as String,
      );
      if (earlier.managedOrderId == id &&
          earlier.revision < delivery.envelope.revision) {
        serverOrderId ??= receipt['server_order_id'] as String;
        earlierEnvelope = earlier;
        break;
      }
    }
    if (serverOrderId == null) return null;
    final rawIds = row['shared_addition_ids'];
    List<String> additions;
    if (rawIds == null) {
      // Pre-sharing envelopes never contained another Client's lines, so a
      // legacy orphan can recover its delta from its earlier frozen receipt.
      if (earlierEnvelope == null) return null;
      final previousIds = earlierEnvelope.lines.map((line) => line.id).toSet();
      additions = delivery.envelope.lines
          .where((line) => !previousIds.contains(line.id))
          .map((line) => line.id!)
          .toList();
    } else {
      final values = jsonDecode(rawIds as String);
      if (values is! List ||
          values.length > 200 ||
          values.any((id) => id is! String || !validOrderId(id)) ||
          values.toSet().length != values.length) {
        throw const FormatException('Invalid frozen shared additions');
      }
      additions = values
          .cast<String>()
          .where((id) => delivery.envelope.lines.any((line) => line.id == id))
          .toList();
    }
    if (additions.isEmpty || !validOrderId(serverOrderId)) {
      throw const FormatException('Missing shared additions');
    }
    return SharedDeliveryTarget(
      serverOrderId,
      additions,
      requiresSharing: frozenTarget != null || mapping != null,
    );
  }

  Future<void> merge(String destination, SharedOrderSnapshot remote) async {
    // Validate again at the persistence boundary before opening the transaction.
    remote = SharedOrderSnapshot.fromJson(
      jsonDecode(jsonEncode(remote.toJson())),
    );
    final incoming = remote.envelope;
    final db = await repository._db;
    await db.transaction((tx) async {
      final config = (await tx.query(
        'network_settings',
        where: 'id = 1',
      )).single;
      final actor = config['installation_id'] as String;
      final destinationRows = await tx.query(
        'network_destinations',
        where: 'id = ? AND is_active = 1',
        whereArgs: [destination],
      );
      if (destinationRows.isEmpty) {
        throw const OrderStorageException('The Server is no longer paired.');
      }
      final links = await tx.query(
        'shared_order_links',
        where: 'destination_id = ? AND server_order_id = ?',
        whereArgs: [destination, remote.serverOrderId],
      );
      String id;
      if (links.isNotEmpty) {
        id = links.single['order_id'] as String;
      } else {
        final own = incoming.clientInstallationId == actor
            ? await tx.query(
                'managed_orders',
                where: 'id = ? AND destination_id = ? AND client_installation_id = ?',
                whereArgs: [incoming.managedOrderId, destination, actor],
              )
            : <Map<String, Object?>>[];
        // Missing origin snapshots after a restore also receive a new local ID.
        id = own.isNotEmpty
            ? incoming.managedOrderId!
            : 'shared-${sha256.convert(utf8.encode('$destination/${remote.serverOrderId}'))}';
      }
      final rows = await tx.query(
        'managed_orders',
        where: 'id = ?',
        whereArgs: [id],
      );
      final previous = rows.isEmpty
          ? null
          : SqliteOrderRepository._managedFromRow(rows.single);
      // Frozen print-gated revisions stay intact until delivery is acknowledged.
      final pendingDeliveries = await tx.rawQuery(
        '''SELECT o.id FROM server_delivery_outbox o
        JOIN tickets t ON t.id = o.ticket_id
        WHERE t.managed_order_id = ? AND o.destination_id = ? AND o.status != 'delivered' ''',
        [id, destination],
      );
      if (pendingDeliveries.isNotEmpty) return;
      if (links.isNotEmpty) {
        final before = _link(links.single).baseline;
        if (incoming.revision < before.envelope.revision ||
            remote.progress.progressRevision <
                before.progress.progressRevision ||
            before.envelope.clientInstallationId !=
                incoming.clientInstallationId ||
            before.envelope.managedOrderId != incoming.managedOrderId ||
            before.envelope.lines.any(
              (old) => !incoming.lines.any((line) => line.id == old.id),
            )) {
          throw const FormatException('Regressive shared order');
        }
      }
      final lines = [...?previous?.lines];
      for (final line in incoming.lines) {
        final old = lines.where((old) => old.id == line.id).toList();
        if (old.isEmpty) {
          lines.add(
            TicketLine(
              id: line.id!,
              name: line.name,
              quantity: line.quantity,
              preparationNote: line.preparationNote,
              courseId: line.courseId,
            ),
          );
        } else if (!old.single.sendToServer ||
            old.single.name != line.name ||
            old.single.quantity != line.quantity ||
            old.single.preparationNote != line.preparationNote ||
            old.single.courseId != line.courseId) {
          throw const FormatException('Changed immutable shared item');
        }
      }
      if (lines.length > NetworkProtocol.maxLines) {
        throw const FormatException('Too many shared lines');
      }
      final courses = [...?previous?.courses];
      for (final course in incoming.courses) {
        if (!courses.any((old) => old.id == course.id)) {
          courses.add(_uniqueCourse(course, courses));
        }
      }
      // Current shared content follows the Server's ordering. Immutable ticket
      // snapshots retain the order in which this Client originally saved them.
      final localLinePositions = {
        for (var i = 0; i < lines.length; i++) lines[i].id: i,
      };
      final sharedLinePositions = {
        for (var i = 0; i < incoming.lines.length; i++) incoming.lines[i].id: i,
      };
      lines.sort(
        (left, right) =>
            (sharedLinePositions[left.id] ??
                    incoming.lines.length + localLinePositions[left.id]!)
                .compareTo(
                  sharedLinePositions[right.id] ??
                      incoming.lines.length + localLinePositions[right.id]!,
                ),
      );
      final localCoursePositions = {
        for (var i = 0; i < courses.length; i++) courses[i].id: i,
      };
      final sharedCoursePositions = {
        for (var i = 0; i < incoming.courses.length; i++)
          incoming.courses[i].id: i,
      };
      courses.sort(
        (left, right) =>
            (sharedCoursePositions[left.id] ??
                    incoming.courses.length + localCoursePositions[left.id]!)
                .compareTo(
                  sharedCoursePositions[right.id] ??
                      incoming.courses.length + localCoursePositions[right.id]!,
                ),
      );
      validateCourses(courses, lines.map((line) => line.courseId));
      final progress = {...?previous?.deliveredQuantities};
      for (final line in incoming.lines) {
        if (previous?.changedDeliveryIds.contains(line.id) ?? false) continue;
        final count = remote.progress.quantities[line.id]!;
        if (count == 0) {
          progress.remove(line.id);
        } else {
          progress[line.id!] = count;
        }
      }
      final changedContent =
          previous == null ||
          lines.length != previous.lines.length ||
          courses.length != previous.courses.length;
      final revision = previous == null
          ? incoming.revision
          : (changedContent ? previous.revision + 1 : previous.revision);
      final effectiveRevision = revision < incoming.revision
          ? incoming.revision
          : revision;
      final values = <String, Object?>{
        'display_number': incoming.ticketNumber,
        'revision': effectiveRevision,
        'created_at': SqliteOrderRepository._timestamp(incoming.createdAt),
        'updated_at': previous != null && !changedContent
            ? SqliteOrderRepository._timestamp(previous.updatedAt)
            : SqliteOrderRepository._timestamp(DateTime.now().toUtc()),
        'heading_snapshot': incoming.heading,
        'reference_snapshot': incoming.reference,
        'order_note_snapshot': incoming.orderNote,
        'courses_json': jsonEncode(courses.map((c) => c.toJson()).toList()),
        'lines_json': encodeOrderLines(lines),
        'destination_id': destination,
        'client_installation_id': actor,
        'server_revision': incoming.revision,
        'delivery_progress_json': jsonEncode(progress),
      };
      if (previous == null) {
        await tx.insert('managed_orders', {'id': id, ...values});
      } else {
        if (previous.heading != incoming.heading ||
            previous.reference != incoming.reference ||
            previous.orderNote != incoming.orderNote ||
            previous.createdAt.toUtc() != incoming.createdAt) {
          throw const FormatException('Changed shared order identity');
        }
        await tx.update(
          'managed_orders',
          values,
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      // A changed line keeps the last observed count until acknowledged or
      // explicitly resolved. Polling must never silently accept a conflict.
      final oldBaseline = links.isEmpty
          ? null
          : _link(links.single).baseline.progress;
      final baselineCounts = {...remote.progress.quantities};
      for (final dirty in previous?.changedDeliveryIds ?? <String>{}) {
        if (baselineCounts.containsKey(dirty)) {
          baselineCounts[dirty] = oldBaseline?.quantities[dirty] ?? 0;
        }
      }
      final baseline = SharedOrderSnapshot(
        remote.serverOrderId,
        incoming,
        OrderProgressSnapshot(
          clientId: remote.progress.clientId,
          orderId: remote.progress.orderId,
          orderRevision: remote.progress.orderRevision,
          progressRevision: remote.progress.progressRevision,
          quantities: baselineCounts,
        ),
      );
      if (links.isEmpty) {
        await tx.insert('shared_order_links', {
          'order_id': id,
          'destination_id': destination,
          'server_order_id': remote.serverOrderId,
          'baseline_json': jsonEncode(baseline.toJson()),
        });
      } else {
        await tx.update(
          'shared_order_links',
          {'baseline_json': jsonEncode(baseline.toJson())},
          where: 'order_id = ?',
          whereArgs: [id],
        );
      }
      // Keep unsaved additions and divider selection while rebasing their prefix.
      for (final row in await tx.query(
        'drafts',
        where: 'managed_order_id = ?',
        whereArgs: [id],
      )) {
        final draft = await SqliteOrderRepository._draftFromRow(tx, row);
        final draftCourses = [...courses];
        for (final course in draft.courses) {
          if (!draftCourses.any((old) => old.id == course.id)) {
            draftCourses.add(_uniqueCourse(course, draftCourses));
          }
        }
        if (lines.length + draft.lines.length > NetworkProtocol.maxLines) {
          throw const OrderStorageException(
            'Reduce unsaved additions before synchronising.',
          );
        }
        await SqliteOrderRepository._writeDraft(
          tx,
          draft.copyWith(
            baseRevision: effectiveRevision,
            courses: draftCourses,
          ),
        );
      }
    });
  }

  Future<void> saveProgress(
    ManagedOrder order,
    OrderProgressChange change,
  ) async {
    await (await repository._db).transaction((tx) async {
      final rows = await tx.query(
        'shared_order_links',
        where: 'order_id = ?',
        whereArgs: [order.id],
      );
      if (rows.length != 1 ||
          rows.single['server_order_id'] != change.orderId ||
          rows.single['pending_json'] != null) {
        throw const OrderStorageException('Invalid pending shared progress.');
      }
      await tx.update(
        'shared_order_links',
        {
          'pending_json': canonicalProgressChange(change),
          'pending_local_revision': order.deliveryEditRevision,
        },
        where: 'order_id = ?',
        whereArgs: [order.id],
      );
    });
  }

  Future<void> settle(
    String id,
    bool accepted,
    OrderProgressSnapshot? applied,
  ) async {
    await (await repository._db).transaction((tx) async {
      final links = await tx.query(
        'shared_order_links',
        where: 'order_id = ?',
        whereArgs: [id],
      );
      if (links.isEmpty) return;
      final link = _link(links.single);
      final orders = await tx.query(
        'managed_orders',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (accepted && link.pending != null && orders.isNotEmpty) {
        final order = SqliteOrderRepository._managedFromRow(orders.single);
        if (order.deliveryEditRevision == link.pendingLocalRevision) {
          await tx.update(
            'managed_orders',
            {
              'delivery_changed_ids': jsonEncode(
                order.changedDeliveryIds
                    .where((id) => !link.pending!.quantities.containsKey(id))
                    .toList(),
              ),
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
      if (accepted && applied != null) {
        final pending = link.pending;
        if (pending == null ||
            applied.clientId != link.baseline.envelope.clientInstallationId ||
            applied.orderId != link.baseline.envelope.managedOrderId ||
            applied.orderRevision != pending.orderRevision ||
            applied.progressRevision != pending.expectedRevision + 1 ||
            applied.quantities.length != pending.quantities.length ||
            applied.quantities.entries.any(
              (entry) => pending.quantities[entry.key] != entry.value,
            )) {
          throw const FormatException('Invalid shared acknowledgement');
        }
        final acknowledged = SharedOrderSnapshot(
          link.baseline.serverOrderId,
          link.baseline.envelope,
          applied,
        );
        await tx.update(
          'shared_order_links',
          {'baseline_json': jsonEncode(acknowledged.toJson())},
          where: 'order_id = ?',
          whereArgs: [id],
        );
      }
      await tx.update(
        'shared_order_links',
        {'pending_json': null, 'pending_local_revision': null},
        where: 'order_id = ?',
        whereArgs: [id],
      );
    });
  }

  static Future<void> restoreLinks(
    DatabaseExecutor tx,
    List<Object?> rows,
  ) async {
    final ids = <String>{};
    final scopes = <String>{};
    for (final value in rows) {
      if (value is! Map<String, Object?> ||
          value.length != 6 ||
          !ids.add(value['order_id'] as String)) {
        throw const FormatException('Invalid shared recovery inventory');
      }
      final link = _link(value);
      final orders = await tx.query(
        'managed_orders',
        where: 'id = ?',
        whereArgs: [link.orderId],
      );
      if (orders.length != 1 ||
          !scopes.add('${link.destinationId}/${link.baseline.serverOrderId}')) {
        throw const FormatException('Invalid shared recovery scope');
      }
      final order = SqliteOrderRepository._managedFromRow(orders.single);
      final inventory = {
        for (final line in order.lines.where((line) => line.sendToServer))
          line.id: line,
      };
      if (link.baseline.envelope.lines.any(
            (line) =>
                inventory[line.id] == null ||
                inventory[line.id]!.name != line.name ||
                inventory[line.id]!.quantity != line.quantity ||
                inventory[line.id]!.preparationNote != line.preparationNote ||
                inventory[line.id]!.courseId != line.courseId,
          ) ||
          (link.pending != null &&
              (link.pending!.orderRevision > order.serverRevision ||
                  link.pending!.expectedRevision >
                      link.baseline.progress.progressRevision ||
                  link.pending!.quantities.entries.any(
                    (entry) =>
                        inventory[entry.key] == null ||
                        entry.value > inventory[entry.key]!.quantity,
                  )))) {
        throw const FormatException('Invalid shared recovery inventory');
      }
      if (order.destinationId != link.destinationId ||
          value['server_order_id'] != link.baseline.serverOrderId ||
          link.baseline.envelope.revision > order.serverRevision ||
          (link.pending == null) != (link.pendingLocalRevision == null) ||
          (link.pending != null &&
              (link.pending!.orderId != link.baseline.serverOrderId ||
                  link.pendingLocalRevision! > order.deliveryEditRevision ||
                  link.pendingLocalRevision! < 0))) {
        throw const FormatException('Invalid shared recovery operation');
      }
      await tx.insert('shared_order_links', value);
    }
  }
}
