import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/model/card.dart';
import 'package:namecard_vision/share/envelope.dart';
import 'package:namecard_vision/web/web_link.dart';

/// The chosen skin must travel with the card so a recipient sees the same art
/// the sender picked — across the QR/NFC/BLE envelope and the web-profile link.
void main() {
  const card = NameCard(
    name: 'Grace Hopper',
    org: 'US Navy',
    styleId: 'harmonograph.v1',
  );

  test('ShareEnvelope preserves styleId', () {
    final back = ShareEnvelope.decode(ShareEnvelope.encode(card));
    expect(back.styleId, 'harmonograph.v1');
    expect(back, equals(card));
  });

  test('WebLink preserves styleId through the URL fragment', () {
    final url = WebLink.forCard(card);
    final back = WebLink.cardFromUri(Uri.parse(url));
    expect(back, isNotNull);
    expect(back!.styleId, 'harmonograph.v1');
    expect(back, equals(card));
  });

  test('a default-skin card still decodes (styleId null)', () {
    const plain = NameCard(name: 'Ada');
    final back = ShareEnvelope.decode(ShareEnvelope.encode(plain));
    expect(back.styleId, isNull);
  });
}
