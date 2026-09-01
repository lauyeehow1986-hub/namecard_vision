import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../model/card.dart';
import '../model/fingerprint_hash.dart';
import 'database.dart';

part 'card_dao.g.dart';

/// Data-access for cards: persistence + FTS5 search, exposing the domain
/// [NameCard] rather than raw Drift rows to the rest of the app.
@DriftAccessor(tables: [Cards])
class CardDao extends DatabaseAccessor<AppDatabase> with _$CardDaoMixin {
  CardDao(super.db);

  static final _rng = Random.secure();

  static String newId() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Insert a new card or replace an existing one (by [id]).
  /// Returns the id used. Recomputes the fingerprint and denormalized search
  /// columns from [card] every time so they never drift out of sync.
  Future<String> upsert(
    NameCard card, {
    required CardOrigin origin,
    String? id,
    Uint8List? avatar,
    DateTime? createdAt,
  }) async {
    final now = DateTime.now();
    final rowId = id ?? newId();
    final fp = Fingerprint.ofCard(card);
    await into(cards).insertOnConflictUpdate(
      CardsCompanion.insert(
        id: rowId,
        fingerprintHex: fp.hex,
        origin: origin.name,
        dataJson: jsonEncode(card.toJson()),
        name: Value(card.name),
        org: Value(card.org),
        title: Value(card.title),
        tags: Value(card.tags.join(' ')),
        note: Value(card.note),
        avatar: Value(avatar),
        createdAt: createdAt ?? now,
        updatedAt: now,
      ),
    );
    return rowId;
  }

  Future<void> deleteById(String id) =>
      (delete(cards)..where((t) => t.id.equals(id))).go();

  /// All cards, newest-updated first, as a live stream.
  Stream<List<StoredCard>> watchAll() {
    final q = select(cards)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return q.map(_toStored).watch();
  }

  Future<List<StoredCard>> getAll() {
    final q = select(cards)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return q.map(_toStored).get();
  }

  Future<StoredCard?> getById(String id) async {
    final row =
        await (select(cards)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toStored(row);
  }

  /// Full-text search over name/org/title/tags/note. The user query is turned
  /// into a prefix match per token so partial words match while typing.
  Future<List<StoredCard>> search(String query) async {
    final match = _toFtsQuery(query);
    if (match.isEmpty) return getAll();
    final rows = await customSelect(
      'SELECT c.* FROM cards c '
      'JOIN card_fts ON card_fts.rowid = c.rowid '
      'WHERE card_fts MATCH ? ORDER BY rank',
      variables: [Variable<String>(match)],
      readsFrom: {cards},
    ).get();
    return rows.map((r) => _toStored(cards.map(r.data))).toList();
  }

  StoredCard _toStored(Card row) => StoredCard(
        id: row.id,
        origin: CardOrigin.values.byName(row.origin),
        fingerprintHex: row.fingerprintHex,
        card: NameCard.fromJson(
            jsonDecode(row.dataJson) as Map<String, dynamic>),
        avatar: row.avatar,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  /// Escape and turn a free-text query into a token-prefix FTS5 expression,
  /// e.g. `ada eng` -> `"ada"* "eng"*`.
  static String _toFtsQuery(String raw) {
    final tokens = raw
        .split(RegExp(r'\s+'))
        .where((t) => t.trim().isNotEmpty)
        .map((t) => '"${t.replaceAll('"', '""')}"*');
    return tokens.join(' ');
  }
}

/// A card as persisted: the domain [card] plus storage metadata.
class StoredCard {
  final String id;
  final CardOrigin origin;
  final String fingerprintHex;
  final NameCard card;
  final Uint8List? avatar;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StoredCard({
    required this.id,
    required this.origin,
    required this.fingerprintHex,
    required this.card,
    required this.avatar,
    required this.createdAt,
    required this.updatedAt,
  });
}
