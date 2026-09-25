# LibreSlip

A private, local order-ticket app for Android 14 and later, built with Flutter. No login or cloud service. Client operation has no server or runtime internet requirement. Application identifier: `io.thelicato.libreslip`.

![LibreSlip Italian ticket preview on a phone](docs/previews/ticket-preview-phone-it.png)

## Current milestone

LibreSlip 0.14.0 moves the foreground local HTTPS Server to TCP port 5119. Client address entry uses 5119 when no port is supplied, Server screens and examples display the new endpoint, and SQLite schema 9 moves existing LibreSlip destinations from port 42837 without changing unrelated custom ports. Certificate pinning, authentication and protocol version 1 are unchanged.

The Client Overview now exposes complete item totals in a dedicated dialog. It sums immutable saved-ticket snapshots for the active inclusive date range and presents every item as a name and quantity. With no date limits, the dialog covers all ticket history. Prices, sales and financial totals remain outside LibreSlip.

Local printing remains first and independent. An unavailable Server cannot roll back or duplicate the local ticket or print attempt. Client mode remains fully usable without pairing or runtime internet access. The Android internet permission is used only for optional local-network communication.

The user reported successful physical printing with the NETUM NT-1809DD during task 4. Successful byte transmission still cannot prove that paper was produced, so the interface asks the operator to check it. LibreSlip records no sale or financial transaction.

## Downloads

The latest review artefacts are generated in `dist/`:

- `LibreSlip-task-14-port-item-totals.zip`: complete port migration and Overview item-total source.
- `LibreSlip-task-14-port-item-totals-preview.apk`: installable Android 14+ preview, signed with a temporary development validation key.
- `LibreSlip-task-14-port-item-totals-SHA256SUMS.txt`: integrity checksums for both files.

The source-delivery ZIP is separate from ZIP files exported inside LibreSlip. The preview supports local item, ticket, PDF, Bluetooth Classic printing and validated portability workflows. Its temporary validation certificate is not the future production certificate, so it must not be used as an upgrade baseline for public releases.

## Develop

Use Flutter 3.47.2 and Dart 3.13.2 with the Android toolchain. See [development instructions](docs/development.md) for architecture, tests and packaging.

```sh
flutter pub get
flutter run
```

## Build

Build locally with an installed Flutter SDK:

```sh
python3 build.py local debug
python3 build.py local prod
```

Or build through a compatible Flutter Docker image selected from the SDK constraints in `pubspec.lock`:

```sh
python3 build.py docker debug
python3 build.py docker prod
```

Generated Android APKs are written to `build/app/outputs/flutter-apk/`. `VERSION` is the only release version file. Update it using the `X.Y.Z` format before a release; both build modes pass it to Flutter as the Android version name.

## Release signing

Android only accepts an update when it is signed by the same certificate as the installed application. Create one long-lived keystore before publishing, keep at least one secure offline backup, and reuse it for every LibreSlip release.

Create the keystore and local signing properties interactively from the project root. The helper uses `keytool`, asks for a public certificate name and a hidden password, and refuses to overwrite existing signing files:

```sh
./scripts/generate_release_keystore.sh
```

The script creates `android/app/libreslip-release.jks` and `android/key.properties`. Both are ignored by Git. A local or Docker production build requires this signing configuration and never falls back to the debug key.

For GitHub releases, add these repository secrets under Settings, Secrets and variables, Actions:

- `LIBRESLIP_KEYSTORE_BASE64` - The single-line Base64 representation of `android/app/libreslip-release.jks`, produced on Linux with `base64 -w 0 android/app/libreslip-release.jks`.
- `LIBRESLIP_STORE_PASSWORD` - The keystore password.
- `LIBRESLIP_KEY_ALIAS` - `libreslip`, unless a different alias was used.
- `LIBRESLIP_KEY_PASSWORD` - The private-key password.

The release workflow decodes the keystore into the temporary runner directory, validates its alias and password, signs the APK, and relies on runner disposal to remove temporary signing material.

## GitHub releases

Update `VERSION`, commit it, then push the matching numeric `vX.Y.Z` tag. `.github/workflows/release.yml` rejects mismatched tags, installs Flutter 3.47.2, analyses and tests LibreSlip, builds `LibreSlip-vX.Y.Z.apk`, creates or updates the GitHub release with `changelogithub`, and uploads the signed APK. GitHub's run number supplies the increasing Android build number.

```sh
# After updating and committing VERSION.
git tag v0.14.0
git push origin v0.14.0
```

Release notes are generated from Conventional Commits since the previous tag. The workflow stops before building or publishing if a signing secret is missing or invalid.

## Project documents

- [Requirements and agent instructions](AGENTS.md)
- [Delivery plan](docs/roadmap.md)
- [Hardware requirements](docs/hardware.md)
- [Development instructions](docs/development.md)
- [Archive format](docs/archive-format.md)
- [Client and server mode plan](docs/client-server-plan.md)
- [Local order protocol](docs/network-protocol.md)
- [Validation results](docs/validation.md)
- [Italian ticket preview](docs/previews/ticket-preview-phone-it.png)
- [Compose preview](docs/previews/compose-phone-en.png)
- [Italian item shelf](docs/previews/items-tablet-it.png)
- [Ticket history preview](docs/previews/tickets-tablet-en.png)

Task 14 is the latest completed milestone. Further changes should remain coherent, reviewable milestones and include a conventional commit name.
