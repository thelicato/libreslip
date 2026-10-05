# Local order protocol

LibreSlip carries immutable order envelopes over pinned HTTPS on the local network. Ordinary orders retain envelope version 1; grouped ordinary orders use version 2; managed orders and additions use version 3. Status and pairing remain version 1, and all endpoints retain their `/v1/` paths. An Android foreground service keeps the Server listening on TCP port 5119 while Server mode is active.

## Encoding and limits

Messages use UTF-8 JSON. An order envelope is limited to 65,536 encoded bytes and 200 item lines. Identifiers use 1 to 128 ASCII letters, digits, dots, underscores, colons or hyphens and must begin with a letter or digit. Ticket numbers and quantities are positive integers; quantities cannot exceed 999.

| Field | Maximum characters |
| --- | ---: |
| Heading | 60 |
| Reference | 80 |
| Order note | 500 |
| Item name | 80 |
| Preparation note | 300 |
| Course name | 40 |

The source creation time is an ISO 8601 UTC value ending in `Z`. Text containing a null character, empty item names, empty item lists, unknown fields, unsupported versions and values outside these limits are rejected before storage.

## Order envelope

Top-level fields are `protocol`, `version`, `clientInstallationId`, `deliveryId`, `ticket` and `checksum`. `protocol` is `libreslip-order` and `version` is `1`. The ticket object contains `id`, `number`, `createdAt`, `heading`, `reference`, `orderNote` and `lines`. Each line contains `name`, `quantity` and `preparationNote`.

Grouped envelopes set `version` to `2`, add the ordered `courses` list of `{id, name}` to the ticket and add nullable `courseId` to every line. There must be between 1 and 20 courses, with unique identifiers and trimmed, case-insensitively unique names without control characters. A non-null line reference must match a course in that ticket. Ungrouped lines render first, followed by non-empty courses in inventory order. Course order and references participate in the canonical checksum. Ordinary envelopes omit these fields, preserving the version 1 wire format.

Managed envelopes set `version` to `3`. The ticket adds `orderId`, integer `revision` from 1 to 100,000, and `courses`, which may be empty. Every line adds a unique stable `id` and nullable `courseId`. Each envelope contains the complete eligible order at that Server revision. The stable order identifier is scoped to the Client installation; the ticket identifier and delivery identifier belong to the individual submission. Creation time, heading, visible number, title and order notes stay fixed. Later revisions must be consecutive and append at least one new line while preserving every previous line's identity, order, quantity, name, course and note. Existing course names and relative ordering stay fixed. Repeated delivery identifiers require the same checksum; stale, skipped or conflicting revisions return HTTP 409 without changing the order.

The checksum is lowercase SHA-256 over the canonical JSON object without the checksum field. Canonical field insertion order is fixed by the codec and line order is significant. The Server reconstructs this object and rejects a mismatch before accepting the order.

`clientInstallationId` identifies one app installation. `deliveryId` identifies one durable delivery group. The Server enforces uniqueness on their pair and returns the existing acknowledgement if an accepted envelope is repeated. The Client ticket identifier remains available for traceability but is not the Server idempotency key.

## Persistence

Database schema 6 introduced mode, installation identity, destinations, outbox, paired Client and immutable Server-order tables. Schema 7 marks at most one destination active and records the Server acknowledgement identifier. Schema 8 adds the enabled-by-default `send_to_server` item flag. Schema 9 changes saved destination URLs ending in the former LibreSlip port 42837 to 5119 and leaves every other explicit port unchanged. Schema 10 adds the durable print gate for Client deliveries. Schema 11 adds course snapshots and line references to local composition, saved tickets and Server orders.

Schema 12 adds independent Client active-order snapshots, local revisions, composition base revisions and ticket additions inventories. The Server retains one current board entry per Client and managed order identifier, plus immutable revision receipts containing identifiers and checksums. Updating the entry and recording its receipt share a transaction. A duplicate receipt returns the original Server order identifier without resetting completion, even after a later revision. Completed-order deletion keeps the minimal receipt metadata so old retries and later updates cannot resurrect deleted content. Server lines retain the revision in which they were added. Done records the completed revision; a later addition returns the order to Received while the preparation summary excludes previously completed lines. Explicit undo of Done resets that marker.

Outbox states are `awaiting_print`, `pending`, `sending`, `delivered` and `failed`. Opening the database returns an interrupted `sending` row to `pending` because Server idempotency makes the same envelope safe to resend. Server order states are only `received` and `done`.

Ticket finalisation and eligible `awaiting_print` outbox creation share one SQLite transaction. Recording a Transmitted print atomically moves that delivery to `pending`; disconnected, failed or uncertain print outcomes leave it gated. The local ticket snapshot always keeps every selected line. A new envelope omits items whose Server flag is off; if no eligible lines remain, no outbox row is created. The outbox keeps its canonical immutable JSON and stable delivery identifier even if the catalogue changes or the local ticket is deleted.

Only courses referenced by eligible Server lines enter an envelope. Empty courses and names used solely by Local only items stay on the Client. If filtering leaves no referenced courses, an ordinary delivery uses envelope version 1; a managed delivery retains version 3. Managed orders snapshot each line's Server eligibility when it is added, so later catalogue changes cannot rewrite earlier revisions. A local revision containing only Local only additions creates no new delivery and does not consume a Server revision.

The Server private key, Server-side token hashes and Client access token use separate Android keystore-backed encrypted storage. Pending approval requests exist only in memory for up to two minutes. Private keys, tokens and networking tables are outside configuration archives and full backups. Full backups retain the per-item Server-delivery flag and accept portable database schemas 5 through 14. Managed orders retain their original non-secret destination and installation identifiers, but an order restored to a different installation continues locally without recreating a delivery or pairing.

