import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/fingerprint/registry.dart';
import 'package:namecard_vision/model/card.dart';
import 'package:namecard_vision/ui/fingerprint_raster.dart';

/// Every registered skin must be a faithful, deterministic fingerprint:
/// same card -> identical pixels, one changed character -> different pixels.
void main() {
  test('the registry exposes the expected skins', () {
    final ids = styles.map((s) => s.id).toList();
    expect(ids, containsAll(<String>['biostat.v1', 'geometric.v1', 'harmonograph.v1']));
    expect(defaultStyle.id, 'biostat.v1');
  });

  for (final style in styles) {
    testWidgets('skin ${style.id} renders a deterministic, faithful PNG',
        (tester) async {
      await tester.runAsync(() async {
        const card = NameCard(name: 'Ada Lovelace', org: 'Analytical Engines');

        final a = await FingerprintRaster.pngOfCard(card, size: 64, style: style);
        final b = await FingerprintRaster.pngOfCard(card, size: 64, style: style);

        // Valid PNG, and stable for the same card + skin.
        expect(a.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
        expect(a, equals(b));

        // A one-character change must reshape the art.
        final other = await FingerprintRaster.pngOfCard(
          const NameCard(name: 'Ada Lovelacf', org: 'Analytical Engines'),
          size: 64,
          style: style,
        );
        expect(a, isNot(equals(other)));
      });
    });
  }

  testWidgets('different skins draw the same card differently', (tester) async {
    await tester.runAsync(() async {
      const card = NameCard(name: 'Grace Hopper', org: 'US Navy');
      final images = <List<int>>[];
      for (final s in styles) {
        images.add(await FingerprintRaster.pngOfCard(card, size: 64, style: s));
      }
      // No two skins produce identical bytes for the same card.
      for (var i = 0; i < images.length; i++) {
        for (var j = i + 1; j < images.length; j++) {
          expect(images[i], isNot(equals(images[j])),
              reason: 'skins ${styles[i].id} and ${styles[j].id} collided');
        }
      }
    });
  });
}
