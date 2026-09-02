import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/model/card.dart';
import 'package:namecard_vision/model/fingerprint_hash.dart';
import 'package:namecard_vision/web/reply_message.dart';
import 'package:namecard_vision/web/web_link.dart';

void main() {
  const recipient = NameCard(
    name: 'Katherine Johnson',
    org: 'NASA',
    emails: ['kj@example.gov'],
  );

  group('ReplyMessage', () {
    test('offers every channel the sender exposed', () {
      const sender = NameCard(
        name: 'Alan',
        emails: ['alan@example.com'],
        phones: [PhoneNumber(e164: '+6591234567')],
      );
      final m = ReplyMessage.build(recipient, sender);

      expect(m.hasDirectChannel, isTrue);
      expect(m.email!.scheme, 'mailto');
      expect(m.email!.path, 'alan@example.com');
      expect(m.whatsApp!.host, 'wa.me');
      expect(m.whatsApp!.path, '/6591234567'); // digits only, no '+'
      expect(m.sms!.scheme, 'sms');
    });

    test('carries the recipient link + safety code the sender will verify', () {
      const sender = NameCard(name: 'Alan', emails: ['alan@example.com']);
      final m = ReplyMessage.build(recipient, sender);

      expect(m.safetyCode, Fingerprint.ofCard(recipient).safetyCode);
      expect(m.body.contains(m.link), isTrue);
      expect(m.body.contains(m.safetyCode), isTrue);

      // The link decodes back to exactly the recipient's card.
      expect(WebLink.cardFromUri(Uri.parse(m.link)), equals(recipient));
    });

    test('a sender with no email or phone has no direct channel', () {
      const sender = NameCard(name: 'Anonymous');
      final m = ReplyMessage.build(recipient, sender);

      expect(m.hasDirectChannel, isFalse);
      expect(m.email, isNull);
      expect(m.whatsApp, isNull);
      expect(m.sms, isNull);
      // The link is still built so the recipient can copy/share it manually.
      expect(WebLink.cardFromUri(Uri.parse(m.link)), equals(recipient));
    });
  });
}
