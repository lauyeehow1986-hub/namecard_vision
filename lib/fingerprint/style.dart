import 'dart:typed_data';
import 'dart:ui';

/// A pluggable way to render a card's 256-bit fingerprint as art.
///
/// Every style is a pure function of the digest: the same 32 bytes must always
/// produce the same image (that is what makes the picture a verifiable
/// checksum). New skins — math-parametric, geometric identicon, ASCII creature
/// — implement this interface and register in [styleRegistry]. Only styles that
/// faithfully encode the full digest belong here; decorative-only skins must
/// never be presented as the verification image.
abstract class FingerprintStyle {
  /// Stable identifier persisted with a card (never change once shipped).
  String get id;

  /// Human-readable name for a style picker.
  String get label;

  /// Paint the fingerprint for [digest] (32 bytes) filling [size].
  void paint(Canvas canvas, Size size, Uint8List digest);
}
