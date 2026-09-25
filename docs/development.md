# Development

## Toolchain

LibreSlip uses Flutter 3.47.2 stable, Dart 3.13.2, Java 21, Gradle 9.3.1, Android Gradle Plugin 9.1.0 and Kotlin 2.4.0. The Dart package is `libreslip`, the Android application identifier is `io.thelicato.libreslip`, and the minimum Android API is 34. Compile and target SDK versions are API 36 with this Flutter SDK. Keep the committed `pubspec.lock` for reproducible dependency resolution.

## Run and validate

Install Flutter and the Android SDK, accept Android SDK licences and connect an Android 14 or later device when platform validation is needed. Development dependency downloads require internet. Client mode needs no runtime internet connection; optional local Client and Server HTTPS uses Android's internet permission for LAN sockets.

```sh
flutter pub get
flutter gen-l10n
flutter run
```

Run host validation with:

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

Run real Android persistence, secure-storage, restart and backup checks on an isolated emulator or test device:

```sh
flutter test integration_test/settings_persistence_test.dart -d DEVICE_ID
```

The integration test restores the previous preference document and removes its dedicated files when complete.

## Version and APK builds

`VERSION` is the only manually maintained release version. It must use `X.Y.Z`. Automation must read it and must not increment or rewrite it. LibreSlip bundles the file and displays the same value at the bottom of Client and Server Settings.

Use the common build entry point:

```sh
python3 build.py local debug
python3 build.py local prod
python3 build.py docker debug
python3 build.py docker prod
```

Local builds use the installed Flutter SDK. Docker builds select a compatible `ghcr.io/gmeligio/flutter-android` image from the locked SDK constraints. Both modes pass `VERSION` to Flutter as the Android version name and write APKs under `build/app/outputs/flutter-apk/`.

Production builds require `android/key.properties` and its referenced keystore, or `LIBRESLIP_KEYSTORE_PATH`, `LIBRESLIP_STORE_PASSWORD`, `LIBRESLIP_KEY_ALIAS` and `LIBRESLIP_KEY_PASSWORD`. Missing release signing is a hard failure and never falls back to the debug certificate. Generate local signing files interactively with:

```sh
./scripts/generate_release_keystore.sh
```

The generated keystore and properties are ignored by Git. Keep secure offline backups of the long-lived release keystore.

`.github/workflows/release.yml` runs for numeric `vX.Y.Z` tags, rejects a tag that differs from `VERSION`, validates LibreSlip, builds a signed APK and attaches it to a GitHub release. Configure `LIBRESLIP_KEYSTORE_BASE64`, `LIBRESLIP_STORE_PASSWORD`, `LIBRESLIP_KEY_ALIAS` and `LIBRESLIP_KEY_PASSWORD` as repository secrets. GitHub's run number supplies the increasing Android build number.

## Architecture and persistence

`lib/app` owns startup, localisation and themes. `lib/core` contains shared visual components. Each feature separates presentation, application or domain logic and persistence or platform transport:

- `features/orders`: catalogue, composition, immutable tickets, history, numbering and SQLite.
- `features/printing`: ticket documents, 58 mm rendering, ESC/POS, durable jobs, Bluetooth transport and PDF sharing.
- `features/portability`: archive creation, validation, preview, transactional restore and recovery.
- `features/networking`: mode selection, pairing, protocol, encrypted secrets, durable Client outbox, Android foreground HTTPS Server service and received or completed board.
- `features/workspace`: responsive navigation, Overview and non-financial statistics.

Simple settings use one versioned JSON document through `SharedPreferencesAsync` and Android DataStore. Settings format version 4 stores locale, appearance, bounded app text scaling, ticket heading, footer, logo and bounded printed-ticket typography. Versions 1 through 3 migrate with the default app text size.

Catalogue, composition, immutable ticket snapshots, counters, print jobs, optional fields and networking records use app-private SQLite schema 10. Migrations are transactional. The ticket origin identifier prevents accidental duplicate finalisation. Resetting the visible order number starts at 1 without reusing stable identifiers or changing history. Catalogue edits cannot rewrite ticket or delivery snapshots.

Full backups serialise the portable catalogue, composition, ticket and print tables in one read transaction and include referenced item images and the ticket logo. Networking tables and encrypted pairing secrets are excluded by archive format version 1. Portable database schemas 5 through 10 are accepted.

## Printing and local networking

New print and reprint actions require an active printer connection. Every accepted print attempt is stored before transmission with its snapshot payload, bonded device, unique request identifier, state and timestamps. Opening the database changes interrupted Sending jobs to Uncertain; LibreSlip never automatically repeats them.

Android printing uses Bluetooth Classic RFCOMM/SPP and requests only `BLUETOOTH_CONNECT`. The 58 mm encoder targets 384 printable dots, encodes supported text with PC858, rasterises unsupported text and logos with bundled fonts and writes 256-byte chunks. Socket completion records Transmitted rather than confirmed paper output.

Optional Client delivery remains durably gated until a local print is recorded as Transmitted. Failed, disconnected or uncertain printing never starts Server delivery. Pairing accepts a local IPv4 address and port, captures and verifies the Server certificate on first contact, then waits for explicit approval in Server Settings. The captured SHA-256 fingerprint pins the approval request and every later connection; redirects remain disabled. Tokens and Server keys use `flutter_secure_storage` with Android keystore-backed protection. Transient deliveries retry from the durable outbox with the same idempotency key. The Android connected-device foreground service retains the Flutter engine and CPU or Wi-Fi locks so the Server stays on port 5119 while locked or backgrounded. Duplicate deliveries return their existing acknowledgement.

## Localisation and interface

Edit `lib/l10n/app_en.arb` and `app_it.arb`, then run `flutter gen-l10n`. Regional ARB files select `en_GB` and `it_IT`. Stored item names, references and notes are never translated.

The workspace uses bottom navigation below 760 logical pixels, a compact sidebar from 760 and an expanded sidebar from 1180. Compose is the central destination. Tests cover phone, landscape, tablet, both languages and doubled text.

Generate review images with installed Flutter SDK fonts:

```sh
flutter test test/preview_test.dart --dart-define=LIBRESLIP_CAPTURE_PREVIEWS=true
```

Images are written under `build/previews`. Normal test runs skip this opt-in capture.

## Package source and preview

After building a fresh release APK, run:

```sh
python3 tool/package_milestone.py --include-apk
```

The script writes `LibreSlip-vX.Y.Z-source.zip`, `LibreSlip-vX.Y.Z-preview.apk` and `LibreSlip-vX.Y.Z-SHA256SUMS.txt` under `dist/`, using the unchanged value in `VERSION`. The source ZIP has a `LibreSlip/` root and excludes Git data, caches, SDK paths, signing material, generated build state and earlier archives.

APK packaging verifies the application identifier, version name, positive build number, matching Flutter and Gradle outputs and a build timestamp newer than every packaged source file. The source-delivery ZIP is separate from LibreSlip's in-app archive format.
