import '../model/card.dart';
import '../model/phone.dart';

/// vCard 3.0 export — the universal, app-less path. A recipient without
/// Namecard Vision can still import the contact from a `.vcf` file or a shared
/// vCard string; every phone's Contacts app understands this format.
///
/// vCard 3.0 (not 4.0) is chosen for the widest importer compatibility.
class VCard {
  /// Serialize [card] to a vCard 3.0 string (CRLF line endings per spec).
  static String of(NameCard card) {
    final lines = <String>[
      'BEGIN:VCARD',
      'VERSION:3.0',
    ];

    final fn = card.name.trim();
    if (fn.isNotEmpty) {
      lines.add('FN:${_esc(fn)}');
      lines.add('N:${_esc(fn)};;;;'); // family/given unsplit -> whole in family
    } else {
      // FN is mandatory in 3.0; fall back to org or a placeholder.
      final fallback = card.org.trim().isNotEmpty ? card.org.trim() : 'Contact';
      lines.add('FN:${_esc(fallback)}');
      lines.add('N:${_esc(fallback)};;;;');
    }

    if (card.org.trim().isNotEmpty) lines.add('ORG:${_esc(card.org.trim())}');
    if (card.title.trim().isNotEmpty) {
      lines.add('TITLE:${_esc(card.title.trim())}');
    }

    for (final phone in card.phones) {
      // Normalize to E.164 (default +65) so the recipient's Contacts app keeps
      // the number whole instead of re-grouping a code-less one.
      final num = PhoneFormat.toE164(phone.e164);
      if (num.isEmpty) continue;
      final type = _telType(phone.label);
      lines.add('TEL;TYPE=$type:${_esc(num)}');
    }

    for (final email in card.emails) {
      final e = email.trim();
      if (e.isNotEmpty) lines.add('EMAIL;TYPE=INTERNET:${_esc(e)}');
    }

    for (final social in card.socials) {
      final url = _socialUrl(social);
      if (url.isNotEmpty) lines.add('URL:${_esc(url)}');
    }

    if (card.note.trim().isNotEmpty) lines.add('NOTE:${_esc(card.note.trim())}');
    if (card.tags.isNotEmpty) {
      lines.add('CATEGORIES:${card.tags.map(_esc).join(',')}');
    }

    lines.add('END:VCARD');
    return lines.join('\r\n');
  }

  static String _telType(String label) {
    switch (label.trim().toLowerCase()) {
      case 'mobile':
      case 'cell':
        return 'CELL';
      case 'work':
      case 'office':
        return 'WORK';
      case 'home':
        return 'HOME';
      case 'fax':
        return 'FAX';
      default:
        return 'VOICE';
    }
  }

  /// Best-effort absolute URL for a social link (prefers an explicit url,
  /// otherwise builds one from the known platform + handle).
  static String _socialUrl(SocialLink s) {
    final url = s.url.trim();
    if (url.isNotEmpty) return url;
    final h = s.handle.trim().replaceFirst(RegExp(r'^@'), '');
    if (h.isEmpty) return '';
    switch (s.platform.trim().toLowerCase()) {
      case 'linkedin':
        return 'https://www.linkedin.com/in/$h';
      case 'github':
        return 'https://github.com/$h';
      case 'x':
      case 'twitter':
        return 'https://x.com/$h';
      case 'instagram':
        return 'https://instagram.com/$h';
      default:
        return h.startsWith('http') ? h : 'https://$h';
    }
  }

  /// Escape the vCard text-value special characters (RFC 6350 §3.4).
  static String _esc(String v) => v
      .replaceAll('\\', r'\\')
      .replaceAll('\n', r'\n')
      .replaceAll(',', r'\,')
      .replaceAll(';', r'\;');
}
