import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../backup/backup_service.dart';

/// UI glue for the `.ncv` backup bundle: export the whole collection through
/// the OS share sheet, and import a bundle the user picks. The heavy lifting
/// (zip codec + content-keyed merge) lives in [BackupService]; this only wires
/// it to files and to the user.
class BackupActions {
  const BackupActions._();

  /// Write the collection to a temp `.ncv` file and hand it to the share sheet
  /// (save to Files, send to another device, etc.). Shows a message if there is
  /// nothing to export.
  static Future<void> export(
    BuildContext context,
    BackupService service,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await service.exportAll();
      // A backup of an empty collection is still valid, but warn so the user
      // isn't surprised by an "empty" file.
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '')
          .split('.')
          .first;
      final file = File(p.join(dir.path, 'namecard-vision-$stamp.ncv'));
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/octet-stream')],
        subject: 'namecard_vision backup',
        text: 'My namecard_vision collection backup.',
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not export the collection.')),
      );
    }
  }

  /// Let the user pick a `.ncv` file and merge it in. Reports how many cards
  /// were added versus already present. Returns true if anything was added
  /// (so the caller can refresh).
  static Future<bool> import(
    BuildContext context,
    BackupService service,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
      dialogTitle: 'Choose a .ncv backup',
    );
    if (picked == null || picked.files.isEmpty) return false;

    final bytes = picked.files.single.bytes;
    if (bytes == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not read that file.')),
      );
      return false;
    }

    try {
      final result = await service.importBundle(bytes);
      final msg = result.added == 0
          ? (result.skipped == 0
              ? 'That backup had no cards.'
              : 'Already up to date — nothing new to add.')
          : 'Added ${result.added} card${result.added == 1 ? '' : 's'}'
              '${result.skipped > 0 ? ' (${result.skipped} already present)' : ''}.';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
      return result.added > 0;
    } on FormatException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("That isn't a valid backup: ${e.message}")),
      );
      return false;
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not import that backup.')),
      );
      return false;
    }
  }
}
