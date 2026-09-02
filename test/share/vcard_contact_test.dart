import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/model/card.dart';
import 'package:namecard_vision/share/contact_actions.dart';
import 'package:namecard_vision/share/vcard.dart';

void main() {
  group('VCard', () {
    test('emits a well-formed vCard 3.0 with the core fields', () {
      final vcf = VCard.of(const NameCard(
        name: 'Grace Hopper',
        title: 'Rear Admiral',
        org: 'US Navy',
        phones: [PhoneNumber(label: 'mobile', e164: '+15125550143')],
        emails: ['grace@navy.example'],
        socials: [SocialLink(platform: 'github', handle: 'grace')],
        note: 'Nanoseconds.',
        tags: ['legend'],
      ));
      expect(vcf.startsWith('BEGIN:VCARD\r\nVERSION:3.0'), isTrue);
      expect(vcf.contains('FN:Grace Hopper'), isTrue);
      expect(vcf.contains('ORG:US Navy'), isTrue);
      expect(vcf.contains('TITLE:Rear Admiral'), isTrue);
      expect(vcf.contains('TEL;TYPE=CELL:+15125550143'), isTrue);
      expect(vcf.contains('EMAIL;TYPE=INTERNET:grace@navy.example'), isTrue);
      expect(vcf.contains('URL:https://github.com/grace'), isTrue);
      expect(vcf.contains('NOTE:Nanoseconds.'), isTrue);
      expect(vcf.trimRight().endsWith('END:VCARD'), isTrue);
    });

    test('escapes commas and semicolons in text values', () {
      final vcf = VCard.of(const NameCard(
        name: 'Doe, John; Jr',
        note: 'a, b; c',
      ));
      expect(vcf.contains(r'FN:Doe\, John\; Jr'), isTrue);
      expect(vcf.contains(r'NOTE:a\, b\; c'), isTrue);
    });

    test('supplies a fallback FN when name is empty (FN is mandatory)', () {
      final vcf = VCard.of(const NameCard(org: 'Acme'));
      expect(vcf.contains('FN:Acme'), isTrue);
    });

    test('defaults a code-less number to +65 and keeps it whole', () {
      final vcf = VCard.of(const NameCard(
        name: 'Local',
        phones: [PhoneNumber(label: 'mobile', e164: '010-010-02')],
      ));
      expect(vcf.contains('TEL;TYPE=CELL:+6501001002'), isTrue);
    });
  });

  group('ContactActions', () {
    test('WhatsApp strips separators and the plus', () {
      expect(ContactActions.whatsApp('+1 (512) 555-0143').toString(),
          'https://wa.me/15125550143');
    });

    test('tel: and sms: keep a dialable form with the leading plus', () {
      expect(ContactActions.call('+1 512-555-0143').toString(),
          'tel:+15125550143');
      expect(ContactActions.sms('+15125550143').toString(),
          'sms:+15125550143');
    });

    test('mailto: builds from an address', () {
      expect(ContactActions.email(' grace@navy.example ').toString(),
          'mailto:grace@navy.example');
    });

    test('social resolves explicit urls and known platforms', () {
      expect(
        ContactActions.social(
                const SocialLink(platform: 'website', url: 'example.org'))
            .toString(),
        'https://example.org',
      );
      expect(
        ContactActions.social(
                const SocialLink(platform: 'linkedin', handle: '@grace'))
            .toString(),
        'https://www.linkedin.com/in/grace',
      );
      expect(
        ContactActions.social(const SocialLink(platform: 'x', handle: 'grace'))
            .toString(),
        'https://x.com/grace',
      );
    });

    test('social returns null when nothing is resolvable', () {
      expect(ContactActions.social(const SocialLink(platform: 'x')), isNull);
    });
  });
}
