import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../model/card.dart';

/// One card as it travels in a backup bundle: the domain [card] plus the
/// storage metadata needed to restore it faithfully on another device.
///
/// [origin] is a plain string (`created` / `received`) so this layer stays
/// free of the Drift database types — the service that talks to the store maps
/// it to/from [CardOrigin].
class BackupEntry {
  final String id;
  final String origin;
  final NameCard card;
  final Uint8List? avatar;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BackupEntry({
    required this.id,
    required this.origin,
    required this.card,
    required this.avatar,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// Reads and writes the portable `.ncv` collection bundle: a zip holding a
/// `manifest.json` describing every card, plus one `avatars/<id>.bin` blob per
/// card that has a photo. A plain file the user can move across devices or OSes;
/// [import] merges it back into a store. Cross-device by design — nothing here
/// depends on the local SQLite layout, only on the stable [NameCard] JSON.
class NcvBackup {
  static const String format = 'ncv-backup';
  static const int version = 1;
  static const String _manifestName = 'manifest.json';
  static const String _avatarDir = 'avatars';

  /// Pack [entries] into `.ncv` bytes. [exportedAt] defaults to now and is
  /// recorded in the manifest for the user's reference (it never affects a
  /// card's fingerprint).
  static Uint8List encode(List<BackupEntry> entries, {DateTime? exportedAt}) {
    final archive = Archive();

    final cards = <Map<String, dynamic>>[];
    for (final e in entries) {
      String? avatarFile;
      if (e.avatar != null && e.avatar!.isNotEmpty) {
        avatarFile = '$_avatarDir/${e.id}.bin';
        archive.addFile(
          ArchiveFile(avatarFile, e.avatar!.length, e.avatar!),
        );
      }
      cards.add({
        'id': e.id,
        'origin': e.origin,
        'createdAt': e.createdAt.toUtc().toIso8601String(),
        'updatedAt': e.updatedAt.toUtc().toIso8601String(),
        'avatar': avatarFile,
        'data': e.card.toJson(),
      });
    }

    final manifest = <String, dynamic>{
      'format': format,
      'version': version,
      'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'cards': cards,
    };
    final manifestBytes =
        utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest));
    archive.addFile(
      ArchiveFile(_manifestName, manifestBytes.length, manifestBytes),
    );

    final zipped = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipped);
  }

  /// Parse `.ncv` [bytes] back into entries. Throws [FormatException] if the
  /// bundle is not a valid backup (bad zip, missing/foreign manifest, or a
  /// version this build cannot read).
  static List<BackupEntry> decode(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('Not a valid .ncv bundle (bad archive)');
    }

    final files = <String, Uint8List>{};
    for (final f in archive) {
      if (f.isFile) {
        files[f.name] = Uint8List.fromList(f.content as List<int>);
      }
    }

    final manifestBytes = files[_manifestName];
    if (manifestBytes == null) {
      throw const FormatException('Missing manifest.json');
    }

    final Map<String, dynamic> manifest;
    try {
      manifest = jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('Corrupt manifest.json');
    }

    if (manifest['format'] != format) {
      throw const FormatException('Not a namecard_vision backup');
    }
    final v = manifest['version'];
    if (v is! int || v > version) {
      throw FormatException('Unsupported backup version: $v');
    }

    final rawCards = manifest['cards'];
    if (rawCards is! List) {
      throw const FormatException('Manifest has no cards list');
    }

    final entries = <BackupEntry>[];
    for (final raw in rawCards) {
      if (raw is! Map) {
        throw const FormatException('Malformed card entry');
      }
      final m = Map<String, dynamic>.from(raw);
      final avatarRef = m['avatar'];
      Uint8List? avatar;
      if (avatarRef is String && avatarRef.isNotEmpty) {
        avatar = files[avatarRef];
        if (avatar == null) {
          throw FormatException('Missing avatar blob: $avatarRef');
        }
      }
      entries.add(BackupEntry(
        id: (m['id'] ?? '') as String,
        origin: (m['origin'] ?? 'created') as String,
        card: NameCard.fromJson(Map<String, dynamic>.from(m['data'] as Map)),
        avatar: avatar,
        createdAt: _parseDate(m['createdAt']),
        updatedAt: _parseDate(m['updatedAt']),
      ));
    }
    return entries;
  }

  static DateTime _parseDate(Object? v) {
    if (v is String) {
      final parsed = DateTime.tryParse(v);
      if (parsed != null) return parsed.toLocal();
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
