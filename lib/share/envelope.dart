import 'dart:convert';
import 'dart:typed_data';

import '../model/card.dart';
import 'base45.dart';

/// The wire format for sharing a card (QR today; NFC/BLE later reuse it).
///
/// Layout: `magic("NCV1") | flags(1) | payload`, base45-encoded for QR. The
/// payload is the card's canonical-lossless JSON (`NameCard.toJson`), so the
/// recipient reconstructs the *exact* card and recomputing its fingerprint
/// reproduces the sender's art + safety code — that is the verification.
///
/// The avatar image is never carried here (only its hash lives on the card);
/// keeping the QR text-only keeps the symbol small and reliably scannable.
/// [flags] reserves bit 0 for a future compressed payload.
class ShareEnvelope {
  static const List<int> _magic = [0x4E, 0x43, 0x56, 0x31]; // 'N','C','V','1'
  static const int _headerLen = 5; // magic(4) + flags(1)

  /// Encode [card] to base45 QR text.
  static String encode(NameCard card) {
    final json = utf8.encode(jsonEncode(card.toJson()));
    final buf = Uint8List(_headerLen + json.length)
      ..setRange(0, 4, _magic)
      ..[4] = 0x00 // flags
      ..setRange(_headerLen, _headerLen + json.length, json);
    return Base45.encode(buf);
  }

  /// Decode base45 QR text back to a [NameCard].
  /// Throws [FormatException] if the text is not a well-formed NCV envelope.
  static NameCard decode(String qrText) {
    final Uint8List bytes;
    try {
      bytes = Base45.decode(qrText.trim());
    } on FormatException {
      rethrow;
    }
    if (bytes.length < _headerLen ||
        bytes[0] != _magic[0] ||
        bytes[1] != _magic[1] ||
        bytes[2] != _magic[2] ||
        bytes[3] != _magic[3]) {
      throw const FormatException('not a Namecard Vision share code');
    }
    final flags = bytes[4];
    if (flags & 0x01 != 0) {
      throw const FormatException('unsupported (compressed) envelope');
    }
    final payload = bytes.sublist(_headerLen);
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(payload));
    } on FormatException {
      throw const FormatException('corrupt card payload');
    }
    if (decoded is! Map) {
      throw const FormatException('corrupt card payload');
    }
    return NameCard.fromJson(Map<String, dynamic>.from(decoded));
  }
}
