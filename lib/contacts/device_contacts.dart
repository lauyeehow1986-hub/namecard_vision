import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;

import '../model/card.dart';

/// Reads the device's native address book and maps entries to [NameCard]s for
/// import. Read-only — the app never modifies the user's contacts here.
class DeviceContacts {
  const DeviceContacts._();

  /// Only Android/iOS have a native contacts store to read.
  static bool get platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Result of [fetchAll]: either the contacts, or a reason they're missing.
  /// Kept explicit so the UI can tell "permission denied" from "none found".
  static Future<DeviceContactsResult> fetchAll() async {
    final status =
        await fc.FlutterContacts.permissions.request(fc.PermissionType.read);
    final granted = status == fc.PermissionStatus.granted ||
        status == fc.PermissionStatus.limited;
    if (!granted) return const DeviceContactsResult.denied();
    final raw = await fc.FlutterContacts.getAll(properties: const {
      fc.ContactProperty.name,
      fc.ContactProperty.phone,
      fc.ContactProperty.email,
      fc.ContactProperty.organization,
      fc.ContactProperty.website,
    });
    final cards = raw.map(_toCard).where((c) => !_isEmpty(c)).toList()
      ..sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return DeviceContactsResult(cards);
  }

  static NameCard _toCard(fc.Contact c) {
    final org = c.organizations.isNotEmpty ? c.organizations.first : null;
    return NameCard(
      name: c.displayName?.trim() ?? '',
      org: org?.name?.trim() ?? '',
      title: org?.jobTitle?.trim() ?? '',
      phones: [
        for (final p in c.phones)
          if (p.number.trim().isNotEmpty)
            PhoneNumber(
                label: _phoneLabel(p.label.label), e164: p.number.trim()),
      ],
      emails: [
        for (final e in c.emails)
          if (e.address.trim().isNotEmpty) e.address.trim(),
      ],
      socials: [
        for (final w in c.websites)
          if (w.url.trim().isNotEmpty)
            SocialLink(platform: _hostPlatform(w.url), url: _abs(w.url)),
      ],
    );
  }

  static bool _isEmpty(NameCard c) =>
      c.name.isEmpty && c.phones.isEmpty && c.emails.isEmpty;

  static String _phoneLabel(fc.PhoneLabel label) {
    switch (label) {
      case fc.PhoneLabel.mobile:
        return 'mobile';
      case fc.PhoneLabel.work:
        return 'work';
      case fc.PhoneLabel.home:
        return 'home';
      case fc.PhoneLabel.workFax:
      case fc.PhoneLabel.homeFax:
        return 'fax';
      default:
        return '';
    }
  }

  static String _abs(String url) =>
      url.trim().startsWith('http') ? url.trim() : 'https://${url.trim()}';

  static String _hostPlatform(String url) {
    final host = Uri.tryParse(_abs(url))?.host.toLowerCase() ?? '';
    if (host.contains('linkedin')) return 'linkedin';
    if (host.contains('github')) return 'github';
    if (host.contains('twitter') || host == 'x.com') return 'x';
    if (host.contains('instagram')) return 'instagram';
    return 'website';
  }
}

/// The outcome of reading device contacts.
class DeviceContactsResult {
  final List<NameCard> contacts;
  final bool permissionDenied;

  const DeviceContactsResult(this.contacts) : permissionDenied = false;
  const DeviceContactsResult.denied()
      : contacts = const [],
        permissionDenied = true;
}
