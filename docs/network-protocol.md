# Local order protocol

LibreSlip protocol version 1 carries immutable order envelopes over pinned HTTPS on the local network. The foreground Server listens on TCP port 5119.

## Encoding and limits

Messages use UTF-8 JSON. An order envelope is limited to 65,536 encoded bytes and 200 item lines. Identifiers use 1 to 128 ASCII letters, digits, dots, underscores, colons or hyphens and must begin with a letter or digit. Ticket numbers and quantities are positive integers; quantities cannot exceed 999.

| Field | Maximum characters |
| --- | ---: |
| Heading | 60 |
| Reference | 80 |
| Order note | 500 |
| Item name | 80 |
| Preparation note | 300 |

The source creation time is an ISO 8601 UTC value ending in `Z`. Text containing a null character, empty item names, empty item lists, unknown fields, unsupported versions and values outside these limits are rejected before storage.

## Order envelope

Top-level fields are `protocol`, `version`, `clientInstallationId`, `deliveryId`, `ticket` and `checksum`. `protocol` is `libreslip-order` and `version` is `1`. The ticket object contains `id`, `number`, `createdAt`, `heading`, `reference`, `orderNote` and `lines`. Each line contains `name`, `quantity` and `preparationNote`.

The checksum is lowercase SHA-256 over the canonical JSON object without the checksum field. Canonical field insertion order is fixed by the codec and line order is significant. The Server reconstructs this object and rejects a mismatch before accepting the order.

`clientInstallationId` identifies one app installation. `deliveryId` identifies one durable delivery group. The Server enforces uniqueness on their pair and returns the existing acknowledgement if an accepted envelope is repeated. The Client ticket identifier remains available for traceability but is not the Server idempotency key.

## Persistence

Database schema 6 introduced mode, installation identity, destinations, outbox, paired Client and immutable Server-order tables. Schema 7 marks at most one destination active and records the Server acknowledgement identifier. Schema 8 adds the enabled-by-default `send_to_server` item flag. Schema 9 changes saved destination URLs ending in the former LibreSlip port 42837 to 5119 and leaves every other explicit port unchanged.

Outbox states are `pending`, `sending`, `delivered` and `failed`. Opening the database returns an interrupted `sending` row to `pending` because Server idempotency makes the same envelope safe to resend. Server order states are only `received` and `done`.

Ticket finalisation and eligible outbox creation share one SQLite transaction. The local ticket snapshot always keeps every selected line. A new envelope omits items whose Server flag is off; if no eligible lines remain, no outbox row is created. The outbox keeps its canonical immutable JSON and stable delivery identifier even if the catalogue changes or the local ticket is deleted.

The Server private key, Server-side token hashes and Client access token use separate Android keystore-backed encrypted storage. Pending approval requests exist only in memory for up to two minutes. Private keys, tokens and networking tables are outside configuration archives and full backups. Full backups retain the per-item Server-delivery flag and accept portable database schemas 5 through 9.

## HTTPS endpoints and authentication

The Server listens on IPv4 TCP port 5119 only while LibreSlip is visible in Server mode. It displays each current local-network address and stops when backgrounded, when Client mode is selected or when the process terminates.

`GET /v1/status` returns the protocol version, Server installation identifier, display name and certificate fingerprint. `POST /v1/pair` accepts the Client installation identifier, display name and 64-character Client identity fingerprint, then waits for explicit approval in Server Settings. An accepted request returns a random 256-bit access token; only its hash is retained. A rejected, concurrent or two-minute-expired request returns HTTP 403. `POST /v1/orders` requires the token as a Bearer credential plus the matching Client installation identifier in `X-LibreSlip-Client-Id`.

Requests must use JSON. Pairing bodies are limited to 4,096 bytes and order bodies to 65,536 bytes. Unsupported paths, invalid content, unauthorised credentials, mismatched identities, oversized bodies and conflicting idempotency keys are rejected without storing an order. A first receipt returns HTTP 201; an identical repeat returns HTTP 200 with the original Server order identifier and `duplicate: true`.

## Certificate pinning and retry

Client pairing accepts only an IPv4 loopback, link-local or RFC 1918 address and HTTPS port. For the first `/v1/status` request, LibreSlip uses a trust store with no roots, captures SHA-256 over the presented DER certificate and requires the status response to advertise that exact fingerprint. The subsequent approval request and every later connection require the captured pin. Redirects are disabled. This trust-on-first-contact flow removes manual fingerprint entry; explicit Server acceptance prevents silent pairing, but an active LAN interceptor during first contact is outside this model.

After pairing, the Client sends the access token only to that pinned Server identity. A new delivery receives one foreground attempt after local printing. Pending records recovered at startup also receive one bounded attempt. Network, authentication, certificate, protocol and Server failures become Needs attention and require explicit retry. Retry retains the Client installation identifier, delivery identifier, immutable JSON and checksum.
