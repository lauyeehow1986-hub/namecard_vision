import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/share/contact_qr.dart';

void main() {
  group('ContactQr vCard', () {
    test('parses name, org, title, phone (type), email and url', () {
      const vcf = 'BEGIN:VCARD\r\n'
          'VERSION:3.0\r\n'
          'N:Lovelace;Ada;;;\r\n'
          'FN:Ada Lovelace\r\n'
          'ORG:Analytical Engine Co\r\n'
          'TITLE:Analyst\r\n'
          'TEL;TYPE=CELL:+6598765432\r\n'
          'EMAIL;TYPE=INTERNET:ada@engine.example\r\n'
          'URL:https://www.linkedin.com/in/ada\r\n'
          'END:VCARD';
      final card = ContactQr.tryParse(vcf)!;
      expect(card.name, 'Ada Lovelace');
      expect(card.org, 'Analytical Engine Co');
      expect(card.title, 'Analyst');
      expect(card.phones.single.e164, '+6598765432');
      expect(card.phones.single.label, 'mobile');
      expect(card.emails.single, 'ada@engine.example');
      expect(card.socials.single.platform, 'linkedin');
    });

    test('derives the name from N when FN is absent', () {
      const vcf =
          'BEGIN:VCARD\nVERSION:2.1\nN:Turing;Alan\nTEL:+441234\nEND:VCARD';
      final card = ContactQr.tryParse(vcf)!;
      expect(card.name, 'Alan Turing');
      expect(card.phones.single.e164, '+441234');
    });

    test('unescapes commas/semicolons and unfolds continued lines', () {
      // RFC-6350 folding: the continuation's single leading space is the fold
      // marker and is removed on unfold (no space added), so "hello" + "world".
      const vcf = 'BEGIN:VCARD\nFN:Doe\\, John\nNOTE:hello\n world\nEND:VCARD';
      final card = ContactQr.tryParse(vcf)!;
      expect(card.name, 'Doe, John');
      expect(card.note, 'helloworld');
    });
  });

  group('ContactQr MeCard', () {
    test('parses N (Last,First), tel, email, url', () {
      const mecard =
          'MECARD:N:Hopper,Grace;TEL:15125550143;EMAIL:grace@navy.example;'
          'URL:github.com/grace;;';
      final card = ContactQr.tryParse(mecard)!;
      expect(card.name, 'Grace Hopper');
      expect(card.phones.single.e164, '15125550143');
      expect(card.emails.single, 'grace@navy.example');
      expect(card.socials.single.platform, 'github');
    });
  });

  group('ContactQr.parseAll', () {
    test('parses several vCards from one file', () {
      const file = 'BEGIN:VCARD\nVERSION:3.0\nFN:Ada\nTEL:+6511111111\n'
          'END:VCARD\n'
          'BEGIN:VCARD\nVERSION:3.0\nFN:Alan\nTEL:+6522222222\n'
          'END:VCARD\n';
      final cards = ContactQr.parseAll(file);
      expect(cards.length, 2);
      expect(cards[0].name, 'Ada');
      expect(cards[1].name, 'Alan');
    });

    test('returns a single card for a non-vCard payload, empty for junk', () {
      expect(ContactQr.parseAll('MECARD:N:Doe,Jane;TEL:123;;').length, 1);
      expect(ContactQr.parseAll('not a contact'), isEmpty);
    });
  });

  group('ContactQr misc', () {
    test('bare tel: and mailto: become minimal cards', () {
      expect(ContactQr.tryParse('tel:+6591234567')!.phones.single.e164,
          '+6591234567');
      expect(ContactQr.tryParse('mailto:ada@x.example?subject=hi')!
          .emails.single, 'ada@x.example');
    });

    test('non-contact payloads are ignored', () {
      expect(ContactQr.tryParse('https://example.com'), isNull);
      expect(ContactQr.tryParse('WIFI:S:net;T:WPA;P:pw;;'), isNull);
      expect(ContactQr.tryParse(''), isNull);
    });
  });
}
