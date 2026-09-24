# Local order protocol

LibreSlip protocol version 1 defines the immutable order envelope used by the local client/server transport. Version 0.13.0 implements the foreground Server receiver, optional pinned Client delivery and per-item delivery exclusion without changing the wire version.

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

The top-level fields are `protocol`, `version`, `clientInstallationId`, `deliveryId`, `ticket` and `checksum`. `protocol` is `libreslip-order` and `version` is `1`. The ticket object contains `id`, `number`, `createdAt`, `heading`, `reference`, `orderNote` and `lines`. Each line contains `name`, `quantity` and `preparationNote`.

The checksum is lowercase SHA-256 over the canonical JSON object without the checksum field. Canonical field insertion order is fixed by the codec and line order is significant. The server must reconstruct this canonical object and reject a mismatch before accepting the order.

`clientInstallationId` identifies one app installation. `deliveryId` identifies one durable delivery attempt group. A server enforces uniqueness on their pair and returns the existing acknowledgement if an accepted envelope is repeated. The client ticket identifier is retained for traceability but is not the server idempotency key.

## Persistence in schema 8

Schema 6 introduced the mode, installation identity, destination, outbox, paired-client and immutable Server-order tables. Schema 7 marks at most one destination active and records the Server acknowledgement identifier. Schema 8 adds an enabled-by-default `send_to_server` flag to reusable catalogue items. Outbox states are `pending`, `sending`, `delivered` and `failed`; opening the database returns an interrupted `sending` row to `pending` because Server idempotency makes resending safe. Server order states remain only `received` and `done`.

Ticket finalisation and any eligible outbox creation share one SQLite transaction. The local ticket snapshot always keeps every selected line. A new envelope omits catalogue items whose flag is off; if no eligible lines remain, no outbox record is created. The outbox keeps its canonical immutable JSON and stable delivery identifier even if the catalogue changes or the local ticket is later deleted.

The Server private key, Server-side token hashes and Client access token use separate Android keystore-backed encrypted storage. Pairing codes exist only in memory for five minutes. Private keys, tokens and all networking tables remain outside configuration archives and full backups until Task 14. Full backups retain the catalogue flag. Existing schema 5, 6 and 7 portable snapshots remain restorable and default a missing flag to enabled.

## HTTPS endpoints and authentication

The Server listens on IPv4 TCP port 42837 only while LibreSlip is visible in Server mode. It displays each current local-network address and the uppercase SHA-256 fingerprint of its self-signed certificate. It stops on backgrounding, leaving Server mode or process termination. Version 0.13.0 provides no background service, discovery or remote-network relay.

`GET /v1/status` returns the protocol version, Server installation identifier, display name and certificate fingerprint. `POST /v1/pair` accepts a one-time code, client installation identifier, display name and 64-character client identity fingerprint. A successful request consumes the five-minute code and returns a random 256-bit access token. Only the token hash is retained. `POST /v1/orders` requires that token as a Bearer credential plus the matching client installation identifier in `X-LibreSlip-Client-Id`.

Requests must use JSON. Pairing bodies are limited to 4,096 bytes and order bodies to 65,536 bytes. Unsupported paths, invalid content, unauthorised credentials, mismatched identities, oversized bodies and conflicting idempotency keys are rejected without storing an order. Successful first receipt returns HTTP 201; an identical repeat returns HTTP 200 with the original Server order identifier and `duplicate: true`.

## Client certificate pinning and retry

Manual Client pairing accepts only an IPv4 loopback, link-local or RFC 1918 address and HTTPS port. The operator copies the fingerprint displayed by the Server. LibreSlip creates an HTTP client with no trusted roots, accepts the self-signed peer only when SHA-256 over its DER certificate exactly matches that fingerprint, and also requires the `/v1/status` identity to report the same fingerprint before sending the one-time code. Redirects are disabled. A general certificate bypass is never used.

After pairing, the Client sends the access token only to that pinned Server identity. A new delivery receives one foreground attempt after local printing. Pending records recovered at startup also receive one bounded attempt. Network, authentication, certificate, protocol and Server failures become Needs attention and require an explicit retry. The retry retains the client installation identifier, delivery identifier, immutable JSON and checksum. It never creates another local ticket or print attempt.
