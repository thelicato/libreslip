# Development

## Toolchain

This milestone was developed with Flutter 3.47.2 stable (revision `d3b14c876900e553bc736ca19295fc09e3853e8e`), Dart 3.13.2, Java 21.0.12.1, Gradle 9.3.1, Android Gradle Plugin 9.1.0 and Kotlin 2.4.0. The application identifier is `io.thelicato.libreslip` and the Dart package is `libreslip`. The Android minimum is API 34 (Android 14); compilation and target SDK versions are API 36, as selected by this Flutter SDK. Use the committed `pubspec.lock` to reproduce dependency resolution.

## Run and build

Install the Flutter SDK and Android SDK, ensure the Android SDK licences are accepted, and connect an Android 14 or later device with USB debugging enabled. Dependency downloads require internet during development; the installed app does not need it.

```sh
flutter pub get
flutter gen-l10n
flutter run
```

Run validation directly:

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

Use the Hecate-style build entry point for APKs:

```sh
python3 build.py local debug
python3 build.py local prod
python3 build.py docker debug
python3 build.py docker prod
```

Local builds use the installed Flutter SDK. Docker builds select the oldest compatible stable Flutter and Dart pair from the constraints in `pubspec.lock` for which `ghcr.io/gmeligio/flutter-android` has an image. Both modes run `flutter pub get`, read the visible version from `VERSION`, and write the APK under `build/app/outputs/flutter-apk/`.

Production builds require `android/key.properties` and its referenced keystore, or the four `LIBRESLIP_KEYSTORE_PATH`, `LIBRESLIP_STORE_PASSWORD`, `LIBRESLIP_KEY_ALIAS` and `LIBRESLIP_KEY_PASSWORD` environment variables. Missing release signing is a hard failure and never falls back to the debug certificate. Generate local files with `./scripts/generate_release_keystore.sh`, back them up securely, and never commit them.

`VERSION` is the only release version that is edited manually. It must use `X.Y.Z`; GitHub release tags must match it as `vX.Y.Z`. The GitHub workflow supplies its monotonically increasing run number as Android's build number.

To exercise Android DataStore, SQLite and full-backup restore through their real platform implementations, select an isolated emulator or test device. The integration test verifies restart recovery and restores a validated archive into an independent empty database. It restores the previous preference document and removes its dedicated files when it finishes.

```sh
flutter test integration_test/settings_persistence_test.dart -d DEVICE_ID
```

## Architecture and persistence

`lib/app` owns app startup, localisation and themes. `lib/core` contains reusable visual primitives. Settings retain their preference model, repository, controller and screens. `lib/features/orders` separates item and ticket domain models, application state, SQLite and image persistence, and the Compose, Items and Tickets pages. `lib/features/printing` separates ticket documents, ESC/POS encoding, durable output coordination, Android transport, PDF sharing and presentation. `lib/features/portability` owns archive models, validation, transactional replacement, recovery and Settings presentation. `lib/features/workspace` owns responsive navigation, the Overview dashboard and pure ticket-statistics calculation. Overview statistics are derived from loaded immutable ticket snapshots using inclusive local calendar dates; they do not add another database or record financial data.

Simple settings remain in one versioned JSON document through `SharedPreferencesAsync`, backed by Android DataStore. Settings format version 3 adds bounded printed-ticket typography while retaining migration from versions 1 and 2. Version 2 added the optional ticket footer and app-private logo path. Reusable items, categories, the automatically persisted composition, ticket snapshots, order numbering, print jobs and composition-field switches use `sqflite` in app-private storage. Database schema version 5 is upgraded transactionally from earlier versions. Version 4 adds a singleton settings row for table or order reference, preparation notes and order notes, all enabled by default. Version 5 separates the resettable visible order number from the monotonic internal ticket number. Resetting starts visible numbering at 1 without deleting history, changing snapshots or reusing stable ticket identifiers. Foreign keys, uniqueness constraints and quantity checks protect relationships and invalid values.

