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
| 7. Overview dashboard | Current LibreSlip printer connection, honest battery availability, and inclusive start/end date filters for non-financial ticket and item counts. | Complete |
| 8. Per-item activity | Item names and summed quantities from immutable saved-ticket snapshots within the Overview date range, with responsive empty and long-list states. | Complete |
| 9. Connected printing gate and network plan | Disable new print, reprint and queued-send actions without a connected printer; reject disconnected output calls before saving attempts; retain legacy queue recovery; define the optional client/server programme. | Complete |
| 10. Mode and protocol foundation | Persist Client or Server mode, specify the versioned protocol and limits, and add transactional outbox/inbox migrations without enabling networking yet. | Planned |
| 11. Server inbox | Authenticated foreground-only local HTTPS receiver, explicit pairing, idempotent storage, received/completed board and Mark Done. | Planned |
| 12. Client delivery | Transactional optional delivery outbox, independent local printing, delivery status and interruption-safe retry. | Planned |
| 13. Discovery, portability and hardening | Evaluate mDNS, extend full backups, and validate multi-client, security, recovery and physical two-device operation. | Planned |

## Scope boundaries

Payment handling, checkout, financial reports, customer accounts, loyalty, stock accounting, staff management and cloud services are excluded. Printing a ticket never records or settles a payment.

## Current handover

LibreSlip 0.9.0 requires a connected printer before Compose can finalise through Print ticket, before ticket history can reprint, and before a legacy queued job can be sent. The presentation reacts to printer connection changes, and the application controller rejects a disconnected request before encoding or creating a print attempt. Compose therefore cannot implicitly save a ticket through a blocked print action. Existing queued jobs remain stored and explicitly recoverable after reconnection.

The next programme adds optional Client and Server modes to the same app. Client retains the complete current offline workflow and may additionally deliver immutable ticket snapshots through a durable idempotent outbox. Server is limited to receiving orders, displaying received/completed queues and marking an order Done. Tasks 10 to 13 are planned only; version 0.9.0 adds no networking permission, listener or server interface. See the [client and server plan](client-server-plan.md), [development instructions](development.md), [hardware requirements](hardware.md) and [milestone validation](validation.md).
