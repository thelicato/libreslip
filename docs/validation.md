# Ticket layout and NETUM printing milestone validation

Validated on 23 September 2026 for LibreSlip 0.4.0+4, Android application identifier `io.thelicato.libreslip`.

| Check | Result |
| --- | --- |
| Dart formatting | Passed, 42 Dart files checked. |
| Static analysis | Passed with no issues. |
| Unit and widget tests | All 41 active tests passed; the normal run skipped only the opt-in render capture. |
| SQLite migrations | Version 1 and 2 data upgraded to version 3 while preserving catalogue, drafts and tickets. |
| Draft and print restart recovery | Passed in automated repository tests and through the real Android SQLite backend after close and reopen. An interrupted sending job recovered as uncertain. |
| Ticket snapshot and duplicate protection | Passed: catalogue edits did not change saved tickets, draft-save retry returned the same ticket, and reprint created another attempt without another ticket. |
| Durable print lifecycle | Passed for queued, sending, transmitted, failed and uncertain states, including idempotent queue requests and no automatic resend after an uncertain outcome. |
| ESC/POS output safety | Passed for a 384-dot 58 mm layout, PC858 Italian text, raster fallback, logo rendering and bounded writes. Tests verify that no cutter or cash-drawer command is emitted. |
| Local PDF output | Passed for offline PDF generation and the system share handoff boundary. |
| Responsive localisation | Passed in British English and Italian on small phone, landscape, tablet and doubled-text layouts. |
| Android platform integration | Passed on a read-only Android 14 API 34 emulator using real DataStore and SQLite implementations. |
| Visual inspection | Italian phone ticket preview and Italian dark-theme settings renders reviewed without clipping or unreadable content. |
| Privacy configuration | Release requests Bluetooth connection only, with no internet or location permission; automatic cloud backup and device transfer remain disabled. |
| Release build and signature | Release APK built successfully for minimum API 34 and its development signature was verified. |
| Physical NETUM NT-1809DD | The user reported that the implemented task 4 workflow worked on the physical printer, including the corrected per-device connection state. This result was not independently observed. |
| Source delivery safeguards | The task 4 packager checks archive contents, versioned APK metadata, source freshness, matching Flutter and Gradle APK outputs and SHA-256 checksums. |

The Android integration test used a dedicated temporary database and restored the previous preference document. The emulator was started read-only and its state was not saved. The final preview remains development-signed rather than production-signed.

Bluetooth transport can establish a socket and report completed byte transmission, but the printer provides no paper-output acknowledgement. LibreSlip therefore labels that outcome as transmitted and asks the operator to check the paper. An interrupted send becomes uncertain and is never automatically retried. Firmware and self-test details, and separate observations for printer-off and paper-out conditions, were not recorded. USB printing is not implemented; Bluetooth Classic SPP is the supported first transport.

This milestone implements ticket preview, Bluetooth setup, test printing, durable print attempts, explicit reprint and local PDF sharing. It does not implement configuration archives or full local backups, which remain task 5. Printing never records a sale, payment or other financial transaction.
