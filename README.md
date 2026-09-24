# LibreSlip

A private, local order-ticket app for Android 14 and later, built with Flutter. No login, cloud service or runtime internet requirement. Application identifier: `io.thelicato.libreslip`.

![LibreSlip Italian ticket preview on a phone](docs/previews/ticket-preview-phone-it.png)

## Current milestone

Task 5 adds local portability to the item, ticket and Bluetooth printing workflow. Settings can be exported as a versioned configuration ZIP, while a full backup also contains a consistent SQLite snapshot, saved ticket history, print attempts and referenced images. Imports validate checksums, paths, sizes, contents and relationships before showing an explicit replacement preview. A durable recovery journal restores the pre-import state if replacement is interrupted.

Individual saved tickets or all previous tickets can now be deleted with confirmation. Their dependent print-attempt history is removed transactionally, while the current draft and order number remain unchanged. Bluetooth pairing credentials are never archived and must be re-established on another phone.

The user reported successful physical operation with the NETUM NT-1809DD. Successful byte transmission cannot prove that paper was produced, so the interface asks the operator to check it. Saving, printing, exporting or restoring a ticket never creates a sale or financial transaction.

## Downloads

The milestone artefacts are generated in `dist/`:

- `LibreSlip-task-05-portability.zip`: complete milestone source and documentation.
- `LibreSlip-task-05-preview.apk`: installable Android 14+ preview, signed with a development key.
- `LibreSlip-task-05-SHA256SUMS.txt`: integrity checksums for both files.

The source-delivery ZIP is separate from ZIP files exported inside LibreSlip. The preview supports local item, ticket, PDF, Bluetooth Classic printing and validated portability workflows.

## Develop

Use Flutter 3.47.2 and Dart 3.13.2 with the Android toolchain. See [development instructions](docs/development.md) for setup, architecture, builds, tests and packaging.

```sh
flutter pub get
flutter run
```

## Project documents

- [Requirements and agent instructions](AGENTS.md)
- [Delivery plan](docs/roadmap.md)
- [Hardware requirements](docs/hardware.md)
- [Development instructions](docs/development.md)
- [Archive format](docs/archive-format.md)
- [Validation results](docs/validation.md)
- [Italian ticket preview](docs/previews/ticket-preview-phone-it.png)
- [Compose preview](docs/previews/compose-phone-en.png)
- [Italian item shelf](docs/previews/items-tablet-it.png)
- [Ticket history preview](docs/previews/tickets-tablet-en.png)

Development stops after each coherent task and supplies a conventional commit name. The next task is final release verification and packaging.
