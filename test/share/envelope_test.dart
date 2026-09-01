import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/model/card.dart';
import 'package:namecard_vision/model/fingerprint_hash.dart';
import 'package:namecard_vision/share/base45.dart';
import 'package:namecard_vision/share/envelope.dart';

void main() {
  group('Base45 (RFC 9285)', () {
    test('known vectors from the RFC', () {
      // "AB" -> "BB8", "Hello!!" -> "%69 VD92EX0", "base-45" -> "UJCLQE7W581"
      expect(Base45.encode(Uint8List.fromList(utf8.encode('AB'))), 'BB8');
      expect(
        Base45.encode(Uint8List.fromList(utf8.encode('Hello!!'))),
        '%69 VD92EX0',
      );
      expect(
        Base45.encode(Uint8List.fromList(utf8.encode('base-45'))),
        'UJCLQE7W581',
      );
      expect(utf8.decode(Base45.decode('BB8')), 'AB');
      expect(utf8.decode(Base45.decode('%69 VD92EX0')), 'Hello!!');
      expect(utf8.decode(Base45.decode('UJCLQE7W581')), 'base-45');
    });

    test('round-trips arbitrary bytes including odd lengths and zeros', () {
      for (final len in [0, 1, 2, 3, 16, 17, 255, 256]) {
        final data =
            Uint8List.fromList(List<int>.generate(len, (i) => (i * 37) & 0xFF));
        expect(Base45.decode(Base45.encode(data)), data, reason: 'len=$len');
      }
    });

    test('rejects characters outside the alphabet', () {
      expect(() => Base45.decode('ab8'), throwsFormatException); // lowercase
      expect(() => Base45.decode('!!!'), throwsFormatException);
    });

    test('rejects an overflowing 3-char group', () {
      // 'GGW' would decode > 0xFFFF.
      expect(() => Base45.decode('GGW'), throwsFormatException);
    });
  });

  group('ShareEnvelope', () {
    final card = const NameCard(
      name: 'Grace Hopper',
      title: 'Rear Admiral',
      org: 'US Navy',
      phones: [PhoneNumber(label: 'mobile', e164: '+15125550143')],
      emails: ['grace@navy.example'],
      socials: [SocialLink(platform: 'website', url: 'https://example.org')],
      note: 'Nanoseconds.',
      tags: ['legend', 'compiler'],
    );

    test('round-trips a full card losslessly', () {
      final decoded = ShareEnvelope.decode(ShareEnvelope.encode(card));
      expect(decoded, card);
    });

    test('the QR text uses only base45 alphabet characters', () {
      const allowed = r'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:';
      final text = ShareEnvelope.encode(card);
      for (final ch in text.split('')) {
        expect(allowed.contains(ch), isTrue, reason: 'stray char "$ch"');
      }
    });

    test('recomputed fingerprint matches the sender (verification holds)', () {
      final sent = Fingerprint.ofCard(card);
      final received = Fingerprint.ofCard(
        ShareEnvelope.decode(ShareEnvelope.encode(card)),
      );
      expect(received.digest, sent.digest);
      expect(received.safetyCode, sent.safetyCode);
    });

    test('a tampered code yields a different card or fails to decode', () {
      final good = ShareEnvelope.encode(card);
      // Flip one character in the middle (payload region).
      final idx = good.length ~/ 2;
      final swap = good[idx] == 'A' ? 'B' : 'A';
      final tampered = good.replaceRange(idx, idx + 1, swap);
      expect(tampered == good, isFalse);
      try {
        final decoded = ShareEnvelope.decode(tampered);
        // If it still decodes, the fingerprint must have moved.
        expect(
          Fingerprint.ofCard(decoded).digest,
          isNot(Fingerprint.ofCard(card).digest),
        );
      } on FormatException {
        // Corruption detected outright — also an acceptable outcome.
      }
    });

    test('rejects non-envelope text', () {
      expect(() => ShareEnvelope.decode('HELLOWORLD'), throwsFormatException);
      expect(() => ShareEnvelope.decode('not base45 %%%lower'),
          throwsFormatException);
    });
  });
}
