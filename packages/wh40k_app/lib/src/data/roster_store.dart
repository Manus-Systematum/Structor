import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:wh40k_core/wh40k_core.dart' as core;

import 'army.dart';
import 'database.dart';

/// Persistence for saved rosters.
///
/// Every roster is stored **with its snapshot**, so a saved list stays
/// renderable even if the faction dataset is later updated, replaced or absent
/// (DESIGN.md §2.2). Loading a roster never touches the network or a catalogue.
class RosterStore {
  final AppDatabase db;

  RosterStore(this.db);

  Stream<List<RosterRow>> watch() => db.watchRosters();

  Future<List<RosterRow>> list() => db.allRosters();

  Future<void> delete(String id) => db.deleteRoster(id);

  /// Rehydrates a saved roster into something the screens can render.
  Future<Army?> load(String id) async {
    final row = await db.rosterById(id);
    if (row == null) return null;
    return Army.fromSnapshot(
      core.Roster.fromJson(jsonDecode(row.rosterJson)),
      core.RosterSnapshot.fromJson(jsonDecode(row.snapshotJson)),
      id: row.id,
    );
  }

  /// Saves a roster, deriving the list-view columns from the army itself so
  /// the roster list never has to parse a document to draw a row.
  Future<void> save(Army army) async {
    await db.upsertRoster(RostersCompanion.insert(
      id: army.id,
      name: army.roster.name,
      factionId: army.roster.factionId,
      battleSizeId: army.roster.battleSizeId,
      points: army.points,
      unitCount: army.combatUnits.length,
      updatedAt: DateTime.now(),
      rosterJson: jsonEncode(army.roster.toJson()),
      snapshotJson: jsonEncode(army.snapshot.toJson()),
    ));
  }

  /// Puts the bundled reference army in on first launch, so a fresh install
  /// has something to look at before anything has been imported.
  Future<void> seedIfEmpty() async {
    if (await db.count() > 0) return;
    final rosterJson =
        await rootBundle.loadString('assets/reference_roster.json');
    final snapshotJson =
        await rootBundle.loadString('assets/reference_snapshot.json');
    await save(Army.fromSnapshot(
      core.Roster.fromJson(jsonDecode(rosterJson)),
      core.RosterSnapshot.fromJson(jsonDecode(snapshotJson)),
      id: 'reference',
    ));
  }
}
