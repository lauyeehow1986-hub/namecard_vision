import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'color_util.dart';
import 'digest_random.dart';
import 'style.dart';

/// A harmonograph skin: several damped-pendulum (Lissajous) pen curves layered
/// over a dark wash. Each curve is
///   x(t) = Σ Aᵢ·sin(fᵢ·t + pᵢ)·e^(−dᵢ·t),  y(t) similarly,
/// with frequencies, phases, damping, amplitude and colour all drawn from the
/// digest — so the loops encode the full 256-bit fingerprint and redraw
/// identically for the same card on any device.
class HarmonographStyle implements FingerprintStyle {
  const HarmonographStyle();

  @override
  String get id => 'harmonograph.v1';

  @override
  String get label => 'Harmonograph';

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
    _paintBackground(canvas, size, baseHue);

    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.shortestSide * 0.34;
    final curves = rnd.intRange(2, 4);

    for (var k = 0; k < curves; k++) {
      final color = hsv(
        baseHue + k * rnd.range(30, 70),
        0.62,
        0.95,
        alpha: 0.75,
      );
      _paintCurve(canvas, center, scale, rnd, color);
    }

    // Thin inner frame to read as a card chip (matches the other skins).
    canvas.drawRRect(
      rrect.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFEAECEF).withValues(alpha: 0.22),
    );
    canvas.restore();
  }

  void _paintCurve(
      Canvas canvas, Offset center, double scale, DigestRandom rnd, Color color) {
    // Frequencies sit near small integers (+ a small detune) so the figures
    // are pleasingly near-closed rather than pure noise.
    double freq() => rnd.intRange(1, 4) + rnd.range(-0.06, 0.06);
    final fx1 = freq(), fx2 = freq(), fy1 = freq(), fy2 = freq();
    final px1 = rnd.range(0, math.pi * 2);
    final px2 = rnd.range(0, math.pi * 2);
    final py1 = rnd.range(0, math.pi * 2);
    final py2 = rnd.range(0, math.pi * 2);
    final dx1 = rnd.range(0.002, 0.02);
    final dx2 = rnd.range(0.002, 0.02);
    final dy1 = rnd.range(0.002, 0.02);
    final dy2 = rnd.range(0.002, 0.02);
    final ax1 = rnd.range(0.4, 0.6);
    final ax2 = 1.0 - ax1;
    final ay1 = rnd.range(0.4, 0.6);
    final ay2 = 1.0 - ay1;

    const steps = 900;
    const tMax = 40.0;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final t = i / steps * tMax;
      final x = ax1 * math.sin(fx1 * t + px1) * math.exp(-dx1 * t) +
          ax2 * math.sin(fx2 * t + px2) * math.exp(-dx2 * t);
      final y = ay1 * math.sin(fy1 * t + py1) * math.exp(-dy1 * t) +
          ay2 * math.sin(fy2 * t + py2) * math.exp(-dy2 * t);
      final pt = center + Offset(x * scale, y * scale);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  void _paintBackground(Canvas canvas, Size size, double baseHue) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = Gradient.radial(
          rect.center,
          size.shortestSide * 0.75,
          [
            hsv(baseHue, 0.45, 0.20),
            hsv(baseHue + 15, 0.60, 0.07),
          ],
        ),
    );
  }
}
