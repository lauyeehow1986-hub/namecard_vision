import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'color_util.dart';
import 'digest_random.dart';
import 'style.dart';

/// A mirror-symmetric identicon skin: a tiled grid of shapes whose left half is
/// drawn from the digest and reflected to the right, over a digest-seeded
/// gradient, with a single rotated-polygon accent on top. Every cell's fill,
/// shape and colour comes from [DigestRandom], so the picture encodes the full
/// 256-bit digest and stays a faithful, deterministic fingerprint.
class GeometricStyle implements FingerprintStyle {
  const GeometricStyle();

  @override
  String get id => 'geometric.v1';

  @override
  String get label => 'Geometric';

  @override
  void paint(Canvas canvas, Size size, Uint8List digest) {
    final rnd = DigestRandom(digest);

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.shortestSide * 0.06),
    );
    canvas.save();
    canvas.clipRRect(rrect);

    final baseHue = rnd.range(0, 360);
    final dark = rnd.chance(0.5);
    _paintBackground(canvas, size, baseHue, dark);

    // Cell colours: a small harmonious palette pulled from the digest.
    final palette = <Color>[
      hsv(baseHue, 0.70, dark ? 0.95 : 0.80),
      hsv(baseHue + rnd.range(25, 55), 0.68, dark ? 0.90 : 0.72),
      hsv(baseHue + rnd.range(160, 200), 0.66, dark ? 0.92 : 0.74),
      hsv(baseHue + rnd.range(90, 130), 0.64, dark ? 0.88 : 0.70),
    ];

    // A grid mirrored across the vertical centre. Odd column count so the
    // centre column is its own axis; only the left half (incl. centre) is
    // decided from the digest, the right half reflects it.
    const cols = 5;
    const rows = 6;
    final pad = size.shortestSide * 0.10;
    final grid = Rect.fromLTRB(
      pad,
      pad,
      size.width - pad,
      size.height - pad,
    );
    final cw = grid.width / cols;
    final ch = grid.height / rows;
    final half = (cols / 2).ceil(); // includes centre column

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < half; c++) {
        final filled = rnd.chance(0.55);
        final shape = rnd.nextInt(3); // 0 square, 1 disc, 2 triangle
        final color = palette[rnd.nextInt(palette.length)];
        if (!filled) continue;
        _cell(canvas, _cellRect(grid, cw, ch, c, r), shape, color, rnd);
        final mirror = cols - 1 - c;
        if (mirror != c) {
          _cell(canvas, _cellRect(grid, cw, ch, mirror, r), shape, color, rnd,
              flip: true);
        }
      }
    }

    _accent(canvas, size, rnd, palette, dark);

    // Thin inner frame to read as a card chip (matches the other skins).
    canvas.drawRRect(
      rrect.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = (dark ? const Color(0xFFEAECEF) : const Color(0xFF1B2430))
            .withValues(alpha: 0.22),
    );
    canvas.restore();
  }

  Rect _cellRect(Rect grid, double cw, double ch, int c, int r) {
    final inset = math.min(cw, ch) * 0.12;
    return Rect.fromLTWH(
      grid.left + c * cw + inset,
      grid.top + r * ch + inset,
      cw - inset * 2,
      ch - inset * 2,
    );
  }

  void _cell(Canvas canvas, Rect cell, int shape, Color color, DigestRandom rnd,
      {bool flip = false}) {
    final paint = Paint()..color = color;
    switch (shape) {
      case 0:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              cell, Radius.circular(cell.shortestSide * 0.18)),
          paint,
        );
        break;
      case 1:
        canvas.drawOval(cell, paint);
        break;
      default:
        final p = Path();
        if (flip) {
          p
            ..moveTo(cell.right, cell.top)
            ..lineTo(cell.right, cell.bottom)
            ..lineTo(cell.left, cell.bottom);
        } else {
          p
            ..moveTo(cell.left, cell.top)
            ..lineTo(cell.left, cell.bottom)
            ..lineTo(cell.right, cell.bottom);
        }
        p.close();
        canvas.drawPath(p, paint);
    }
  }

  void _paintBackground(Canvas canvas, Size size, double baseHue, bool dark) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          [
            hsv(baseHue, dark ? 0.55 : 0.14, dark ? 0.15 : 0.99),
            hsv(baseHue + 18, dark ? 0.62 : 0.20, dark ? 0.09 : 0.94),
          ],
        ),
    );
  }

  /// A single translucent rotated polygon centred on the tile — a focal accent
  /// whose sides, rotation and colour come from the digest.
  void _accent(Canvas canvas, Size size, DigestRandom rnd, List<Color> palette,
      bool dark) {
    final sides = rnd.intRange(3, 7);
    final radius = size.shortestSide * rnd.range(0.16, 0.26);
    final rot = rnd.range(0, math.pi * 2);
    final center = Offset(
      size.width * rnd.range(0.4, 0.6),
      size.height * rnd.range(0.4, 0.6),
    );
    final path = Path();
    for (var i = 0; i <= sides; i++) {
      final a = rot + i / sides * math.pi * 2;
      final pt = center + Offset(math.cos(a) * radius, math.sin(a) * radius);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeJoin = StrokeJoin.round
        ..color = palette[rnd.nextInt(palette.length)]
            .withValues(alpha: dark ? 0.9 : 0.8),
    );
  }
}
