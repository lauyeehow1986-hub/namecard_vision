import 'dart:typed_data';

/// RFC 9285 base45 — the encoding used for QR "alphanumeric" mode, which only
/// admits the 45 characters below. Chosen over base64 because a QR code stores
/// alphanumeric data far more densely than binary/byte mode, so a card fits in
/// a smaller, more reliably scannable symbol.
class Base45 {
  static const String _alphabet =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ \$%*+-./:';

  static final Uint8List _decodeMap = _buildDecodeMap();

  static Uint8List _buildDecodeMap() {
    final map = Uint8List(128)..fillRange(0, 128, 0xFF);
    for (var i = 0; i < _alphabet.length; i++) {
      map[_alphabet.codeUnitAt(i)] = i;
    }
    return map;
  }

  /// Encode raw bytes to a base45 string (3 chars per 2 bytes, 2 for a
  /// trailing odd byte).
  static String encode(Uint8List data) {
    final out = StringBuffer();
    var i = 0;
    for (; i + 1 < data.length; i += 2) {
      var n = (data[i] << 8) | data[i + 1]; // 0..65535
      final c = n % 45;
      n ~/= 45;
      final d = n % 45;
      n ~/= 45;
      out.write(_alphabet[c]);
      out.write(_alphabet[d]);
      out.write(_alphabet[n]); // n now 0..44
    }
    if (i < data.length) {
      var n = data[i]; // 0..255
      out.write(_alphabet[n % 45]);
      out.write(_alphabet[n ~/ 45]); // 0..5
    }
    return out.toString();
  }

  /// Decode a base45 string back to bytes. Throws [FormatException] on any
  /// character outside the alphabet or a malformed / overflowing group.
  static Uint8List decode(String s) {
    final bytes = <int>[];
    final n = s.length;
    var i = 0;
    for (; i + 2 < n; i += 3) {
      final v = _val(s, i) + _val(s, i + 1) * 45 + _val(s, i + 2) * 45 * 45;
      if (v > 0xFFFF) {
        throw FormatException('base45 group out of range', s, i);
      }
      bytes.add((v >> 8) & 0xFF);
      bytes.add(v & 0xFF);
    }
    final rem = n - i;
    if (rem == 2) {
      final v = _val(s, i) + _val(s, i + 1) * 45;
      if (v > 0xFF) {
        throw FormatException('base45 tail out of range', s, i);
      }
      bytes.add(v);
    } else if (rem != 0) {
      throw FormatException('base45 length is not a valid grouping', s, i);
    }
    return Uint8List.fromList(bytes);
  }

  static int _val(String s, int i) {
    final u = s.codeUnitAt(i);
    final v = u < 128 ? _decodeMap[u] : 0xFF;
    if (v == 0xFF) {
      throw FormatException('invalid base45 character', s, i);
    }
    return v;
  }
}
