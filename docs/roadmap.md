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

## Scope boundaries

Payment handling, checkout, financial reports, customer accounts, loyalty, stock accounting, staff management and cloud services are excluded. Printing a ticket never records or settles a payment.

## Current handover

LibreSlip 0.7.0 adds a responsive Overview dashboard without expanding into POS reporting. It displays the current in-app Bluetooth socket state and connected device name, refreshes explicitly and when the Overview opens, and clears state after disconnect or transmission failure. Battery percentage is an optional transport value, but the NETUM NT-1809DD documentation and Android Bluetooth Classic public API provide no reliable percentage, so this printer shows an honest unavailable message and directs the operator to its physical indicator.

The same dashboard filters immutable saved-ticket snapshots by inclusive local start and end dates. It reports saved-ticket count, summed item quantities and average items per ticket only. It never derives revenue, sales, prices or other financial measures. Task 6 release verification remains valid for the underlying workflow; task 7 adds focused calculation, printer-state, localisation and responsive rendering coverage. See [development instructions](development.md), [hardware requirements](hardware.md) and [milestone validation](validation.md).
