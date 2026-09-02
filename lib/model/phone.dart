/// Phone-number normalization to E.164.
///
/// A number that already carries an explicit country code (a leading `+`, or an
/// `00` international prefix) is kept as-is apart from stripping spaces, dashes
/// and parentheses. Anything else is treated as a local number and gets the
/// default country code prepended — Singapore (`+65`) unless overridden. This
/// is what keeps a saved contact from being mis-grouped by the phone's Contacts
/// app when the stored number lacks a country code.
class PhoneFormat {
  /// Singapore. Change per user locale later if the app gains a setting.
  static const String defaultCountryCode = '65';

  /// Return [raw] in E.164 form (`+<cc><subscriber>`), or `''` if it has no
  /// digits. Never invents a country code when one is already present.
  static String toE164(String raw, {String countryCode = defaultCountryCode}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('+')) {
      final d = _digits(trimmed);
      return d.isEmpty ? '' : '+$d';
    }
    final digits = _digits(trimmed);
    if (digits.isEmpty) return '';
    // `00` is the international call prefix — it stands in for `+`.
    if (digits.startsWith('00')) {
      final rest = digits.substring(2);
      return rest.isEmpty ? '' : '+$rest';
    }
    return '+$countryCode$digits';
  }

  /// Bare international digits (no `+`), e.g. for `wa.me/<number>`.
  static String digitsE164(String raw,
          {String countryCode = defaultCountryCode}) =>
      toE164(raw, countryCode: countryCode).replaceAll('+', '');

  static String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
}
