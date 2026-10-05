# Validation evidence

## Unnamed order dividers, 5 October 2026

Validated step 7 with `VERSION` unchanged at 1.7.0.

| Area | Evidence |
| --- | --- |
| Formatting and analysis | All 100 Dart files passed formatting checks and `flutter analyze --no-pub` reported no issues. `VERSION` and `pubspec.lock` are unchanged. |
| Automated regression | All 192 active tests passed; the normal run skipped only opt-in render capture. Existing migration, optional printer, Server delivery, progress exchange and invalid or interrupted restore tests passed. |
| One-button composition | English and Italian tests covered standard tablet and doubled-text phone layouts, Compact Compose and landscape. Add divider opened no dialog, immediately created a visible boundary and placed later items below it without displaying a name. Repeated empty boundaries were prevented. New orders inherited no group inventory. |
| Persistence and printing | Fresh controllers recovered divider identities, active selection, quantities and notes after database reopen. Removing the latest boundary merged its items into the preceding section without losing content. Saved managed boundaries could not be removed during additions and earlier immutable revisions remained intact. ESC/POS content placed an unlabelled rule between sections; PDF generation passed. Interrupted printing recovered as Uncertain with the exact original payload. |
| Archives and Server receipt | Full backup restore retained divider metadata, active selection and line relationships. The existing envelope codec round-tripped the same content and checksum. Server storage retained the split and duplicate receipt left one order. Existing named snapshots and printed captions retained compatibility. No database, archive or protocol version changed. |
| Responsive and localised rendering | Seventy captures passed framework and missed-tap checks. Inspected full-width centred teal dividers in English tablet Compose, Italian Compact Compose, a 320-pixel Italian doubled-text layout, Italian Server cards, English Server details and the Italian ticket preview. Legacy captions wrap and the new unnamed sections show no stored ordinal tokens. |
| Android preview APK | Fresh 1.7.0 debug APK, build 1, uses `io.thelicato.libreslip`, minimum API 34 and target API 36. APK Signature Scheme v2 verified with the Android Debug development certificate. Flutter and Gradle APK outputs matched. This is an installable development-key preview. |
| Platform and hardware checks | No new physical-device installation, offline cold launch, Android process-death, permission-denial or physical printer verification was performed. Host database, widget and encoded checks do not establish device behaviour or paper output. |
| Compatibility | Order dividers remains optional and off by default. Existing named group content remains immutable and keeps its captions. Updated Servers show unnamed visual rules; older grouped-order Servers preserve section relationships but display automatic markers. Actual printing and optional printer readiness retain their existing behaviour. |

## Optional printer connection, 5 October 2026

Validated step 6 with `VERSION` unchanged at 1.7.0.

| Area | Evidence |
| --- | --- |
| Formatting and analysis | All 99 Dart files passed formatting checks and final `flutter analyze --no-pub` reported no issues. `VERSION` and `pubspec.lock` are unchanged. |
| Automated regression | All 189 active tests passed; the normal run skipped only opt-in render capture. Existing migrations, interrupted printing, progress exchange, archive rollback and restore recovery checks passed. |
| Printer requirement | First launch and preferences versions 1 through 7 require a printer. English and Italian widget workflows switched the setting off, saved managed orders and additions without print jobs, then restored the disconnected guard by switching it on. A device with no printer adapter also saved locally. Connected optional printing retained a transmitted attempt. The real switch remained reachable at 320 pixels with doubled Italian text. |
| Durable Server readiness | Real pinned loopback HTTPS accepted a printer-optional order after database reopen. A lost acknowledgement retried the original envelope and retained one Server order; optional additions updated that order without any print job. Repeated finalisation retained the original readiness policy in both directions. An optional later revision remained blocked behind an uncertain earlier print, then drained in order after explicit print and acknowledgement recovery. |
| Settings and archives | Settings format 8 round-tripped the disabled requirement and restored it across controller recreation, configuration replacement, full backup and fresh-install restore. Legacy archives restored the enabled default; malformed modern values failed preview without replacing current settings. Database schema 15, configuration document version 4 and network protocol formats are unchanged. Exported backups continue to exclude outbox rows and pairing secrets. |
| Responsive and localised rendering | Sixty-three captures passed framework and missed-tap checks. Inspected the English default-on Settings control, English tablet and landscape Save order actions, Italian Save additions and both 320-pixel doubled-text screens. The Settings explanation flows beneath the control so its length does not hide the switch; the composition action remains pinned. |
| Android preview APK | Fresh debug APK built as 1.7.0, build 1, `io.thelicato.libreslip`, minimum API 34 and target API 36. APK Signature Scheme v2 verified with the Android Debug development certificate. Flutter and Gradle APK outputs matched. This is an installable development-key preview. |
| Platform and hardware checks | No new physical-device installation, offline cold launch, Android process-death, permission-denial or physical printer verification was performed. Host persistence, TLS, widget and encoded checks do not establish physical-device behaviour or paper output. |
| Compatibility | Require printer connection is on by default. Disabling it affects new submissions; older Waiting for print rows retain their requirement and managed revisions retain acknowledgement ordering. Actual printing, reprinting and recovery require a connected printer. Optional connected printing is independent of Server delivery, so an optional order can reach the Server even if that print fails. |

