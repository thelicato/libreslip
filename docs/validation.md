# Validation evidence

## Optional course groups, 5 October 2026

Validated the second optional order management step with the unchanged LibreSlip `VERSION` value 1.6.0.

| Area | Evidence |
| --- | --- |
| Formatting and analysis | Dart formatting passed and `flutter analyze --no-pub` reported no issues. |
| Automated regression | All 118 active tests passed; the opt-in capture test remained skipped in the normal run. The separate capture run passed. |
| Composition and persistence | Covered course creation, ordering, renaming, moving and removal, separate quantities and notes for the same product in different courses, restart recovery, saved snapshot preservation and disabling the option for subsequent orders. |
| Migration and printing recovery | Schema 10 fixtures migrated to schema 11 without changing ordinary tickets or queued print bytes. An interrupted grouped print retained its bytes and recovered as uncertain. Grouped ESC/POS section ordering and PDF generation passed automated checks. |
| Networking | Real pinned HTTPS tests covered grouped delivery, lost acknowledgements and idempotent receipt. An older Server received no grouped order POST; explicit retry after advertising support succeeded. Local-only group names were excluded from delivery while retained in the local snapshot. |
| Archives and restore | Configuration and full-backup round trips preserved the course option, inventories and line references, including restore on a fresh installation. Invalid course relationships were rejected both by the repository and during archive preview with valid recomputed checksums, leaving original data usable. Existing rollback and malicious archive tests passed. |
| Responsive and localised rendering | Twenty-eight render captures completed without framework errors. Inspected grouped standard and Compact Compose, Italian phone composition, the 320-pixel Italian course manager at doubled text, Italian ticket preview, Server phone cards and tablet details, plus the English tablet composition. Course headings, per-line selectors, management actions and notes remained readable. |
| Android preview APK | Fresh debug APK built with version name 1.6.0, application identifier `io.thelicato.libreslip`, minimum API 34 and target API 36. APK Signature Scheme v2 verified with the Android Debug development certificate. This is a preview, not a production release. |
| Platform and hardware checks | No new device installation, offline cold launch, permission-denial, process-death or physical printer verification was performed for this step. Existing historical hardware evidence below does not verify the new course headings on paper. |
| Compatibility and scope | Ungrouped composition remains the default and plain network envelopes retain version 1. Grouped envelopes require an updated Server supporting version 2. Database schema 11 and configuration document version 2 accept their supported older formats. Active order updates, per-item delivery and optional prices or totals remain planned. |

## Optional order titles, 5 October 2026

Validated the first optional order management step with the unchanged LibreSlip `VERSION` value 1.6.0.

| Check | Result |
| --- | --- |
| Formatting and analysis | Dart formatting check passed across application, tests and integration tests; `flutter analyze --no-pub` reported no issues. |
| Automated tests | All 106 active unit and widget tests passed. Normal runs skipped only opt-in render capture. Existing persistence, migrations, interrupted printing, HTTPS delivery and restore failure checks passed. Title assertions cover Client composition and history, Server details, disabling the field and full-backup restoration. |
| Responsive and localised rendering | Twenty render captures completed without framework errors. Inspected standard and Compact Compose, long Italian titles at 320 logical pixels with doubled text, landscape composition, ticket history and Italian ticket preview, and Server cards and details. Narrow or enlarged-text Compose places Reset below the title to preserve its width. |
| Android preview APK | Debug APK built with version name 1.6.0, application identifier `io.thelicato.libreslip`, minimum API 34 and target API 36. APK Signature Scheme v2 verified with the Android Debug development certificate. This is a preview, not a production release. |
| Platform and hardware checks | No new device installation, offline cold launch, permission-denial, process-death or physical printer verification was performed for this step. Existing historical hardware evidence below does not verify the revised printed title label. |
| Compatibility and scope | Titles reuse the existing reference field. Database, configuration, archive and network protocol formats remain unchanged. Course groups, active order updates, per-item delivery and optional prices or totals are planned, not implemented in this step. |

## Earlier baseline

Validated on 26 September 2026 for LibreSlip 1.5.0, Android application identifier `io.thelicato.libreslip`.

