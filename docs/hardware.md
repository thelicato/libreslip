# Hardware compatibility

## Supported printer

LibreSlip targets the NETUM NT-1809DD portable thermal printer with 58 mm paper, Bluetooth 4.0, USB, 203 DPI output and ESC/POS-compatible commands. Android Bluetooth Classic SPP is the implemented transport. USB printing is not implemented.

## Printing behaviour

- Pair the printer through Android before opening LibreSlip printer setup.
- LibreSlip lists bonded Bluetooth devices and requests `BLUETOOTH_CONNECT`. It does not scan and does not need location permission.
- Ticket layout, ESC/POS encoding and Bluetooth transport are separate components. The current profile uses a 384-dot printable width and 256-byte output chunks.
- Supported text uses the PC858 code page. Unsupported characters and configured logos are rasterised with bundled fonts.
- Test tickets and order tickets contain no cash-drawer or cutter commands.
- Print jobs are durable. Interrupted transmission becomes Uncertain and is never resent automatically.
- A completed socket write means Transmitted, not confirmed paper output. Check the physical ticket.

## Connection and battery

The Client header and Overview report whether LibreSlip's RFCOMM socket is connected and identify the selected bonded device. This is different from Android pairing: a paired printer can still be disconnected. LibreSlip remembers the last selected address, checks Bluetooth and socket state every 15 seconds while running and reconnects that bonded printer when possible. Manual Disconnect forgets it. These checks never send or repeat print data. Bluetooth Classic has no universally reliable side-effect-free remote liveness probe, so some power or range losses may only become visible when Android reports a closed socket or a write fails.

The NT-1809DD protocol documents printer, offline, error and paper-sensor replies but no battery-level reply. Android's public Bluetooth Classic API also exposes no portable battery percentage. LibreSlip therefore shows the printer's physical battery-indicator guidance instead of guessing a value.

## Compatibility evidence

| Check | Status |
| --- | --- |
| Bluetooth Classic pairing and connection | Confirmed on a physical NETUM NT-1809DD. |
| 58 mm order ticket | Confirmed on the physical printer. |
| Logo, long content and Italian text | Hands-on printing completed; automated tests also cover wrapping and raster fallback. |
| Reconnect and explicit reprint | Hands-on manual reconnect completed previously; automated tests cover remembered startup reconnect, periodic loss detection, recovery and manual opt-out. Storage tests verify that reprint adds an attempt without adding a ticket. |
| Printer off, paper out and interrupted transmission | Recovery states are implemented and automated interruption paths are covered; separate physical fault observations are not recorded. |
| Connection dashboard | Controller and widget tests cover the shared Client-header state, connected device, Bluetooth-off state, periodic refresh and state clearing. |
| Battery percentage | Unavailable through the documented NT-1809DD Classic SPP protocol. |

The phone saves a ticket independently of physical output and retains it when printing fails. A Transmitted state still requires a paper check.