## Optional product prices and estimates, 5 October 2026

Validated step 5 of optional order management with `VERSION` unchanged at 1.6.0.

| Area | Evidence |
| --- | --- |
| Formatting and analysis | Formatting passed for all 99 Dart files and final `flutter analyze --no-pub` reported no issues. `pubspec.lock` and `VERSION` are unchanged. |
| Automated regression | All 180 active tests passed; only opt-in render capture was skipped in the normal run. All 13 archive tests passed again after adding explicit priced-composition round-trip and priced interrupted-restore assertions. |
| Exact prices and immutable content | Covered absent versus zero, decimal input, malformed values, precision and currency bounds. Integer estimates kept currencies separate, counted unpriced quantities and calculated the maximum 200-line quantity inventory exactly. Catalogue edits left the persistent composition and saved revisions unchanged; additions captured new prices. Disabled defaults and disabling during composition preserved data and omitted new price snapshots. |
| Migration and printing recovery | Schema 14 migration retained immutable history, active orders and interrupted print bytes, recovering Sending as Uncertain while prices defaulted to absent. Legacy restore modernised managed inventories with absent prices. Priced and unpriced snapshots produced identical preparation-ticket ESC/POS bytes; Server envelopes contained no price fields or currency data. |
| Archives and rollback | Configuration and full-backup round trips preserved the price option, zero and maximum prices, priced composition and immutable order lines, including fresh-install restore. Legacy configurations defaulted to disabled prices. Invalid switches, currencies, mismatched nullable pairs, fractional or excessive minor units and inconsistent revision prices failed preview with current data intact. Failed and interrupted replacement retained priced snapshots; existing pending progress-operation recovery checks passed. |
| Responsive and localised rendering | Fifty-seven captures passed framework and missed-tap checks. Inspected English tablet and landscape estimates, a complete estimate with separate EUR and GBP totals, Italian phone and Compact Compose, both 320-pixel doubled-text price screens, the standard Italian editor and English ticket details. Price-editor and composition widget tests passed in English and Italian at tablet, landscape and doubled-text phone sizes. Helper and error text wrap and dialogs remain scrollable. |
| Android preview APK | Fresh debug APK built as 1.6.0, build 1, `io.thelicato.libreslip`, minimum API 34 and target API 36. APK Signature Scheme v2 verified with the Android Debug development certificate. Packaged Flutter and Gradle APK outputs matched. This is an installable development-key preview. |
| Platform and hardware checks | No new physical-device installation, offline cold launch, Android process-death, permission-denial or physical printer validation was performed. Host persistence and rendered checks do not establish device behaviour or paper output. |
| Compatibility and scope | Product prices and estimates is disabled by default and independent of courses and managed orders. Schema 15 accepts portable schemas 5 through 14; configuration document version 4 accepts versions 1, 2 and 3. Supported prices use EUR, GBP and USD with two fractional digits. Preparation printing, ticket PDFs and network protocol content retain their existing behaviour. No payments or financial recording were added. |

## Explicit paired delivery progress, 5 October 2026

Validated step 4b of optional order management with `VERSION` unchanged at 1.6.0.

