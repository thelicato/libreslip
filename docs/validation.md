# ZIP portability milestone validation

Validated on 24 September 2026 for LibreSlip 0.5.0+5, Android application identifier `io.thelicato.libreslip`.

| Check | Result |
| --- | --- |
| Dart formatting | Passed, 48 Dart files checked. |
| Static analysis | Passed with no issues. |
| Unit and widget tests | All 57 active tests passed; the normal run skipped only the opt-in render capture. |
| Configuration ZIP round trip | Passed: settings format 3, locale, theme, heading, footer, bounded typography, logo reference and SQLite order-field switches were exported, inspected and restored without replacing items or ticket history. |
| Full-backup round trip | Passed: a consistent schema 5 snapshot restored items, categories, drafts, ticket snapshots, print attempts, counters, feature switches, settings, logo and item images. A separate empty SQLite database and settings store verified the fresh-install restore path. |
| Archive integrity and hostile input | Passed for SHA-256 inventory verification, count mismatches, path traversal, duplicate paths and altered payloads. Implementation also bounds compressed and expanded size, entry count, individual file size and compression ratio, and rejects absolute paths, drive paths, backslashes, links, directories, unknown paths, unknown file types, unsupported format/schema versions and invalid relationships. |
| Replacement and interruption safety | Passed: a forced settings-write failure restored the pre-import database, and a simulated pending journal on cold start restored settings, SQLite state and removed partial staged assets. SQLite replacement itself is one transaction. |
| Ticket deletion | Passed at repository and widget levels. Deleting one ticket removes its dependent print attempts; deleting all tickets clears history. Neither operation updates the visible order counter or the monotonic internal ticket counter, and the current draft remains available. |
| Ticket snapshot and duplicate protection | Passed: catalogue edits do not change saved tickets, conversion retry returns the same ticket, reprint creates another attempt without another ticket, and history deletion does not cause number reuse. |
| Responsive localisation | Passed in British English and Italian on small phone, landscape, tablet and doubled-text layouts. Every new string has matching localisation metadata and placeholders. |
| Representative renders | Fresh portability Settings and ticket-history renders completed without framework errors and were visually inspected. Controls fit the existing Material 3 cards, destructive actions are distinct and the phone navigation remains one line. |
| Android platform integration | Passed on a read-only Android 14 API 34 emulator using real DataStore and SQLite implementations. Existing preference, typography, schema 5, restart and reset-number assertions passed after close and reopen. The test restored its prior preference document and removed its dedicated database. |
| Release APK | Built successfully. Verified version 0.5.0+5, application identifier `io.thelicato.libreslip`, minimum API 34 and target API 36. Flutter and Gradle APK outputs had identical SHA-256 hashes before packaging. |
| Privacy configuration | The release requests Bluetooth connection only, plus Android's app-local dynamic-receiver signature permission. It requests no internet, location or broad storage permission; automatic cloud backup and device transfer remain disabled. |
| Physical NETUM NT-1809DD | The user's earlier task 4 report confirms the implemented Bluetooth printing workflow on the physical printer. Task 5 does not change transport behaviour, and no new hardware test was required or claimed. |

The archive tests call the same codec, validation, staging and restore service used by the app. The fresh-install check uses an independent empty database and settings store on the development host rather than a second physical phone. The Android document picker and share-sheet interaction were compiled into the APK but were not manually exercised on a handset during this milestone. Export cancellation and destination behaviour therefore remain platform-owned and unobserved here.

The source archive format is documented in [archive format](archive-format.md). Bluetooth pairing is excluded by design and must be re-established after restore. Configuration import replaces settings and order-field options only; full backup import replaces settings, catalogue, drafts, history and print attempts. Both paths require a validated preview and explicit in-app confirmation.

A transmitted printer state still means that the phone completed its socket write, not that paper output was confirmed. LibreSlip never automatically retries an uncertain print and never records a sale, payment or financial transaction. USB printing remains outside this milestone.
