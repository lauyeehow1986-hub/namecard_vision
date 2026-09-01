import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/backup/ncv_backup.dart';
import 'package:namecard_vision/model/card.dart';
import 'package:namecard_vision/model/fingerprint_hash.dart';

BackupEntry _entry({
  required String id,
  required NameCard card,
  Uint8List? avatar,
  String origin = 'created',
}) {
  return BackupEntry(
    id: id,
    origin: origin,
    card: card,
    avatar: avatar,
    createdAt: DateTime.utc(2024, 1, 2, 3, 4, 5),
    updatedAt: DateTime.utc(2024, 6, 7, 8, 9, 10),
  );
}

void main() {
  group('NcvBackup', () {
    test('round-trips an empty collection', () {
      final bytes = NcvBackup.encode([]);
      final back = NcvBackup.decode(bytes);
      expect(back, isEmpty);
    });

    test('round-trips cards, metadata, and avatars faithfully', () {
      final avatar = Uint8List.fromList(List<int>.generate(300, (i) => i % 256));
      final entries = [
        _entry(
          id: 'aaa',
          origin: 'created',
          card: const NameCard(
            name: 'Ada Lovelace',
            org: 'Analytical Engine',
            phones: [PhoneNumber(label: 'mobile', e164: '+441234567890')],
            emails: ['ada@example.org'],
            socials: [SocialLink(platform: 'github', handle: 'ada')],
            tags: ['math', 'first-programmer'],
            note: 'note with, commas; and\nnewlines',
            avatarSha256: 'deadbeef',
          ),
          avatar: avatar,
        ),
        _entry(
          id: 'bbb',
          origin: 'received',
          card: const NameCard(name: 'No Photo', org: 'Nowhere'),
        ),
      ];

      final back = NcvBackup.decode(NcvBackup.encode(entries));
      expect(back.length, 2);

      final a = back[0];
      expect(a.id, 'aaa');
      expect(a.origin, 'created');
      expect(a.card, entries[0].card); // NameCard value-equality
      expect(a.avatar, avatar);
      expect(a.createdAt.toUtc(), DateTime.utc(2024, 1, 2, 3, 4, 5));
      expect(a.updatedAt.toUtc(), DateTime.utc(2024, 6, 7, 8, 9, 10));

      final b = back[1];
      expect(b.id, 'bbb');
      expect(b.origin, 'received');
      expect(b.avatar, isNull);
      expect(b.card, entries[1].card);
    });

    test('a restored card recomputes the same fingerprint (verification)', () {
      const card = NameCard(name: 'Grace Hopper', org: 'US Navy');
      final before = Fingerprint.ofCard(card).hex;
      final back = NcvBackup.decode(NcvBackup.encode([_entry(id: 'x', card: card)]));
      final after = Fingerprint.ofCard(back.single.card).hex;
      expect(after, before);
    });

    test('rejects a non-zip blob', () {
      expect(
        () => NcvBackup.decode(Uint8List.fromList(utf8.encode('not a zip'))),
        throwsFormatException,
      );
    });

    test('rejects a zip with no manifest', () {
      final archive = Archive()
        ..addFile(ArchiveFile('random.txt', 3, utf8.encode('abc')));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
      expect(() => NcvBackup.decode(bytes), throwsFormatException);
    });

    test('rejects a foreign manifest format', () {
      final manifest = utf8.encode(jsonEncode({'format': 'something-else'}));
      final archive = Archive()
        ..addFile(ArchiveFile('manifest.json', manifest.length, manifest));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
      expect(() => NcvBackup.decode(bytes), throwsFormatException);
    });

    test('rejects a newer backup version', () {
      final manifest = utf8.encode(jsonEncode({
        'format': NcvBackup.format,
        'version': NcvBackup.version + 1,
        'cards': [],
      }));
      final archive = Archive()
        ..addFile(ArchiveFile('manifest.json', manifest.length, manifest));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
      expect(() => NcvBackup.decode(bytes), throwsFormatException);
    });

    test('rejects a manifest that references a missing avatar blob', () {
      final manifest = utf8.encode(jsonEncode({
        'format': NcvBackup.format,
        'version': NcvBackup.version,
        'cards': [
          {
            'id': 'x',
            'origin': 'created',
            'createdAt': DateTime.utc(2024).toIso8601String(),
            'updatedAt': DateTime.utc(2024).toIso8601String(),
            'avatar': 'avatars/x.bin', // not present in the zip
            'data': const NameCard(name: 'X').toJson(),
          }
        ],
      }));
      final archive = Archive()
        ..addFile(ArchiveFile('manifest.json', manifest.length, manifest));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
      expect(() => NcvBackup.decode(bytes), throwsFormatException);
    });
  });
}