| Area | Evidence |
| --- | --- |
| Formatting and analysis | Formatting passed for all 95 Dart files and `flutter analyze --no-pub` reported no issues. `pubspec.lock` and `VERSION` are unchanged. |
| Automated regression | All 166 active tests passed; the normal run skipped only opt-in render capture. The 33 targeted sync, dialog and archive tests also passed. Existing migrations, interrupted printing, Server delivery and restore checks passed in the full suite. |
| Explicit exchange and immutability | Pull, push, partial delivery, completion and undo preserved immutable ticket contents, revision numbers, print jobs and Local only counts. Shared additions waited for receipt. Original Server routing remained fixed; local orders and orders restored to a different installation retained offline operation. A newer Server content revision was rejected. |
| Conflict and interruption | Concurrent differences required explicit whole-shared-order Client or Server choice; cancellation retained edits and stale choices refreshed the conflict. Lost acknowledgement survived SQLite reopen and retried the same operation without overwriting later Server undo. New offline edits during recovery retained their generation and used a new operation when appropriate. Server revision races and conflicting nonce reuse were rejected atomically. |
| Migration, archives and rollback | Schema 13 migration retained progress and conservatively marked all legacy line identities edited. Schema 14 backups preserved zero-valued undo intent while excluding sync baselines and pending operations. Fresh-install restore and invalid edit metadata checks passed. Failed settings replacement and simulated interrupted restore recovered the exact pending operation from the private journal; invalid private recovery rolled back atomically. |
| Pinned HTTPS | Real loopback TLS tests verified authenticated progress, Client-scoped access and live board refresh. Older pinned Servers received no progress GET or POST; explicit retry after advertising support succeeded. No automatic progress networking was introduced. |
| Responsive and localised rendering | Forty-eight captures passed framework and missed-tap checks. Inspected English tablet sync and success, Italian phone conflict and unsupported-Server feedback, Italian 320-pixel doubled text and English landscape conflict choices. Actual Active orders dialog tests exercised sync, cancellation and resolution in English, Italian and large text. |
| Android preview APK | Fresh debug APK built as 1.6.0, build 1, `io.thelicato.libreslip`, minimum API 34 and target API 36. APK Signature Scheme v2 verified with the Android Debug development certificate. Flutter and Gradle APK outputs matched. This is an installable development-key preview. |
| Platform and hardware checks | No new physical-device installation, offline cold launch, permission-denial, Android process-death or printer test was performed. Host SQLite, TLS and widget checks do not establish physical-device behaviour or paper output. |
| Compatibility and scope | Optional managed orders remain disabled by default. Schema 14 accepts portable schemas 5 through 13; configuration document version 3 and order envelope versions 1, 2 and 3 remain unchanged. Progress protocol version 1 is optional and explicit. Prices and estimated totals remain step 5. |

## Optional per-item delivery on each device, 5 October 2026

Validated step 4a of optional order management with the unchanged LibreSlip `VERSION` value 1.6.0.

| Area | Evidence |
| --- | --- |
| Formatting and analysis | Dart formatting passed and `flutter analyze --no-pub` reported no issues. |
| Automated regression | All 142 active tests passed; only the opt-in render capture was skipped in the normal run. The 32 affected persistence, Server, composition and archive tests passed again after the final layout and restore checks. |
| Offline progress and snapshots | Partial delivery, whole-line delivery and undo survived database reopen. Editing delivery during additions preserved progress; new lines started at zero. Edits did not rewrite saved tickets, change their revision or queue networking. Retained active orders remained editable with the option disabled. Closed orders and invalid or stale quantity edits were rejected atomically. |
| Migration and Server completion | Schema 12 migration preserved earlier managed Done actions, including orders reopened by additions, and left local ticket history unchanged. Server preparation totals subtracted delivered quantities. The final unit completed the order; undo returned it to Received. Done filled all counts, Move to Received reset them, revisions and duplicate acknowledgements retained partial deliveries, and ordinary orders kept their original controls. |
| Archives and recovery | Full backup restore on a fresh installation preserved partial progress and continued additions locally. Schema 12 snapshots defaulted to zero progress. Unknown lines, missing maps and invalid quantity values were rejected before replacement. A malformed archive with recomputed checksums failed preview without changing progress. Failed settings replacement rolled back current delivery counts, and interrupted restore recovered the pre-import progress. |
| Responsive and localised rendering | Forty-two captures completed with framework and missed-tap checks. Inspected English tablet and landscape Client progress, Italian phone progress and the 320-pixel Italian dialog at doubled text, plus Italian phone and English tablet and landscape Server details. Scrolling retains reachable controls; per-line buttons wrap on narrow layouts. Both Client and Server widget tests exercised delivery and undo. |
| Android preview APK | Fresh debug APK built with version name 1.6.0, application identifier `io.thelicato.libreslip`, minimum API 34 and target API 36. APK Signature Scheme v2 verified with the Android Debug development certificate. This is a preview, not a production release. |
| Platform and hardware checks | No new device installation, offline cold launch, permission-denial, Android process-death or physical printer verification was performed. SQLite reopen and widget tests do not establish Android device behaviour or paper output. |
| Compatibility and scope | Delivery controls belong to the disabled-by-default managed-order workflow. Database schema 13 accepts portable schemas 5 through 12; configuration document version 3 and order envelope versions 1, 2 and 3 remain unchanged. Client and Server progress is explicitly local to each device. Paired progress synchronisation is step 4b; optional prices follow in step 5. |

