# Foundation milestone validation

Validated on 23 September 2026 for LibreSlip 0.2.0+2, Android application identifier `io.thelicato.libreslip`.

| Check | Result |
| --- | --- |
| Dart formatting | Passed, 18 Dart files checked. |
| Static analysis | Passed with no issues. |
| Unit, widget and render tests | All 22 passed, including storage failure/recovery, language switching, phone/tablet/landscape layouts and doubled text size. |
| Real Android preference storage | Integration test passed on an isolated Android 14 emulator. |
| Clean release build | APK built successfully; application label LibreSlip, minimum API 34, target API 36. |
| Release signature | APK signature verified; development signing key used for this preview. |
| Offline cold launch | Release app launched with airplane mode enabled and Wi-Fi/mobile data disabled. |
| Process restart | Italian selection survived full process termination and a cold restart. |
| Privacy configuration | Release has no internet permission; automatic backup and device transfer exclusions are configured. |
| Visual inspection | Phone, wide-screen and Italian dark-theme renders reviewed. |
| Source ZIP | Packaging verifies archive integrity and exact source contents; APK packaging also rejects a mismatched application ID or inconsistent Gradle/Flutter outputs. |

The Android check used a read-only emulator instance, without changing its saved state. See the [offline Italian screen](previews/android14-offline-it.png). The integration test passed; an attempted cleanup of the previous app identifier produced a harmless emulator uninstall warning. The final release was rebuilt from clean generated files and verified independently.

This milestone implements the app shell and local preferences. Item management, order composition/history, printer communication and in-app ZIP transfer remain pending. Physical NETUM NT-1809DD compatibility has not been tested.
