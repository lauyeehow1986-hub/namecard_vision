import 'dart:convert';
import 'dart:typed_data';

import 'card.dart';

/// Deterministic, versioned canonical byte encoding of a [NameCard].
///
/// The same logical card ALWAYS produces the same bytes on any device/OS —
/// that reproducibility is what lets the fingerprint act as a faithful
/// checksum. This is deliberately a fully-specified, hand-rolled TLV format
/// (not a general-purpose serializer) so the security-critical bytes can never
/// silently change with a dependency upgrade.
///
/// Format (all lengths big-endian):
///   magic "NCVC" (4 bytes) · schemaVersion (u8)
///   name · title · org                       (length-prefixed UTF-8)
///   phones   : u32 count, then [label, e164] per entry
///   emails   : u32 count, then [value] per entry
///   socials  : u32 count, then [platform, handle, url] per entry
///   note                                      (length-prefixed UTF-8)
///   tags     : u32 count, then [value] per entry
///   avatarSha256 : optional (u8 present flag, then string if present)
///
/// Field VALUES are encoded verbatim: any normalization (trim, phone→E.164,
/// lowercasing handles) is the editor's responsibility upstream, so that the
/// canonical form has exactly one job — reproducible bytes.
class CanonicalEncoder {
  static const List<int> magic = [0x4E, 0x43, 0x56, 0x43]; // "NCVC"
  static const int schemaVersion = 1;

  static Uint8List encode(NameCard card) {
    final b = BytesBuilder(copy: false);
    b.add(magic);
    _u8(b, schemaVersion);
    _str(b, card.name);
    _str(b, card.title);
    _str(b, card.org);
    _u32(b, card.phones.length);
    for (final p in card.phones) {
      _str(b, p.label);
      _str(b, p.e164);
    }
    _u32(b, card.emails.length);
    for (final e in card.emails) {
      _str(b, e);
    }
    _u32(b, card.socials.length);
    for (final s in card.socials) {
      _str(b, s.platform);
      _str(b, s.handle);
      _str(b, s.url);
    }
    _str(b, card.note);
    _u32(b, card.tags.length);
    for (final t in card.tags) {
      _str(b, t);
    }
    _optStr(b, card.avatarSha256);
    return b.toBytes();
  }

  static void _u8(BytesBuilder b, int v) => b.addByte(v & 0xFF);

  static void _u32(BytesBuilder b, int v) {
    b.addByte((v >> 24) & 0xFF);
    b.addByte((v >> 16) & 0xFF);
    b.addByte((v >> 8) & 0xFF);
    b.addByte(v & 0xFF);
  }

  static void _str(BytesBuilder b, String s) {
    final bytes = utf8.encode(s);
    _u32(b, bytes.length);
    b.add(bytes);
  }

  static void _optStr(BytesBuilder b, String? s) {
    if (s == null) {
      _u8(b, 0);
    } else {
      _u8(b, 1);
      _str(b, s);
    }
  }
}
