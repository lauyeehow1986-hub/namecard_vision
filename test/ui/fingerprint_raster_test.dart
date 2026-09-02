import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/model/card.dart';
import 'package:namecard_vision/ui/fingerprint_raster.dart';

void main() {
  // toImage()/toByteData() need a live engine, so drive them under runAsync.
  testWidgets('rasterizes the fingerprint to a deterministic PNG',
      (tester) async {
    await tester.runAsync(() async {
      const card = NameCard(name: 'Ada Lovelace', org: 'Analytical Engines');

      final a = await FingerprintRaster.pngOfCard(card, size: 64);
      final b = await FingerprintRaster.pngOfCard(card, size: 64);

      // PNG magic number.
      expect(a.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(a.isNotEmpty, isTrue);

      // Same card -> byte-identical image (it's a fingerprint, not decoration).
      expect(a, equals(b));

      // A one-character change must produce a different image.
      final other = await FingerprintRaster.pngOfCard(
        const NameCard(name: 'Ada Lovelacf', org: 'Analytical Engines'),
        size: 64,
      );
      expect(a, isNot(equals(other)));
    });
  });
}
