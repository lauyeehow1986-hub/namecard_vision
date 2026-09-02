import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;

import '../model/card.dart';
import '../model/phone.dart';
import '../share/contact_actions.dart';

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

  /// Write [card] into the phone's address book as a new native contact.
  /// Numbers are normalized (E.164, default +65) so they're dialable. Read-back
  /// isn't attempted; this only adds.
  static Future<SaveToPhoneOutcome> saveToPhone(NameCard card) async {
    try {
      if (!await _requestWrite()) return SaveToPhoneOutcome.permissionDenied;
      await fc.FlutterContacts.create(_buildContact(card));
      return SaveToPhoneOutcome.saved;
    } catch (_) {
      return SaveToPhoneOutcome.failed;
    }
  }

  /// Write many cards at once. Requests permission a single time, then creates
  /// each contact, counting successes and failures so the UI can summarize.
  static Future<BulkExportResult> saveManyToPhone(
      List<NameCard> cards) async {
    if (!await _requestWrite()) return const BulkExportResult.denied();
    var saved = 0;
    var failed = 0;
    for (final card in cards) {
      try {
        await fc.FlutterContacts.create(_buildContact(card));
        saved++;
      } catch (_) {
        failed++;
      }
    }
    return BulkExportResult(saved: saved, failed: failed);
  }

  static Future<bool> _requestWrite() async {
    final status =
        await fc.FlutterContacts.permissions.request(fc.PermissionType.write);
    return status == fc.PermissionStatus.granted ||
        status == fc.PermissionStatus.limited;
  }

  static fc.Contact _buildContact(NameCard card) {
    final hasOrg = card.org.trim().isNotEmpty || card.title.trim().isNotEmpty;
    return fc.Contact(
      name: fc.Name(first: card.name.trim()),
      organizations: hasOrg
          ? [fc.Organization(name: card.org.trim(), jobTitle: card.title.trim())]
          : const [],
      phones: [
        for (final p in card.phones)
          if (p.e164.trim().isNotEmpty)
            fc.Phone(
              number: PhoneFormat.toE164(p.e164),
              label: fc.Label(_toPhoneLabel(p.label)),
            ),
      ],
      emails: [
        for (final e in card.emails)
          if (e.trim().isNotEmpty) fc.Email(address: e.trim()),
      ],
      websites: [
        for (final s in card.socials)
          if (ContactActions.social(s) != null)
            fc.Website(url: ContactActions.social(s)!.toString()),
      ],
    );
  }

  static fc.PhoneLabel _toPhoneLabel(String label) {
    switch (label.trim().toLowerCase()) {
      case 'mobile':
      case 'cell':
        return fc.PhoneLabel.mobile;
      case 'work':
      case 'office':
        return fc.PhoneLabel.work;
      case 'home':
        return fc.PhoneLabel.home;
      case 'fax':
        return fc.PhoneLabel.workFax;
      default:
        return fc.PhoneLabel.mobile;
    }
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

/// The outcome of writing a card into the phone's contacts.
enum SaveToPhoneOutcome { saved, permissionDenied, failed }

/// The tally from a bulk export to the phone's contacts.
class BulkExportResult {
  final int saved;
  final int failed;
  final bool permissionDenied;

  const BulkExportResult({this.saved = 0, this.failed = 0})
      : permissionDenied = false;
  const BulkExportResult.denied()
      : saved = 0,
        failed = 0,
        permissionDenied = true;
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
