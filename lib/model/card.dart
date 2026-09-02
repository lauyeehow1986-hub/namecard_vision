import 'dart:typed_data';

/// A phone number on a card. [e164] is the normalized dialable form
/// (e.g. `+6591234567`); [label] is a free-text tag such as "mobile".
class PhoneNumber {
  final String label;
  final String e164;

  const PhoneNumber({this.label = '', required this.e164});

  PhoneNumber copyWith({String? label, String? e164}) =>
      PhoneNumber(label: label ?? this.label, e164: e164 ?? this.e164);

  Map<String, dynamic> toJson() => {'label': label, 'e164': e164};

  factory PhoneNumber.fromJson(Map<String, dynamic> j) => PhoneNumber(
        label: (j['label'] ?? '') as String,
        e164: (j['e164'] ?? '') as String,
      );

  @override
  bool operator ==(Object other) =>
      other is PhoneNumber && other.label == label && other.e164 == e164;

  @override
  int get hashCode => Object.hash(label, e164);
}

/// A social/web link. [platform] is a short key (e.g. `linkedin`, `github`,
/// `x`, `website`). Either [handle] or [url] may be empty depending on source.
class SocialLink {
  final String platform;
  final String handle;
  final String url;

  const SocialLink({required this.platform, this.handle = '', this.url = ''});

  SocialLink copyWith({String? platform, String? handle, String? url}) =>
      SocialLink(
        platform: platform ?? this.platform,
        handle: handle ?? this.handle,
        url: url ?? this.url,
      );

  Map<String, dynamic> toJson() =>
      {'platform': platform, 'handle': handle, 'url': url};

  factory SocialLink.fromJson(Map<String, dynamic> j) => SocialLink(
        platform: (j['platform'] ?? '') as String,
        handle: (j['handle'] ?? '') as String,
        url: (j['url'] ?? '') as String,
      );

  @override
  bool operator ==(Object other) =>
      other is SocialLink &&
      other.platform == platform &&
      other.handle == handle &&
      other.url == url;

  @override
  int get hashCode => Object.hash(platform, handle, url);
}

/// The core namecard entity.
///
/// The avatar image itself is NOT stored on this object — only its SHA-256
/// ([avatarSha256], lowercase hex or null). The raw bytes live in the data
/// layer / share payload. Hashing over the avatar *digest* (not the pixels)
/// keeps the canonical form compact and stable while still making the
/// fingerprint change if the photo changes. See [avatarBytesToHash].
class NameCard {
  final String name;
  final String title;
  final String org;
  final List<PhoneNumber> phones;
  final List<String> emails;
  final List<SocialLink> socials;
  final String note;
  final List<String> tags;
  final String? avatarSha256;

  /// Which fingerprint art skin this card is drawn with (a [FingerprintStyle]
  /// id, e.g. `biostat.v1`). This is a *rendering* choice, so it is carried on
  /// the card and travels with it — a recipient sees the skin the sender picked
  /// — but it is deliberately NOT part of the canonical hash: the safety code
  /// verifies the card's contents, not how the art looks. `null` means the
  /// default skin.
  final String? styleId;

  const NameCard({
    this.name = '',
    this.title = '',
    this.org = '',
    this.phones = const [],
    this.emails = const [],
    this.socials = const [],
    this.note = '',
    this.tags = const [],
    this.avatarSha256,
    this.styleId,
  });

  NameCard copyWith({
    String? name,
    String? title,
    String? org,
    List<PhoneNumber>? phones,
    List<String>? emails,
    List<SocialLink>? socials,
    String? note,
    List<String>? tags,
    String? avatarSha256,
    bool clearAvatar = false,
    String? styleId,
  }) =>
      NameCard(
        name: name ?? this.name,
        title: title ?? this.title,
        org: org ?? this.org,
        phones: phones ?? this.phones,
        emails: emails ?? this.emails,
        socials: socials ?? this.socials,
        note: note ?? this.note,
        tags: tags ?? this.tags,
        avatarSha256: clearAvatar ? null : (avatarSha256 ?? this.avatarSha256),
        styleId: styleId ?? this.styleId,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'title': title,
        'org': org,
        'phones': phones.map((p) => p.toJson()).toList(),
        'emails': emails,
        'socials': socials.map((s) => s.toJson()).toList(),
        'note': note,
        'tags': tags,
        'avatarSha256': avatarSha256,
        // Only emitted when set, so default-skin cards stay byte-for-byte
        // identical to pre-skins payloads.
        if (styleId != null) 'styleId': styleId,
      };

  factory NameCard.fromJson(Map<String, dynamic> j) => NameCard(
        name: (j['name'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        org: (j['org'] ?? '') as String,
        phones: ((j['phones'] ?? const []) as List)
            .map((e) => PhoneNumber.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        emails: ((j['emails'] ?? const []) as List).cast<String>(),
        socials: ((j['socials'] ?? const []) as List)
            .map((e) => SocialLink.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        note: (j['note'] ?? '') as String,
        tags: ((j['tags'] ?? const []) as List).cast<String>(),
        avatarSha256: j['avatarSha256'] as String?,
        styleId: j['styleId'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is NameCard &&
      other.name == name &&
      other.title == title &&
      other.org == org &&
      _listEq(other.phones, phones) &&
      _listEq(other.emails, emails) &&
      _listEq(other.socials, socials) &&
      other.note == note &&
      _listEq(other.tags, tags) &&
      other.avatarSha256 == avatarSha256 &&
      other.styleId == styleId;

  @override
  int get hashCode => Object.hash(
        name,
        title,
        org,
        Object.hashAll(phones),
        Object.hashAll(emails),
        Object.hashAll(socials),
        note,
        Object.hashAll(tags),
        avatarSha256,
        styleId,
      );
}

bool _listEq(List a, List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Marker for how avatar bytes feed the fingerprint: callers compute the
/// SHA-256 of the (normalized) avatar image and set [NameCard.avatarSha256].
/// Kept as a named helper so the intent is documented in one place.
Uint8List? avatarBytesToHash(Uint8List? avatar) => avatar;