## Optional active-order additions, 5 October 2026

Validated the third optional order management step with the unchanged LibreSlip `VERSION` value 1.6.0.

| Area | Evidence |
| --- | --- |
| Formatting and analysis | Dart formatting passed and final `flutter analyze --no-pub` reported no issues. `VERSION` and `pubspec.lock` are unchanged. |
| Automated regression | All 132 active tests passed; the normal run skipped only the opt-in render capture. Relevant delivery, composition, migration, restore and cleanup tests passed again after final recovery and lifecycle refinements. |
| Persistence and revisions | Covered schema 11 migration preserving grouped history and queued print bytes, disabled defaults, restart during additions, fixed original content, stable numbering and line identities, immutable full revision snapshots, idempotent finalisation, stale or closed additions and independent active-order state after history deletion. Closing an order without remaining history removes its current snapshot. |
| Printing recovery and counts | The additions document contains only the new lines and a revision label. ESC/POS bytes exclude earlier preparation notes. Interrupted additions printing preserves the exact payload and becomes Uncertain. Client item statistics count additions rather than every repeated full snapshot. Connected-printer guards and existing explicit recovery tests passed. |
| Real pinned HTTPS | Tested initial managed receipt, lost acknowledgement retry, an update to the same completed Server order, stable acknowledgements and new-line revision metadata. A later printed revision waited for an earlier uncertain print and lost acknowledgement; explicit recovery sent revisions in order. Older Servers supporting versions 1 or 2 received no unsupported order POST; retry after advertising support succeeded. |
| Server integrity | Covered one board entry per managed order, consecutive revisions, unchanged prior lines, stale and conflicting update rejection, duplicate older acknowledgements preserving completion, preparation totals excluding earlier completed lines and rejection of retries or additions after deletion. |
| Archives and rollback | Configuration and full backups round-trip the option and active-order state. A fresh-install restore recovered interrupted additions and continued them locally without rebuilding networking state. Invalid base revisions, missing addition references and malformed archive metadata were rejected before replacement or preview with current data intact. Existing interrupted restore, rollback and malicious archive checks passed. |
| Responsive and localised rendering | Thirty-five captures completed without framework errors. Inspected English tablet and landscape additions, Italian Compact Compose, the 320-pixel Italian active-order selector at doubled text, the Italian additions ticket with full-snapshot expansion, Italian Server cards and English tablet Server details. The additions print action stays pinned and longer dialogs scroll. |
| Android preview APK | Final debug APK built with version name 1.6.0, application identifier `io.thelicato.libreslip`, minimum API 34 and target API 36. APK Signature Scheme v2 verified with the Android Debug development certificate. This is a preview, not a production release. |
| Platform and hardware checks | No new device installation, offline cold launch, permission-denial, device process-death or physical printer verification was performed for this step. Database reopen tests and rendered or encoded output do not verify Android lifecycle behaviour or additions on paper. |
| Compatibility and scope | Keep orders open is disabled by default; existing ordinary and course-group workflows remain available. Database schema 12 and configuration document version 3 accept their supported legacy formats. Managed delivery requires a version 3 Server. This step adds items to active orders; editing submitted content, per-item delivery and prices remain outside this step. Client closing and Server Done remain separate. |

## Optional course groups, 5 October 2026

Validated the second optional order management step with the unchanged LibreSlip `VERSION` value 1.6.0.

