import '../model/card.dart';

/// Pure builders for the external URIs a card's action buttons launch. Kept
/// free of `url_launcher` so the URI construction is unit-testable; the UI
/// layer does the actual launching.
class ContactActions {
  /// `https://wa.me/<digits>` — opens a WhatsApp chat. WhatsApp presence can't
  /// be detected, so this is always offered as one option in the chooser
  /// rather than auto-selected. Strips the leading `+` and any separators.
  static Uri whatsApp(String e164) =>
      Uri.parse('https://wa.me/${_digits(e164)}');

  /// `sms:` to the number (E.164 kept verbatim, incl. leading `+`).
  static Uri sms(String e164) => Uri(scheme: 'sms', path: _dialable(e164));

  /// `tel:` to the number.
  static Uri call(String e164) => Uri(scheme: 'tel', path: _dialable(e164));

  /// `mailto:` an address.
  static Uri email(String address) =>
      Uri(scheme: 'mailto', path: address.trim());

  /// Absolute web URL for a social link, or null if it can't be resolved.
  static Uri? social(SocialLink s) {
    final url = s.url.trim();
    if (url.isNotEmpty) {
      return Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    }
    final h = s.handle.trim().replaceFirst(RegExp(r'^@'), '');
    if (h.isEmpty) return null;
    switch (s.platform.trim().toLowerCase()) {
      case 'linkedin':
        return Uri.parse('https://www.linkedin.com/in/$h');
      case 'github':
        return Uri.parse('https://github.com/$h');
      case 'x':
      case 'twitter':
        return Uri.parse('https://x.com/$h');
      case 'instagram':
        return Uri.parse('https://instagram.com/$h');
      default:
        return h.startsWith('http') ? Uri.tryParse(h) : Uri.tryParse('https://$h');
    }
  }

  /// Keep only digits (WhatsApp's wa.me wants a bare international number).
  static String _digits(String e164) => e164.replaceAll(RegExp(r'\D'), '');

  /// Preserve a leading '+' for tel:/sms: but drop spaces, dashes, parens.
  static String _dialable(String e164) {
    final trimmed = e164.trim();
    final plus = trimmed.startsWith('+') ? '+' : '';
    return '$plus${_digits(trimmed)}';
  }
}
