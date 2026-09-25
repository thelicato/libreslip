# Validation evidence

Validated on 25 September 2026 for LibreSlip 0.14.0, Android application identifier `io.thelicato.libreslip`.

| Check | Result |
| --- | --- |
| Dart formatting | Passed across application, test and integration-test Dart sources. |
| Static analysis | Passed with no issues. |
| Unit and widget tests | All 90 active tests passed; the normal run skipped only opt-in preview capture. |
| Version display | Client and Server Settings both load the unchanged bundled `VERSION` value and show it at the end of the screen. |
| Port 5119 and migration | Passed address normalisation, listener defaults and schema 9 migration from the former LibreSlip port while preserving unrelated custom ports and pairing trust. |
| Ticket and item persistence | Passed transactional composition recovery, immutable snapshots, visible-number reset, deletion, migration and duplicate-ticket protection. |
| Printing | Passed encoding, durable print states, disconnected printing gate, interruption recovery and reprint without creating another ticket. Physical Bluetooth printing completed on a NETUM NT-1809DD. A socket write still cannot prove paper output. |
| Client and Server HTTPS | Passed loopback TLS pairing, exact SHA-256 certificate pinning, authentication, item filtering, lost-acknowledgement retry and idempotent Server receipt. A mismatched certificate remained rejected. |
| Statistics | Passed all-history, empty and inclusive local date ranges. Totals use immutable saved-ticket snapshots and keep renamed item labels distinct. |
| Backup compatibility | Passed configuration and full-backup round trips, fresh-install restore, rollback and malicious archive checks for portable schema 9. Legacy portable schemas 5 through 8 remain accepted. Networking tables and pairing secrets are excluded. |
| Accessibility and localisation | Passed British English and Italian phone, landscape, tablet and doubled-text tests. |
| Representative renders | Fourteen previews completed without framework errors. Client, Server, Overview, Compose, item, ticket, Settings, portability and item-total screens were visually inspected. The Server version footer is aligned, readable and clear of the navigation bar. |
| Android platform integration | The latest connected-device run passed real DataStore, SQLite, secure identity and token storage, pinned loopback delivery, listener shutdown, restart recovery and archive exclusion. It was not repeated after the emulator was stopped. |
| Offline cold launch | A development-signed release passed clean offline cold launch on Android 14. This was not repeated after the emulator was stopped. |
| Release APK | Passed with a temporary development validation certificate. Verified version 0.14.0, application identifier `io.thelicato.libreslip`, minimum API 34, target API 36 and APK Signature Scheme v2. Flutter and Gradle outputs matched byte for byte. |
| Permissions and backup | The release requests `BLUETOOTH_CONNECT`, `INTERNET` and Android's app-local dynamic-receiver signature permission. It requests no location or broad storage permission. Automatic cloud backup and device transfer are disabled. |

## Current limitations

- Server receipt between two separate physical Android devices on the same Wi-Fi network has not been recorded. Router client isolation and network changes can prevent local delivery.
- Server mode is foreground-only and supports manual IPv4 address entry. There is no automatic discovery, background service, hosted relay or remote-network support.
- Networking tables and pairing secrets are outside the archive format. Moving data to another device requires fresh pairing.
- The Android document picker and share sheet compile into the release and have automated cancellation and state coverage, but the latest validation did not repeat every platform-owned destination flow manually.
- USB printing is not implemented. The NETUM Classic SPP protocol does not provide battery percentage.
- The GitHub release workflow has not been executed because no release tag was pushed and no repository signing secrets were changed.

Development-signed previews are not a production upgrade baseline. Keep the long-lived release keystore securely backed up and publish only from a tag matching `VERSION`.
