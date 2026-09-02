import 'dart:typed_data';

/// Deterministic pseudo-random stream seeded by a full SHA-256 digest.
///
/// The whole point of the fingerprint is that the art encodes *all* 256 bits
/// of the digest, so this generator both seeds from every byte and keeps
/// mixing digest bytes into the stream as it advances. It is intentionally
/// simple integer math kept masked to 32 bits so it produces identical
/// sequences on the mobile (native, 64-bit int) and web (JS number) VMs —
/// a fingerprint that renders differently per platform would not be a
/// fingerprint at all.
class DigestRandom {
  final Uint8List _digest;
  int _state;
  int _i = 0;

  DigestRandom(this._digest) : _state = _seed(_digest);

  /// FNV-1a fold of every digest byte into a non-zero 32-bit seed.
  static int _seed(Uint8List d) {
    var h = 0x811C9DC5;
    for (final b in d) {
      h = (h ^ b) & 0xFFFFFFFF;
      h = _mul32(h, 0x01000193);
    }
    return h == 0 ? 0x9E3779B9 : h;
  }

  /// Low 32 bits of `a * b`, computed so the intermediate never exceeds 2^53.
  ///
  /// A direct `(a * b) & 0xFFFFFFFF` overflows the 53-bit mantissa of a web
  /// (JS) number when both operands are large — the FNV prime times a 32-bit
  /// accumulator reaches ~2^56 — silently dropping low bits and making the art
  /// render differently on web than on mobile. Splitting `a` into 16-bit halves
  /// keeps every product under 2^41, so the result is exact on every platform.
  static int _mul32(int a, int b) {
    final aLo = a & 0xFFFF;
    final aHi = (a >> 16) & 0xFFFF;
    // (aHi*b) only contributes to the low 32 bits through its own low 16 bits.
    return (aLo * b + (((aHi * b) & 0xFFFF) << 16)) & 0xFFFFFFFF;
  }

  /// Next unsigned 32-bit value (xorshift32, then a digest byte mixed in).
  int nextU32() {
    var x = _state;
    x ^= (x << 13) & 0xFFFFFFFF;
    x &= 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    x &= 0xFFFFFFFF;
    x = (x ^ _digest[_i % _digest.length]) & 0xFFFFFFFF;
    _i++;
    _state = x == 0 ? 0x9E3779B9 : x;
    return _state;
  }

  /// Uniform double in [0, 1).
  double nextDouble() => nextU32() / 0x100000000;

  /// Uniform double in [lo, hi).
  double range(double lo, double hi) => lo + (hi - lo) * nextDouble();

  /// Uniform int in [0, maxExclusive).
  int nextInt(int maxExclusive) => nextU32() % maxExclusive;

  /// Uniform int in [lo, hi] inclusive.
  int intRange(int lo, int hi) => lo + nextInt(hi - lo + 1);

  /// True with probability [p].
  bool chance(double p) => nextDouble() < p;
}
