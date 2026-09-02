import '../model/card.dart';

/// Parses common, non–Namecard-Vision contact QR payloads into a [NameCard]:
/// **vCard** (2.1 / 3.0 / 4.0), **MeCard**, and bare `tel:` / `mailto:` links.
///
/// Returns null when the text isn't a recognizable contact, so pointing the
/// camera at a random URL or Wi-Fi QR is ignored rather than creating an empty
/// card. Numbers are kept verbatim; the app normalizes them (E.164, default
/// +65) wherever they're shown, dialed, or exported.
class ContactQr {
  /// Parse a file that may contain **several** contacts — a `.vcf` can hold
  /// many `BEGIN:VCARD…END:VCARD` blocks (e.g. a WhatsApp-shared multi-contact
  /// file). Falls back to [tryParse] for a single non-vCard payload.
  static List<NameCard> parseAll(String raw) {
    final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final re = RegExp(r'BEGIN:VCARD.*?END:VCARD',
        caseSensitive: false, dotAll: true);
    final blocks = re.allMatches(text).toList();
    if (blocks.isEmpty) {
      final one = tryParse(text);
      return one == null ? const [] : [one];
    }
    final out = <NameCard>[];
    for (final b in blocks) {
      final c = _vcard(b.group(0)!);
      if (c != null) out.add(c);
    }
    return out;
  }

  static NameCard? tryParse(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final upper = t.toUpperCase();
    if (upper.startsWith('BEGIN:VCARD')) return _vcard(t);
    if (upper.startsWith('MECARD:')) return _mecard(t);
    if (upper.startsWith('TEL:')) {
      final num = t.substring(4).trim();
      return num.isEmpty ? null : NameCard(phones: [PhoneNumber(e164: num)]);
    }
    if (upper.startsWith('MAILTO:')) {
      final e = t.substring(7).split('?').first.trim();
      return e.isEmpty ? null : NameCard(emails: [e]);
    }
    return null;
  }

  // --- vCard ---------------------------------------------------------------

  static NameCard? _vcard(String text) {
    var fn = '';
    var nName = '';
    var org = '';
    var title = '';
    var note = '';
    final phones = <PhoneNumber>[];
    final emails = <String>[];
    final socials = <SocialLink>[];

    for (final line in _unfold(text)) {
      final idx = line.indexOf(':');
      if (idx <= 0) continue;
      final keyPart = line.substring(0, idx);
      final value = _unescape(line.substring(idx + 1)).trim();
      final segs = keyPart.split(';');
      // Strip any group prefix like "item1.TEL".
      final key = segs.first.split('.').last.toUpperCase();
      final params = segs.skip(1).toList();
      switch (key) {
        case 'FN':
          fn = value;
        case 'N':
          nName = _nameFromN(value);
        case 'ORG':
          org = value.split(';').first.trim();
        case 'TITLE':
          title = value;
        case 'NOTE':
          note = value;
        case 'TEL':
          if (value.isNotEmpty) {
            phones.add(PhoneNumber(label: _telLabel(params), e164: value));
          }
        case 'EMAIL':
          if (value.isNotEmpty) emails.add(value);
        case 'URL':
          final s = _social(value);
          if (s != null) socials.add(s);
      }
    }

    final name = fn.isNotEmpty ? fn : nName;
    if (name.isEmpty && phones.isEmpty && emails.isEmpty) return null;
    return NameCard(
      name: name,
      org: org,
      title: title,
      note: note,
      phones: phones,
      emails: emails,
      socials: socials,
    );
  }

  /// Merge RFC-6350 folded continuation lines (those beginning with a space or
  /// tab) back into the preceding logical line.
  static List<String> _unfold(String text) {
    final raw =
        text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final out = <String>[];
    for (final l in raw) {
      if (l.isEmpty) continue;
      if ((l.startsWith(' ') || l.startsWith('\t')) && out.isNotEmpty) {
        out[out.length - 1] += l.substring(1);
      } else {
        out.add(l);
      }
    }
    return out;
  }

  static String _unescape(String v) => v
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\N', '\n')
      .replaceAll(r'\,', ',')
      .replaceAll(r'\;', ';')
      .replaceAll(r'\\', r'\');

  /// vCard `N` is `Family;Given;Additional;Prefix;Suffix` — build "Given Family".
  static String _nameFromN(String v) {
    final p = v.split(';');
    final family = p.isNotEmpty ? p[0].trim() : '';
    final given = p.length > 1 ? p[1].trim() : '';
    return [given, family].where((s) => s.isNotEmpty).join(' ');
  }

  static String _telLabel(List<String> params) {
    for (final p in params) {
      final up = p.toUpperCase();
      final val = up.startsWith('TYPE=') ? up.substring(5) : up;
      for (final t in val.split(',')) {
        switch (t.trim()) {
          case 'CELL':
          case 'MOBILE':
            return 'mobile';
          case 'WORK':
            return 'work';
          case 'HOME':
            return 'home';
          case 'FAX':
            return 'fax';
        }
      }
    }
    return '';
  }

  // --- MeCard --------------------------------------------------------------

  static NameCard? _mecard(String text) {
    final body = text.substring(text.toUpperCase().indexOf('MECARD:') + 7);
    var name = '';
    var org = '';
    var note = '';
    final phones = <PhoneNumber>[];
    final emails = <String>[];
    final socials = <SocialLink>[];

    for (final field in body.split(';')) {
      final i = field.indexOf(':');
      if (i <= 0) continue;
      final key = field.substring(0, i).toUpperCase();
      final value = field.substring(i + 1).trim();
      if (value.isEmpty) continue;
      switch (key) {
        case 'N':
          name = _mecardName(value);
        case 'ORG':
          org = value;
        case 'TEL':
          phones.add(PhoneNumber(e164: value));
        case 'EMAIL':
          emails.add(value);
        case 'URL':
          final s = _social(value);
          if (s != null) socials.add(s);
        case 'NOTE':
          note = value;
      }
    }

    if (name.isEmpty && phones.isEmpty && emails.isEmpty) return null;
    return NameCard(
      name: name,
      org: org,
      note: note,
      phones: phones,
      emails: emails,
      socials: socials,
    );
  }

  /// MeCard `N` is `Last,First` — build "First Last".
  static String _mecardName(String v) {
    final p = v.split(',');
    if (p.length >= 2) return '${p[1].trim()} ${p[0].trim()}'.trim();
    return v.trim();
  }

  // --- shared --------------------------------------------------------------

  static SocialLink? _social(String url) {
    if (url.isEmpty) return null;
    final u = url.startsWith('http') ? url : 'https://$url';
    final host = Uri.tryParse(u)?.host.toLowerCase() ?? '';
    var platform = 'website';
    if (host.contains('linkedin')) {
      platform = 'linkedin';
    } else if (host.contains('github')) {
      platform = 'github';
    } else if (host.contains('twitter') || host == 'x.com' ||
        host.endsWith('.x.com')) {
      platform = 'x';
    } else if (host.contains('instagram')) {
      platform = 'instagram';
    }
    return SocialLink(platform: platform, url: u);
  }
}
