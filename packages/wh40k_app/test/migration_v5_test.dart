import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wh40k_app/src/data/database.dart';

/// Opening a database written by version 4, which is what every install that
/// already has armies in it is.
///
/// The column added in version 5 is ordered by, so a migration that failed
/// would not merely lose the ordering — the database would refuse to open and
/// the armies would be gone from the app. `ALTER TABLE ... ADD COLUMN` is also
/// the statement SQLite is fussiest about, so this runs the real thing against
/// the real schema rather than trusting that it parses.
void main() {
  late File file;

  setUp(() {
    file = File(
        '${Directory.systemTemp.createTempSync('structor').path}/app.sqlite');

    // The v4 shape, written the way v4 wrote it.
    final raw = sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE rosters (
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        faction_id TEXT NOT NULL,
        battle_size_id TEXT NOT NULL,
        points INTEGER NOT NULL,
        unit_count INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        roster_json TEXT NOT NULL,
        snapshot_json TEXT NOT NULL,
        battle_log_json TEXT NULL,
        PRIMARY KEY (id)
      );
      CREATE TABLE battles (
        id TEXT NOT NULL, roster_id TEXT NOT NULL, roster_name TEXT NOT NULL,
        faction_id TEXT NOT NULL, finished_at INTEGER NOT NULL,
        rounds INTEGER NOT NULL, my_score INTEGER NOT NULL,
        opponent_score INTEGER NOT NULL, opponent_name TEXT NULL,
        log_json TEXT NOT NULL, PRIMARY KEY (id)
      );
      CREATE TABLE settings (
        key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY (key)
      );
      PRAGMA user_version = 4;
    ''');
    for (final (id, name, at) in [
      ('r1', 'Made first, edited never', DateTime(2026, 3, 1)),
      ('r2', 'Made later, edited since', DateTime(2026, 7, 1)),
    ]) {
      raw.execute(
        'INSERT INTO rosters (id, name, faction_id, battle_size_id, points, '
        'unit_count, updated_at, roster_json, snapshot_json) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [id, name, 'tau-empire', 'strike-force', 0, 0,
            at.millisecondsSinceEpoch ~/ 1000, '{}', '{}'],
      );
    }
    raw.close();
  });

  tearDown(() => file.parent.deleteSync(recursive: true));

  test('a version 4 database opens, and keeps its armies', () async {
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final rows = await db.allRosters();
    expect(rows.map((r) => r.name),
        ['Made later, edited since', 'Made first, edited never']);
  });

  test('rows written before the column get their age from updated_at',
      () async {
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final rows = await db.allRosters();
    for (final row in rows) {
      expect(row.createdAt, row.updatedAt,
          reason: 'the only evidence of age a v4 row carries');
    }
  });

  test('and a save after the migration keeps that age', () async {
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final before = (await db.rosterById('r1'))!;
    await db.upsertRoster(RostersCompanion.insert(
      id: 'r1',
      name: 'Renamed',
      factionId: before.factionId,
      battleSizeId: before.battleSizeId,
      points: 10,
      unitCount: 1,
      updatedAt: DateTime(2026, 8, 29),
      createdAt: Value(before.createdAt),
      rosterJson: '{}',
      snapshotJson: '{}',
    ));

    final after = (await db.rosterById('r1'))!;
    expect(after.createdAt, before.createdAt);
    expect(after.name, 'Renamed');
  });
}
