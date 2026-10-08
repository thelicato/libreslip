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
- Compose tickets with quantities, preparation notes, order notes and an optional order title or table name. Titles appear prominently in Compose, ticket history and the Server board, alongside the order number. The print action stays on screen, and optional Compact Compose shows every reusable item in one order card with a quantity starting at 0.
- Recover the current order after closing or restarting LibreSlip.
- Optionally separate items with unnamed visual dividers in Compose, Server orders, ticket previews, printed tickets and PDFs.
- Optionally keep orders open, share them across Clients paired with the same Server, add items later and print labelled additions while retaining every saved revision. Track and synchronise delivered quantities within each divider, or enable Complete whole steps for one completion button per step.
- Print to the NETUM NT-1809DD through Bluetooth Classic SPP, with a ticket logo sized to 25%, 50%, 75% or 100% of the printable width.
- Reprint or share a ticket as a PDF without creating a second order.
- Browse immutable ticket history and delete individual tickets or clear the history when needed.
- Review ticket counts, total quantities and per-item totals for any date range.
- Switch instantly between British English and Italian, choose light, dark or system appearance and increase the app text size.
- Export configuration ZIPs or complete local backups with validated, recoverable restore.

## Client mode

Client mode is the everyday workspace. Add catalogue items, compose an order, connect the printer and print. **Require printer connection** in Client Settings is on by default, keeping this workflow. Turn it off to use **Save order** or **Save additions** when disconnected, retaining immutable history and sending eligible items to a paired Server without a print attempt. With a connected printer, the normal print action remains available. Printing and reprinting still require a connection.

A paired LibreSlip Server is optional. If it becomes unavailable, local composition, printing, history, PDF sharing and backups continue normally. Items marked Local only remain on the printed ticket but are not included in the Server copy.

Pair with several Servers in Client Settings to keep them available together. The most recently paired Server becomes the destination for new orders; select another with **Use for new orders** or the **Order destination** selector in Compose. Each order goes to its selected Server, and additions and delivery progress keep that original destination. All connected Servers continue to deliver and, with Keep orders open enabled, sync their shared orders independently. Unpairing one Server retains its queued work and leaves the others connected.

Use **Order title / table** in Compose to name an order, for example Table 4 or Garden. Leave it blank to use the order number alone, or disable the field in Client Settings under Order fields. Existing table references serve as titles and keep their content. Saved titles remain visible even when the field is disabled for new tickets.

Enable **Order dividers** in Client Settings under Order fields. Add the first items, then tap **Add divider** in the order summary. The next selected items go below a teal separator, with no name to enter. Use the arrow controls on a selected item to move it above or below a divider; **Remove last divider** joins the last two sections without changing quantities or notes. In Compact Compose, catalogue quantities apply below the latest divider and the summary shows all sections. Each new order starts without dividers.

Order dividers are off by default. Disabling them preserves the current composition and saved tickets. Existing named groups retain their saved captions. Updated Servers show the same visual separators; older grouped-order Servers preserve the split but show its automatic marker. Preparation tickets and PDFs use an unlabelled rule between sections.

Enable **Keep orders open** under Order fields to retain new orders for later additions. After printing or saving, choose **Active orders** in Compose, select an order and add drinks or other catalogue items. Finish the current composition before selecting another order. **Print additions** saves a new full-order revision and prints only the new items, with the original order number and a revision label. Ticket details retain the complete snapshot and explicit reprint recovery. Previously submitted content stays fixed. Cancel additions discards only the current additions; Close order ends further additions without deleting history or marking the Server order Done. Existing active orders remain available after disabling the option.

Managed Server delivery requires an updated Server and sends revisions in order. Each newly saved revision waits for local printing when Require printer connection is on, or is ready immediately when it is off. Changing the toggle does not release older orders waiting for print recovery; later revisions still wait for earlier acknowledgements. Optional orders can reach the Server even if an attempted print fails. The Server keeps one order, highlights additions and returns it to Received when needed, preserving which earlier revision was completed. Active orders started unpaired stay local; moving a backup to a different phone keeps those orders available locally. Pending managed deliveries retain their history tickets for recovery. The [optional order-management steps](docs/order-management-plan.md) also include local price estimates.

