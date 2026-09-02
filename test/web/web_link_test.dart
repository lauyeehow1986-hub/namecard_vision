import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/model/card.dart';
import 'package:namecard_vision/model/fingerprint_hash.dart';
import 'package:namecard_vision/web/web_link.dart';

void main() {
  const card = NameCard(
    name: 'Grace Hopper',
    title: 'Rear Admiral',
    org: 'US Navy',
    emails: ['grace@example.mil'],
    phones: [PhoneNumber(label: 'office', e164: '+12025550100')],
    socials: [SocialLink(platform: 'github', handle: 'amazing-grace')],
    note: 'a nanosecond is 11.8 inches; commas, colons: & % symbols too',
    tags: ['navy', 'compilers'],
  );

  group('WebLink', () {
    test('forCard builds a fragment URL on the hosted base', () {
      final url = WebLink.forCard(card);
      expect(url.startsWith(WebLink.base), isTrue);
      expect(url.contains('#'), isTrue);
    });

    test('round-trips a card through a real URL parse (fragment decodes)', () {
      final url = WebLink.forCard(card);
      final parsed = Uri.parse(url);
      final back = WebLink.cardFromUri(parsed);
      expect(back, equals(card));
      // The whole point: recomputed fingerprint matches the sender's.
      expect(Fingerprint.ofCard(back!).hex, Fingerprint.ofCard(card).hex);
    });

    test('percent-encoded special characters survive the round trip', () {
      // The note deliberately contains %, :, &, commas — all of which must
      // come back intact through the fragment.
      final url = WebLink.forCard(card);
      final back = WebLink.cardFromUri(Uri.parse(url));
      expect(back!.note, card.note);
    });

    test('a URL with no fragment yields null', () {
      expect(WebLink.cardFromUri(Uri.parse(WebLink.base)), isNull);
    });

    test('a garbage fragment yields null rather than throwing', () {
      expect(WebLink.cardFromFragment('not-an-envelope'), isNull);
      expect(WebLink.cardFromUri(Uri.parse('${WebLink.base}#zzz%20zzz')),
          isNull);
    });

    test('honours a custom base for a future host swap', () {
      final url = WebLink.forCard(card, base: 'https://cards.example/');
      expect(url.startsWith('https://cards.example/#'), isTrue);
      expect(WebLink.cardFromUri(Uri.parse(url)), equals(card));
    });
  });
}
