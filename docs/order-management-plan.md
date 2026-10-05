# Optional order management

Deliver each step as a separate, reviewable change. The existing offline composition, immutable ticket history and explicit printing workflow remains available. New order management capabilities must be optional and must work locally without a Server.

## 1. Order titles: implemented

The optional Order title / table field uses the existing persisted order reference, with an 80-character limit. Titles appear above the order number in standard and Compact Compose, ticket history and ticket details, and Server cards and details. Blank titles use the numbered view. Client Settings can hide the field; disabling it preserves the current composition content but omits it from newly saved tickets, matching the existing optional-field behaviour. Saved titles remain visible. Tickets, PDF sharing, local backups and Server delivery retain the same reference field, so existing data and paired devices remain compatible. No database, archive or protocol migration is required.

## 2. Course groups: implemented

Client Settings enables named, ordered courses, for example Drinks, First course and Second course. The option is off by default. Standard and Compact Compose, Server cards and details, previews, 58 mm preparation tickets and PDFs visually separate courses. Select a course for additions or move individual lines; the same item in different courses keeps separate quantities and notes. Manage courses to rename, reorder or remove them, with removal returning items to Ungrouped. Empty courses are omitted from rendered tickets. When enabled, the next composition reuses course definitions; disabling preserves the current order and saved snapshots and returns the next composition to the ordinary layout.

Transactional SQLite schema 11 stores course definitions, line references, active selection and the optional setting. Configuration document version 2 and full backups round-trip the new data, accept older formats and validate course relationships before restore. Plain delivery retains envelope version 1; grouped delivery uses version 2 and checks the pinned Server's advertised support before posting. Unsupported deliveries remain available for explicit retry after updating the Server. Course groups provide visual organisation; they do not yet schedule preparation, update saved orders or track delivery progress.

## 3. Updates to active orders: planned

Allow the Client to add items to an active managed order, including drinks. Keep a stable order identifier and explicit revisions, with immutable saved ticket snapshots for each submitted change. Track active orders separately from the single persistent composition and ticket history. Send revisions through a durable, idempotent outbox, reject stale or conflicting updates and recover after interruption. Keep local updates available offline and make printing of additions explicit, with the existing connection and uncertain-output rules. The Server receives revisions without gaining catalogue editing or order composition.

## 4. Per-item delivery: planned

Track delivered quantities against stable order-line identifiers, allowing partial delivery when a line contains several units. Show outstanding and delivered items within each course on both devices. Persist local delivery progress and synchronise changes explicitly with revision and conflict handling when paired. Additions remain outstanding and must not inherit earlier delivery state. Preserve the existing Received and Completed workflow for ordinary tickets. Completion and undo rules must be explicit and recoverable.

## 5. Optional product prices and totals: planned

The October 2026 request explicitly revises the earlier prohibition on prices and monetary totals for this optional feature. Add optional catalogue prices and an estimated order total, using integer minor units and an explicit currency rather than floating-point money. Distinguish missing prices from zero prices and snapshot prices used for each order revision. Keep price entry and totals disabled by default, with localised display and validated backup restoration. Preparation printing remains focused on items, quantities and notes. Payment processing, payment recording, checkout, taxes, discounts, refunds and financial reporting remain outside scope.

## Validation and delivery

Each step includes formatting, analysis, relevant automated checks, localised responsive render inspection, source ZIP and a development-key Android preview when buildable. Changes to persistence, protocols or restore require migration, interruption and invalid-restore tests. Automated byte transmission and rendered previews do not establish physical printer output; Android and physical hardware checks must be reported separately.
