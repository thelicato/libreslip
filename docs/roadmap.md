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
| 10. Mode and protocol foundation | Persist Client or Server mode, specify the versioned protocol and limits, and add transactional outbox/inbox migrations without enabling networking yet. | Complete |
| 11. Server inbox | Authenticated foreground-only local HTTPS receiver, explicit pairing, idempotent storage, received/completed board and Mark Done. | Complete |
| 12. Client delivery | Transactional optional delivery outbox, independent local printing, delivery status and interruption-safe retry. | Complete |
| 13. Discovery, portability and hardening | Evaluate mDNS, extend full backups, and validate multi-client, security, recovery and physical two-device operation. | Planned |

## Scope boundaries

Payment handling, checkout, financial reports, customer accounts, loyalty, stock accounting, staff management and cloud services are excluded. Printing a ticket never records or settles a payment.

## Current handover

LibreSlip 0.12.0 completes optional Client delivery to the foreground-only Server receiver. Pairing requires the Server's local IPv4 address, exact displayed SHA-256 certificate fingerprint and a five-minute one-time code. The client uses strict certificate pinning for the self-signed HTTPS identity and keeps its access token in Android keystore-backed encrypted storage.

When a paired Client finalises a ticket, SQLite stores the immutable local snapshot and one stable delivery envelope atomically. Local printing runs first and independently. Pending deliveries receive one bounded foreground attempt after creation or restart; failures remain Needs attention for explicit retry. Repeating a delivery after a lost acknowledgement returns the original Server order rather than creating another. Ticket deletion never changes its delivery or the visible ticket-number counter. Networking data remains excluded from archives until Task 13. Physical two-device validation, discovery evaluation and portability hardening are the remaining Task 13 work. See the [client and server plan](client-server-plan.md), [protocol specification](network-protocol.md), [development instructions](development.md), [hardware requirements](hardware.md) and [milestone validation](validation.md).
