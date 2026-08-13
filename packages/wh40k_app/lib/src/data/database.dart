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
  TextColumn get rosterJson => text()();
  TextColumn get snapshotJson => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Rosters])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// In-memory instance for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  Future<List<RosterRow>> allRosters() =>
      (select(rosters)..orderBy([(r) => OrderingTerm.desc(r.updatedAt)])).get();

  Stream<List<RosterRow>> watchRosters() =>
      (select(rosters)..orderBy([(r) => OrderingTerm.desc(r.updatedAt)]))
          .watch();

  Future<RosterRow?> rosterById(String id) =>
      (select(rosters)..where((r) => r.id.equals(id))).getSingleOrNull();

  Future<void> upsertRoster(RostersCompanion roster) =>
      into(rosters).insertOnConflictUpdate(roster);

  Future<int> deleteRoster(String id) =>
      (delete(rosters)..where((r) => r.id.equals(id))).go();

  Future<int> count() async =>
      (await select(rosters).get()).length;
}

/// Opens the on-device database file.
Future<AppDatabase> openAppDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'structor.sqlite'));
  return AppDatabase(NativeDatabase.createInBackground(file));
}
