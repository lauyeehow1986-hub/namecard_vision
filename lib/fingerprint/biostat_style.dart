import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'digest_random.dart';
import 'style.dart';

/// The MVP hero fingerprint: a small "study panel" of biostatistics motifs —
/// a flow-field wash, stacked Kaplan-Meier survival curves with censor ticks,
/// and a forest plot of effect estimates. Every visual parameter (curve count,
/// step positions, drop sizes, palette, marker placement) is drawn from the
/// digest via [DigestRandom], so the picture is a faithful, deterministic
/// encoding of all 256 bits: one changed character in the card visibly
/// reshapes it.
class BiostatStyle implements FingerprintStyle {
  const BiostatStyle();

  @override
  String get id => 'biostat.v1';

  @override
  String get label => 'Biostatistics';

  @override
  void paint(Canvas canvas, Size size, Uint8List digest) {
    final rnd = DigestRandom(digest);
    final palette = _palette(rnd);

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.shortestSide * 0.06),
    );
    canvas.save();
    canvas.clipRRect(rrect);

    _paintBackground(canvas, size, palette);
    _paintFlowField(canvas, size, rnd, palette);

    // The KM plot occupies the upper ~62%, the forest plot the lower band.
    final pad = size.shortestSide * 0.09;
    final plot = Rect.fromLTRB(
      pad,
      pad,
      size.width - pad,
      size.height - pad,
    );
    final split = plot.top + plot.height * 0.60;
    final kmRect = Rect.fromLTRB(plot.left, plot.top, plot.right, split);
    final forestRect =
        Rect.fromLTRB(plot.left, split + plot.height * 0.06, plot.right, plot.bottom);

    _paintAxes(canvas, kmRect, palette);
    _paintKaplanMeier(canvas, kmRect, rnd, palette);
    _paintForest(canvas, forestRect, rnd, palette);

    // Thin inner frame to read as a card chip.
    canvas.drawRRect(
      rrect.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = palette.ink.withValues(alpha: 0.25),
    );
    canvas.restore();
  }

  // --- palette -------------------------------------------------------------

  _Palette _palette(DigestRandom rnd) {
    final baseHue = rnd.range(0, 360);
    final scheme = rnd.nextInt(3); // analogous / triadic / complementary
    double h2, h3;
    switch (scheme) {
      case 0:
        h2 = baseHue + rnd.range(20, 45);
        h3 = baseHue - rnd.range(20, 45);
        break;
      case 1:
        h2 = baseHue + 120;
        h3 = baseHue + 240;
        break;
      default:
        h2 = baseHue + 180;
        h3 = baseHue + rnd.range(150, 210);
    }
    final dark = rnd.chance(0.6);
    final bgTop = _hsv(baseHue, dark ? 0.55 : 0.18, dark ? 0.16 : 0.98);
    final bgBottom = _hsv(baseHue + 12, dark ? 0.65 : 0.22, dark ? 0.09 : 0.92);
    return _Palette(
      bgTop: bgTop,
      bgBottom: bgBottom,
      ink: dark ? const Color(0xFFEAECEF) : const Color(0xFF1B2430),
      curves: [
        _hsv(baseHue, 0.75, dark ? 0.95 : 0.75),
        _hsv(h2, 0.72, dark ? 0.9 : 0.7),
        _hsv(h3, 0.7, dark ? 0.88 : 0.68),
        _hsv(baseHue + 60, 0.68, dark ? 0.85 : 0.66),
      ],
      dark: dark,
    );
  }

  // --- layers --------------------------------------------------------------

  void _paintBackground(Canvas canvas, Size size, _Palette p) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          [p.bgTop, p.bgBottom],
        ),
    );
  }

  /// A faint field of short strokes following a digest-seeded direction field —
  /// gives the panel texture without competing with the data marks.
  void _paintFlowField(Canvas canvas, Size size, DigestRandom rnd, _Palette p) {
    final cols = 10;
    final rows = 7;
    final swirl = rnd.range(0.4, 2.2);
    final phase = rnd.range(0, math.pi * 2);
    final len = size.shortestSide * 0.05;
    final paint = Paint()
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..color = p.ink.withValues(alpha: p.dark ? 0.08 : 0.06);
    for (var c = 0; c < cols; c++) {
      for (var r = 0; r < rows; r++) {
        final x = (c + 0.5) / cols * size.width;
        final y = (r + 0.5) / rows * size.height;
        final angle = math.sin(x / size.width * math.pi * swirl + phase) +
            math.cos(y / size.height * math.pi * swirl - phase);
        final dx = math.cos(angle) * len;
        final dy = math.sin(angle) * len;
        canvas.drawLine(
            Offset(x - dx, y - dy), Offset(x + dx, y + dy), paint);
      }
    }
  }

  void _paintAxes(Canvas canvas, Rect r, _Palette p) {
    final axis = Paint()
      ..color = p.ink.withValues(alpha: 0.35)
      ..strokeWidth = 1.2;
    canvas.drawLine(r.bottomLeft, r.bottomRight, axis);
    canvas.drawLine(r.topLeft, r.bottomLeft, axis);
    // A couple of faint horizontal gridlines at 0.5 and 1.0 survival.
    final grid = Paint()
      ..color = p.ink.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;
    for (final f in const [0.0, 0.5]) {
      final y = r.top + r.height * f;
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), grid);
    }
  }

  /// Stacked step-down survival curves. Each starts at S=1.0 and drops at
  /// digest-driven event times, with small vertical censor ticks between
  /// events. Curve count and shape encode a chunk of the digest each.
  void _paintKaplanMeier(Canvas canvas, Rect r, DigestRandom rnd, _Palette p) {
    final n = rnd.intRange(2, 4);
    for (var k = 0; k < n; k++) {
      final color = p.curves[k % p.curves.length];
      final steps = rnd.intRange(5, 9);
      double s = 1.0;
      final floor = rnd.range(0.05, 0.35);
      final path = Path()..moveTo(r.left, _y(r, s));
      final tickXs = <double>[];
      double x = r.left;
      for (var i = 0; i < steps; i++) {
        final nextX = r.left + r.width * ((i + 1) / steps);
        // horizontal run at current survival
        path.lineTo(nextX, _y(r, s));
        // step down by a random drop bounded so we stay above the floor
        final drop = rnd.range(0.04, 0.18) * (s - floor + 0.05);
        s = math.max(floor, s - drop);
        path.lineTo(nextX, _y(r, s));
        // remember a spot for a censor tick on the run
        tickXs.add((x + nextX) / 2);
        x = nextX;
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r.height * 0.018 + 1.2
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
      // censor ticks
      final tick = Paint()
        ..color = color.withValues(alpha: 0.9)
        ..strokeWidth = 1.4;
      double sTick = 1.0;
      for (var i = 0; i < tickXs.length; i++) {
        if (rnd.chance(0.5)) {
          final ty = _y(r, sTick);
          final h = r.height * 0.02;
          canvas.drawLine(
              Offset(tickXs[i], ty - h), Offset(tickXs[i], ty + h), tick);
        }
        sTick = math.max(floor, sTick - 0.1);
      }
    }
  }

  double _y(Rect r, double survival) => r.bottom - r.height * survival;

  /// A forest plot: rows of confidence intervals with a point estimate marker,
  /// centred on a dashed line of null effect. Row count, effect sizes, and CI
  /// widths come from the digest.
  void _paintForest(Canvas canvas, Rect r, DigestRandom rnd, _Palette p) {
    final rows = rnd.intRange(3, 5);
    final nullX = r.left + r.width * rnd.range(0.42, 0.58);

    // dashed vertical "no effect" reference line
    final refPaint = Paint()
      ..color = p.ink.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;
    const dash = 4.0;
    for (double y = r.top; y < r.bottom; y += dash * 2) {
      canvas.drawLine(Offset(nullX, y),
          Offset(nullX, math.min(y + dash, r.bottom)), refPaint);
    }

    final rowH = r.height / rows;
    for (var i = 0; i < rows; i++) {
      final cy = r.top + rowH * (i + 0.5);
      final color = p.curves[i % p.curves.length];
      final estimate = r.left + r.width * rnd.range(0.12, 0.88);
      final half = r.width * rnd.range(0.06, 0.22);
      final lo = math.max(r.left, estimate - half);
      final hi = math.min(r.right, estimate + half);

      // whisker (confidence interval)
      final line = Paint()
        ..color = color.withValues(alpha: 0.85)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(lo, cy), Offset(hi, cy), line);
      final capH = rowH * 0.18;
      canvas.drawLine(Offset(lo, cy - capH), Offset(lo, cy + capH), line);
      canvas.drawLine(Offset(hi, cy - capH), Offset(hi, cy + capH), line);

      // point estimate marker: square weighted by (random) study size
      final w = rowH * rnd.range(0.28, 0.5);
      canvas.drawRect(
        Rect.fromCenter(center: Offset(estimate, cy), width: w, height: w),
        Paint()..color = color,
      );
    }
  }

  /// HSV -> [Color] without depending on flutter/painting, so the engine
  /// stays pure `dart:ui`. [hue] in degrees, [sat]/[val] in [0, 1].
  static Color _hsv(double hue, double sat, double val) {
    final h = (hue % 360 + 360) % 360;
    final s = sat.clamp(0.0, 1.0);
    final v = val.clamp(0.0, 1.0);
    final c = v * s;
    final x = c * (1 - (((h / 60) % 2) - 1).abs());
    final m = v - c;
    double r, g, b;
    if (h < 60) {
      r = c;
      g = x;
      b = 0;
    } else if (h < 120) {
      r = x;
      g = c;
      b = 0;
    } else if (h < 180) {
      r = 0;
      g = c;
      b = x;
    } else if (h < 240) {
      r = 0;
      g = x;
      b = c;
    } else if (h < 300) {
      r = x;
      g = 0;
      b = c;
    } else {
      r = c;
      g = 0;
      b = x;
    }
    int ch(double f) => ((f + m) * 255).round().clamp(0, 255);
    return Color.fromARGB(255, ch(r), ch(g), ch(b));
  }
}

class _Palette {
  final Color bgTop;
  final Color bgBottom;
  final Color ink;
  final List<Color> curves;
  final bool dark;

  const _Palette({
    required this.bgTop,
    required this.bgBottom,
    required this.ink,
    required this.curves,
    required this.dark,
  });
}
