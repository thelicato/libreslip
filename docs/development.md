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

Simple settings use one versioned JSON document through `SharedPreferencesAsync` and Android DataStore. Settings format version 10 stores locale, appearance, bounded app text scaling, ticket heading, footer, logo, the 25%, 50%, 75% or 100% printed-logo width, bounded printed-ticket typography, the last selected printer address, the Compact Compose preference, the enabled-by-default printer connection requirement, the disabled-by-default whole-step completion preference and the disabled-by-default Server order-details visibility preference. Versions 1 through 4 migrate without a remembered printer, version 5 migrates with the standard Compose layout and versions 1 through 6 migrate with a 100% logo width. Versions 1 through 7 require a printer; versions 8 through 10 validate the requirement as a boolean. Versions 1 through 8 retain individual delivery controls; versions 9 and 10 validate `completeWholeSteps` as a boolean. Versions 1 through 9 default the Server order-details visibility preference to false; version 10 validates it as a boolean. Preferences remain local to this device and do not synchronise to other devices.

Catalogue, composition, immutable ticket snapshots, counters, print jobs, optional fields and networking records use app-private SQLite schema 17. Migrations are transactional. Schema 11 adds bounded ordered course inventories, scoped line references, the active composition course and the disabled-by-default course option. Schema 12 adds the disabled-by-default managed-order option, independent current-order snapshots, composition base revisions, immutable ticket revision and additions metadata, stable line identifiers and Server revision receipts and completion markers. Schema 13 adds independent Client delivered-quantity maps and per-line Server delivered counts. Migration converts existing managed Server completion markers to quantities. Legacy rows retain ordinary-ticket behaviour. The ticket origin identifier prevents accidental duplicate finalisation. Resetting the visible order number starts at 1 without reusing stable identifiers or changing history. Catalogue edits cannot rewrite ticket or delivery snapshots.

Full backups serialise the portable catalogue, composition, ticket, print and current-order tables in one read transaction and include referenced item images and the ticket logo. Networking tables and encrypted pairing secrets are excluded by archive format version 1. Portable database schemas 5 through 17 are accepted. Course inventories, active-order timestamps, stable line identities, bounded delivered quantities, ticket additions and composition base revisions are validated before import preview and again before replacement. Configuration document version 4 includes the course, managed-order and price options and accepts legacy versions 1, 2 and 3; the preferences document uses settings format 9. An order bound to a different installation is presented and continued locally after restore.

Schema 17 replaces the single active-destination index with a unique selected-destination index and retains the previous active Server as selected. Several destinations can remain paired; the selected Server routes new tickets. Existing managed orders retain their original destination. Each Server drains its durable delivery queue and fetches its shared feed independently; incoming preparation snapshots merge through the composition writer lock. Shared errors, refresh times and unavailable order identities remain scoped to their Server. Disconnect removes only that Server’s credential and chooses a remaining destination when necessary. Connection selection and pairing remain installation-local and outside archives.

## Printing and local networking

New print and reprint actions require an active printer connection. Every accepted print attempt is stored before transmission with its snapshot payload, bonded device, unique request identifier, state and timestamps. Opening the database changes interrupted Sending jobs to Uncertain; LibreSlip never automatically repeats them.

Android printing uses Bluetooth Classic RFCOMM/SPP and requests only `BLUETOOTH_CONNECT`. The 58 mm encoder targets 384 printable dots, encodes supported text with PC858, rasterises unsupported text and logos with bundled fonts, applies the configured logo width as 96, 192, 288 or 384 dots and writes 256-byte chunks. Socket completion records Transmitted rather than confirmed paper output. LibreSlip checks Bluetooth and RFCOMM socket state every 15 seconds while running and reconnects the last selected bonded printer when possible. Manual Disconnect clears that preference. Connection monitoring never resends print data.

With Require printer connection on, new Client delivery remains durably gated until a local print is recorded as Transmitted. Failed, disconnected or uncertain printing never starts that delivery. Turning the preference off saves new tickets without a print job when disconnected and creates eligible outbox rows as Pending in the finalisation transaction. Each row retains its creation policy across restart and later preference changes; older gated revisions cannot be bypassed. Optional connected printing is independent of order delivery. Pairing accepts a local IPv4 address and port, captures and verifies the Server certificate on first contact, then waits for explicit approval in Server Settings. The captured SHA-256 fingerprint pins the approval request and every later connection; redirects remain disabled. Tokens and Server keys use `flutter_secure_storage` with Android keystore-backed protection. Transient deliveries retry from the durable outbox with the same idempotency key. The Android connected-device foreground service retains the Flutter engine and CPU or Wi-Fi locks so the Server stays on port 5119 while locked or backgrounded. Duplicate deliveries return their existing acknowledgement.

## Localisation and interface

Edit `lib/l10n/app_en.arb` and `app_it.arb`, then run `flutter gen-l10n`. Regional ARB files select `en_GB` and `it_IT`. Stored item names, references and notes are never translated.

The workspace uses bottom navigation below 760 logical pixels, a compact sidebar from 760 and an expanded sidebar from 1180. Compose is the central destination, with a print action pinned outside the scrolling content. Compact Compose replaces the separate catalogue and selected-order panels with one order card. Every reusable item has a zero-based quantity stepper; reference and order notes use compact edit dialogs. Tests cover phone, landscape, tablet, both languages and doubled text.

