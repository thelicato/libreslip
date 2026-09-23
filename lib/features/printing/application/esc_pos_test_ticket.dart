import 'dart:typed_data';

abstract final class EscPosTestTicket {
  static Uint8List build() {
    final bytes = <int>[];

    void command(List<int> value) => bytes.addAll(value);
    void line(String value) {
      bytes
        ..addAll(_encodeCp858(value))
        ..add(0x0A);
    }

    command([0x1B, 0x40]); // Initialise.
    command([0x1B, 0x61, 0x01]); // Centre.
    command([0x1B, 0x45, 0x01]); // Bold on.
    command([0x1D, 0x21, 0x11]); // Double width and height.
    line('LIBRESLIP');
    command([0x1D, 0x21, 0x00]);
    command([0x1B, 0x45, 0x00]);
    line('CONNECTION TEST');
    line('TEST DI CONNESSIONE');
    line('');
    command([0x1B, 0x61, 0x00]); // Left.
    line('NETUM NT-1809DD');
    line('58 mm / Bluetooth SPP');
    line('--------------------------------');
    line('ASCII: 0123456789 ABC xyz');
    command([0x1B, 0x74, 0x13]); // PC858 on common ESC/POS firmware.
    line('Italiano: caffè, tè, più, così');
    line('Euro: €');
    line('--------------------------------');
    line('If every line is readable,');
    line('the connection test passed.');
    line('');
    line('No sale or payment was created.');
    command([0x1B, 0x64, 0x04]); // Feed four lines. Never cut.
    return Uint8List.fromList(bytes);
  }

  static List<int> _encodeCp858(String value) => [
    for (final rune in value.runes)
      switch (rune) {
        0x00E0 => 0x85,
        0x00E8 => 0x8A,
        0x00E9 => 0x82,
        0x00EC => 0x8D,
        0x00F2 => 0x95,
        0x00F9 => 0x97,
        0x00C0 => 0xB7,
        0x00C8 => 0xD4,
        0x00C9 => 0x90,
        0x00CC => 0xDE,
        0x00D2 => 0xE3,
        0x00D9 => 0xEB,
        0x20AC => 0xD5,
        >= 0x20 && <= 0x7E => rune,
        _ => 0x3F,
      },
  ];
}
