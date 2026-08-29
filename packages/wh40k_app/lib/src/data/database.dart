import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

/// Saved rosters (DESIGN.md §2.2, §4.3).
///
/// The roster and its snapshot are stored as JSON text rather than shredded
/// into relational columns. That is deliberate: both are versioned documents
/// whose *whole point* is to be read back verbatim by a later build of the
/// app, and a snapshot in particular must survive the domain model moving on.
/// Normalising them into tables would tie saved lists to today's schema.
///
/// The columns beside them are the ones a roster list needs to render without
/// parsing every document — nothing more.
@DataClassName('RosterRow')
class Rosters extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get factionId => text()();
  TextColumn get battleSizeId => text()();
  IntColumn get points => integer()();
  IntColumn get unitCount => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  /// When the army was first saved, which is what the list is ordered by.
  ///
  /// Ordering by `updatedAt` meant the list rearranged itself under the
  /// reader: opening an army to look something up moved it to the top, so the
  /// order was a record of what had been touched rather than what the armies
  /// are. Creation is fixed, and a list that does not move is one you can
  /// learn the shape of.
  ///
  /// Rows written before this column existed are backfilled with `updatedAt`,
  /// the only evidence there is — approximate for an army edited since, exact
  /// for one never edited, and stable from then on either way.
  ///
  /// **The stored default is the epoch, and the real one is [clientDefault].**
  /// SQLite refuses `ADD COLUMN` with a non-constant default, so a column
  /// defaulted to `CURRENT_TIMESTAMP` cannot be added to a database that
  /// already exists — every install with armies in it would have failed to
  /// open. A constant satisfies the statement, the migration immediately
  /// overwrites it, and new rows are stamped in Dart before they ever reach
  /// SQL.
  DateTimeColumn get createdAt => dateTime()
      .withDefault(Constant(DateTime.fromMillisecondsSinceEpoch(0)))
      .clientDefault(DateTime.now)();
  TextColumn get rosterJson => text()();
  TextColumn get snapshotJson => text()();

  /// The battle event log (DESIGN.md §7.4), or null when no game is in
  /// progress. Stored as a document for the same reason as the roster: it is
  /// an append-only history whose value is being replayed verbatim.
  TextColumn get battleLogJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A battle that has been played to its end.
///
/// **The log is kept whole, not summarised into columns.** A finished battle
/// is the same append-only history it was while being played (§7.4), so the
/// record it leaves can be replayed — every round's scoring, every stratagem,
/// the table it was fought on. Storing only the final numbers would make the
/// history page cheap to build and impossible to extend.
///
/// The columns beside it are what the list needs to draw a row without
/// decoding a log per battle.
@DataClassName('BattleRow')
class Battles extends Table {
  TextColumn get id => text()();
  TextColumn get rosterId => text()();

  /// The army's name **as it was**, because a roster can be renamed or
  /// deleted afterwards and a finished battle must not change with it.
  TextColumn get rosterName => text()();
  TextColumn get factionId => text()();

  DateTimeColumn get finishedAt => dateTime()();
  IntColumn get rounds => integer()();
  IntColumn get myScore => integer()();
  IntColumn get opponentScore => integer()();
  TextColumn get opponentName => text().nullable()();

  TextColumn get logJson => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// App-wide preferences, one row per key.
///
/// A table rather than a file because the database is already here and
/// already migrated; there is one setting today and no reason to add a second
/// storage mechanism for it.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Rosters, Battles, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// In-memory instance for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.addColumn(rosters, rosters.battleLogJson);
          if (from < 3) await m.createTable(battles);
          if (from < 4) await m.createTable(settings);
          if (from < 5) {
            await m.addColumn(rosters, rosters.createdAt);
            // The default stamps every existing row with the moment of the
            // migration, which would order them all alike; `updatedAt` is the
            // only evidence of age these rows carry.
            await customStatement(
                'UPDATE rosters SET created_at = updated_at');
          }
        },
      );

  /// One preference, or null when it has never been set.
  Future<String?> setting(String key) async {
    final row = await (select(settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watchSetting(String key) =>
      (select(settings)..where((s) => s.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value);

  Future<void> setSetting(String key, String value) => into(settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  /// Finished battles, newest first — every roster's, or one roster's.
  ///
  /// A record keeps the roster id it was played with as well as a copy of the
  /// name, so it can be filed under the army it belongs to without depending
  /// on that army still existing (§7.3.12).
  SimpleSelectStatement<$BattlesTable, BattleRow> _battles(String? rosterId) {
    final query = select(battles)
      ..orderBy([(b) => OrderingTerm.desc(b.finishedAt)]);
    if (rosterId != null) query.where((b) => b.rosterId.equals(rosterId));
    return query;
  }

  Future<List<BattleRow>> allBattles({String? rosterId}) =>
      _battles(rosterId).get();

  Stream<List<BattleRow>> watchBattles({String? rosterId}) =>
      _battles(rosterId).watch();

  Future<void> insertBattle(BattlesCompanion battle) =>
      into(battles).insertOnConflictUpdate(battle);

  Future<int> deleteBattle(String id) =>
      (delete(battles)..where((b) => b.id.equals(id))).go();

  /// Saved armies, newest **made** first.
  ///
  /// Not newest edited: see [Rosters.createdAt].
  SimpleSelectStatement<$RostersTable, RosterRow> _rosters() =>
      select(rosters)
        ..orderBy([
          (r) => OrderingTerm.desc(r.createdAt),
          // Two armies made in the same millisecond — a duplicate, or a
          // restore — still need a fixed order, or the list flickers between
          // rebuilds.
          (r) => OrderingTerm.desc(r.id),
        ]);

  Future<List<RosterRow>> allRosters() => _rosters().get();

  Stream<List<RosterRow>> watchRosters() => _rosters().watch();

  Future<RosterRow?> rosterById(String id) =>
      (select(rosters)..where((r) => r.id.equals(id))).getSingleOrNull();

  Future<void> upsertRoster(RostersCompanion roster) =>
      into(rosters).insertOnConflictUpdate(roster);

  Future<void> saveBattleLog(String rosterId, String? json) =>
      (update(rosters)..where((r) => r.id.equals(rosterId)))
          .write(RostersCompanion(battleLogJson: Value(json)));

  Future<int> deleteRoster(String id) =>
      (delete(rosters)..where((r) => r.id.equals(id))).go();

  Future<int> count() async => (await select(rosters).get()).length;
}

/// Opens the on-device database file.
Future<AppDatabase> openAppDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'structor.sqlite'));
  return AppDatabase(NativeDatabase.createInBackground(file));
}
