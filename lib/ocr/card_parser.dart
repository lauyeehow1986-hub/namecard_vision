import '../model/card.dart';

/// One recognized line of text from OCR, with an optional [height] (the pixel
/// height of its bounding box) used to rank which line is most likely the
/// person's name — on a business card the name is usually the largest text.
/// [height] is 0 when the source did not provide geometry.
class OcrLine {
  final String text;
  final double height;

  const OcrLine(this.text, {this.height = 0});
}

/// Heuristic parser: recognized card text → a best-guess [NameCard] to *prefill*
/// the editor. It never has to be perfect — the user reviews and corrects every
/// field before saving — so it favours useful guesses over strict precision.
///
/// Pure Dart with no ML/plugin dependency, so the classification rules are
/// unit-tested on the host; the on-device ML Kit adapter only feeds it lines.
class CardParser {
  const CardParser._();

  // A permissive email; the address is validated by use, not by us.
  static final RegExp _email =
      RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');

  // A URL or bare domain (not an email — emails are stripped first).
  static final RegExp _url = RegExp(
    r'((https?://)|(www\.))[^\s]+|[A-Za-z0-9\-]+\.(com|org|net|io|co|dev|ai|me|app|gov|edu)([/\w\-.]*)?',
    caseSensitive: false,
  );

  // A run that looks like a phone number: optional +, then 7+ dialable chars.
  static final RegExp _phone =
      RegExp(r'(\+?\d[\d\s().\-]{6,}\d)');

  static final RegExp _hasLetter = RegExp(r'[A-Za-z]');
  static final RegExp _hasDigit = RegExp(r'\d');
  // Name-like: letters plus spaces and a few name punctuation marks only.
  static final RegExp _nameLike = RegExp(r"^[A-Za-z][A-Za-z .,'\-]*$");

  static const _titleKeywords = [
    'manager', 'director', 'engineer', 'developer', 'consultant', 'officer',
    'president', 'ceo', 'cto', 'cfo', 'coo', 'founder', 'co-founder', 'owner',
    'analyst', 'designer', 'architect', 'scientist', 'researcher', 'professor',
    'lecturer', 'specialist', 'coordinator', 'associate', 'assistant', 'lead',
    'head', 'chief', 'vp', 'vice president', 'partner', 'advisor', 'consultant',
    'nurse', 'doctor', 'physician', 'phd', 'md', 'account', 'sales', 'marketing',
    'executive', 'administrator', 'supervisor', 'technician', 'intern',
  ];

  static const _orgKeywords = [
    'inc', 'inc.', 'ltd', 'ltd.', 'llc', 'llp', 'gmbh', 'pte', 'pty', 'corp',
    'corporation', 'co.', 'company', 'group', 'holdings', 'technologies',
    'technology', 'solutions', 'systems', 'services', 'consulting', 'labs',
    'laboratory', 'university', 'college', 'institute', 'hospital', 'clinic',
    'foundation', 'agency', 'studio', 'ventures', 'capital', 'partners',
    'associates', 'industries', 'enterprises', 'international', 'global',
  ];

  static const _phoneLabelHints = {
    'fax': 'fax',
    'mobile': 'mobile',
    'mob': 'mobile',
    'cell': 'mobile',
    'tel': 'tel',
    'phone': 'tel',
    'office': 'work',
    'work': 'work',
    'direct': 'work',
    'home': 'home',
  };

  /// Parse pre-split [lines] (optionally carrying height) into a card.
  static NameCard parse(List<OcrLine> lines) {
    final emails = <String>[];
    final phones = <PhoneNumber>[];
    final socials = <SocialLink>[];
    final seenEmail = <String>{};
    final seenPhone = <String>{};
    final seenUrl = <String>{};

    // Lines that were consumed as a contact detail are not candidates for
    // name/title/org.
    final consumed = List<bool>.filled(lines.length, false);

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i].text.trim();
      if (raw.isEmpty) {
        consumed[i] = true;
        continue;
      }
      var isContact = false;

      for (final m in _email.allMatches(raw)) {
        final e = m.group(0)!.toLowerCase();
        if (seenEmail.add(e)) emails.add(e);
        isContact = true;
      }

      // Strip emails before looking for URLs so the domain isn't double-counted.
      final withoutEmail = raw.replaceAll(_email, ' ');
      for (final m in _url.allMatches(withoutEmail)) {
        final u = _cleanUrl(m.group(0)!);
        if (u.isEmpty) continue;
        if (seenUrl.add(u.toLowerCase())) {
          socials.add(SocialLink(platform: _platformFor(u), url: u));
        }
        isContact = true;
      }

