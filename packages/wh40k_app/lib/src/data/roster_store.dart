import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import 'package:wh40k_core/wh40k_core.dart' as core;

import 'army.dart';
import 'database.dart';
import 'play_density.dart';

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

  Future<void> clearBattle(String rosterId) => db.saveBattleLog(rosterId, null);

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

  /// Whether Legends datasheets are offered in the builder.
  ///
  /// **Off by default.** 485 of 1,857 datasheets are shelved out of the
  /// tournament pool, and offering them beside the rest makes the picker a
  /// third longer with entries most events will not take. Hidden rather than
  /// removed: a Legends game is a real game and the datasheets are real, so
  /// this is a preference and not a filter baked into the data.
  static const _legendsKey = 'show-legends';

  Future<bool> showLegends() async => await db.setting(_legendsKey) == 'true';

  /// How much detail the turn page shows for one roster.
  ///
  /// Per roster, not per player: you know one army and not the next, and a
  /// global preference is wrong every time a new list is started (§7.3.13).
  Future<PlayDensity?> density(String rosterId) async =>
      switch (await db.setting('density:$rosterId')) {
        final String raw => PlayDensity.parse(raw),
        null => null,
      };

  Future<void> setDensity(String rosterId, PlayDensity density) =>
      db.setSetting('density:$rosterId', density.name);

  Stream<bool> watchShowLegends() =>
      db.watchSetting(_legendsKey).map((v) => v == 'true');

  Future<void> setShowLegends(bool on) =>
      db.setSetting(_legendsKey, on ? 'true' : 'false');

  Future<void> delete(String id) => db.deleteRoster(id);

  /// Rebuilds a saved army's snapshot from today's dataset, keeping the list
  /// itself exactly as it is.
  ///
  /// **The one deliberate way past §2.2.** A saved roster carries a copy of
  /// the data it was built from so that it stops moving, which is what makes
  /// a list you wrote in March still readable in September. The cost is that
  /// it also stops gaining: an army saved before stratagem text existed shows
  /// no stratagems in play mode however many times the app is updated, and
  /// nothing on screen explains why.
  ///
  /// So this exists, and it is a menu item rather than something that happens
  /// on launch. Rebuilding silently is precisely the failure §2.2 was written
  /// against — it would re-cost an army the night before a game.
  ///
  /// The [Roster] is untouched: same units, same loadouts, same detachments.
  /// Only the denormalised copy beside it is replaced, so what changes is
  /// what the *data* says about those choices — points, rules, wording.
  /// Returns the army as it now stands, or null when there is no such row.
  /// The [builder] must be for this army's own faction; the row carries it.
  Future<Army?> refreshSnapshot(
    String id, {
    required core.SnapshotBuilder builder,
  }) async {
    final army = await rebuilt(id, builder: builder);
    if (army != null) await save(army);
    return army;
  }

  /// The same rebuild, **not** saved.
  ///
  /// For asking whether an army would change at all before offering to change
  /// it: an army already built from today's data has nothing to update, and a
  /// dialog about it is a question with one answer.
  Future<Army?> rebuilt(
    String id, {
    required core.SnapshotBuilder builder,
  }) async {
    final row = await db.rosterById(id);
    if (row == null) return null;
    final roster = core.Roster.fromJson(jsonDecode(row.rosterJson));
    return Army.fromSnapshot(roster, builder.build(roster), id: row.id);
  }

  /// Whether [army] says anything its saved copy does not.
  Future<bool> differsFromSaved(Army army) async {
    final row = await db.rosterById(army.id);
    return row != null &&
        jsonEncode(army.snapshot.toJson()) != row.snapshotJson;
  }

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
    // **Creation is set once and never rewritten.** The upsert would otherwise
    // stamp a new one on every autosave, and the list — ordered by it — would
    // put whatever was last edited on top, which is the ordering this column
    // exists to replace.
    final existing = await db.rosterById(army.id);
    await db.upsertRoster(RostersCompanion.insert(
      id: army.id,
      name: army.roster.name,
      factionId: army.roster.factionId,
      battleSizeId: army.roster.battleSizeId,
      points: army.points,
      unitCount: army.combatUnits.length,
      updatedAt: DateTime.now(),
      createdAt: Value(existing?.createdAt ?? DateTime.now()),
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
