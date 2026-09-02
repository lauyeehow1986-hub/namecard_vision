import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/model/phone.dart';

void main() {
  group('PhoneFormat.toE164', () {
    test('prepends the default +65 to a bare local number', () {
      expect(PhoneFormat.toE164('98765432'), '+6598765432');
    });

    test('strips local grouping before defaulting the code', () {
      expect(PhoneFormat.toE164('010-010-02'), '+6501001002');
      expect(PhoneFormat.toE164('9876 5432'), '+6598765432');
    });

    test('keeps an explicit + country code, dropping separators', () {
      expect(PhoneFormat.toE164('+1 (512) 555-0143'), '+15125550143');
      expect(PhoneFormat.toE164('+44 20 7946 0000'), '+442079460000');
    });

    test('treats a 00 international prefix as +', () {
      expect(PhoneFormat.toE164('001 512 555 0143'), '+15125550143');
    });

    test('honours a non-Singapore default when asked', () {
      expect(PhoneFormat.toE164('2079460000', countryCode: '44'),
          '+442079460000');
    });

    test('empty / digitless input yields empty', () {
      expect(PhoneFormat.toE164(''), '');
      expect(PhoneFormat.toE164('   '), '');
      expect(PhoneFormat.toE164('+'), '');
    });
  });

  group('PhoneFormat.digitsE164', () {
    test('drops the + for wa.me style use', () {
      expect(PhoneFormat.digitsE164('98765432'), '6598765432');
      expect(PhoneFormat.digitsE164('+6598765432'), '6598765432');
    });
  });
}