      for (final m in _phone.allMatches(raw)) {
        final normalized = _normalizePhone(m.group(0)!);
        if (normalized.length < 7) continue; // too short to be a real number
        if (seenPhone.add(normalized)) {
          phones.add(PhoneNumber(label: _phoneLabel(raw), e164: normalized));
        }
        isContact = true;
      }

      if (isContact) consumed[i] = true;
    }

    final name = _pickName(lines, consumed);
    final title = _pickByKeywords(lines, consumed, _titleKeywords, exclude: name);
    final org = _pickOrg(lines, consumed, exclude: {name, title});

    return NameCard(
      name: name,
      title: title,
      org: org,
      phones: phones,
      emails: emails,
      socials: socials,
    );
  }

  /// Convenience: parse a newline-separated OCR block (no geometry).
  static NameCard parseText(String block) {
    final lines = block
        .split(RegExp(r'[\r\n]+'))
        .map((l) => OcrLine(l))
        .toList();
    return parse(lines);
  }

  /// The name is the tallest name-like, non-contact line; ties break toward the
  /// top of the card. Falls back to the first non-contact text line.
  static String _pickName(List<OcrLine> lines, List<bool> consumed) {
    int? best;
    for (var i = 0; i < lines.length; i++) {
      if (consumed[i]) continue;
      final t = lines[i].text.trim();
      if (!_isNameLike(t)) continue;
      if (best == null || lines[i].height > lines[best].height) {
        best = i;
      }
    }
    if (best != null) return lines[best].text.trim();

    for (var i = 0; i < lines.length; i++) {
      if (!consumed[i] && lines[i].text.trim().isNotEmpty) {
        return lines[i].text.trim();
      }
    }
    return '';
  }

  static bool _isNameLike(String t) {
    if (!_nameLike.hasMatch(t)) return false;
    if (_hasDigit.hasMatch(t)) return false;
    final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length < 2 || words.length > 4) return false;
    // Reject lines that are really a title/org caught by the name shape.
    final lower = t.toLowerCase();
    if (_titleKeywords.any((k) => _wordIn(lower, k))) return false;
    if (_orgKeywords.any((k) => _wordIn(lower, k))) return false;
    return true;
  }

  static String _pickByKeywords(
    List<OcrLine> lines,
    List<bool> consumed,
    List<String> keywords, {
    String exclude = '',
  }) {
    for (var i = 0; i < lines.length; i++) {
      if (consumed[i]) continue;
      final t = lines[i].text.trim();
      if (t.isEmpty || t == exclude) continue;
      final lower = t.toLowerCase();
      if (keywords.any((k) => _wordIn(lower, k))) return t;
    }
    return '';
  }

  static String _pickOrg(
    List<OcrLine> lines,
    List<bool> consumed, {
    required Set<String> exclude,
  }) {
    // First, a line with a company-ish keyword.
    for (var i = 0; i < lines.length; i++) {
      if (consumed[i]) continue;
      final t = lines[i].text.trim();
      if (t.isEmpty || exclude.contains(t)) continue;
      final lower = t.toLowerCase();
      if (_orgKeywords.any((k) => _wordIn(lower, k))) return t;
    }
    // Otherwise, an ALL-CAPS line that isn't the name/title (common for logos).
    for (var i = 0; i < lines.length; i++) {
      if (consumed[i]) continue;
      final t = lines[i].text.trim();
      if (t.isEmpty || exclude.contains(t)) continue;
      if (_hasLetter.hasMatch(t) && t == t.toUpperCase() && t.length > 2) {
        return t;
      }
    }
    return '';
  }

  static String _phoneLabel(String line) {
    final lower = line.toLowerCase();
    for (final entry in _phoneLabelHints.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return '';
  }

  static String _normalizePhone(String raw) {
    final hasPlus = raw.trimLeft().startsWith('+');
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return hasPlus ? '+$digits' : digits;
  }

  static String _cleanUrl(String raw) {
    var u = raw.trim();
    // Drop trailing punctuation OCR often tacks on.
    u = u.replaceAll(RegExp(r'[.,;:)\]]+$'), '');
    if (u.isEmpty) return '';
    return u;
  }

  static String _platformFor(String url) {
    final l = url.toLowerCase();
    if (l.contains('linkedin.')) return 'linkedin';
    if (l.contains('github.')) return 'github';
    if (l.contains('twitter.') || l.contains('x.com')) return 'x';
    if (l.contains('instagram.')) return 'instagram';
    return 'website';
  }

  /// Whole-word (or hyphen-bounded) match so "co" doesn't fire inside "cost".
  static bool _wordIn(String haystackLower, String needleLower) {
    final escaped = RegExp.escape(needleLower);
    return RegExp('(^|[^a-z])$escaped([^a-z]|\$)').hasMatch(haystackLower);
  }
}
