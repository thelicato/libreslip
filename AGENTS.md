# LibreSlip agent instructions

## Product requirements

- Build LibreSlip in Flutter and Dart for Android 14 and later. Use `libreslip` as the Dart project name and `io.thelicato.libreslip` as the Android application identifier. Use original branding and a modern, polished interface. The repository location does not dictate the app name.
- LibreSlip creates and prints order tickets. The user's 20 September 2026 instruction replaces the earlier point-of-sale scope. Loyverse and Kyte feature parity is no longer a requirement.
- Never add payment processing or payment recording, checkout, tenders, change, refunds, taxes, discounts, cash drawers, shifts, sales reporting, loyalty, debt, purchasing or stock valuation. Ticket printing must not create a sale or financial transaction. Tickets contain items, quantities and notes, without prices or monetary totals.
- Require no registration, login, subscription, server or internet connection for core operation, including first launch.
- Store settings, reusable items, ticket drafts, history and assets on the phone. Use transactional local SQLite storage with versioned migrations for items and tickets; simple preferences may use a local preferences backend.
- Do not introduce cloud databases, analytics, remote fonts or background uploads. Configure Android backup exclusions to prevent automatic cloud backup and device transfer of app data.
- Support British English (`en_GB`) and Italian (`it_IT`) throughout the interface, validation, tickets and exports. Allow immediate language changes and persist the choice. Language changes must not modify item or ticket content.
- Support ZIP import/export of the current configuration, plus full local backups for transferring or restoring items and ticket history. Source-delivery ZIPs are a separate artefact.
- Support the NETUM NT-1809DD 58 mm Bluetooth 4.0/USB printer identified by the user: <https://amzn.eu/d/0hYiM2dg>, Amazon ASIN `B0854CCF75`. Android Bluetooth Classic SPP is the first transport. See [hardware requirements](docs/hardware.md); verify compatibility on the actual printer before claiming it.
- Support general Android phones, portrait/landscape layouts and wider displays. iOS and desktop distribution are outside the current scope.

## Required workflows

| Area | Required LibreSlip capabilities |
| --- | --- |
| Reusable items | Local item names, categories, optional images and search for quickly composing tickets. No favourites or stock accounting. |
| Ticket composition | Reusable items, quantities, optional preparation notes, optional order notes, optional table or order reference, persistent recovery and print preview. Do not add one-off items or expose multiple-draft management. |
| Ticket history | Stable ticket identifiers, creation times, saved snapshots, viewing, explicit reprint and a clear distinction between editable work and print attempts. Do not duplicate saved tickets into drafts. |
| Printing | Custom heading/logo/footer, readable 58 mm layout, bilingual labels, printer setup, test ticket, durable print jobs, reconnect and recoverable failures. |
| Portability | Versioned configuration ZIPs and full backups, import preview, validated restore, rollback, and optional ticket PDF sharing through the system share sheet. |

Do not silently expand this into a business management suite. Prioritise composing a ticket and getting it reliably onto paper. Printed content is an order/preparation ticket, not a payment or fiscal receipt.

## Architecture and data correctness

- Organise code by feature with presentation, application/domain and persistence boundaries. Keep storage, ticket rendering, ESC/POS encoding, transport, archives and platform permissions behind interfaces.
- Preserve the item names, quantities, notes and header used for a saved ticket as a snapshot. Catalogue edits must not rewrite previously printed tickets.
- Use stable identifiers and database transactions. Persist drafts and ticket/print-job changes reliably, and recover after process interruption without creating duplicate tickets.
- Keep printing separate from ticket creation. A failed print must not erase a ticket. A reprint must not create another order.
- Distinguish queued, sending, failed and uncertain print attempts. Do not automatically resend when the printer may already have printed the job. Successful byte transmission alone does not prove paper output.
- Store timestamps consistently and format them for the selected locale and device/business timezone. Use validated quantities appropriate to the item type.
- Keep ticket contents, personal notes and device secrets out of logs. Use app-private storage and minimal permissions. Import, export and rendering must not block the interface.
- Prefer small, maintained dependencies compatible with the chosen Flutter and Android versions. Record the toolchain and retain the application lockfile.

## ZIP import and export

- Configuration archives include ticket identity/logo, locale, appearance, ticket templates and printer preferences. Full backups also include a consistent database snapshot and all referenced assets. Exclude device pairing credentials, caches and temporary files.
- Include a manifest identifying LibreSlip, archive kind, format/schema/app versions, creation time, file inventory and checksums. Document the implemented format.
- Export through platform file access/share APIs without mandatory broad storage permissions. Explain that exported archives contain private ticket data.
- Stage imports separately. Validate format/version, checksums, referential integrity, entry counts, file types, sizes and total expanded size. Reject path traversal, absolute paths, links, duplicate paths and excessive compression ratios.
- Show a preview and obtain explicit in-app confirmation before replacing existing settings or data. Keep a recoverable pre-import snapshot and make replacement atomic. Invalid, cancelled, interrupted or unsupported imports must leave the original data usable.
- Restore is replacement rather than an implicit merge. Verify round trips for configuration and full backup archives, including restore on a fresh installation. Printer preferences may restore, but pairing must be re-established.

## Interface and localisation

- Use a distinctive Material 3 interface with deep ink, warm neutral surfaces and a teal accent, implemented through reusable design tokens. Keep branding and illustrations original and bundled locally.
- Make item selection, quantities, notes and printing fast to reach. Use a split item/ticket layout on wider screens and reachable navigation on phones.
- Support light/dark/system themes, safe areas, keyboard insets, semantic labels, readable contrast, scalable text and touch targets of at least 48 logical pixels. Honour reduced-motion preferences.
- Provide complete loading, empty, validation, error and recovery states. Do not use decorative controls that do nothing, fabricated history or fake print-success messages. Unfinished features must be clearly labelled as previews.
- Use Flutter localisation generation and ARB resources with appropriate placeholders and plurals. Do not hard-code user-facing strings. Localise labels, dates and numbers without translating stored user content.
- Use British English in authored English prose and comments. Do not use em-dashes. Do not use emojis in the README. Keep documentation compact, without manually wrapped paragraphs or unnecessary blank lines; retain valid Markdown spacing.

## Delivery workflow

- Work in coherent, reviewable atomic tasks, following [the delivery plan](docs/roadmap.md). Stop after each task, report changes, validation, limitations, download links and one conventional commit name, then wait for the user's continuation.
- Do not create commits or push unless requested. Preserve unrelated user changes. Do not delegate to sub-agents unless the user explicitly asks.
- Deliver source ZIPs under a `LibreSlip/` root, with the files required to reproduce the milestone. Exclude `.git`, tool state, caches, build intermediates, local SDK paths, secrets, signing keys and previous archives. Include checksums and honest milestone status.
- When buildable, include an installable Android preview APK with source delivery. Label development-key builds as previews. Do not call a scaffold or visual shell a completed ticket printer.
- Run formatting checks, `flutter analyze` and relevant tests. Test item/ticket persistence, migrations, interrupted printing and restore failure paths when implemented. Verify responsive/localised screens and inspect representative renders.
- Before release, build the APK and verify offline cold start, process-death recovery, both languages, ZIP round trips, permission denial and the actual printer. Distinguish automated checks from physical hardware verification. Never invent test results.
