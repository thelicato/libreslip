# Delivery plan

LibreSlip is an offline order-ticket printer. The user's revised scope replaces the earlier POS roadmap. Complete one coherent task, provide a conventional commit name and stop before starting the next.

| Task | Deliverable and acceptance | Status |
| --- | --- | --- |
| 1. Requirements and project rules | Product rules, local storage requirements, Android 14+ baseline and NETUM NT-1809DD hardware target. Updated for the LibreSlip scope. | Complete |
| 2. Flutter foundation and visual shell | LibreSlip branding, bilingual resources, responsive navigation, local heading/language/theme settings, original design, toolchain documentation and preview APK/source ZIP. Verify analysis, tests and offline launch. | Complete |
| 3. Items and order tickets | SQLite schema/migrations, reusable item editing, categories, search, quantities, optional notes and references, persistent recovery, ticket snapshots and history. Verify restart recovery and duplicate protection. | Complete |
| 4. Ticket layout and NETUM printing | Bilingual 58 mm ticket preview, header/logo/footer settings, Bluetooth Classic SPP, setup/test ticket, durable print jobs, reconnect, explicit reprint and PDF sharing. Verify the user's physical printer. | Complete |
| 5. ZIP portability | Configuration/full-backup export, validated staged import, preview, confirmation and rollback. Verify fresh-install restore, corruption, malicious paths, interruption and round trips. | Complete |
| 6. Release verification and packaging | Accessibility, both languages, offline operation, process recovery, hardware evidence, build instructions, installable APK, source ZIP and checksums. | Complete |

## Scope boundaries

Payment handling, checkout, financial reports, customer accounts, loyalty, stock accounting, staff management and cloud services are excluded. Printing a ticket never records or settles a payment.

## Current handover

LibreSlip 0.6.0 completes the current delivery plan as an Android 14+ release candidate. The app supports reusable items, one automatically persisted composition, immutable saved-ticket snapshots, resettable visible order numbering, transactional ticket deletion, Bluetooth Classic printing, local PDF sharing, and validated configuration or full-backup ZIP portability. It retains no payment, checkout, stock or other POS capability.

Final validation covers formatting, static analysis, the full host test suite, representative responsive renders, Android DataStore and SQLite recovery, a full backup restored into an independent empty Android database, an offline release cold start, permission denial, APK identity and privacy configuration. The user's earlier task 4 report remains the physical NETUM NT-1809DD evidence; task 6 does not claim a new hardware run. Hecate-style local and Docker build entry points, strict release signing, a single `VERSION` source and tagged GitHub APK releases are documented in [development instructions](development.md). Detailed evidence and remaining platform-owned limitations are in [milestone validation](validation.md).
