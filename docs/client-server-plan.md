# Client and Server modes

LibreSlip is one Android application with two selectable modes.

| Mode | Purpose |
| --- | --- |
| Client | Manages the local catalogue, composition, printing, history, statistics and backups. A paired Server is an optional extra destination. |
| Server | Receives immutable order snapshots, shows Received and Completed queues and marks a received order Done. |

Switching modes requires confirmation and does not delete Client data or the Server inbox. Client mode remains fully usable without pairing, a reachable Server or internet access.

## Client operation

Print ticket first requires a connected local printer. Ticket finalisation stores one immutable local snapshot and one durable print attempt. If a Server is paired, the same SQLite transaction also creates one stable delivery envelope containing only items enabled for Server orders. An order containing only Local only items creates no delivery.

Local printing runs independently from Server delivery. A Server outage cannot delay, roll back or duplicate the local ticket or print attempt. Delivery states are Pending, Sending, Delivered and Needs attention. Transient network or Server failures retry automatically every ten seconds while the Client process is available and again after restart. Automatic and explicit retries reuse the same delivery identifier and cannot create another local ticket or print attempt.

Deleting a local ticket does not remotely delete an order already accepted by the Server. Marking a Server order Done does not edit or delete the Client snapshot.

## Pairing

Both Android devices must be on a local network that permits device-to-device traffic. Client mode needs only the Server IPv4 address and port. The Server displays each pending request with its source address and must explicitly accept it within two minutes. Rejection, timeout or leaving Server mode fails the request without pairing.

On first contact, the Client captures the self-signed Server certificate fingerprint from the TLS connection and verifies that `/v1/status` reports the same identity. The pairing request and all later traffic use that pin with redirects disabled. A random access token authenticates later order delivery. The Client token, Server private key and Server token hashes use Android keystore-backed encrypted storage and never enter logs, configuration ZIPs or full backups. First-contact trust avoids manual fingerprint entry but cannot independently defeat an active local-network interception during that first request, so accept only an expected request on a trusted LAN.

Manual IPv4 address entry is the supported connection method. An Android foreground service, CPU wake lock and Wi-Fi lock keep TCP port 5119 available while the screen is locked or LibreSlip is in the background. Switching to Client mode stops the receiver. Force-stopping LibreSlip, restarting the device or terminating its process stops reception until Server mode is opened again. There is no automatic discovery, hosted relay or remote-network mode.

## Server operation

The Orders tab lists oldest orders first. Each constrained card includes item quantities and preparation notes, while the larger detail dialog contains the immutable order details and Mark Done action. Origin device names are not displayed. The summary lists quantities still outstanding across Received orders. Settings contains listener state, local addresses, pending Client approval, mode selection, language, appearance, app text size and the installed version.

Server orders preserve the Client ticket heading, reference, order note, item names, quantities, preparation notes and creation time. They contain no prices, taxes, payments or financial totals. Server mode has no catalogue editing, ticket composition, printing or reporting.

## Reliability and persistence

Ticket finalisation and eligible outbox creation are transactional. The Server stores receipt and acknowledgement atomically and enforces uniqueness on the Client installation and delivery identifiers. Repeating an accepted request returns the original acknowledgement rather than inserting another order.

An interrupted Client Sending row returns to Pending when the database opens because Server idempotency makes the same delivery safe to resend. This differs from printer transmission: an interrupted printer write remains Uncertain and is never sent again automatically.

Client outbox, paired destinations, paired Client records, Server orders and Done state use versioned SQLite tables. Networking tables and pairing secrets are outside the current archive format, so restoring a backup keeps the destination device's existing mode and networking state. Pair again after moving data to another device.
