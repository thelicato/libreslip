import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../domain/ticket_document.dart';
import '../domain/ticket_typography.dart';

class TicketPrinterProfile {
  const TicketPrinterProfile({
    this.widthDots = 384,
    this.charactersPerLine = 32,
    this.codePage = 19,
    this.dpi = 203,
  });

  final int widthDots;
  final int charactersPerLine;
  final int codePage;
  final int dpi;
}

class EscPosTicketEncoder {
  const EscPosTicketEncoder({this.profile = const TicketPrinterProfile()});

  final TicketPrinterProfile profile;

  Future<Uint8List> encode(TicketDocument document) async {
    final output = BytesBuilder(copy: false);
    void command(List<int> bytes) => output.add(bytes);

    command([0x1B, 0x40]);
    command([0x1B, 0x74, profile.codePage]);

    final typography = document.typography;
    final logoPath = document.logoPath;
    if (logoPath != null) {
      final raster = await _logoRaster(logoPath);
      if (raster.isNotEmpty) {
        command([0x1B, 0x61, 0x01]);
        command(raster);
      }
    }

    await _writeStyled(
      output,
      document.heading,
      align: TextAlign.center,
      bold: true,
      doubleSize: true,
      fontSize: typography.heading,
      nativeFontSize: TicketTypography.defaultHeading,
    );
    await _writeStyled(
      output,
      '${document.ticketLabel} #${document.ticketNumber}',
      align: TextAlign.center,
      bold: true,
      fontSize: typography.details,
      nativeFontSize: TicketTypography.defaultDetails,
    );
    await _writeStyled(
      output,
      document.createdAt,
      align: TextAlign.center,
      fontSize: typography.details,
      nativeFontSize: TicketTypography.defaultDetails,
    );
    _line(output, '');
    if (document.reference.isNotEmpty) {
      await _writeStyled(
        output,
        '${document.referenceLabel}: ${document.reference}',
        bold: true,
        fontSize: typography.details,
        nativeFontSize: TicketTypography.defaultDetails,
      );
    }
    _line(output, '-' * profile.charactersPerLine);

    for (final line in document.lines) {
      await _writeStyled(
        output,
        '${line.quantity} x ${line.name}',
        bold: true,
        fontSize: typography.items,
        nativeFontSize: TicketTypography.defaultItems,
      );
      if (line.note.isNotEmpty) {
        await _writeStyled(
          output,
          '${document.lineNotePrefix}: ${line.note}',
          fontSize: typography.notes,
          nativeFontSize: TicketTypography.defaultNotes,
        );
      }
    }

    if (document.orderNote.isNotEmpty) {
      _line(output, '-' * profile.charactersPerLine);
      await _writeStyled(
        output,
        document.orderNotesLabel,
        bold: true,
        fontSize: typography.notes,
        nativeFontSize: TicketTypography.defaultNotes,
      );
      await _writeStyled(
        output,
        document.orderNote,
        fontSize: typography.notes,
        nativeFontSize: TicketTypography.defaultNotes,
      );
    }
    if (document.footer.isNotEmpty) {
      _line(output, '-' * profile.charactersPerLine);
      await _writeStyled(
        output,
        document.footer,
        align: TextAlign.center,
        fontSize: typography.footer,
        nativeFontSize: TicketTypography.defaultFooter,
      );
    }
    command([0x1B, 0x61, 0x00]);
    command([0x1B, 0x45, 0x00]);
    command([0x1D, 0x21, 0x00]);
    command([0x1B, 0x64, 0x04]);
    return output.takeBytes();
  }

  Future<void> _writeStyled(
    BytesBuilder output,
    String text, {
    TextAlign align = TextAlign.left,
    bool bold = false,
    bool doubleSize = false,
    required int fontSize,
    required int nativeFontSize,
  }) async {
    if (text.isEmpty) return;
    final alignment = switch (align) {
      TextAlign.center => 1,
      TextAlign.right => 2,
      _ => 0,
    };
    output.add([0x1B, 0x61, alignment]);
    output.add([0x1B, 0x45, bold ? 1 : 0]);
    output.add([0x1D, 0x21, doubleSize ? 0x11 : 0x00]);

    if (fontSize == nativeFontSize && _canEncode(text)) {
      final width = doubleSize
          ? profile.charactersPerLine ~/ 2
          : profile.charactersPerLine;
      for (final line in _wrap(text, width)) {
        _line(output, line);
      }
      return;
    }

    output.add([0x1B, 0x45, 0x00]);
    output.add([0x1D, 0x21, 0x00]);
    output.add(
      await _textRaster(text, align: align, bold: bold, fontSize: fontSize),
    );
  }

