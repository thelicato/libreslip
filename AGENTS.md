# LibreSlip agent instructions

## Product requirements

- Build LibreSlip in Flutter and Dart for Android 14 and later. Use `libreslip` as the Dart project name and `io.thelicato.libreslip` as the Android application identifier. Use original branding and a modern, polished interface. The repository location does not dictate the app name.
- LibreSlip creates and prints order or preparation tickets containing items, quantities and notes without prices or monetary totals.
- Never add payment processing or payment recording, checkout, tenders, change, refunds, taxes, discounts, cash drawers, shifts, sales reporting, loyalty, debt, purchasing or stock valuation. Ticket printing must not create a sale or financial transaction.
- Require no registration, login, subscription, Server connection or internet connection for core Client operation, including first launch. Optional Server delivery must never be required for composing, local printing, history, export or backup.
- Store settings, reusable items, the persistent composition, history and assets on the phone. Use transactional local SQLite storage with versioned migrations for items and tickets; simple preferences may use a local preferences backend.
- Do not introduce cloud databases, analytics, remote fonts or background uploads. Keep Android cloud backup and device transfer disabled.
- Support British English (`en_GB`) and Italian (`it_IT`) throughout the interface, validation, tickets and exports. Allow immediate language changes and persist the choice. Language changes must not modify item or ticket content.
- Support ZIP import and export of the current configuration, plus complete local backups for transferring or restoring items and ticket history. Source-delivery ZIPs are separate artefacts.
- Support the NETUM NT-1809DD 58 mm Bluetooth 4.0/USB printer. Android Bluetooth Classic SPP is the implemented transport. See [hardware compatibility](docs/hardware.md) and keep physical evidence distinct from automated checks.
- Support Android phones, portrait and landscape layouts and wider displays. iOS and desktop distribution are outside the current scope.

## Required workflows

| Area | Required LibreSlip capabilities |
| --- | --- |
| Reusable items | Local item names, categories, optional images and search for quickly composing tickets. No favourites or stock accounting. |
| Ticket composition | Reusable items, quantities, optional preparation notes, optional order notes, optional table or order reference, persistent recovery and print preview. Do not add one-off items or expose multiple-draft management. |
| Ticket history | Stable ticket identifiers, creation times, saved snapshots, viewing, deletion, explicit reprint and a clear distinction between editable work and print attempts. Do not duplicate saved tickets into drafts. |
| Printing | Custom heading, logo and footer, readable 58 mm layout, bilingual labels, printer setup, test ticket, durable print jobs, reconnect and recoverable failures. |
| Portability | Versioned configuration ZIPs and full backups, import preview, validated restore, rollback and optional ticket PDF sharing through the system share sheet. |
| Client and Server | Client retains every offline capability and may deliver immutable tickets. Server only receives orders, displays Received and Completed queues and marks orders Done. |

Do not expand LibreSlip into a business management suite. Prioritise composing a ticket and getting it reliably onto paper. Printed content is an order or preparation ticket, not a payment or fiscal receipt. Server mode is a receive-and-Done board only and must not gain catalogue editing, printing, payments or reporting.

## Architecture and data correctness

- Organise code by feature with presentation, application or domain and persistence boundaries. Keep storage, ticket rendering, ESC/POS encoding, transport, archives and platform permissions behind interfaces.
- Preserve the item names, quantities, notes and heading used for a saved ticket as a snapshot. Catalogue edits must not rewrite saved tickets.
- Use stable identifiers and database transactions. Persist composition and ticket or print-job changes reliably, and recover after process interruption without creating duplicate tickets.
- Keep printing separate from ticket creation. A failed print must not erase a ticket. A reprint must not create another order. Do not allow a new Print ticket or reprint action without a connected printer; existing queued jobs may remain available for explicit recovery after reconnection.
- Distinguish queued, sending, failed and uncertain print attempts. Do not automatically resend when the printer may already have printed the job. Successful byte transmission alone does not prove paper output.
- Store timestamps consistently and format them for the selected locale and device timezone. Use validated positive integer quantities.
- Keep ticket contents, personal notes and device secrets out of logs. Use app-private storage and minimal permissions. Import, export and rendering must not block the interface.
- Prefer small, maintained dependencies compatible with the chosen Flutter and Android versions. Record the toolchain and retain `pubspec.lock`.

## ZIP import and export

- Configuration archives include ticket identity and logo, locale, appearance, ticket templates and printer preferences. Full backups also include a consistent database snapshot and referenced assets. Exclude device pairing credentials, caches and temporary files.
- Include a manifest identifying LibreSlip, archive kind, format, schema and app versions, creation time, file inventory and checksums. Keep the implemented format documented.
- Export through platform file access or share APIs without mandatory broad storage permissions. Explain that exported archives contain private ticket data.
- Stage imports separately. Validate format and version, checksums, referential integrity, entry counts, file types, sizes and total expanded size. Reject path traversal, absolute paths, links, duplicate paths and excessive compression ratios.
- Show a preview and require explicit in-app confirmation before replacing existing settings or data. Keep a recoverable pre-import snapshot and make replacement atomic. Invalid, cancelled, interrupted or unsupported imports must leave the original data usable.
- Restore is replacement rather than an implicit merge. Verify configuration and full-backup round trips, including restore on a fresh installation. Printer preferences may restore, but pairing must be re-established.

## Interface and localisation

- Use a distinctive Material 3 interface with deep ink, warm neutral surfaces and a teal accent, implemented through reusable design tokens. Keep branding and illustrations original and bundled locally.
- Make item selection, quantities, notes and printing fast to reach. Use a split item and ticket layout on wider screens and reachable navigation on phones.
- Support light, dark and system themes, safe areas, keyboard insets, semantic labels, readable contrast, scalable text and touch targets of at least 48 logical pixels. Honour reduced-motion preferences.
- Provide complete loading, empty, validation, error and recovery states. Do not use decorative controls that do nothing, fabricated history or fake print-success messages.
- Use Flutter localisation generation and ARB resources with appropriate placeholders and plurals. Do not hard-code interface strings. Localise labels, dates and numbers without translating stored content.
- Use British English in authored English prose and comments. Do not use em dashes. Do not use emojis in the README. Keep documentation compact, without manually wrapped paragraphs or unnecessary blank lines; retain valid Markdown spacing.

## Delivery workflow

- Work in coherent, reviewable atomic changes. Stop after each change, report implementation, validation, limitations, download links and one conventional commit name, then wait for continuation.
- Do not change `VERSION` unless explicitly requested. Release version changes belong to the release owner.
- Do not create commits or push unless requested. Preserve unrelated changes. Do not delegate to sub-agents unless explicitly requested.
- Deliver source ZIPs under a `LibreSlip/` root with the files required to reproduce the current state. Exclude `.git`, tool state, caches, build intermediates, local SDK paths, secrets, signing keys and previous archives. Include checksums and honest status.
- When buildable, include an installable Android preview APK with source delivery. Label development-key builds as previews.
- Run formatting checks, `flutter analyze` and relevant tests. Test persistence, migrations, interrupted printing and restore failure paths when affected. Verify responsive and localised screens and inspect representative renders.
- Before a production release, build the APK and verify offline cold start, process-death recovery, both languages, ZIP round trips, permission denial and the physical printer. Distinguish automated checks from physical hardware verification. Never invent results.
