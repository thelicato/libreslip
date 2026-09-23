# Development

## Toolchain

This milestone was developed with Flutter 3.47.2 stable (revision `d3b14c876900e553bc736ca19295fc09e3853e8e`), Dart 3.13.2, Java 21.0.7, Gradle 9.3.1, Android Gradle Plugin 9.1.0 and Kotlin 2.4.0. The application identifier is `io.thelicato.libreslip` and the Dart package is `libreslip`. The Android minimum is API 34 (Android 14); compilation and target SDK versions are API 36, as selected by this Flutter SDK. Use the committed `pubspec.lock` to reproduce dependency resolution.

## Run and build

Install the Flutter SDK and Android SDK, ensure the Android SDK licences are accepted, and connect an Android 14 or later device with USB debugging enabled. Dependency downloads require internet during development; the installed app does not need it.

```sh
flutter pub get
flutter gen-l10n
flutter run
```

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build apk --release
```

The APK is produced at `build/app/outputs/flutter-apk/app-release.apk`. Milestone builds use the development machine's debug signing key even in release mode. They are installable previews, not production-signed releases. Do not distribute private signing material. A preview rebuilt on another machine may need its own installation because the signing key differs.

To exercise Android DataStore and SQLite through their real platform implementations, select an isolated emulator or test device. The integration test restores the previous preference document and removes its dedicated database when it finishes.

```sh
flutter test integration_test/settings_persistence_test.dart -d DEVICE_ID
```

## Architecture and persistence

`lib/app` owns app startup, localisation and themes. `lib/core` contains reusable visual primitives. Settings retain their preference model, repository, controller and screens. `lib/features/orders` separates item and ticket domain models, application state, SQLite and image persistence, and the Compose, Items and Tickets pages. `lib/features/workspace` owns responsive navigation and the overview.

Simple settings remain in one versioned JSON document through `SharedPreferencesAsync`, backed by Android DataStore. Reusable items, categories, drafts, draft lines, tickets, ticket lines and ticket numbering use `sqflite` in app-private storage. Schema version 2 is upgraded transactionally from version 1. Foreign keys, uniqueness constraints and quantity checks protect relationships and invalid values.

Every draft line stores the item name selected at that moment. Saving a ticket copies heading, reference, notes, names and quantities into separate snapshot tables in one transaction. The ticket table has a unique origin draft identifier. A retry after an uncertain caller response returns the existing ticket instead of incrementing the number or inserting a duplicate. Saving removes only the converted draft and immediately creates a fresh editable draft in application state. Catalogue edits and archival cannot change saved snapshots.

Optional item images are selected through the Android system picker and copied into the app support directory. Removing or replacing an item image removes the old private file after the database change succeeds. Image files are not uploaded. Full backup of database and referenced images belongs to task 5.

The release manifest requests no internet permission. Automatic Android cloud backup and device transfer remain excluded for all app data domains. Printing and in-app ZIP portability are not present in this milestone.

## Localisation and interface

Edit `lib/l10n/app_en.arb` and `app_it.arb`, then regenerate with `flutter gen-l10n`. The regional ARB files select `en_GB` and `it_IT`; the app offers exactly those two locales. English uses British spelling. Stored item names, references and notes are never translated when the interface language changes.

The shell uses bottom navigation below 760 logical pixels, a compact sidebar from 760, and an expanded sidebar from 1180. Compose uses a split item/draft view when space permits and a stacked flow on phones. Tests cover both languages on small phones, landscape, tablets and doubled text size.

Generate review images with the installed Flutter SDK fonts:

```sh
flutter test test/preview_test.dart --dart-define=LIBRESLIP_CAPTURE_PREVIEWS=true
```

Images are written under `build/previews`. This optional capture is skipped during normal tests; it is a review aid rather than a pixel-perfect golden assertion.

## Package a milestone

```sh
python3 tool/package_milestone.py --include-apk
```

The script writes the task 3 source ZIP, preview APK and SHA-256 checksums to `dist/`. The source archive uses a `LibreSlip/` root, includes the lockfile and Gradle wrapper, and excludes local SDK paths, caches, IDE files, generated plugin registration, signing material and previous archives. The source ZIP is separate from the planned in-app backup format. APK packaging checks the release application identifier, version name and version code, rejects an APK older than any packaged source, and requires matching Flutter and Gradle outputs.