Every editable line stores the item name selected at that moment. Print ticket first copies the enabled reference, notes, names and quantities into separate snapshot tables in one transaction, then creates a durable print attempt. Disabled optional fields remain recoverable in editable storage if re-enabled but are omitted from a newly saved ticket. The ticket table has a unique origin identifier, so a retry after an uncertain caller response returns the existing ticket instead of inserting a duplicate. Catalogue edits and archival cannot change saved snapshots.

Optional item images and the ticket logo are selected through the Android system picker and copied into the app support directory. Removing or replacing an image removes the old private file after its owning state change succeeds. Image files are not uploaded. Full backups serialise all SQLite tables in one read transaction and include referenced active-item images and the ticket logo.

Each print attempt stores its ticket snapshot payload, selected device, request identifier, status and timestamps before transmission. A unique request identifier makes queue creation idempotent. Jobs move through queued, sending, transmitted, failed or uncertain states. Opening the database changes any interrupted sending job to uncertain, and the app never automatically resends it. Explicit reprint creates a new print attempt for the existing ticket and cannot create another order.

Android printing uses the platform Bluetooth Classic RFCOMM/SPP APIs and lists already bonded devices. It requests only `BLUETOOTH_CONNECT`, does not scan for devices and never needs location or internet access. The 58 mm encoder targets 384 printable dots, selects PC858 for supported text and rasterises unsupported text and configured logos with bundled Roboto fonts. Data is written in bounded 256-byte chunks. Neither tickets nor test tickets send cash-drawer or cutter commands. A completed socket write is recorded as transmitted, not as proof that paper was produced. The Overview reports LibreSlip’s current RFCOMM socket state and refreshes it without requesting permission automatically. Printer battery percentage is nullable by design: it is displayed only when a documented transport supplies a value from 0 to 100.

PDF tickets are rendered locally with the same bundled fonts and passed to the Android system share sheet. The app creates no server upload and chooses no destination on the user's behalf.

The release manifest requests no internet permission. Automatic Android cloud backup and device transfer remain excluded for all app data domains. ZIP export uses the system share sheet and import uses the Android document picker without broad storage permission. Archive encoding and decoding run off the interface isolate. Import validation rejects unsafe paths, links, duplicate paths, unknown types, unsupported versions, oversized or over-compressed content, checksum mismatches, count mismatches and invalid database relationships. Replacement uses SQLite transactions and an app-private recovery journal that is resolved before normal startup. See [archive format](archive-format.md).

## Localisation and interface

Edit `lib/l10n/app_en.arb` and `app_it.arb`, then regenerate with `flutter gen-l10n`. The regional ARB files select `en_GB` and `it_IT`; the app offers exactly those two locales. English uses British spelling. Stored item names, references and notes are never translated when the interface language changes.

The shell uses bottom navigation below 760 logical pixels, a compact sidebar from 760, and an expanded sidebar from 1180. Compose is the central destination. Bottom-navigation labels select the largest font size that keeps every translated label on one line. Compose uses a split item/order view when space permits and one continuous card on phones, with a compact quantity stepper and a confirmed visible-number reset. Tests cover both languages on small phones, landscape, tablets and doubled text size.

Generate review images with the installed Flutter SDK fonts:

```sh
flutter test test/preview_test.dart --dart-define=LIBRESLIP_CAPTURE_PREVIEWS=true
```

Images are written under `build/previews`. This optional capture is skipped during normal tests; it is a review aid rather than a pixel-perfect golden assertion. The task 7 review set adds English phone/tablet Overview renders and a scrolled Italian phone dashboard with representative ticket counts to the existing Compose, ticket, Settings and portability screens.

## Package a milestone

```sh
python3 tool/package_milestone.py --include-apk
```

The script writes the task 7 dashboard source ZIP, preview APK and SHA-256 checksums to `dist/`. The source archive uses a `LibreSlip/` root, includes `VERSION`, build and CI automation, the lockfile, bundled font licence and Gradle wrapper, and excludes local SDK paths, caches, IDE files, generated plugin registration, signing material and previous archives. The source ZIP is separate from the in-app backup format. APK packaging reads the expected version from `VERSION`, checks the application identifier and positive build number, rejects an APK older than any packaged source, and requires matching Flutter and Gradle outputs. `--include-apk` therefore requires a fresh, correctly signed production build.
