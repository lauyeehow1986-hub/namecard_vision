import 'dart:typed_data';

import '../model/card.dart';
import '../model/fingerprint_hash.dart';

/// A DECORATIVE ASCII "critter" derived from a card's fingerprint digest.
///
/// Unlike the [FingerprintStyle] skins, this is deliberately **not** a
/// verification image and is **not** in the style registry: an ASCII critter is
/// too low-entropy to trust as a checksum, so it must never be the thing a
/// recipient verifies a card against. It is still a *deterministic* function of
/// the digest (same card → same critter), which makes it a fun, stable
/// signature flourish — but it carries no verification meaning and does not
/// travel as the card's chosen skin.
///
/// The critter is assembled from digest-indexed parts (antenna, eyes, nose,
/// mouth, feet) into a fixed 6-line, 11-column monospace box. Every slot is
/// hard-padded to an exact width so the box can never come out ragged, whatever
/// the parts.
class AsciiSignature {
  const AsciiSignature._();

  /// The critter for [card].
  static String ofCard(NameCard card) =>
      ofDigest(Fingerprint.ofCard(card).digest);

  /// The critter for a raw 32-byte [digest].
  static String ofDigest(Uint8List digest) {
    // Pick from [table] using digest byte [i] (wrapping if the digest is short).
    T pick<T>(List<T> table, int i) =>
        table[digest[i % digest.length] % table.length];

    final antenna = _fix(pick(_antennae, 0), _inner);
    final eL = _fix(pick(_eyes, 1), 1);
    final eR = _fix(pick(_eyes, 2), 1);
    final nose = _fix(pick(_noses, 3), 1);
    final mouth = _fix(pick(_mouths, 4), 5);
    final feet = _fix(pick(_feet, 5), _width);

    // Fixed layout so the frame is always square (inner width 9, total 11).
    final eyesRow = '  $eL   $eR  '; // 2+1+3+1+2 = 9
    final noseRow = '    $nose    '; // 4+1+4 = 9
    final mouthRow = '  $mouth  '; // 2+5+2 = 9

    final border = '+${'-' * _inner}+';
    final lines = <String>[
      border,
      '|$antenna|',
      '|${_fix(eyesRow, _inner)}|',
      '|${_fix(noseRow, _inner)}|',
      '|${_fix(mouthRow, _inner)}|',
      border,
      feet,
    ];
    return lines.join('\n');
  }

  static const int _inner = 9; // columns inside the frame
  static const int _width = _inner + 2; // total incl. the two border columns

  /// Pad (centre) or trim [s] to exactly [n] characters, so no part can make
  /// the box ragged.
  static String _fix(String s, int n) {
    if (s.length == n) return s;
    if (s.length > n) return s.substring(0, n);
    final total = n - s.length;
    final left = total ~/ 2;
    return '${' ' * left}$s${' ' * (total - left)}';
  }

  // Part tables — kept ASCII-only for portability across fonts/terminals.
  static const List<String> _antennae = [
    r'   \|/   ',
    r'  \ | /  ',
    r'   .!.   ',
    r'  o___o  ',
    r'  =[_]=  ',
    r'  \o o/  ',
    r'   vvv   ',
    r'  (___)  ',
  ];
  static const List<String> _eyes = [
    'o', 'O', '0', '^', '*', '@', 'x', '-', '=', '.', 'e', 'u',
  ];
  static const List<String> _noses = [
    '.', ',', 'v', 'u', 'o', '~', '-', 'T',
  ];
  static const List<String> _mouths = [
    r'\___/',
    '=====',
    'vvvvv',
    '~~~~~',
    'o-o-o',
    '.---.',
    'WWWWW',
    r' \_/ ',
  ];
  static const List<String> _feet = [
    r'   / \   ',
    r'  _/ \_  ',
    r'   | |   ',
    r'  d   b  ',
    r'   ^ ^   ',
    r'  ~   ~  ',
    r'  J   L  ',
    r'  /   \  ',
  ];
}