In **Active orders**, expand **Delivery progress** to deliver individual units, mark a whole line delivered or undo. Delivered and outstanding items are separated within each divider, and new additions start outstanding. These edits work offline and never print or change saved tickets. A fully delivered order stays open for additions.

With **Keep orders open** enabled and an updated Server paired, every paired Client receives the same managed orders automatically while its app is in the foreground. Any Client can add catalogue items or update deliveries. Refresh runs every five seconds and after local changes, with a manual refresh in Active orders. Concurrent additions are combined by stable item identifiers; delivery edits to different items merge, while conflicting edits to the same item require an explicit Client or Server choice. Offline changes remain durable and retry after reconnection. Printer-gated additions stay private until their existing print requirement is satisfied. Other Clients' items appear as saved order content without importing their catalogue, prices, ticket history or print jobs. Local only items and prices stay on their original phone.

**Close order** hides a shared order on this Client only; other Clients can still update it and the Server is not marked Done. Turning off Keep orders open pauses automatic sharing and leaves cached orders and offline edits available. Unpaired Clients retain the original offline workflow. Older Servers keep the earlier explicit **Sync progress** action for the originating Client and must be updated for shared editing.

In Client Settings, **Product prices and estimates** enables optional unit prices in the item editor and estimates in Compose, Active orders and ticket details. It is off by default. Each price uses EUR, GBP or USD, with up to two decimal places. Blank means no price; zero is retained as a price. Different currencies have separate subtotals and missing prices are clearly flagged. Estimates include all ordered quantities, including delivered items. Prices are captured when items are first added to the composition; catalogue edits affect later selections and additions. Remove and re-add an editable line to use its current catalogue price. Saved snapshots retain their original prices. Disabling the option hides prices and preserves existing data, while new tickets and additions omit price snapshots. Prices stay local and are excluded from Server delivery, preparation printing and ticket PDFs.

## Server mode

Server mode turns another Android device into a focused preparation board:

- **Orders** puts the item totals still waiting to be prepared above the Received and Completed lists, followed by order details. Managed orders show delivery progress by item or step. Completed orders can be restored to Received or deleted individually or together.
- **Settings** shows connection addresses, pending Client requests, listener status, whole-step completion, language, appearance and app version.

For managed orders, details let you deliver individual quantities, or complete and reopen whole steps when enabled in Settings. Preparation totals count only the first unfinished section of each managed order, advancing when it is delivered. Delivering the last unit moves the order to Completed; undoing any unit returns it to Received. Done delivers all items, while Undo Done resets every delivered quantity. Ordinary orders keep their Received/Done controls. Clients using shared managed orders receive these counts automatically; older Servers retain explicit synchronisation.

Server mode receives orders, tracks preparation delivery, moves orders between Received and Completed, and removes Completed history when requested. It does not edit the catalogue, compose or print tickets, process payments or produce financial reports. An Android foreground service keeps HTTPS port 5119 available while the screen is locked or LibreSlip is in the background. Switching to Client mode stops the receiver. Android shows an ongoing notification while this service is active, and the CPU and Wi-Fi locks may increase battery use.

## Printing

Pair the NETUM NT-1809DD in Android, then open LibreSlip Settings to select and connect it. Client Settings also lets you choose whether the ticket logo uses 25%, 50%, 75% or 100% of the 58 mm printable width. LibreSlip remembers the selected printer, reconnects it when possible on a later launch and checks the connection every 15 seconds while running. The current state is visible throughout Client mode. Manual Disconnect forgets the selection.

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
- [Optional order management roadmap](docs/order-management-plan.md)

Development, testing, signing and release instructions are kept in [docs/development.md](docs/development.md).