  void _line(BytesBuilder output, String text) {
    output
      ..add(_encodeCp858(text))
      ..addByte(0x0A);
  }

  Future<List<int>> _logoRaster(String path) async {
    try {
      final decoded = img.decodeImage(await File(path).readAsBytes());
      if (decoded == null) return const [];
      final targetWidth = decoded.width > profile.widthDots
          ? profile.widthDots
          : decoded.width;
      final resized = img.copyResize(
        decoded,
        width: targetWidth,
        interpolation: img.Interpolation.average,
      );
      return _rasterCommand(resized.width, resized.height, (x, y) {
        final pixel = resized.getPixel(x, y);
        final luminance =
            (pixel.r.toDouble() * 299 +
                pixel.g.toDouble() * 587 +
                pixel.b.toDouble() * 114) /
            1000;
        return pixel.a.toDouble() > 32 && luminance < 165;
      });
    } catch (_) {
      return const [];
    }
  }

  Future<List<int>> _textRaster(
    String text, {
    required TextAlign align,
    required bool bold,
    required int fontSize,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black,
          fontFamily: 'RobotoTicket',
          fontSize: fontSize * profile.dpi / 72,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          height: 1.2,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: profile.widthDots.toDouble() - 8);
    final height = painter.height.ceil() + 8;
    painter.paint(canvas, const Offset(4, 4));
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(profile.widthDots, height);
    final data = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
    rendered.dispose();
    picture.dispose();
    final bytes = data!.buffer.asUint8List();
    return _rasterCommand(profile.widthDots, height, (x, y) {
      final offset = (y * profile.widthDots + x) * 4;
      final alpha = bytes[offset + 3];
      final luminance =
          (bytes[offset] * 299 +
              bytes[offset + 1] * 587 +
              bytes[offset + 2] * 114) /
          1000;
      return alpha > 32 && luminance < 165;
    });
  }

  List<int> _rasterCommand(
    int width,
    int height,
    bool Function(int x, int y) isBlack,
  ) {
    final widthBytes = (width + 7) ~/ 8;
    final bytes = <int>[
      0x1D,
      0x76,
      0x30,
      0x00,
      widthBytes & 0xFF,
      widthBytes >> 8,
      height & 0xFF,
      height >> 8,
    ];
    for (var y = 0; y < height; y++) {
      for (var byteIndex = 0; byteIndex < widthBytes; byteIndex++) {
        var value = 0;
        for (var bit = 0; bit < 8; bit++) {
          final x = byteIndex * 8 + bit;
          if (x < width && isBlack(x, y)) value |= 0x80 >> bit;
        }
        bytes.add(value);
      }
    }
    return bytes;
  }

  static List<String> _wrap(String value, int width) {
    final result = <String>[];
    for (final paragraph in value.split('\n')) {
      final words = paragraph.trim().split(RegExp(r'\s+'));
      var line = '';
      for (final word in words) {
        if (word.isEmpty) continue;
        final candidate = line.isEmpty ? word : '$line $word';
        if (candidate.runes.length <= width) {
          line = candidate;
          continue;
        }
        if (line.isNotEmpty) result.add(line);
        final runes = word.runes.toList();
        var offset = 0;
        while (offset + width < runes.length) {
          result.add(
            String.fromCharCodes(runes.sublist(offset, offset + width)),
          );
          offset += width;
        }
        line = String.fromCharCodes(runes.sublist(offset));
      }
      result.add(line);
    }
    return result;
  }

  static bool _canEncode(String value) =>
      value.runes.every((rune) => _cp858[rune] != null);

  static Uint8List _encodeCp858(String value) => Uint8List.fromList([
    for (final rune in value.runes) _cp858[rune] ?? 0x3F,
  ]);

  static final Map<int, int> _cp858 = {
    for (var value = 0x20; value <= 0x7E; value++) value: value,
    0x00E0: 0x85,
    0x00E8: 0x8A,
    0x00E9: 0x82,
    0x00EC: 0x8D,
    0x00F2: 0x95,
    0x00F9: 0x97,
    0x00C0: 0xB7,
    0x00C8: 0xD4,
    0x00C9: 0x90,
    0x00CC: 0xDE,
    0x00D2: 0xE3,
    0x00D9: 0xEB,
    0x00A3: 0x9C,
    0x00B0: 0xF8,
    0x00B7: 0xFA,
    0x00D7: 0x9E,
    0x20AC: 0xD5,
    0x000A: 0x0A,
  };
}
