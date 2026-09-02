import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/model/card.dart';
import 'package:namecard_vision/model/fingerprint_hash.dart';

void main() {
  group('NameCard.styleId', () {
    test('round-trips through toJson/fromJson', () {
      const card = NameCard(name: 'Ada', styleId: 'geometric.v1');
      final back = NameCard.fromJson(card.toJson());
      expect(back.styleId, 'geometric.v1');
      expect(back, equals(card));
    });

    test('is omitted from JSON when null (payload stays legacy-compatible)', () {
      const card = NameCard(name: 'Ada');
      expect(card.toJson().containsKey('styleId'), isFalse);
      // A payload without the key decodes to the default (null) skin.
      final back = NameCard.fromJson(const {'name': 'Ada'});
      expect(back.styleId, isNull);
    });

    test('does NOT change the fingerprint — the safety code verifies content, '
        'not the skin', () {
      const biostat = NameCard(name: 'Ada Lovelace', styleId: 'biostat.v1');
      const geometric = NameCard(name: 'Ada Lovelace', styleId: 'geometric.v1');
      const none = NameCard(name: 'Ada Lovelace');

      final f1 = Fingerprint.ofCard(biostat);
      final f2 = Fingerprint.ofCard(geometric);
      final f3 = Fingerprint.ofCard(none);

      expect(f1.hex, equals(f2.hex));
      expect(f2.hex, equals(f3.hex));
      expect(f1.safetyCode, equals(f3.safetyCode));
    });

    test('is a distinguishing field for equality', () {
      const a = NameCard(name: 'Ada', styleId: 'geometric.v1');
      const b = NameCard(name: 'Ada', styleId: 'harmonograph.v1');
      expect(a == b, isFalse);
    });
  });
}
