<h1 align="center">
  <img src="logo.svg" alt="LibreSlip" width="160">
</h1>

<p align="center">
  <a href="https://github.com/thelicato/libreslip/releases">
    <img alt="Latest release" src="https://img.shields.io/github/v/release/thelicato/libreslip">
  </a>
  <img alt="Android 14 or later" src="https://img.shields.io/badge/Android-14%2B-3DDC84?logo=android&logoColor=white">
  <img alt="British English and Italian" src="https://img.shields.io/badge/languages-English%20%7C%20Italian-0F766E">
</p>

<p align="center">
  <strong>LibreSlip is a fast, private order-ticket app for Android.</strong><br>
  Build an order, print a clear preparation ticket and keep everything safely on the phone.
</p>

## Overview

LibreSlip keeps order preparation simple. Choose reusable items, adjust quantities, add the details the kitchen or preparation area needs, then print a clean 58 mm ticket without prices or payment information.

There is no account, subscription or required cloud service. The catalogue, current order, ticket history, settings and backups stay under your control. Client mode works offline, while optional Server mode can send immutable order copies to another LibreSlip device on the same local network.

## Highlights

- Create a reusable catalogue with categories, search and optional item images.
- Compose tickets with quantities, preparation notes, order notes and an optional table or order reference.
- Recover the current order after closing or restarting LibreSlip.
- Print to the NETUM NT-1809DD through Bluetooth Classic SPP.
- Reprint or share a ticket as a PDF without creating a second order.
- Browse immutable ticket history and delete individual tickets or clear the history when needed.
- Review ticket counts, total quantities and per-item totals for any date range.
- Switch instantly between British English and Italian, plus light, dark or system appearance.
- Export configuration ZIPs or complete local backups with validated, recoverable restore.

## Client mode

Client mode is the everyday workspace. Add catalogue items, compose an order, connect the printer and print. A connected printer is required before LibreSlip saves a new ticket through Print ticket or starts an explicit reprint.

A paired LibreSlip Server is optional. If it becomes unavailable, local composition, printing, history, PDF sharing and backups continue normally. Items marked Local only remain on the printed ticket but are not included in the Server copy.

## Server mode

Server mode turns another Android device into a focused preparation board:

- **Orders** shows Received and Completed orders, immutable order details and the quantities still waiting to be prepared.
- **Settings** shows connection addresses, pending Client requests, listener status, language, appearance and app version.

Mark Done is the only order action. Server mode does not edit the catalogue, compose or print tickets, process payments or produce financial reports. It listens on HTTPS port 5119 only while LibreSlip remains open in Server mode.

## Printing

Pair the NETUM NT-1809DD in Android, then open LibreSlip Settings to select and connect it. Overview shows LibreSlip's current printer connection state.

A Transmitted result means Android finished writing the ticket bytes. Check the paper before continuing because the printer does not confirm physical output. LibreSlip never automatically repeats a print whose outcome might be uncertain.

The NT-1809DD Bluetooth protocol does not provide a reliable battery percentage. When no percentage is available, use the printer's physical battery indicator.

## Privacy and backups

LibreSlip stores settings, catalogue items, the current order, ticket history, print jobs and images in app-private storage. It includes no analytics, background uploads or remote fonts. Automatic Android cloud backup and device transfer are disabled.

Optional Client and Server traffic stays on the configured local network and uses pinned HTTPS authentication. Pairing tokens, private keys and Bluetooth credentials are excluded from exports and backups.

Exported backups can contain private ticket content. Keep backup ZIPs somewhere secure.

## Requirements

- Android 14 or later.
- NETUM NT-1809DD for direct Bluetooth printing.
- Bluetooth permission for printer connection.
- Local-network access only when using the optional Client and Server workflow.

USB printing is not currently available.

## Install and update

Download the current APK from [GitHub Releases](https://github.com/thelicato/libreslip/releases). Android only accepts an update signed with the same certificate as the installed copy, so install releases from the same trusted source.

The installed version appears at the bottom of Settings in both Client and Server modes.

## Guides and reference

- [Hardware compatibility](docs/hardware.md)
- [Client and Server modes](docs/client-server-plan.md)
- [Privacy, validation and current limitations](docs/validation.md)
- [Archive and backup format](docs/archive-format.md)
- [Local order protocol](docs/network-protocol.md)

Development, testing, signing and release instructions are kept in [docs/development.md](docs/development.md).
