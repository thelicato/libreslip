# Client and server mode plan

## Product shape

LibreSlip will remain one Android application with two selectable modes:

| Mode | Responsibility |
| --- | --- |
| Client | The current catalogue, composition, local history and printing workflow. A configured server is an optional additional destination. The client remains fully usable when the server is absent or unreachable. |
| Server | A focused incoming-order board. It receives immutable order snapshots, shows received and completed orders, and lets the operator mark a received order as Done. It does not compose, edit, print or financially process orders. |

The first implementation target is communication between Android devices on the same local network. No hosted LibreSlip cloud, account, subscription or mandatory internet connection is planned. Remote operation should be treated as a later product decision because it changes deployment, security and support requirements.

## Non-negotiable behaviour

- Existing client operation, local storage and printing continue without a configured server.
- Printing remains local and requires a connected printer. Server availability never enables or blocks local printing.
- When a server is configured, finalising the existing Print ticket workflow saves one immutable ticket snapshot and creates one durable server-delivery record in the same local transaction. Delivery runs independently and cannot delay, roll back or duplicate local printing.
- An unavailable server leaves the delivery pending. The client may retry the same delivery identifier safely while the app is active or after an explicit Retry action.
- The server stores each delivery once, even if the acknowledgement is lost and the client sends it again.
- Server orders contain the saved heading, reference, notes, item names, quantities and creation time. They never contain prices, taxes, payments or financial totals.
- Marking an order Done changes only the server copy. It does not edit or delete the client ticket.
- Deleting a client ticket after confirmed delivery does not remotely delete the server order.
- Switching modes does not silently delete either client data or the server inbox.

## Proposed architecture

The networking feature should have its own domain, application, persistence and transport boundaries:

- features/networking/domain: mode, paired-server identity, protocol envelope and delivery states.
- features/networking/application: client outbox coordinator, retry policy, server inbox controller and mode switching.
- features/networking/data: SQLite repositories, secure secret storage, local-network discovery and the authenticated transport.
- features/networking/presentation: mode settings, server pairing, delivery status and the server order board.

Client delivery states should be pending, sending, delivered and failed. An interrupted sending record returns to pending because the server-side idempotency key makes resending safe. This differs from printer transmission, where an interrupted write remains uncertain and must never be retried automatically.

Server order states should be only received and done. The server must not edit item content or expose checkout, stock, reporting or other business-management functions.

## Protocol and identity

Use a small versioned protocol over HTTPS on the local network. The initial order envelope should include:

- protocol version;
- stable client installation identifier;
- stable delivery identifier;
- client ticket identifier and visible ticket number;
- source creation time in UTC;
- ticket heading, reference and order note;
- item snapshot names, quantities and preparation notes;
- payload checksum.

The server should enforce a unique constraint on the client installation and delivery identifiers. Repeating an accepted request returns the original acknowledgement without inserting another order.

Pairing should be explicit. The server creates an app-private identity and displays its address, certificate fingerprint and a short one-time pairing code. The client pins that identity after the operator confirms the code. Pairing secrets, private keys and trust tokens must use Android-backed secure storage and must never enter logs, configuration ZIPs or full backups. Restored devices pair again.

Manual address entry is the required fallback. Local discovery can be added after the protocol works reliably; mDNS would add multicast permission and lifecycle complexity. Local networking uses Android's internet permission even though traffic remains on the LAN, and the interface and privacy documentation explain that distinction.

## Client workflow

The current client interface remains the default. When no server is paired, it behaves exactly as it does now.

When a server is paired:

1. Print ticket validates the connected printer and finalises the immutable local ticket.
2. The same database transaction creates an outbox delivery for that ticket.
3. Local printing proceeds through the existing durable print-attempt path.
4. Server delivery proceeds independently with the same stable delivery identifier.
5. The ticket history shows delivery as Pending, Delivered or Needs attention, without mixing it with printer outcome.
6. Pending delivery can be retried explicitly. A bounded retry while the app is active may be added only after idempotency and interruption tests pass.

A server outage must not block catalogue editing, composition, local printing, history, PDF sharing, export or backup.

## Server workflow

Entering server mode replaces the client workspace navigation with a deliberately small interface:

- Received orders, newest first.
- Completed orders.
- Order detail showing source device label, ticket number, received time, original creation time, reference, items, quantities and notes.
- One primary Mark Done action.
- Settings for server name, pairing, connection address and mode switching.

The initial server should listen only while LibreSlip is open in server mode. Reliable background serving on Android requires a foreground service and persistent notification, so that should be a separate, explicit milestone rather than an implicit promise.

## Persistence and portability

Add versioned SQLite migrations for:

- app mode and non-secret server identity metadata;
- client server-delivery outbox;
- server paired clients;
- server received orders and immutable order lines.

The outbox creation must be transactional with ticket finalisation and unique per ticket and destination. Server receipt must store the full order and acknowledgement atomically.

Configuration export may include the selected mode and non-secret server preferences. Full backups should eventually include outbox and server inbox history, but exclude private keys, pairing codes, trust tokens, cached addresses and discovery state. Restoring requires fresh pairing.

## Delivery sequence

### Task 10: mode and protocol foundation

Implemented in LibreSlip 0.10.0 without enabling networking.

- Add Client and Server mode selection with confirmation and persistence.
- Define and test the versioned protocol, limits, checksums and idempotency identifiers.
- Add database migrations for outbox and inbox domains.
- Keep networking disabled and request no new permission until the transport milestone.

### Task 11: server inbox

Implemented in LibreSlip 0.11.0.

- Implement the foreground-only authenticated local HTTPS listener.
- Add explicit manual pairing and pinned server identity.
- Validate payload size, text length, quantities, timestamps and protocol version.
- Store received orders transactionally and idempotently.
- Build the responsive received/completed board and Mark Done action.

### Task 12: client delivery

Implemented in LibreSlip 0.12.0.

- Pair manually through a local IPv4 address, one-time code and exact SHA-256 certificate pin.
- Keep the access token in Android keystore-backed encrypted storage and out of archives.
- Create one stable outbox envelope transactionally when a paired client finalises a ticket.
- Prioritise local printing, then deliver without changing its outcome.
- Show Pending, Sending, Delivered and Needs attention independently from print status.
- Retry explicitly with the same delivery identifier and recover interrupted sending as pending after restart.

### Task 13: discovery, portability and hardening

- Evaluate mDNS discovery with manual address fallback.
- Extend full backups and validation for the new non-secret data.
- Test mode switching, multiple clients, duplicate delivery, malformed input, unauthorised devices, network changes, large queues, Italian text and Android process death.
- Decide separately whether foreground-service background hosting or remote-network support is justified.

## Acceptance criteria

- A client with no paired or reachable server retains every current offline capability.
- An unreachable server never blocks or rolls back printing.
- A lost acknowledgement and repeated delivery create one server order.
- Restarting either device preserves pending deliveries, received orders and Done state.
- The server exposes no item editing, printing, payments, prices or business reporting.
- Pairing secrets and order contents do not appear in logs or archives.
- Both modes work in British English and Italian on phone, landscape and tablet layouts.
- Automated tests cover protocol compatibility, database migrations, idempotency, interruption and malformed input before physical two-device testing.
