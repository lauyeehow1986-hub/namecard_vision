import 'dart:ui';

/// HSV -> [Color], kept dependency-free so the fingerprint engine stays pure
/// `dart:ui` (no flutter/painting import). [hue] in degrees (wraps), [sat] and
/// [val] in [0, 1] (clamped). Shared by the art skins so palette math lives in
/// one place.
Color hsv(double hue, double sat, double val, {double alpha = 1.0}) {
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
  final a = (alpha.clamp(0.0, 1.0) * 255).round();
  return Color.fromARGB(a, ch(r), ch(g), ch(b));
}