## HTTPS endpoints and authentication

The Server listens on IPv4 TCP port 5119 while Server mode is active. A foreground service retains the Flutter engine and holds CPU and Wi-Fi locks so the HTTPS listener continues when the screen locks or the activity is backgrounded. It displays each current local-network address and stops when Client mode is selected, LibreSlip is force-stopped, the process terminates or the device restarts.

`GET /v1/status` returns the protocol version, Server installation identifier, display name and certificate fingerprint. `POST /v1/pair` accepts the Client installation identifier, display name and 64-character Client identity fingerprint, then waits for explicit approval in Server Settings. An accepted request returns a random 256-bit access token; only its hash is retained. A rejected, concurrent or two-minute-expired request returns HTTP 403. `POST /v1/orders` requires the token as a Bearer credential plus the matching Client installation identifier in `X-LibreSlip-Client-Id`.

The updated status response also advertises `orderVersions: [1, 2, 3]`. Before posting a grouped or managed delivery, the Client requests status through the pinned connection, checks the Server identity and requires the envelope's advertised version. An older Server produces `unsupported_courses` or `unsupported_updates` without receiving an order POST. The immutable delivery remains Needs attention for explicit retry after updating the Server. Acknowledgements use the accepted envelope's version; ordinary Clients and Servers remain compatible.

Requests must use JSON. Pairing bodies are limited to 4,096 bytes and order bodies to 65,536 bytes. Unsupported paths, invalid content, unauthorised credentials, mismatched identities, oversized bodies and conflicting idempotency keys are rejected without storing an order. A first receipt returns HTTP 201; an identical repeat returns HTTP 200 with the original Server order identifier and `duplicate: true`.

## Certificate pinning and retry

Client pairing accepts only an IPv4 loopback, link-local or RFC 1918 address and HTTPS port. For the first `/v1/status` request, LibreSlip uses a trust store with no roots, captures SHA-256 over the presented DER certificate and requires the status response to advertise that exact fingerprint. The subsequent approval request and every later connection require the captured pin. Redirects are disabled. This trust-on-first-contact flow removes manual fingerprint entry; explicit Server acceptance prevents silent pairing, but an active LAN interceptor during first contact is outside this model.

After pairing, the Client sends the access token only to that pinned Server identity. A new delivery is attempted only after local printing is recorded as Transmitted. Lost acknowledgements, unreachable-network failures and Server failures are retried automatically every ten seconds while the Client process is available and again when the app opens. Authentication, certificate, destination, storage and protocol errors remain Needs attention for explicit action. Every attempt retains the Client installation identifier, delivery identifier, immutable JSON and checksum. The Server commits an order and its acknowledgement atomically, then returns the existing acknowledgement for an identical resend.

Managed revisions wait for every earlier delivery for the same order and destination to be acknowledged. The Client controller orders them by original order time and revision, and storage also rejects attempts that bypass an unfinished earlier revision. A later printed revision remains pending while an earlier print is failed or uncertain, with a localised recovery explanation. Explicit retry cannot bypass that dependency. Managed history tickets needed for unfinished delivery cannot be deleted. Orders started unpaired remain local, and an active order does not automatically move to a newly paired destination. Restoring older state on the original installation leaves networking state intact; the Server rejects stale revisions rather than replacing a newer order.

Schema 13 stores delivered quantities independently on the Client and Server. Managed order envelopes remain version 3 and contain order content only; retries and revisions cannot reset existing Server delivery counts. Schema 14 adds explicit progress synchronisation separately from order delivery and printing.


## Explicit delivery progress

Status advertises `progressVersions: [1]`. A Client checks that capability and the pinned Server installation identifier before each exchange. Unsupported Servers receive no progress GET or POST. Progress uses the original order destination and Client installation identifier, the existing Bearer token and `X-LibreSlip-Client-Id`. The Server scopes every lookup to the authenticated Client and managed order identifier. Ordinary orders have no progress endpoint.

`GET /v1/progress?orderId=<id>` returns JSON fields `protocol: libreslip-order`, `version: 1`, `clientId`, `orderId`, `orderRevision`, `progressRevision` and `quantities`. The quantities map includes every shared stable line identifier with a delivered integer from zero to its original quantity. Snapshots contain at most 200 lines. Local only identifiers and counts never enter this map. Order content revisions remain separate from progress revisions.

`POST /v1/progress` accepts JSON fields `protocol`, `version`, `operationId`, `orderId`, `orderRevision`, `expectedRevision` and the complete `quantities` map. Bodies are limited to 65,536 bytes. In one transaction, the Server requires the exact shared inventory and current order and progress revisions, updates counts and queue completion, increments progress revision and stores the canonical request and original applied snapshot. The response is HTTP 200 with that snapshot. Repeating the same Client-scoped operation and content returns its original snapshot even if later Server changes occurred; conflicting reuse returns HTTP 409. A missing or deleted managed order returns HTTP 404. Delivery edits, Done and Undo Done also increment progress revisions. Order additions preserve prior counts and start new lines at zero.

Client sync runs only when requested. It first recovers any durably stored pending operation with the same identifier, acknowledges only the corresponding local edit generation, then fetches current progress. Offline edits include zero-valued undo. Differences on both devices require an explicit choice of all shared Client or Server counts; Local only progress is retained. Resolution compares the observed remote revisions, and a further Server edit refreshes the conflict without overwriting it. New shared additions must already be received, and a newer Server order revision requires current local order data. No progress exchange creates a ticket, print attempt or content revision, and no printer connection is required.