| Area | Evidence |
| --- | --- |
| Formatting and analysis | Dart formatting passed and `flutter analyze --no-pub` reported no issues. |
| Automated regression | All 118 active tests passed; the opt-in capture test remained skipped in the normal run. The separate capture run passed. |
| Composition and persistence | Covered course creation, ordering, renaming, moving and removal, separate quantities and notes for the same product in different courses, restart recovery, saved snapshot preservation and disabling the option for subsequent orders. |
| Migration and printing recovery | Schema 10 fixtures migrated to schema 11 without changing ordinary tickets or queued print bytes. An interrupted grouped print retained its bytes and recovered as uncertain. Grouped ESC/POS section ordering and PDF generation passed automated checks. |
| Networking | Real pinned HTTPS tests covered grouped delivery, lost acknowledgements and idempotent receipt. An older Server received no grouped order POST; explicit retry after advertising support succeeded. Local-only group names were excluded from delivery while retained in the local snapshot. |
| Archives and restore | Configuration and full-backup round trips preserved the course option, inventories and line references, including restore on a fresh installation. Invalid course relationships were rejected both by the repository and during archive preview with valid recomputed checksums, leaving original data usable. Existing rollback and malicious archive tests passed. |
| Responsive and localised rendering | Twenty-eight render captures completed without framework errors. Inspected grouped standard and Compact Compose, Italian phone composition, the 320-pixel Italian course manager at doubled text, Italian ticket preview, Server phone cards and tablet details, plus the English tablet composition. Course headings, per-line selectors, management actions and notes remained readable. |
| Android preview APK | Fresh debug APK built with version name 1.6.0, application identifier `io.thelicato.libreslip`, minimum API 34 and target API 36. APK Signature Scheme v2 verified with the Android Debug development certificate. This is a preview, not a production release. |
| Platform and hardware checks | No new device installation, offline cold launch, permission-denial, process-death or physical printer verification was performed for this step. Existing historical hardware evidence below does not verify the new course headings on paper. |
| Compatibility and scope | Ungrouped composition remains the default and plain network envelopes retain version 1. Grouped envelopes require an updated Server supporting version 2. Database schema 11 and configuration document version 2 accept their supported older formats. Active order updates, per-item delivery and optional prices or totals remain planned. |

## Optional order titles, 5 October 2026

Validated the first optional order management step with the unchanged LibreSlip `VERSION` value 1.6.0.

| Check | Result |
| --- | --- |
| Formatting and analysis | Dart formatting check passed across application, tests and integration tests; `flutter analyze --no-pub` reported no issues. |
| Automated tests | All 106 active unit and widget tests passed. Normal runs skipped only opt-in render capture. Existing persistence, migrations, interrupted printing, HTTPS delivery and restore failure checks passed. Title assertions cover Client composition and history, Server details, disabling the field and full-backup restoration. |
| Responsive and localised rendering | Twenty render captures completed without framework errors. Inspected standard and Compact Compose, long Italian titles at 320 logical pixels with doubled text, landscape composition, ticket history and Italian ticket preview, and Server cards and details. Narrow or enlarged-text Compose places Reset below the title to preserve its width. |
| Android preview APK | Debug APK built with version name 1.6.0, application identifier `io.thelicato.libreslip`, minimum API 34 and target API 36. APK Signature Scheme v2 verified with the Android Debug development certificate. This is a preview, not a production release. |
| Platform and hardware checks | No new device installation, offline cold launch, permission-denial, process-death or physical printer verification was performed for this step. Existing historical hardware evidence below does not verify the revised printed title label. |
| Compatibility and scope | Titles reuse the existing reference field. Database, configuration, archive and network protocol formats remain unchanged. Course groups, active order updates, per-item delivery and optional prices or totals are planned, not implemented in this step. |

## Earlier baseline

Validated on 26 September 2026 for LibreSlip 1.5.0, Android application identifier `io.thelicato.libreslip`.

