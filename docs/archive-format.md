# LibreSlip archive format

LibreSlip ZIP archives use format identifier `libreslip-portability` and format version `1`. Configuration archives contain preferences and ticket-field options. Full backups additionally contain local catalogue, composition, active-order, ticket and print state plus referenced logo and item-image files. Bluetooth credentials, pairing secrets, caches and temporary files are never included. The remembered printer address is a preference rather than a pairing credential; Android pairing must still exist on the restored device.

## Entries

| Path | Required | Content |
| --- | --- | --- |
| `manifest.json` | Always | Archive identity, kind, versions, UTC creation time, counts and payload inventory. |
| `configuration.json` | Always | Configuration document version 3 with settings format version 7, ticket typography, locale, theme, heading, footer, logo reference and printed width, order-field switches including `courseGroupsEnabled` and `managedOrdersEnabled`, Compact Compose preference, remembered printer address and a non-secret printer transport description. Legacy configuration document versions 1 and 2 are accepted. |
| `database.json` | Full backup only | Portable database schema version 12, or accepted legacy version 5 through 11, with categories, items, composition, lines, active orders, tickets, ticket lines, counters, print jobs and order-field settings. Binary print payloads use Base64. |
| `assets/logo.<ext>` | When configured | App-private ticket logo. |
| `assets/items/<item-id>.<ext>` | When referenced | App-private reusable-item image. |

The manifest inventory covers every entry except `manifest.json`. Each inventory record contains the exact POSIX path, uncompressed byte size, media type and lowercase SHA-256 digest. `archiveKind` is `configuration` or `fullBackup`; full backups also declare the SQLite schema version. The manifest counts items, compositions, tickets and print attempts.

Schema 11 stores ordered course definitions as `courses_json` arrays of `{id, name}` on composition and ticket rows, nullable `course_id` on lines and `active_course_id` on the composition. Inventories contain at most 20 groups, with unique identifiers and trimmed, case-insensitively unique names of at most 40 characters without control characters. Encoded inventories are bounded to 16,384 characters. References must belong to their own composition or ticket inventory. The `course_groups_enabled` switch is stored with the order-field settings. Legacy archives default to empty inventories and the option disabled. Older app versions reject configuration document version 2 rather than silently ignoring its new setting.

Schema 12 adds `managed_orders` with stable identity, visible number, local revision, UTC timestamps, optional closure time, fixed heading and notes, course inventory and `lines_json`. Lines contain `id`, `catalogueItemId`, `name`, `quantity`, `preparationNote`, `courseId` and the snapshotted `sendToServer` flag. The inventory is bounded to 200 lines and 262,144 characters. Managed rows also retain non-secret original destination and Client installation identifiers and the Server revision; these do not restore pairing or outbox state. Drafts use `managed_order_id` and `base_revision`. Tickets use `managed_order_id`, `revision` and `addition_line_ids`, with `order_line_id` on their lines. These relationships, stable line contents, fixed ticket metadata and positive revision bounds are validated before preview and replacement. Closed current-order records remain available while their saved tickets exist. Deleting their last ticket removes that closed current-order snapshot; open orders survive history deletion. Legacy archives contain no active orders and default `managed_orders_enabled` to disabled. Older apps reject configuration document version 3 and schema 12.

## Validation and restore

Imports are read without extracting archive paths directly to disk. LibreSlip rejects absolute paths, drive paths, backslashes, `.` or `..` segments, directories, symbolic links, duplicate names, unknown paths or file types, oversized archives and entries, excessive expanded size and excessive compression ratios. It verifies the manifest version, complete inventory, sizes, SHA-256 digests, declared counts, settings bounds, asset references, database schema and relationships before presenting a preview.

Restore is replacement, not merge. A configuration restore replaces preferences and order-field switches but retains items, composition, active orders and ticket history. A full restore replaces settings and the archived catalogue, composition, active-order, ticket and print tables. Assets are copied to a new app-private directory and stored paths are rewritten.

Before replacement, LibreSlip durably records the previous settings and either previous field switches or a complete previous portable database snapshot. A pending journal rolls back on the next cold start; a committed journal is only cleaned up. Invalid, cancelled and failed imports do not replace current data.

Mode, paired Server destinations, Client outbox, paired Clients, Server inbox and Server revision receipt tables are outside format version 1. Restore keeps the destination device's existing mode and networking data. Client access tokens, Server token hashes and the Server private key are always excluded. Active orders restored to a different installation are presented and continued locally, including an interrupted additions composition. Restoring on the original installation does not rewind a Server and stale updates are rejected. Full backups preserve each reusable item's Server-delivery flag. Portable schemas 5 through 11 remain accepted, with a missing item flag defaulting to included.
