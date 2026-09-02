import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/ocr/card_parser.dart';

void main() {
  group('CardParser.parseText', () {
    test('extracts email, phone and website from a typical card', () {
      const block = '''
Grace Hopper
Senior Systems Engineer
Anderson Technologies Inc.
Mobile: +1 (512) 555-0143
grace.hopper@anderson.example
www.anderson.example
''';
      final card = CardParser.parseText(block);

      expect(card.name, 'Grace Hopper');
      expect(card.title, 'Senior Systems Engineer');
      expect(card.org, 'Anderson Technologies Inc.');
      expect(card.emails, ['grace.hopper@anderson.example']);
      expect(card.phones.single.e164, '+15125550143');
      expect(card.phones.single.label, 'mobile');
      expect(card.socials.any((s) => s.url.contains('anderson.example')), isTrue);
    });

    test('does not treat an email domain as a separate website', () {
      const block = '''
Ada Lovelace
ada@example.com
''';
      final card = CardParser.parseText(block);
      expect(card.emails, ['ada@example.com']);
      expect(card.socials, isEmpty); // example.com came only from the email
    });

    test('captures multiple phones with fax/office labels, de-duplicated', () {
      const block = '''
Alan Turing
Bletchley Park Ltd
Tel: +44 20 7946 0000
Fax +44 20 7946 0001
Tel: +44 20 7946 0000
''';
      final card = CardParser.parseText(block);
      expect(card.phones.length, 2);
      expect(card.phones[0].e164, '+442079460000');
      expect(card.phones[0].label, 'tel');
      expect(card.phones[1].e164, '+442079460001');
      expect(card.phones[1].label, 'fax');
    });

    test('classifies known social platforms', () {
      const block = '''
Jane Roe
https://www.linkedin.com/in/janeroe
github.com/janeroe
''';
      final card = CardParser.parseText(block);
      final platforms = card.socials.map((s) => s.platform).toSet();
      expect(platforms, containsAll(['linkedin', 'github']));
    });

    test('falls back to first line when no name-like line qualifies', () {
      const block = '''
ACME9000 DEVICE
support@acme.example
''';
      final card = CardParser.parseText(block);
      // No two-word alphabetic name; falls back to the first non-contact line.
      expect(card.name, 'ACME9000 DEVICE');
      expect(card.emails, ['support@acme.example']);
    });

    test('org keyword wins over an ALL-CAPS logo line for org', () {
      const block = '''
John Smith
Product Manager
BIGLOGO
Northwind Trading Company
''';
      final card = CardParser.parseText(block);
      expect(card.name, 'John Smith');
      expect(card.title, 'Product Manager');
      expect(card.org, 'Northwind Trading Company');
    });

    test('uses an ALL-CAPS line as org when no org keyword is present', () {
      const block = '''
John Smith
Product Manager
NORTHWIND
''';
      final card = CardParser.parseText(block);
      expect(card.org, 'NORTHWIND');
    });

    test('empty / whitespace input yields an empty card', () {
      final card = CardParser.parseText('   \n  \n');
      expect(card.name, '');
      expect(card.title, '');
      expect(card.org, '');
      expect(card.emails, isEmpty);
      expect(card.phones, isEmpty);
      expect(card.socials, isEmpty);
    });

    test('a short digit run is not mistaken for a phone number', () {
      const block = '''
Mary Jones
Suite 220
mary@example.org
''';
      final card = CardParser.parseText(block);
      expect(card.phones, isEmpty); // "220" is too short
      expect(card.name, 'Mary Jones');
    });
  });

  group('CardParser.parse with geometry', () {
    test('the tallest name-like line is chosen as the name', () {
      final card = CardParser.parse(const [
        OcrLine('Acme Corp', height: 12),
        OcrLine('Grace Hopper', height: 40), // biggest → the name
        OcrLine('Chief Scientist', height: 14),
      ]);
      expect(card.name, 'Grace Hopper');
      expect(card.title, 'Chief Scientist');
      expect(card.org, 'Acme Corp');
    });
  });
}