| Check | Result |
| --- | --- |
| Dart formatting | Passed across application, test and integration-test Dart sources. |
| Static analysis | Passed with no issues. |
| Unit and widget tests | All 106 active tests passed; the normal run skipped only opt-in preview capture. |
| Version display | Client and Server Settings both load the unchanged bundled `VERSION` value and show it at the end of the screen. |
| Port 5119 and migrations | Passed address normalisation, listener defaults, schema 9 port migration and schema 10 print-gated outbox migration. Unprinted rows remain blocked after restart. |
| Ticket and item persistence | Passed transactional composition recovery, immutable snapshots, visible-number reset, deletion, migration and duplicate-ticket protection. |
| Printing | Passed encoding, exact 25%, 50%, 75% and 100% logo raster widths, durable print states, disconnected printing gate, interruption recovery, remembered startup reconnect, 15-second connection monitoring, manual reconnect opt-out and reprint without creating another ticket. Physical Bluetooth printing completed previously on a NETUM NT-1809DD, but the four new logo sizes have not been checked on paper. A socket write still cannot prove paper output. |
| Client and Server HTTPS | Passed address-only loopback TLS pairing, explicit Server approval and rejection, first-contact certificate capture, retained SHA-256 pinning, mismatched-certificate rejection, authentication, item filtering, failed-print delivery blocking, automatic lost-acknowledgement resend and idempotent Server receipt. Server Done and move-back-to-Received states survive restart; Received orders reject deletion, while specific and bulk Completed deletion preserve unrelated orders. Lifecycle tests confirm that pausing the activity does not stop the listener service boundary. |
| Statistics | Passed all-history, empty and inclusive local date ranges. Totals use immutable saved-ticket snapshots and keep renamed item labels distinct. |
| Backup compatibility | Passed configuration and full-backup round trips, fresh-install restore, rollback and malicious archive checks for portable schema 10. Legacy portable schemas 5 through 9 remain accepted. Settings format 7 round-trips the printed-logo width; versions 1 through 6 migrate to 100%. Networking tables and pairing secrets are excluded. |
| Accessibility and localisation | Passed British English and Italian phone, landscape, tablet and doubled-text tests. The persisted 100%, 115% and 130% app text sizes compose with Android accessibility scaling. The live printer indicator remains usable in compact and wide Client headers. Compact Compose passes a 320 logical-pixel phone test with doubled text, zero-based item quantities, note-preserving increments and a pinned print action that remains in the viewport. |
| Representative renders | Eighteen previews completed without framework errors. Client pairing, the shared printer badge, paired Client, standard and zero-based Compact Compose, simplified Client and Server headers, Server orders with the outstanding summary first, Received and Completed tablet dialogs, Overview, item, ticket, Settings with the four-step printed-logo slider, portability and item-total screens were inspected. Actions, quantities and content widths remain aligned and readable. |
| Android platform integration | The latest connected-device run passed real DataStore, SQLite, secure identity and token storage, pinned loopback delivery, listener shutdown, restart recovery and archive exclusion. It was not repeated after the emulator was stopped. |
| Offline cold launch | A development-signed release passed clean offline cold launch on Android 14. This was not repeated after the emulator was stopped. |
| Release APK | Passed with a temporary development validation certificate. Verified version 1.5.0, application identifier `io.thelicato.libreslip`, minimum API 34, target API 36 and APK Signature Scheme v2. Flutter and Gradle outputs matched byte for byte. |
| Permissions and backup | The release requests `BLUETOOTH_CONNECT`, `INTERNET`, notification, foreground connected-device service, wake-lock, Wi-Fi-state and Android's app-local dynamic-receiver signature permissions. It requests no location or broad storage permission. Automatic cloud backup and device transfer are disabled. |

## Current limitations

- Server receipt between two separate physical Android devices on the same Wi-Fi network has not been recorded. Router client isolation and network changes can prevent local delivery.
- The Android foreground service and retained-engine lifecycle compile and have host lifecycle coverage, but locked-screen receipt has not yet been verified on a physical Android device. Force-stop, process termination or device restart stops reception until LibreSlip is opened in Server mode again.
- Server mode supports manual IPv4 address entry. There is no automatic discovery, boot start, hosted relay or remote-network support.
- Networking tables and pairing secrets are outside the archive format. Moving data to another device requires fresh pairing.
- Ordinary Server Received or Done state is not synchronised back to the Client. Managed orders support explicit delivery-count synchronisation; Client closure remains separate from Server completion. Deleting one or all Client tickets leaves durable delivery records and Server copies untouched; per-ticket delivery status is no longer available from history after the local ticket is deleted.
- The Android document picker and share sheet compile into the release and have automated cancellation and state coverage, but the latest validation did not repeat every platform-owned destination flow manually.
- USB printing is not implemented. The NETUM Classic SPP protocol does not provide battery percentage.
- Bluetooth Classic does not provide a universally reliable side-effect-free remote liveness probe. The 15-second monitor detects Bluetooth changes and socket failures, but some printer power or range losses may only appear after Android closes the socket or the next write fails.
- The GitHub release workflow has not been executed because no release tag was pushed and no repository signing secrets were changed.

Development-signed previews are not a production upgrade baseline. Keep the long-lived release keystore securely backed up and publish only from a tag matching `VERSION`.