| Check | Result |
| --- | --- |
| Dart formatting | Passed across application, test and integration-test Dart sources. |
| Static analysis | Passed with no issues. |
| Unit and widget tests | All 106 active tests passed; the normal run skipped only opt-in preview capture. |
| Version display | Client and Server Settings both load the unchanged bundled `VERSION` value and show it at the end of the screen. |
| Port 5119 and migrations | Passed address normalisation, listener defaults, schema 9 port migration and schema 10 print-gated outbox migration. Unprinted rows remain blocked after restart. |
| Ticket and item persistence | Passed transactional composition recovery, immutable snapshots, visible-number reset, deletion, migration and duplicate-ticket protection. |
| Printing | Passed encoding, exact 25%, 50%, 75% and 100% logo raster widths, durable print states, disconnected printing gate, interruption recovery, remembered startup reconnect, 15-second connection monitoring, manual reconnect opt-out and reprint without creating another ticket. Physical Bluetooth printing completed previously on a NETUM NT-1809DD, but the four new logo sizes have not been checked on paper. A socket write still cannot prove paper output. |
| Client and Server HTTPS | Passed address-only loopback TLS pairing, explicit Server approval and rejection, first-contact certificate capture, retained SHA-256 pinning, mismatched-certificate rejection, authentication, item filtering, failed-print delivery blocking, automatic lost-acknowledgement resend and idempotent Server receipt. Server Done and move-back-to-Received states survive restart; Received orders reject deletion, while specific and bulk Completed deletion preserve unrelated orders. Lifecycle tests confirm that pausing the activity does not stop the listener service boundary. |
| Statistics | Passed all-history, empty and inclusive local date ranges. Totals use immutable saved-ticket snapshots and keep renamed item labels distinct. |
| Backup compatibility | Passed configuration and full-backup round trips, fresh-install restore, rollback and malicious archive checks for portable schema 10. Legacy portable schemas 5 through 9 remain accepted. Settings format 7 round-trips the printed-logo width; versions 1 through 6 migrate to 100%. Networking tables and pairing secrets are excluded. |
| Accessibility and localisation | Passed British English and Italian phone, landscape, tablet and doubled-text tests. The persisted 100%, 115% and 130% app text sizes compose with Android accessibility scaling. The live printer indicator remains usable in compact and wide Client headers. Compact Compose passes a 320 logical-pixel phone test with doubled text, zero-based item quantities, note-preserving increments and a pinned print action that remains in the viewport. |
| Representative renders | Eighteen previews completed without framework errors. Client pairing, the shared printer badge, paired Client, standard and zero-based Compact Compose, simplified Client and Server headers, Server orders with the outstanding summary first, Received and Completed tablet dialogs, Overview, item, ticket, Settings with the four-step printed-logo slider, portability and item-total screens were inspected. Actions, quantities and content widths remain aligned and readable. |
| Android platform integration | The latest connected-device run passed real DataStore, SQLite, secure identity and token storage, pinned loopback delivery, listener shutdown, restart recovery and archive exclusion. It was not repeated after the emulator was stopped. |
| Offline cold launch | A development-signed release passed clean offline cold launch on Android 14. This was not repeated after the emulator was stopped. |
| Release APK | Passed with a temporary development validation certificate. Verified version 1.5.0, application identifier `io.thelicato.libreslip`, minimum API 34, target API 36 and APK Signature Scheme v2. Flutter and Gradle outputs matched byte for byte. |
| Permissions and backup | The release requests `BLUETOOTH_CONNECT`, `INTERNET`, notification, foreground connected-device service, wake-lock, Wi-Fi-state and Android's app-local dynamic-receiver signature permissions. It requests no location or broad storage permission. Automatic cloud backup and device transfer are disabled. |

## Current limitations

- Server receipt between two separate physical Android devices on the same Wi-Fi network has not been recorded. Router client isolation and network changes can prevent local delivery.
- The Android foreground service and retained-engine lifecycle compile and have host lifecycle coverage, but locked-screen receipt has not yet been verified on a physical Android device. Force-stop, process termination or device restart stops reception until LibreSlip is opened in Server mode again.
- Server mode supports manual IPv4 address entry. There is no automatic discovery, boot start, hosted relay or remote-network support.
- Networking tables and pairing secrets are outside the archive format. Moving data to another device requires fresh pairing.
- Server Received or Done state is not synchronised back to the Client. Deleting one or all Client tickets leaves durable delivery records and Server copies untouched; per-ticket delivery status is no longer available from history after the local ticket is deleted.
- The Android document picker and share sheet compile into the release and have automated cancellation and state coverage, but the latest validation did not repeat every platform-owned destination flow manually.
- USB printing is not implemented. The NETUM Classic SPP protocol does not provide battery percentage.
- Bluetooth Classic does not provide a universally reliable side-effect-free remote liveness probe. The 15-second monitor detects Bluetooth changes and socket failures, but some printer power or range losses may only appear after Android closes the socket or the next write fails.
- The GitHub release workflow has not been executed because no release tag was pushed and no repository signing secrets were changed.

Development-signed previews are not a production upgrade baseline. Keep the long-lived release keystore securely backed up and publish only from a tag matching `VERSION`.
