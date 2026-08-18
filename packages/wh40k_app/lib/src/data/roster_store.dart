import 'dart:convert';

import 'package:drift/drift.dart' show Value;

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

  /// The battle in progress for [rosterId], or an empty log if none.
  Future<core.BattleLog> loadBattle(String rosterId) async {
    final row = await db.rosterById(rosterId);
    final json = row?.battleLogJson;
    if (json == null) return const core.BattleLog();
    return core.BattleLog.fromJson(jsonDecode(json));
  }

  Future<void> saveBattle(String rosterId, core.BattleLog log) =>
      db.saveBattleLog(rosterId, jsonEncode(log.toJson()));

  Future<void> clearBattle(String rosterId) =>
      db.saveBattleLog(rosterId, null);

  /// Finished battles, newest first. Scoped to one roster when [rosterId] is
  /// given, which is how the Play tab shows an army its own history and not
  /// somebody else's.
  Stream<List<BattleRow>> watchBattles({String? rosterId}) =>
      db.watchBattles(rosterId: rosterId);

  Future<List<BattleRow>> battles({String? rosterId}) =>
      db.allBattles(rosterId: rosterId);

  Future<void> deleteBattleRecord(String id) => db.deleteBattle(id);

  /// Files the battle away and clears the board.
  ///
  /// The two halves are one action on purpose: a finished battle that stayed
  /// in `battleLogJson` would still be the roster's *current* game, and the
  /// Play tab would open on a game that is over.
  ///
  /// **Nothing is summarised away.** The whole log is written, so a record
  /// can be replayed later; the columns beside it exist only so the list of
  /// battles draws without decoding one document per row.
  Future<void> finishBattle(Army army, core.BattleLog log) async {
    final state = log.state;
    await db.insertBattle(BattlesCompanion.insert(
      id: 'b${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      rosterId: army.id,
      // Copied, not referenced: the roster can be renamed or deleted and a
      // finished battle must not change with it.
      rosterName: army.roster.name,
      factionId: army.roster.factionId,
      finishedAt: DateTime.now(),
      rounds: state.round,
      myScore: state.me.total,
      opponentScore: state.opponent.total,
      opponentName: Value(state.setup?.opponentName),
      logJson: jsonEncode(log.toJson()),
    ));
    await clearBattle(army.id);
  }

  Future<void> delete(String id) => db.deleteRoster(id);

  /// Copies a saved roster under a new name.
  ///
  /// **The snapshot is copied verbatim rather than rebuilt.** A copy is made
  /// to try a variant of a list that already exists, so it has to be the same
  /// list — rebuilding it from today's dataset would silently hand back a
  /// differently-costed army, which is the thing §2.2 exists to prevent.
  Future<Army?> duplicate(String id, {required String name}) async {
    final row = await db.rosterById(id);
    if (row == null) return null;
    final army = Army.fromSnapshot(
      core.Roster.fromJson(jsonDecode(row.rosterJson)).copyWith(name: name),
      core.RosterSnapshot.fromJson(jsonDecode(row.snapshotJson)),
      id: 'r${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
    );
    await save(army);
    return army;
  }

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
}

/// A name for a copy of [base] that no army in [taken] is already using.
///
/// Plain `Copy` first, because that is what one copy is called; the number
/// only appears once it has to distinguish something.
String copyName(String base, Iterable<String> taken) {
  final used = taken.map((n) => n.trim()).toSet();
  final first = '$base Copy';
  if (!used.contains(first)) return first;
  for (var n = 2;; n++) {
    if (!used.contains('$first $n')) return '$first $n';
  }
}
