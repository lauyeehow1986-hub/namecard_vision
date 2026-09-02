import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/model/card.dart';
import 'package:namecard_vision/model/fingerprint_hash.dart';
import 'package:namecard_vision/share/ble_transfer.dart';

/// Drive a full framer -> reassembler round trip and return the payload the
/// receiver reconstructs.
Uint8List _roundTrip(Uint8List payload, int maxFrame) {
  final frames = BleFramer.frames(payload, maxFrame);
  final r = BleReassembler();
  Uint8List? out;
  for (final f in frames) {
    out = r.add(f) ?? out;
  }
  expect(r.isComplete, isTrue);
  return out!;
}

void main() {
  group('BleFramer + BleReassembler round trip', () {
    test('reconstructs bytes exactly across many frame sizes', () {
      final payload =
          Uint8List.fromList(List<int>.generate(1000, (i) => i % 256));
      for (final maxFrame in [5, 20, 23, 100, 512, 2000]) {
        final out = _roundTrip(payload, maxFrame);
        expect(out, equals(payload), reason: 'maxFrame=$maxFrame');
      }
    });

    test('a tiny maxFrame still makes progress (clamped up)', () {
      final payload = Uint8List.fromList(utf8.encode('hello bluetooth'));
      // Below the per-frame prefix; framer must clamp so each frame carries >=1 byte.
      final out = _roundTrip(payload, 1);
      expect(out, equals(payload));
    });

    test('empty payload completes on the header frame alone', () {
      final frames = BleFramer.frames(Uint8List(0), 20);
      expect(frames, hasLength(1)); // header only, no data frames
      final r = BleReassembler();
      final out = r.add(frames.first);
      expect(out, isNotNull);
      expect(out, isEmpty);
      expect(r.isComplete, isTrue);
    });

    test('header reports the total before data arrives', () {
      final payload = Uint8List.fromList(List<int>.filled(50, 7));
      final frames = BleFramer.frames(payload, 20);
      final r = BleReassembler();
      r.add(frames.first);
      expect(r.total, 50);
      expect(r.received, 0);
      expect(r.isComplete, isFalse);
    });
  });

  group('BleReassembler error handling', () {
    test('data before header throws', () {
      final r = BleReassembler();
      final data = Uint8List.fromList([0x02, 0x00, 0x00, 0x41]);
      expect(() => r.add(data), throwsA(isA<BleTransferException>()));
    });

    test('out-of-order data frame throws', () {
      final payload = Uint8List.fromList(List<int>.filled(30, 1));
      final frames = BleFramer.frames(payload, 10);
      final r = BleReassembler();
      r.add(frames[0]); // header
      r.add(frames[1]); // seq 0
      // Skip seq 1, jump to seq 2.
      expect(() => r.add(frames[3]), throwsA(isA<BleTransferException>()));
    });

    test('duplicate header throws', () {
      final frames = BleFramer.frames(Uint8List.fromList([1, 2, 3]), 20);
      final r = BleReassembler();
      r.add(frames.first);
      expect(() => r.add(frames.first), throwsA(isA<BleTransferException>()));
    });

    test('unknown frame type throws', () {
      final r = BleReassembler();
      expect(() => r.add(Uint8List.fromList([0x09, 0x00])),
          throwsA(isA<BleTransferException>()));
    });

    test('empty frame throws', () {
      final r = BleReassembler();
      expect(() => r.add(Uint8List(0)), throwsA(isA<BleTransferException>()));
    });

    test('an absurd declared length is rejected', () {
      // type=header, totalLen = 0x7FFFFFFF (well over the 64 KiB cap).
      final bad = Uint8List.fromList([0x01, 0x7F, 0xFF, 0xFF, 0xFF]);
      final r = BleReassembler();
      expect(() => r.add(bad), throwsA(isA<BleTransferException>()));
    });
  });

  group('BleTransfer card payload', () {
    test('payload round-trips a card and preserves its fingerprint', () {
      const card = NameCard(
        name: 'Ada Lovelace',
        title: 'Analyst',
        org: 'Analytical Engine Co',
        emails: ['ada@example.com'],
        phones: [PhoneNumber(label: 'mobile', e164: '+6591234567')],
        socials: [SocialLink(platform: 'github', handle: 'ada')],
        note: 'met at the symposium',
        tags: ['math', 'history'],
      );
      final payload = BleTransfer.payloadFor(card);

      // Move it across BLE framing, then decode.
      final delivered = _roundTrip(payload, 23);
      final received = BleTransfer.cardFrom(delivered);

      expect(received, equals(card));
      // The whole point: the recomputed fingerprint matches the sender's.
      expect(Fingerprint.ofCard(received).hex, Fingerprint.ofCard(card).hex);
    });

    test('cardFrom rejects non-envelope bytes', () {
      final junk = Uint8List.fromList(utf8.encode('not an envelope'));
      expect(() => BleTransfer.cardFrom(junk), throwsA(isA<FormatException>()));
    });
  });
}
