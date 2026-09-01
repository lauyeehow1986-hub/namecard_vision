import 'dart:typed_data';

import '../data/card_dao.dart';
import '../data/database.dart' hide Card;
import '../model/fingerprint_hash.dart';
import 'ncv_backup.dart';

/// Outcome of importing a bundle: how many cards were newly added versus
/// skipped because an identical card (same fingerprint) was already present.
class ImportResult {
  final int added;
  final int skipped;

  const ImportResult({required this.added, required this.skipped});

  int get total => added + skipped;
}

/// Bridges the Drift store and the portable [NcvBackup] codec: export the whole
/// collection to `.ncv` bytes, and import a bundle back with a content-keyed
/// merge so re-importing (or importing an overlapping backup) never duplicates.
class BackupService {
  final CardDao dao;

  BackupService(this.dao);

  /// Serialize every stored card (with avatars) into a `.ncv` bundle.
  Future<Uint8List> exportAll() async {
    final stored = await dao.getAll();
    final entries = stored
        .map((s) => BackupEntry(
              id: s.id,
              origin: s.origin.name,
              card: s.card,
              avatar: s.avatar,
              createdAt: s.createdAt,
              updatedAt: s.updatedAt,
            ))
        .toList();
    return NcvBackup.encode(entries);
  }

  /// Merge a `.ncv` bundle into the store. Cards are de-duplicated by
  /// fingerprint (identical content ⇒ identical card ⇒ skipped), so the import
  /// is idempotent regardless of the random row ids assigned per device. A new
  /// id is minted only if the backup's id happens to collide with one already
  /// present. Throws [FormatException] on a malformed bundle.
  Future<ImportResult> importBundle(Uint8List bytes) async {
    final entries = NcvBackup.decode(bytes);
    final existing = await dao.getAll();
    final seenFingerprints = existing.map((s) => s.fingerprintHex).toSet();
    final seenIds = existing.map((s) => s.id).toSet();

    var added = 0;
    var skipped = 0;
    for (final e in entries) {
      final fp = Fingerprint.ofCard(e.card).hex;
      if (seenFingerprints.contains(fp)) {
        skipped++;
        continue;
      }
      final id = seenIds.contains(e.id) ? CardDao.newId() : e.id;
      final origin =
          e.origin == 'received' ? CardOrigin.received : CardOrigin.created;
      await dao.upsert(
        e.card,
        origin: origin,
        id: id,
        avatar: e.avatar,
        createdAt: e.createdAt,
      );
      seenFingerprints.add(fp);
      seenIds.add(id);
      added++;
    }
    return ImportResult(added: added, skipped: skipped);
  }
}
