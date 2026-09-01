import 'package:drift/drift.dart';

import 'card_dao.dart';

part 'database.g.dart';

/// Where a stored card came from.
enum CardOrigin { created, received }

/// One namecard row.
///
/// [dataJson] holds the full [NameCard] (source of truth for the fingerprint);
/// [name]/[org]/[title]/[tags]/[note] are denormalized copies kept for list
/// display and full-text search. [avatar] holds the raw image bytes.
class Cards extends Table {
  TextColumn get id => text()();
  TextColumn get fingerprintHex => text()();
  TextColumn get origin => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get org => text().withDefault(const Constant(''))();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get tags => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get dataJson => text()();
  BlobColumn get avatar => blob().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Cards], daos: [CardDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createFts();
        },
      );

  /// Standalone FTS5 index over the searchable columns, kept in sync with the
  /// `cards` table by triggers (external-content pattern keyed on rowid).
  Future<void> _createFts() async {
    await customStatement(
      "CREATE VIRTUAL TABLE card_fts USING fts5("
      "name, org, title, tags, note, content='cards', content_rowid='rowid');",
    );
    await customStatement('''
      CREATE TRIGGER cards_ai AFTER INSERT ON cards BEGIN
        INSERT INTO card_fts(rowid, name, org, title, tags, note)
        VALUES (new.rowid, new.name, new.org, new.title, new.tags, new.note);
      END;''');
    await customStatement('''
      CREATE TRIGGER cards_ad AFTER DELETE ON cards BEGIN
        INSERT INTO card_fts(card_fts, rowid, name, org, title, tags, note)
        VALUES ('delete', old.rowid, old.name, old.org, old.title, old.tags, old.note);
      END;''');
    await customStatement('''
      CREATE TRIGGER cards_au AFTER UPDATE ON cards BEGIN
        INSERT INTO card_fts(card_fts, rowid, name, org, title, tags, note)
        VALUES ('delete', old.rowid, old.name, old.org, old.title, old.tags, old.note);
        INSERT INTO card_fts(rowid, name, org, title, tags, note)
        VALUES (new.rowid, new.name, new.org, new.title, new.tags, new.note);
      END;''');
  }
}
