import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/model/canonical.dart';
import 'package:namecard_vision/model/card.dart';
import 'package:namecard_vision/model/fingerprint_hash.dart';

NameCard sample() => const NameCard(
      name: 'Ada Lovelace',
      title: 'Analyst',
      org: 'Analytical Engine Co',
      phones: [PhoneNumber(label: 'mobile', e164: '+6591234567')],
      emails: ['ada@example.org'],
      socials: [SocialLink(platform: 'github', handle: 'ada', url: '')],
      note: 'Notes on the Engine',
      tags: ['maths', 'poetry'],
    );

void main() {
  group('CanonicalEncoder', () {
    test('is deterministic across repeated calls', () {
      final a = CanonicalEncoder.encode(sample());
      final b = CanonicalEncoder.encode(sample());
      expect(a, equals(b));
    });

    test('two independently-built identical cards encode identically', () {
      expect(CanonicalEncoder.encode(sample()),
          equals(CanonicalEncoder.encode(sample())));
    });

    test('starts with magic + schema version', () {
      final bytes = CanonicalEncoder.encode(const NameCard());
      expect(bytes.sublist(0, 4), equals(CanonicalEncoder.magic));
      expect(bytes[4], equals(CanonicalEncoder.schemaVersion));
    });
  });

  group('Fingerprint', () {
    test('digest is 32 bytes and hex is 64 chars', () {
      final fp = Fingerprint.ofCard(sample());
      expect(fp.digest.length, 32);
      expect(fp.hex.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(fp.hex), isTrue);
    });

    test('same card -> identical digest (stable fingerprint)', () {
      expect(Fingerprint.ofCard(sample()), equals(Fingerprint.ofCard(sample())));
    });

    test('single-character change flips the digest', () {
      final base = Fingerprint.ofCard(sample());
      final edited = Fingerprint.ofCard(sample().copyWith(name: 'Ada Lovelacf'));
      expect(edited, isNot(equals(base)));
    });

    test('a changed phone digit flips the digest', () {
      final base = Fingerprint.ofCard(sample());
      final edited = Fingerprint.ofCard(sample().copyWith(
          phones: const [PhoneNumber(label: 'mobile', e164: '+6591234568')]));
      expect(edited, isNot(equals(base)));
    });

    test('reordering list fields changes the digest (order is significant)', () {
      final base = Fingerprint.ofCard(sample());
      final reordered =
          Fingerprint.ofCard(sample().copyWith(tags: const ['poetry', 'maths']));
      expect(reordered, isNot(equals(base)));
    });

    test('setting an avatar hash flips the digest', () {
      final base = Fingerprint.ofCard(sample());
      final withAvatar = Fingerprint.ofCard(
          sample().copyWith(avatarSha256: 'a' * 64));
      expect(withAvatar, isNot(equals(base)));
    });

    test('empty vs whitespace note differ (no hidden normalization)', () {
      final empty = Fingerprint.ofCard(sample().copyWith(note: ''));
      final space = Fingerprint.ofCard(sample().copyWith(note: ' '));
      expect(empty, isNot(equals(space)));
    });
  });

  group('safety code', () {
    test('format is XXXX-XXXX in Crockford base32', () {
      final code = Fingerprint.ofCard(sample()).safetyCode;
      expect(RegExp(r'^[0-9A-HJKMNP-TV-Z]{4}-[0-9A-HJKMNP-TV-Z]{4}$')
          .hasMatch(code), isTrue,
          reason: 'got "$code"');
    });

    test('is stable for the same card', () {
      expect(Fingerprint.ofCard(sample()).safetyCode,
          equals(Fingerprint.ofCard(sample()).safetyCode));
    });

    test('differs when the card differs', () {
      final a = Fingerprint.ofCard(sample()).safetyCode;
      final b = Fingerprint.ofCard(sample().copyWith(org: 'Other Co')).safetyCode;
      expect(a, isNot(equals(b)));
    });
  });
}
