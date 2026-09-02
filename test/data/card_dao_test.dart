import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/data/database.dart';
import 'package:namecard_vision/model/card.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('upsert then getAll roundtrips the card', () async {
    const card = NameCard(
      name: 'Ada Lovelace',
      org: 'Engine Co',
      title: 'Analyst',
      tags: ['maths'],
    );
    final id = await db.cardDao.upsert(card, origin: CardOrigin.created);
    final all = await db.cardDao.getAll();
    expect(all.length, 1);
    expect(all.first.id, id);
    expect(all.first.card.name, 'Ada Lovelace');
    expect(all.first.origin, CardOrigin.created);
    expect(all.first.fingerprintHex.length, 64);
  });

  test('FTS search matches by name/org, token and prefix', () async {
    await db.cardDao.upsert(
        const NameCard(name: 'Ada Lovelace', org: 'Analytical Engine'),
        origin: CardOrigin.created);
    await db.cardDao.upsert(
        const NameCard(name: 'Alan Turing', org: 'Bletchley'),
        origin: CardOrigin.received);

    expect((await db.cardDao.search('ada')).length, 1);
    expect((await db.cardDao.search('turing')).length, 1);
    expect((await db.cardDao.search('engine')).length, 1);
    expect((await db.cardDao.search('lov')).length, 1); // prefix match
    expect((await db.cardDao.search('zzz')).length, 0);
    expect((await db.cardDao.search('')).length, 2); // empty -> all
  });

  test('editing a card keeps FTS in sync (triggers)', () async {
    final id = await db.cardDao
        .upsert(const NameCard(name: 'Grace Hopper'), origin: CardOrigin.created);
    expect((await db.cardDao.search('hopper')).length, 1);

    await db.cardDao.upsert(const NameCard(name: 'Grace Murray'),
        origin: CardOrigin.created, id: id);
    expect((await db.cardDao.search('hopper')).length, 0);
    expect((await db.cardDao.search('murray')).length, 1);
  });

  test('deleteById removes from cards and search index', () async {
    final id = await db.cardDao
        .upsert(const NameCard(name: 'Test User'), origin: CardOrigin.created);
    await db.cardDao.deleteById(id);
    expect((await db.cardDao.getAll()).isEmpty, isTrue);
    expect((await db.cardDao.search('test')).isEmpty, isTrue);
  });

  test('cards default to unpinned and not-mine', () async {
    await db.cardDao
        .upsert(const NameCard(name: 'Ada'), origin: CardOrigin.created);
    final s = (await db.cardDao.getAll()).single;
    expect(s.pinned, isFalse);
    expect(s.isMine, isFalse);
  });

  test('upsert can mark a card as the user\'s own', () async {
    final id = await db.cardDao.upsert(const NameCard(name: 'Me'),
        origin: CardOrigin.created, isMine: true);
    expect((await db.cardDao.getById(id))!.isMine, isTrue);
  });

  test('setPinned / setMine toggle independently', () async {
    final id = await db.cardDao
        .upsert(const NameCard(name: 'Ada'), origin: CardOrigin.created);

    await db.cardDao.setPinned(id, true);
    expect((await db.cardDao.getById(id))!.pinned, isTrue);
    expect((await db.cardDao.getById(id))!.isMine, isFalse);

    await db.cardDao.setMine(id, true);
    final s = (await db.cardDao.getById(id))!;
    expect(s.pinned, isTrue);
    expect(s.isMine, isTrue);
  });

  test('editing a card preserves pin and role (isMine omitted)', () async {
    final id = await db.cardDao.upsert(const NameCard(name: 'Ada'),
        origin: CardOrigin.created, isMine: true);
    await db.cardDao.setPinned(id, true);

    // Re-save without passing isMine: flags must survive the edit.
    await db.cardDao.upsert(const NameCard(name: 'Ada Lovelace'),
        origin: CardOrigin.created, id: id);
    final s = (await db.cardDao.getById(id))!;
    expect(s.card.name, 'Ada Lovelace');
    expect(s.pinned, isTrue);
    expect(s.isMine, isTrue);
  });
}
