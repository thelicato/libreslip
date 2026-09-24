# Delivery plan

LibreSlip is an offline order-ticket printer. The user's revised scope replaces the earlier POS roadmap. Complete one coherent task, provide a conventional commit name and stop before starting the next.

| Task | Deliverable and acceptance | Status |
| --- | --- | --- |
| 1. Requirements and project rules | Product rules, local storage requirements, Android 14+ baseline and NETUM NT-1809DD hardware target. Updated for the LibreSlip scope. | Complete |
| 2. Flutter foundation and visual shell | LibreSlip branding, bilingual resources, responsive navigation, local heading/language/theme settings, original design, toolchain documentation and preview APK/source ZIP. Verify analysis, tests and offline launch. | Complete |
| 3. Items and order tickets | SQLite schema/migrations, reusable item editing, categories, search, quantities, optional notes and references, persistent recovery, ticket snapshots and history. Verify restart recovery and duplicate protection. | Complete |
| 4. Ticket layout and NETUM printing | Bilingual 58 mm ticket preview, header/logo/footer settings, Bluetooth Classic SPP, setup/test ticket, durable print jobs, reconnect, explicit reprint and PDF sharing. Verify the user's physical printer. | Complete |
| 5. ZIP portability | Configuration/full-backup export, validated staged import, preview, confirmation and rollback. Verify fresh-install restore, corruption, malicious paths, interruption and round trips. | Complete |
| 6. Release verification and packaging | Accessibility, both languages, offline operation, process recovery, hardware evidence, build instructions, installable APK, source ZIP and checksums. | Pending |

## Scope boundaries

Payment handling, checkout, financial reports, customer accounts, loyalty, stock accounting, staff management and cloud services are excluded. Printing a ticket never records or settles a payment.

## Current handover

LibreSlip now supports reusable items, one automatically persisted composition, immutable saved-ticket snapshots, resettable visible order numbering, Bluetooth Classic printing and local PDF sharing. Individual tickets or all previous tickets can be deleted transactionally with their print attempts without changing the current order number.

Task 5 adds versioned configuration and full-backup ZIP export through the system share sheet. Imports are staged in memory, validated for paths, links, duplicate names, formats, sizes, compression ratio, inventory, SHA-256 checksums, counts and database relationships, then shown for explicit replacement confirmation. Full backups carry a consistent SQLite data snapshot and referenced private images. Replacement is transactional at the database boundary and uses a durable pre-import recovery journal across process interruption; Bluetooth pairing is deliberately excluded. The implemented archive format is documented in [archive format](archive-format.md). See [development instructions](development.md) and [milestone validation](validation.md). The next task is final release verification and packaging.
