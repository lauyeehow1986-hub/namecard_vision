import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'canonical.dart';
import 'card.dart';

/// The cryptographic fingerprint of a card: SHA-256 over the canonical bytes.
///
/// The 32-byte [digest] is the single source of truth that drives BOTH the
/// generative art and the human-readable [safetyCode]. Recomputing it from a
/// received card and comparing (art + code) is how a recipient verifies the
/// card was not altered in transit.
class Fingerprint {
  /// 32 raw bytes of SHA-256.
  final Uint8List digest;

  const Fingerprint(this.digest);

  /// Compute the fingerprint of [card] from its canonical encoding.
  factory Fingerprint.ofCard(NameCard card) {
    final bytes = CanonicalEncoder.encode(card);
    final d = sha256.convert(bytes);
    return Fingerprint(Uint8List.fromList(d.bytes));
  }

  /// Full lowercase hex of the digest (64 chars).
  String get hex {
    final sb = StringBuffer();
    for (final b in digest) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  /// Short, eyeball-comparable code derived from the first 5 bytes (40 bits),
  /// Crockford base32, grouped as `XXXX-XXXX`. A secondary human check that
  /// sits beneath the art (the art itself encodes the full 256 bits).
  String get safetyCode {
    final s = _crockford32(digest.sublist(0, 5)); // 5 bytes -> 8 symbols
    return '${s.substring(0, 4)}-${s.substring(4, 8)}';
  }

  @override
  bool operator ==(Object other) =>
      other is Fingerprint && _bytesEq(other.digest, digest);

  @override
  int get hashCode => Object.hashAll(digest);
}

const String _crockfordAlphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// Crockford base32 for a byte buffer whose bit-length is a multiple of 5.
/// (Used here with 5 bytes = 40 bits = exactly 8 symbols, no padding.)
String _crockford32(List<int> bytes) {
  var buffer = 0;
  var bits = 0;
  final out = StringBuffer();
  for (final b in bytes) {
    buffer = (buffer << 8) | b;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out.write(_crockfordAlphabet[(buffer >> bits) & 0x1F]);
    }
  }
  if (bits > 0) {
    out.write(_crockfordAlphabet[(buffer << (5 - bits)) & 0x1F]);
  }
  return out.toString();
}

bool _bytesEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
