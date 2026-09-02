import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/fingerprint/ascii_signature.dart';
import 'package:namecard_vision/model/card.dart';
import 'package:namecard_vision/model/fingerprint_hash.dart';

void main() {
  group('AsciiSignature (decorative)', () {
    test('is deterministic for a card', () {
      const card = NameCard(name: 'Ada Lovelace', org: 'Analytical Engines');
      expect(AsciiSignature.ofCard(card), AsciiSignature.ofCard(card));
    });

    test('ofCard matches ofDigest of the card fingerprint', () {
      const card = NameCard(name: 'Grace Hopper', org: 'US Navy');
      final d = Fingerprint.ofCard(card).digest;
      expect(AsciiSignature.ofCard(card), AsciiSignature.ofDigest(d));
    });

    test('a one-character change reshapes the critter', () {
      const a = NameCard(name: 'Ada Lovelace');
      const b = NameCard(name: 'Ada Lovelacf');
      expect(AsciiSignature.ofCard(a), isNot(AsciiSignature.ofCard(b)));
    });

    test('the frame is always well-formed regardless of the digest', () {
      // Try a spread of digests, including all-zero and all-0xFF extremes.
      final digests = <Uint8List>[
        Uint8List(32),
        Uint8List.fromList(List.filled(32, 0xFF)),
        Uint8List.fromList(List.generate(32, (i) => i * 7 % 256)),
        Fingerprint.ofCard(const NameCard(name: 'x')).digest,
      ];
      for (final d in digests) {
        final lines = AsciiSignature.ofDigest(d).split('\n');
        expect(lines.length, 7);
        // Top and bottom borders.
        expect(lines[0], '+${'-' * 9}+');
        expect(lines[5], '+${'-' * 9}+');
        // Every framed row is exactly the box width and bordered with '|'.
        for (final i in const [1, 2, 3, 4]) {
          expect(lines[i].length, 11, reason: 'row $i width');
          expect(lines[i].startsWith('|'), isTrue);
          expect(lines[i].endsWith('|'), isTrue);
        }
        // Feet line is padded to the box width too.
        expect(lines[6].length, 11);
      }
    });
  });
}
