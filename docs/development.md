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

To exercise the real Android preference backend, select an isolated emulator or test device. The integration test restores the previous preference document when it finishes.

```sh
flutter test integration_test/settings_persistence_test.dart -d DEVICE_ID
```

## Structure and persistence

`lib/app` owns app startup, localisation and themes. `lib/core` contains reusable visual primitives. `lib/features/settings` separates the preference model, repository, controller and screens. `lib/features/workspace` contains navigation, the overview and explicitly labelled previews of later features.

The only runtime package beyond Flutter localisation and formatting is `shared_preferences`. Its asynchronous API uses Android DataStore by default. A single versioned JSON preference document holds ticket heading, language and appearance. Failed reads show a retry screen; unknown versions or malformed documents are never silently reset. Failed writes keep the prior visible settings, and overlapping saves are blocked. This store is only for preferences; it must not be used for items, drafts or ticket history. SQLite arrives in the items and tickets milestone. See the [plugin documentation](https://pub.dev/packages/shared_preferences) for its persistence guarantees.

The main Android manifest requests no internet or runtime permissions. Debug/profile manifests retain Flutter's development internet permission. Automatic Android cloud backup and device transfer are excluded for all app data domains. In-app ZIP portability is a later milestone, so this preview has no backup interface. The configuration follows [Android's backup documentation](https://developer.android.com/identity/data/autobackup).

## Localisation and interface

Edit `lib/l10n/app_en.arb` and `app_it.arb`, then regenerate with `flutter gen-l10n`. The regional ARB files select `en_GB` and `it_IT`; the app offers exactly those two locales. English uses British spelling. Generated localisation files are included for source review. Follow [Flutter's localisation workflow](https://docs.flutter.dev/ui/internationalization).

The shell uses bottom navigation below 760 logical pixels, a compact sidebar from 760, and an expanded sidebar from 1180. All pages scroll, choice controls stack when space is limited, and layout tests cover both languages with doubled text size. Fonts and icons ship with Flutter; nothing is downloaded at runtime. The ticket illustration and brand mark are vector shapes drawn in code. Theme and navigation transitions honour the platform's reduced-motion setting.

Generate review images with the installed Flutter SDK fonts:

```sh
flutter test test/preview_test.dart --dart-define=LIBRESLIP_CAPTURE_PREVIEWS=true
```

Images are written under `build/previews`. This optional capture is skipped during normal tests; it is a review aid rather than a pixel-perfect golden assertion.

## Package a milestone

```sh
python3 tool/package_milestone.py --include-apk
```

The script writes the source ZIP, preview APK and SHA-256 checksums to `dist/`. The source archive uses a `LibreSlip/` root, includes the lockfile and Gradle wrapper, and excludes local SDK paths, caches, IDE files, generated plugin registration, signing material and previous archives. The source ZIP is separate from the planned in-app backup format. APK packaging checks the release application identifier and requires matching Flutter and Gradle outputs, rejecting stale builds after a rename.
