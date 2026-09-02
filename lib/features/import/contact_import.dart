import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../contacts/device_contacts.dart';
import '../../data/card_dao.dart';
import '../../data/database.dart';
import '../../model/card.dart';
import '../../share/contact_qr.dart';
import 'import_contacts_screen.dart';

/// Orchestrates importing external contacts into the collection, from either a
/// contact file (`.vcf`, e.g. one shared over WhatsApp) or the phone's address
/// book. Both funnel through [ImportContactsScreen] for review/selection, then
/// bulk-save as ordinary (not-mine) contacts. Returns how many were added.
class ContactImport {
  const ContactImport._();

  /// Let the user pick a contact file, parse it, choose which to add, save them.
  static Future<int> fromFile(BuildContext context, CardDao dao) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
      dialogTitle: 'Choose a contact file (.vcf)',
    );
    if (picked == null || picked.files.isEmpty) return 0;

    final bytes = picked.files.single.bytes;
    if (bytes == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not read that file.')),
      );
      return 0;
    }

    final text = _decode(bytes);
    final candidates = ContactQr.parseAll(text);
    if (candidates.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No contacts found in that file.')),
      );
      return 0;
    }
    if (!context.mounted) return 0;
    return _selectAndSave(context, dao, candidates, 'Import from file');
  }

  /// Read the phone's contacts, choose which to add, save them.
  static Future<int> fromPhone(BuildContext context, CardDao dao) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await DeviceContacts.fetchAll();
    if (!context.mounted) return 0;
    if (result.permissionDenied) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Contacts permission is needed to import.')),
      );
      return 0;
    }
    if (result.contacts.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No contacts found on this device.')),
      );
      return 0;
    }
    return _selectAndSave(context, dao, result.contacts, 'Phone contacts');
  }

  static Future<int> _selectAndSave(
    BuildContext context,
    CardDao dao,
    List<NameCard> candidates,
    String title,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final selected = await Navigator.of(context).push<List<NameCard>>(
      MaterialPageRoute<List<NameCard>>(
        builder: (_) =>
            ImportContactsScreen(candidates: candidates, title: title),
      ),
    );
    if (selected == null || selected.isEmpty) return 0;

    for (final card in selected) {
      await dao.upsert(card, origin: CardOrigin.created, isMine: false);
    }
    messenger.showSnackBar(
      SnackBar(content: Text('Added ${selected.length} '
          'contact${selected.length == 1 ? '' : 's'}.')),
    );
    return selected.length;
  }

  /// vCard files are UTF-8 in practice; fall back to Latin-1 if that fails so a
  /// legacy file still imports rather than throwing.
  static String _decode(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }
}
