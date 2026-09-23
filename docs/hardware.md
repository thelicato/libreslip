# Hardware compatibility

## Required printer

The supplied [Amazon link](https://amzn.eu/d/0hYiM2dg) resolved on 19 September 2026 to [ASIN B0854CCF75](https://www.amazon.it/dp/B0854CCF75). Amazon returned an access challenge rather than the product details. The user subsequently confirmed that the product details identify the model as NT-1809DD.

The required device is the NETUM NT-1809DD 58 mm Portable Thermal Receipt Printer with Bluetooth 4.0 and USB, and the phone baseline is any Android 14 or later handset. NETUM's [NT-1809DD product specifications](https://www.netum.net/products/nt-1809dd-thermal-printer) document 58 mm paper, Bluetooth 4.0, ESC/POS-compatible commands, 203 DPI resolution and Android POS SPP support. Use Android Bluetooth Classic serial transport as the implementation baseline and verify it on the actual device. NETUM provides [receipt-printer software and SDK resources](https://support.netum.net/hc/en-us/articles/44800664000795--All-Models-Receipt-Printer-Software-Drivers) that explicitly include NT-1809DD.

## Implementation requirements

- Target Android 14 and later with Bluetooth Classic SPP as the first printer transport. Verify pairing and communication on the actual printer; do not choose a BLE-only plugin for this requirement.
- Separate ticket layout, ESC/POS encoding and transport. Include configurable paper width, printable dot width, margins, code page and raster fallback. Keep additional paper widths extensible without changing ticket logic.
- Support printer selection, connection feedback, permission denial, a test ticket, reconnect and explicit reprint. Preserve a durable print queue without automatically repeating a job whose physical outcome is unknown.
- Test Italian accented characters and punctuation. Render unsupported text as an image if the printer's verified code pages cannot represent it. Do not assume UTF-8 support.
- Send large images and tickets in bounded chunks appropriate to the verified device. Treat successful transmission separately from confirmed physical output when the hardware provides no acknowledgement.
- Do not send cash-drawer commands. Enable cutting only for profiles with verified cutter support; do not assume this portable printer has a cutter.
- Keep USB and network adapters extensible. Do not promise iOS Bluetooth compatibility without checking the exact printer protocol and platform support.

## Acceptance record

| Check | Status |
| --- | --- |
| Amazon identifier resolved | B0854CCF75 |
| Printer model | User confirmed NETUM NT-1809DD, 58 mm, Bluetooth 4.0 and USB |
| Firmware and self-test details | Not recorded during this milestone |
| Phone operating system | User confirmed Android 14 or later, no specific handset |
| Bluetooth profile and pairing | User reported successful Classic SPP pairing and connection on the physical printer |
| 58 mm layout, long names and Italian accents | User reported the task 4 physical ticket workflow worked; automated coverage verifies wrapping and raster fallback |
| Logo and long ticket | User reported the task 4 physical ticket workflow worked |
| Reconnect, printer off, paper out and interrupted transmission | Reconnect workflow was included in the successful user test; individual printer-off and paper-out observations were not separately recorded |
| Reprint without duplicate ticket | User reported success; automated storage tests also verify that reprint adds an attempt without adding a ticket |
| Final compatibility claim | Bluetooth Classic printing is confirmed by the user for the implemented NETUM NT-1809DD workflow; firmware details and separate fault-condition observations remain unrecorded |

The phone saves an order independently of printing and retains its ticket when printing is unavailable. The physical result above was reported by the user rather than independently observed by the developer. A transmitted state means the phone completed its write and still requires the operator to check the paper.
