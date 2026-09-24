# LibreSlip archive format

LibreSlip task 5 writes ZIP archives with format identifier `libreslip-portability` and format version `1`. Configuration archives contain preferences and ticket-field options. Full backups additionally contain the complete SQLite-backed state and referenced logo and item-image files. Bluetooth pairing credentials, caches and temporary files are never included.

## Entries

| Path | Required | Content |
| --- | --- | --- |
| `manifest.json` | Always | Archive identity, kind, versions, UTC creation time, counts and payload inventory. |
| `configuration.json` | Always | Settings format version 3, ticket typography, locale, theme, heading, footer, logo reference, order-field switches and a non-secret printer transport description. |
| `database.json` | Full backup only | Database schema version 5 and a consistent snapshot of categories, items, drafts, draft lines, tickets, ticket lines, counters, print jobs and order feature settings. Binary print payloads use Base64. |
| `assets/logo.<ext>` | When configured | App-private ticket logo. |
| `assets/items/<item-id>.<ext>` | When referenced | App-private reusable-item image. |

The manifest inventory covers every entry except `manifest.json`. Each inventory record contains the exact POSIX path, uncompressed byte size, media type and lowercase SHA-256 digest. `archiveKind` is `configuration` or `fullBackup`; full backups also declare the SQLite schema version. The manifest counts items, drafts, tickets and print attempts.

## Validation and restore

Imports are read without extracting archive paths directly to disk. LibreSlip rejects absolute paths, drive paths, backslashes, `.` or `..` segments, directories, symbolic links, duplicate names, unknown entry paths or file types, oversized archives and entries, excessive expanded size and excessive compression ratio. It verifies the manifest version, complete inventory, sizes, SHA-256 digests, declared counts, settings bounds, asset references, database schema and database relationships before presenting a preview.

Restore is replacement, not merge. A configuration restore replaces preferences and order-field switches but retains items, drafts and ticket history. A full restore replaces all settings and SQLite-backed data. Assets are copied to a new app-private directory and stored paths are rewritten. Before replacement, LibreSlip durably records the prior settings and either prior feature switches or a complete prior database snapshot. A pending journal is rolled back on the next cold start; a committed journal is only cleaned up. Invalid, cancelled and failed imports do not replace current data.

The format is intentionally strict. A future incompatible format or database schema must use a new version and must not be silently accepted by this implementation.
