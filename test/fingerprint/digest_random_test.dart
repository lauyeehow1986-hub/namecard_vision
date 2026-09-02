import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/fingerprint/digest_random.dart';

/// The whole verification promise rests on the art re-deriving *identically*
/// from a digest on every platform. The PRNG is the one place that can drift:
/// on the web every `int` is a 64-bit float, so any integer op that exceeds
/// 2^53 before masking silently diverges from mobile. These goldens pin the
/// stream so a regression (like the FNV multiply that once overflowed on web)
/// is caught in CI rather than by users comparing a phone to the web viewer.
void main() {
  Uint8List seqDigest() => Uint8List.fromList(List.generate(32, (i) => i));

  test('nextU32 produces a fixed, platform-stable stream', () {
    final r = DigestRandom(seqDigest());
    final got = [for (var i = 0; i < 8; i++) r.nextU32()];
    expect(got, _goldenStream);
  });

  test('same digest replays the same stream', () {
    final a = DigestRandom(seqDigest());
    final b = DigestRandom(seqDigest());
    for (var i = 0; i < 64; i++) {
      expect(a.nextU32(), b.nextU32());
    }
  });

  test('a one-byte change diverges the stream', () {
    final base = seqDigest();
    final flipped = Uint8List.fromList(base)..[31] ^= 0x01;
    final a = DigestRandom(base);
    final b = DigestRandom(flipped);
    final anyDiff =
        List.generate(16, (_) => a.nextU32() != b.nextU32()).any((x) => x);
    expect(anyDiff, isTrue);
  });
}

// Captured on the native (reference) VM, where FNV is computed exactly; the web
// build must reproduce these to the bit.
const List<int> _goldenStream = <int>[
  3948500090,
  4212713136,
  505167797,
  2763045699,
  3368605515,
  2518291774,
  1124750182,
  632581490,
];
