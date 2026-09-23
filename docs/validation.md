# Items and order tickets milestone validation

Validated on 23 September 2026 for LibreSlip 0.3.0+3, Android application identifier `io.thelicato.libreslip`.

| Check | Result |
| --- | --- |
| Dart formatting | Passed, 27 Dart files checked. |
| Static analysis | Passed with no issues. |
| Unit and widget tests | All 26 active tests passed; the normal run skipped only the opt-in render capture. |
| SQLite migrations | Version 1 to 2 upgrade passed while preserving existing catalogue data. |
| Draft restart recovery | Passed in a temporary desktop database and through the real Android SQLite backend after close and reopen. |
| Ticket snapshot integrity | Passed: later catalogue rename and archival did not change saved heading, item name, quantity or notes. |
| Duplicate protection | Passed: retrying conversion of the same draft returned the same stable ticket and left one history record. |
| End-to-end workflow | Passed from reusable item creation through composition, reference persistence, ticket history and duplication into a new draft. |
| Responsive localisation | Passed in British English and Italian on small phone, landscape, tablet and doubled-text layouts. |
| Android platform integration | Passed on a read-only Android 14 API 34 emulator using real DataStore and SQLite implementations. |
| Visual inspection | Fresh Compose phone, Italian Items dark-theme and Tickets wide-screen renders reviewed. |
| Privacy configuration | Release requests no internet permission; automatic cloud backup and device transfer remain disabled. |
| Release build and signature | Release APK built successfully and its development signature was verified. |
| Source delivery | Packaging verified the archive root and contents, versioned APK metadata, source freshness, matching APK outputs and SHA-256 checksums. |

The Android integration test used a dedicated temporary database and restored the previous preference document. The emulator was started read-only and its state was not saved. Automated tests do not verify operating-system process kill during an in-progress SQLite transaction, but SQLite transactions and the idempotent origin-draft constraint protect the implemented save boundary.

This milestone implements local item management, multiple editable drafts and saved ticket history. Integer quantities from 1 to 999 are supported. Item images remain app-private and will enter full backups in task 5. Printing, print attempts, 58 mm rendering, PDF sharing and in-app ZIP transfer are not implemented. The NETUM NT-1809DD has not been tested, and no print success is claimed.