Order title / table is the user-facing name of the existing optional reference field. Compose, history and Server details give it prominence while retaining the order number. Saved reference content and the database, archive and protocol formats are unchanged. See the [optional order management roadmap](order-management-plan.md) for subsequent steps.

Divider controls appear when enabled or when the composition already contains groups. Add divider appends a stable section and selects it for subsequent items, without a naming dialog. An empty latest divider prevents another insertion. Removing an editable divider merges its items into the preceding section, preserving line identities, quantities and notes; committed managed boundaries remain fixed. New orders start with no inherited group inventory. Compact Compose edits quantities below the latest divider and shows a complete summary with per-line movement controls. Existing named snapshots retain their captions.

Unnamed dividers reuse the existing bounded `{id, name}` inventory: a `divider-` identifier and automatic `#<positive ordinal>` token identify an unlabelled boundary. The token is compatibility metadata, never a user-entered title or a displayed Client caption. Both devices, preparation previews, ESC/POS and PDFs resolve it as a rule; order language changes never rewrite it. Schema 15, configuration document 4, settings 8 and envelope versions 1 through 3 are unchanged. Older grouped-order Servers retain separation but display the token. Existing archive validation, checksums and managed-revision immutability still apply.

ManagedOrderComposer selects active orders without exposing multiple drafts or copying historical tickets into the editor. The composition contains only additions and retains its expected base revision across restart. Previously ordered content stays read-only. Finalisation saves the full revision and current order, removes the editor and queues eligible Server delivery in one transaction. TicketDocument derives print lines from the saved additions inventory and includes a localised revision label for ESC/POS, preview and PDF. Statistics sum those same additions to avoid duplicate quantities. Managed envelopes use version 3 after a pinned capability check, and the durable outbox prevents later revisions overtaking earlier unacknowledged deliveries.

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

DeliveryProgress renders course-scoped outstanding and delivered sections on both devices. Local progress is a bounded map keyed by stable line identifiers; Server progress is stored beside received line snapshots. Transactions validate quantities and compare the expected prior count to reject stale actions. Neither path changes ticket content or print attempts. Server additions preserve counts while new lines start at zero. Managed completion follows quantities, whereas ordinary orders retain the original queue transitions. OrderProgressSynchroniser runs only on an explicit Client action against the original paired Server. Schema 14 adds local dirty line identities and edit generations, Server progress revisions, durable pending operations and original applied-snapshot receipts. ClientProgressStore, ServerProgressStore and OrderProgressTransport isolate transactional persistence and pinned HTTPS. Whole-order conflict choices compare the observed Server revision before writing. Lost acknowledgements retain the same operation identity; later Server or local edits survive recovery. Full backups omit sync metadata, while ProgressRecoveryStore captures it atomically beside the portable database for app-private restore rollback.


ProductPrice bounds integer minor units and explicit EUR, GBP or USD currencies. Schema 15 stores nullable amount/currency pairs beside catalogue and selected or saved lines; managed JSON uses explicit nullable price fields. OrderPriceEstimate groups integer subtotals by currency and counts unpriced quantities. Price capture happens on the first catalogue selection, with immutable reuse for quantity changes and prior managed lines. OrderEstimate is a local Client presentation component and never enters TicketDocument, networking envelopes or item statistics. Disabling prices hides the component and clears prices only on newly submitted lines; existing catalogue and saved snapshots remain intact. Archive preview validates prices and immutable revision consistency before replacement.

## Shared managed orders

Schema 16 adds private Client links with acknowledged per-line baselines and durable pending progress identities, plus Server receipts for append operations. SharedOrdersController polls authenticated, certificate-pinned HTTPS every five seconds and after local changes, only with Keep orders open, a paired Server and foreground Client mode. Startup never awaits a network request. Received and Completed managed orders are available to every paired Client; ordinary tickets retain their existing workflow. SharedClientStore, SharedServerStore and SharedOrdersTransport keep persistence and networking behind interfaces.

A received mirror creates current-order state without tickets, catalogue rows, prices or print jobs. Its stable local identity is derived from the destination and Server order identity; origin-owned orders retain their existing identity. Snapshot merge preserves private lines, prices, local delivery intent and immutable history. Incoming additions rebase the persistent composition under the workspace write lock. Frozen outbox revisions remain untouched until their printing policy and delivery acknowledgement are satisfied.

Shared additions use the existing immutable envelope and saved additions inventory. The Server appends only new stable line identifiers inside a transaction, checks retained line content, preserves earlier deliveries and serialises its own revision. Concurrent unnamed dividers receive unique hidden markers. Lost acknowledgements reuse the same operation identity and cannot append twice. Delivery changes compare the observed order and progress revisions; disjoint edits merge against per-line baselines and same-line divergence stays visible until explicit resolution. Private restore journals include exact links and pending operations; exported backups exclude them. Successful restore discards pending network commands, then paired foreground sync can rediscover shared state. Local closure hides a mirror only on that Client and remains distinct from Server completion. No Client background service, catalogue sharing or automatic print recovery is introduced.

Shared addition routing and the exact new eligible line identifiers are frozen with the existing private outbox row. They survive history deletion and successful local backup replacement, so retrying an accepted addition after a lost acknowledgement still uses its original Server identity and delta. Schema 15 migration backfills retained ticket additions; an older original envelope without its history row can derive its append-only delta from its earlier acknowledged envelope. These routing fields remain excluded from exported archives with the rest of the outbox.
