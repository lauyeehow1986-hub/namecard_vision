import 'dart:typed_data';
import 'dart:ui';

import 'color_util.dart';
import 'style.dart';

/// A **verifiable** ASCII randomart skin — the OpenSSH "drunken bishop"
/// algorithm (as used by `VisualHostKey`) applied to the card fingerprint.
///
/// Unlike the decorative critter, this walks the FULL 256-bit digest: each of
/// the 32 bytes contributes four 2-bit moves (128 moves total), so every byte
/// affects the picture and two different cards almost always produce different
/// grids. That makes it a faithful fingerprint, so it belongs in the registry
/// and may be picked as a card's verification image.
///
/// The grid is a pure function ([asciiArt]) so it can be unit-tested on its own
/// and copied as text; [paint] just lays that text out as monospace art.
class RandomartStyle implements FingerprintStyle {
  const RandomartStyle();

  @override
  String get id => 'randomart.v1';

  @override
  String get label => 'Randomart';

  static const int _cols = 17;
  static const int _rows = 9;

  /// Symbols by visit count; index 15 = start ('S'), 16 = end ('E').
  static const String _symbols = r' .o+=*BOX@%&#/^SE';

  /// The framed ASCII randomart for a 32-byte [digest], as an 11-line,
  /// 19-column block (a 17x9 field inside a `+`/`-`/`|` border).
  static String asciiArt(Uint8List digest) {
    final field = List.generate(_rows, (_) => List<int>.filled(_cols, 0));
    var x = _cols ~/ 2; // 8
    var y = _rows ~/ 2; // 4
    final startX = x, startY = y;

    for (final byte in digest) {
      var b = byte;
      for (var i = 0; i < 4; i++) {
        final move = b & 0x3;
        // low bit: right if set else left; high bit: down if set else up.
        x = ((move & 0x1) != 0 ? x + 1 : x - 1).clamp(0, _cols - 1);
        y = ((move & 0x2) != 0 ? y + 1 : y - 1).clamp(0, _rows - 1);
        field[y][x] += 1;
        b >>= 2;
      }
    }

    final maxIdx = _symbols.length - 3; // last count symbol before S/E
    final sb = StringBuffer()..writeln('+${'-' * _cols}+');
    for (var r = 0; r < _rows; r++) {
      sb.write('|');
      for (var c = 0; c < _cols; c++) {
        if (r == startY && c == startX) {
          sb.write('S');
        } else if (r == y && c == x) {
          sb.write('E');
        } else {
          final v = field[r][c];
          sb.write(_symbols[v > maxIdx ? maxIdx : v]);
        }
      }
      sb.writeln('|');
    }
    sb.write('+${'-' * _cols}+');
    return sb.toString();
  }

  @override
  void paint(Canvas canvas, Size size, Uint8List digest) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.shortestSide * 0.06),
    );
    canvas.save();
    canvas.clipRRect(rrect);

    // Digest-seeded terminal palette: dark ground, one accent hue for the art
    // and a brighter hue for the S/E markers.
    final hue = digest[0] / 255 * 360;
    final markerHue = hue + 150;
    final bg = hsv(hue, 0.45, 0.08);
    final border = hsv(hue, 0.30, 0.55);
    final marker = hsv(markerHue, 0.65, 1.0);

    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    final lines = asciiArt(digest).split('\n');
    final rowCount = lines.length;
    final colCount = lines.first.length;
    final fontSize = size.shortestSide * 0.09;

    final builder = ParagraphBuilder(ParagraphStyle(
      fontFamily: 'RobotoMono',
      fontSize: fontSize,
      height: 1.15,
      textAlign: TextAlign.left,
    ));
    for (var r = 0; r < rowCount; r++) {
      final line = lines[r];
      for (var c = 0; c < line.length; c++) {
        final ch = line[c];
        final isBorder =
            r == 0 || r == rowCount - 1 || c == 0 || c == line.length - 1;
        Color color;
        if (ch == ' ') {
          color = const Color(0x00000000);
        } else if (isBorder) {
          color = border;
        } else if (ch == 'S' || ch == 'E') {
          color = marker;
        } else {
          // Brighten with visit density so busy cores glow.
          final idx = _symbols.indexOf(ch).clamp(0, 14);
          color = hsv(hue, 0.55, 0.5 + 0.5 * (idx / 14));
        }
        builder.pushStyle(TextStyle(color: color));
        builder.addText(ch);
        builder.pop();
      }
      if (r != rowCount - 1) builder.addText('\n');
    }
    final paragraph = builder.build()
      ..layout(ParagraphConstraints(width: fontSize * colCount * 1.2));

    final pad = size.shortestSide * 0.08;
    final availW = size.width - pad * 2;
    final availH = size.height - pad * 2;
    final contentW = paragraph.longestLine;
    final contentH = paragraph.height;
    final scale = _min(availW / contentW, availH / contentH);

    canvas.translate(
      (size.width - contentW * scale) / 2,
      (size.height - contentH * scale) / 2,
    );
    canvas.scale(scale);
    canvas.drawParagraph(paragraph, Offset.zero);
    canvas.restore();
  }

  static double _min(double a, double b) => a < b ? a : b;
}
