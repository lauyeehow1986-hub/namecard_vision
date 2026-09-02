import 'dart:convert';
import 'dart:typed_data';

import '../model/card.dart';
import 'envelope.dart';

/// The BLE wire protocol for sharing a card, kept **pure** so the interesting
/// part — chunking a card across many small BLE packets and reassembling it —
/// is fully host-testable without a Bluetooth stack or a device.
///
/// A BLE notification carries at most one MTU worth of bytes (often ~20, up to
/// ~512 once negotiated), while a card's [ShareEnvelope] can be larger. So the
/// sender ([BleFramer]) splits the envelope bytes into small **frames** and the
/// receiver ([BleReassembler]) stitches them back into the exact same bytes.
/// The payload is the identical `NCV1` envelope used by QR and NFC, so a
/// received card recomputes the sender's fingerprint + safety code — that is
/// the verification. The art is never transmitted.
///
/// Frame layout (first byte is the type tag):
///   header  `0x01 | totalLen(4, big-endian)`
///   data    `0x02 | seq(2, big-endian) | bytes…`
/// The header announces the total payload length; data frames follow in order
/// from seq 0. Reassembly completes when the accumulated length matches.
class BleTransfer {
  BleTransfer._();

  /// 128-bit service UUID advertised by a sending phone. Fixed and app-specific
  /// so a receiver scans only for Namecard Vision peers. (`4e434256` = "NCBV".)
  static const String serviceUuid = '4e434256-0001-4000-8000-000000000001';

  /// The single characteristic that streams the framed envelope (notify + read).
  static const String characteristicUuid =
      '4e434256-0002-4000-8000-000000000002';

  /// Short local name used in the BLE advertisement.
  static const String advertisedName = 'NamecardVision';

  static const int _typeHeader = 0x01;
  static const int _typeData = 0x02;

  static const int _headerLen = 5; // type(1) + totalLen(4)
  static const int _dataPrefixLen = 3; // type(1) + seq(2)

  /// Hard ceiling on an accepted payload (64 KiB) — a card envelope is far
  /// smaller, so anything larger is treated as malformed rather than buffered.
  static const int maxPayloadLen = 64 * 1024;

  /// The payload bytes for [card]: the same base45 `NCV1` envelope as QR/NFC.
  static Uint8List payloadFor(NameCard card) =>
      Uint8List.fromList(utf8.encode(ShareEnvelope.encode(card)));

  /// Decode reassembled [payload] back into a [NameCard]. Throws
  /// [FormatException] if it is not a well-formed envelope.
  static NameCard cardFrom(Uint8List payload) =>
      ShareEnvelope.decode(utf8.decode(payload));
}

/// Splits an envelope payload into ordered BLE frames sized to fit a single
/// notification. Pure and deterministic: given the same payload and
/// [maxFrameLength] it always yields the same frames.
class BleFramer {
  /// Build every frame (header first, then data frames) for [payload].
  ///
  /// [maxFrameLength] is the largest number of bytes a single notification can
  /// carry (i.e. the negotiated ATT payload size). It must leave room for the
  /// per-frame prefix; values below the minimum are clamped up so a frame
  /// always carries at least one payload byte.
  static List<Uint8List> frames(Uint8List payload, int maxFrameLength) {
    final cap = maxFrameLength < BleTransfer._headerLen
        ? BleTransfer._headerLen
        : maxFrameLength;
    final perData = cap - BleTransfer._dataPrefixLen;
    final chunk = perData < 1 ? 1 : perData;

    final out = <Uint8List>[];

    // Header frame: type + total length.
    final header = Uint8List(BleTransfer._headerLen);
    header[0] = BleTransfer._typeHeader;
    final total = payload.length;
    header[1] = (total >> 24) & 0xFF;
    header[2] = (total >> 16) & 0xFF;
    header[3] = (total >> 8) & 0xFF;
    header[4] = total & 0xFF;
    out.add(header);

    // Data frames in order.
    var seq = 0;
    for (var off = 0; off < payload.length; off += chunk) {
      final end = (off + chunk < payload.length) ? off + chunk : payload.length;
      final slice = payload.sublist(off, end);
      final frame = Uint8List(BleTransfer._dataPrefixLen + slice.length);
      frame[0] = BleTransfer._typeData;
      frame[1] = (seq >> 8) & 0xFF;
      frame[2] = seq & 0xFF;
      frame.setRange(BleTransfer._dataPrefixLen, frame.length, slice);
      out.add(frame);
      seq++;
    }
    return out;
  }
}

/// Reassembles frames from [BleFramer] back into the original payload. Feed
/// each received notification to [add]; when it returns the completed payload,
/// the transfer is done. Ordering follows the BLE connection guarantee (frames
/// arrive in the order the peer sent them).
class BleReassembler {
  int? _total;
  final BytesBuilder _buf = BytesBuilder(copy: false);
  int _nextSeq = 0;

  /// Bytes accumulated so far (for a progress indicator).
  int get received => _buf.length;

  /// Expected total once the header has arrived, else null.
  int? get total => _total;

  /// True once the whole payload has been received.
  bool get isComplete => _total != null && _buf.length >= _total!;

  /// Feed one frame. Returns the completed payload on the frame that finishes
  /// the transfer, otherwise null. Throws [BleTransferException] on a malformed
  /// or out-of-sequence frame.
  Uint8List? add(Uint8List frame) {
    if (frame.isEmpty) {
      throw const BleTransferException('empty BLE frame');
    }
    switch (frame[0]) {
      case BleTransfer._typeHeader:
        if (frame.length < BleTransfer._headerLen) {
          throw const BleTransferException('short header frame');
        }
        if (_total != null) {
          throw const BleTransferException('duplicate header frame');
        }
        final total = (frame[1] << 24) |
            (frame[2] << 16) |
            (frame[3] << 8) |
            frame[4];
        if (total < 0 || total > BleTransfer.maxPayloadLen) {
          throw const BleTransferException('payload length out of range');
        }
        _total = total;
        return _maybeComplete();
      case BleTransfer._typeData:
        if (_total == null) {
          throw const BleTransferException('data frame before header');
        }
        if (frame.length < BleTransfer._dataPrefixLen) {
          throw const BleTransferException('short data frame');
        }
        final seq = (frame[1] << 8) | frame[2];
        if (seq != _nextSeq) {
          throw BleTransferException('out-of-order frame ($seq != $_nextSeq)');
        }
        _nextSeq++;
        final data = frame.sublist(BleTransfer._dataPrefixLen);
        if (_buf.length + data.length > _total!) {
          throw const BleTransferException('payload overran declared length');
        }
        _buf.add(data);
        return _maybeComplete();
      default:
        throw BleTransferException('unknown frame type 0x${frame[0]}');
    }
  }

  Uint8List? _maybeComplete() => isComplete ? _buf.toBytes() : null;
}

/// A malformed or unexpected frame during reassembly.
class BleTransferException implements Exception {
  final String message;
  const BleTransferException(this.message);

  @override
  String toString() => 'BleTransferException: $message';
}
