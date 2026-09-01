import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/backup/backup_service.dart';
import 'package:namecard_vision/data/database.dart';
import 'package:namecard_vision/model/card.dart';

void main() {
  // These tests deliberately open a second in-memory store to model a
  // migration between devices; that is not the race the warning guards against.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late BackupService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = BackupService(db.cardDao);
  });
  tearDown(() async => db.close());

  test('export then import into an empty store restores every card', () async {
    final avatar = Uint8List.fromList(List<int>.generate(64, (i) => i));
    await db.cardDao.upsert(
      const NameCard(name: 'Ada Lovelace', org: 'Engine Co'),
      origin: CardOrigin.created,
      avatar: avatar,
    );
    await db.cardDao.upsert(
      const NameCard(name: 'Alan Turing', org: 'Bletchley'),
      origin: CardOrigin.received,
    );

    final bundle = await service.exportAll();

    // Restore into a fresh store.
    final db2 = AppDatabase(NativeDatabase.memory());
    final service2 = BackupService(db2.cardDao);
    final result = await service2.importBundle(bundle);

    expect(result.added, 2);
    expect(result.skipped, 0);
    final restored = await db2.cardDao.getAll();
    expect(restored.length, 2);
    final ada = restored.firstWhere((s) => s.card.name == 'Ada Lovelace');
    expect(ada.origin, CardOrigin.created);
    expect(ada.avatar, avatar);
    await db2.close();
  });

  test('re-importing the same bundle is idempotent (dedup by fingerprint)',
      () async {
    await db.cardDao.upsert(
      const NameCard(name: 'Grace Hopper', org: 'US Navy'),
      origin: CardOrigin.created,
    );
    final bundle = await service.exportAll();

    // Import back into the SAME store: the card is already present.
    final result = await service.importBundle(bundle);
    expect(result.added, 0);
    expect(result.skipped, 1);
    expect((await db.cardDao.getAll()).length, 1);
  });

  test('import merges only new cards from an overlapping backup', () async {
    await db.cardDao.upsert(const NameCard(name: 'Shared'),
        origin: CardOrigin.created);

    // A second store with the shared card plus a unique one; its bundle is
    // merged into the first.
    final db2 = AppDatabase(NativeDatabase.memory());
    await db2.cardDao
        .upsert(const NameCard(name: 'Shared'), origin: CardOrigin.created);
    await db2.cardDao
        .upsert(const NameCard(name: 'Unique'), origin: CardOrigin.received);
    final bundle = await BackupService(db2.cardDao).exportAll();

    final result = await service.importBundle(bundle);
    expect(result.added, 1); // only 'Unique'
    expect(result.skipped, 1); // 'Shared' already present
    final names =
        (await db.cardDao.getAll()).map((s) => s.card.name).toSet();
    expect(names, {'Shared', 'Unique'});
    await db2.close();
  });
}
