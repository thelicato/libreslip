# LibreSlip

A private, local order-ticket app for Android 14 and later, built with Flutter. No login, cloud service or runtime internet requirement. Application identifier: `io.thelicato.libreslip`.

![LibreSlip Italian ticket preview on a phone](docs/previews/ticket-preview-phone-it.png)

## Current milestone

Task 4 adds ticket output to the reusable item and persistent order workflow. Compose presents one automatically persisted working ticket and Print ticket saves its immutable snapshot before creating a durable print attempt. Optional reference, preparation-note and order-note fields can be hidden through SQLite-backed settings. Tickets have a bilingual 58 mm preview, configurable heading, optional app-private logo and footer, and local PDF sharing. Android printer setup lists bonded devices and connects to the NETUM NT-1809DD through Bluetooth Classic SPP.

Items, drafts, ticket snapshots and durable print attempts use a versioned transactional SQLite database. Draft-to-ticket conversion is atomic and idempotent, so retrying the same conversion cannot create a second ticket. Catalogue edits do not rewrite saved ticket content. Queued, sending, failed, uncertain and transmitted print states are distinct; interrupted sends are never retried automatically.

The user reported successful physical operation with the NETUM NT-1809DD. Successful byte transmission cannot prove that paper was produced, so the interface asks the operator to check it. Saving or printing a ticket never creates a sale or financial transaction. In-app ZIP portability remains pending.

## Downloads

The milestone artefacts are generated in `dist/`:

- `LibreSlip-task-04-ticket-printing.zip`: complete milestone source, documentation and reviewed screenshots.
- `LibreSlip-task-04-preview.apk`: installable Android 14+ preview, signed with a development key.
- `LibreSlip-task-04-SHA256SUMS.txt`: integrity checksums for both files.

The source ZIP is separate from the planned in-app configuration and backup archives. The preview supports local item, ticket, PDF and Bluetooth Classic printing workflows.

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
- [Validation results](docs/validation.md)
- [Italian ticket preview](docs/previews/ticket-preview-phone-it.png)
- [Compose preview](docs/previews/compose-phone-en.png)
- [Italian item shelf](docs/previews/items-tablet-it.png)
- [Ticket history preview](docs/previews/tickets-tablet-en.png)

Development stops after each coherent task and supplies a conventional commit name. The next task is validated configuration and full-backup ZIP portability.
