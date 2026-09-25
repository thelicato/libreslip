# Client and Server modes

LibreSlip is one Android application with two selectable modes.

| Mode | Purpose |
| --- | --- |
| Client | Manages the local catalogue, composition, printing, history, statistics and backups. A paired Server is an optional extra destination. |
| Server | Receives immutable order snapshots, shows Received and Completed queues and marks a received order Done. |

Switching modes requires confirmation and does not delete Client data or the Server inbox. Client mode remains fully usable without pairing, a reachable Server or internet access.

## Client operation

Print ticket first requires a connected local printer. Ticket finalisation stores one immutable local snapshot and one durable print attempt. If a Server is paired, the same SQLite transaction also creates one stable delivery envelope containing only items enabled for Server orders. An order containing only Local only items creates no delivery.

Local printing runs independently from Server delivery. A Server outage cannot delay, roll back or duplicate the local ticket or print attempt. Delivery states are Pending, Sending, Delivered and Needs attention. Explicit retry reuses the same delivery identifier and cannot create another local ticket or print attempt.

Deleting a local ticket does not remotely delete an order already accepted by the Server. Marking a Server order Done does not edit or delete the Client snapshot.

## Pairing

Both Android devices must be on a local network that permits device-to-device traffic. Server mode displays its IPv4 HTTPS addresses and SHA-256 certificate fingerprint. Allow client pairing opens a five-minute code. Client mode pairs through that address, exact fingerprint, code and a local device name.

The Client pins the self-signed Server certificate and disables redirects. A random access token authenticates later order delivery. The Client token, Server private key and Server token hashes use Android keystore-backed encrypted storage. Pairing secrets never enter logs, configuration ZIPs or full backups.

Manual IPv4 address entry is the supported connection method. The Server listens on TCP port 5119 only while LibreSlip is visible in Server mode. There is no background service, automatic discovery, hosted relay or remote-network mode.

## Server operation

The Orders tab contains Received and Completed filters, immutable order details and the Mark Done action. Its summary lists quantities still outstanding across Received orders. The Settings tab contains listener state, local addresses, certificate fingerprint, pairing controls, mode selection and the installed version.

Server orders preserve the Client ticket heading, reference, order note, item names, quantities, preparation notes and creation time. They contain no prices, taxes, payments or financial totals. Server mode has no catalogue editing, ticket composition, printing or reporting.

## Reliability and persistence

Ticket finalisation and eligible outbox creation are transactional. The Server stores receipt and acknowledgement atomically and enforces uniqueness on the Client installation and delivery identifiers. Repeating an accepted request returns the original acknowledgement rather than inserting another order.

An interrupted Client Sending row returns to Pending when the database opens because Server idempotency makes the same delivery safe to resend. This differs from printer transmission: an interrupted printer write remains Uncertain and is never sent again automatically.

Client outbox, paired destinations, paired Client records, Server orders and Done state use versioned SQLite tables. Networking tables and pairing secrets are outside the current archive format, so restoring a backup keeps the destination device's existing mode and networking state. Pair again after moving data to another device.
