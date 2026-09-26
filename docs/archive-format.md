# LibreSlip archive format

LibreSlip ZIP archives use format identifier `libreslip-portability` and format version `1`. Configuration archives contain preferences and ticket-field options. Full backups additionally contain local catalogue, composition, ticket and print state plus referenced logo and item-image files. Bluetooth credentials, pairing secrets, caches and temporary files are never included. The remembered printer address is a preference rather than a pairing credential; Android pairing must still exist on the restored device.

## Entries

| Path | Required | Content |
| --- | --- | --- |
| `manifest.json` | Always | Archive identity, kind, versions, UTC creation time, counts and payload inventory. |
| `configuration.json` | Always | Settings format version 7, ticket typography, locale, theme, heading, footer, logo reference and printed width, order-field switches, Compact Compose preference, remembered printer address and a non-secret printer transport description. |
| `database.json` | Full backup only | Portable database schema version 10, or accepted legacy version 5 through 9, with categories, items, composition, lines, tickets, ticket lines, counters, print jobs and order-field settings. Binary print payloads use Base64. |
| `assets/logo.<ext>` | When configured | App-private ticket logo. |
| `assets/items/<item-id>.<ext>` | When referenced | App-private reusable-item image. |

The manifest inventory covers every entry except `manifest.json`. Each inventory record contains the exact POSIX path, uncompressed byte size, media type and lowercase SHA-256 digest. `archiveKind` is `configuration` or `fullBackup`; full backups also declare the SQLite schema version. The manifest counts items, compositions, tickets and print attempts.

## Validation and restore

Imports are read without extracting archive paths directly to disk. LibreSlip rejects absolute paths, drive paths, backslashes, `.` or `..` segments, directories, symbolic links, duplicate names, unknown paths or file types, oversized archives and entries, excessive expanded size and excessive compression ratios. It verifies the manifest version, complete inventory, sizes, SHA-256 digests, declared counts, settings bounds, asset references, database schema and relationships before presenting a preview.

Restore is replacement, not merge. A configuration restore replaces preferences and order-field switches but retains items, composition and ticket history. A full restore replaces settings and the archived catalogue, composition, ticket and print tables. Assets are copied to a new app-private directory and stored paths are rewritten.

Before replacement, LibreSlip durably records the previous settings and either previous field switches or a complete previous portable database snapshot. A pending journal rolls back on the next cold start; a committed journal is only cleaned up. Invalid, cancelled and failed imports do not replace current data.

Mode, paired Server destinations, Client outbox, paired Clients and Server inbox tables are outside format version 1. Restore keeps the destination device's existing mode and networking data. Client access tokens, Server token hashes and the Server private key are always excluded. Full backups preserve each reusable item's Server-delivery flag. Portable schemas 5 through 9 remain accepted, with a missing item flag defaulting to included.
