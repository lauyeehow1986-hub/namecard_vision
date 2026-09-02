import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/fingerprint/randomart_style.dart';

/// The randomart grid must be a faithful fingerprint: a well-formed frame,
/// deterministic, and — the property the decorative critter lacked — sensitive
/// to EVERY byte of the digest, including the last one.
void main() {
  Uint8List digest(int fill) => Uint8List.fromList(List.filled(32, fill));

  test('produces a well-formed 11x19 framed grid', () {
    final lines = RandomartStyle.asciiArt(digest(0x42)).split('\n');
    expect(lines.length, 11);
    expect(lines.first, '+${'-' * 17}+');
    expect(lines.last, '+${'-' * 17}+');
    for (final l in lines) {
      expect(l.length, 19);
    }
    // Start and end markers are always present.
    final body = lines.sublist(1, 10).join();
    expect(body.contains('S'), isTrue);
    expect(body.contains('E'), isTrue);
  });

  test('is deterministic', () {
    expect(RandomartStyle.asciiArt(digest(0x99)),
        RandomartStyle.asciiArt(digest(0x99)));
  });

  test('reads the WHOLE digest — changing the last byte changes the art', () {
    final a = List.generate(32, (i) => i);
    final b = List.generate(32, (i) => i)..[31] ^= 0x01; // flip 1 bit, last byte
    expect(
      RandomartStyle.asciiArt(Uint8List.fromList(a)),
      isNot(RandomartStyle.asciiArt(Uint8List.fromList(b))),
    );
  });

  test('a change to the first byte also changes the art', () {
    final a = List.generate(32, (i) => i);
    final b = List.generate(32, (i) => i)..[0] ^= 0x01;
    expect(
      RandomartStyle.asciiArt(Uint8List.fromList(a)),
      isNot(RandomartStyle.asciiArt(Uint8List.fromList(b))),
    );
  });
}
