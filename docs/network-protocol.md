# Local order protocol

LibreSlip protocol version 1 defines the immutable order envelope used by the planned local client/server transport. Version 0.10.0 validates and persists the protocol foundations only. It does not open a network listener, pair devices or transmit orders.

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

## Persistence prepared in schema 6

Schema 6 adds a singleton mode and installation identity row, non-secret destination metadata, the client delivery outbox, paired-client metadata, immutable server orders and server order lines. Outbox states are `pending`, `sending`, `delivered` and `failed`; an interrupted `sending` row returns to `pending` on restart because server idempotency makes the retry safe. Server order states are only `received` and `done`.

The tables are empty in version 0.10.0 and no transport writes them. Pairing secrets and private keys are deliberately absent. Networking data is not yet included in configuration archives or full backups; that extension and its validation belong to Task 13. Existing schema 5 full-backup snapshots remain restorable because the portable order-table inventory is unchanged.
