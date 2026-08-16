import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/data/army.dart';
import 'package:wh40k_app/src/data/database.dart';
import 'package:wh40k_app/src/data/roster_store.dart';
import 'package:wh40k_core/wh40k_core.dart' as core;

void main() {
  late AppDatabase db;
  late RosterStore store;
  late Army reference;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    reference = await Army.loadReference();
  });

  setUp(() {
    db = AppDatabase.memory();
    store = RosterStore(db);
  });

  tearDown(() => db.close());

  test('a saved roster survives a round trip through the database', () async {
    await store.save(reference);

    final loaded = await store.load(reference.id);
    expect(loaded, isNotNull);
    expect(loaded!.roster.name, '2k ret');
    expect(loaded.points, 2000);
    expect(loaded.combatUnits, hasLength(12));
    expect(loaded.roster.links, hasLength(4));
    expect(loaded.validation.isLegal, isTrue);
  });

  test('the list view renders from columns, not from the documents', () async {
    await store.save(reference);
    final row = (await store.list()).single;

    expect(row.name, '2k ret');
    expect(row.points, 2000);
    expect(row.unitCount, 12);
    expect(row.factionId, 'tau-empire');
    expect(row.battleSizeId, 'strike-force');
  });

  test('saving the same id updates rather than duplicating', () async {
    await store.save(reference);
    await store.save(reference);
    expect(await db.count(), 1);
  });

  test('a roster loads without any faction dataset present', () async {
    // The whole point of storing the snapshot alongside: this rehydrates from
    // the row alone (DESIGN.md §2.2).
    await store.save(reference);
    final loaded = await store.load(reference.id);

    // Selected by member, not by label: units are named after their
    // datasheets now, and this list fields two identical Commander + Crisis
    // Fireknife groups.
    final attached = loaded!.combatUnits
        .firstWhere((u) => u.group.any((g) => g.instanceId == 'u02'));
    final table = attached.weapons(core.WeaponKind.ranged);
    expect(table.isComplete, isTrue);
    expect(table.weapons.map((w) => w.attacks.fixed), containsAll([8, 12]));
  });

  test('a fresh install starts empty', () async {
    expect(await db.count(), 0);
  });

  test('delete removes the roster', () async {
    await store.save(reference);
    await store.delete(reference.id);
    expect(await db.count(), 0);
    expect(await store.load(reference.id), isNull);
  });

  group('battle state', () {
    test('a game persists and replays', () async {
      await store.save(reference);
      expect((await store.loadBattle(reference.id)).events, isEmpty);

      final log = const core.BattleLog()
          .add(const core.SetRound(3))
          .add(const core.AdjustCp(4))
          .add(const core.UseStratagem(
            stratagemId: 'overwatch',
            targetInstanceId: 'u01',
            round: 3,
            phase: 'shooting',
            cp: 1,
          ));
      await store.saveBattle(reference.id, log);

      final restored = await store.loadBattle(reference.id);
      final state = restored.state;
      expect(state.round, 3);
      expect(state.cp, 3, reason: '4 gained, 1 spent');
      expect(state.hasUsedStratagem('u01', phase: 'shooting'), isTrue);
    });

    test('undo persists as a shorter log', () async {
      await store.save(reference);
      final log = const core.BattleLog().add(const core.SetRound(4));
      await store.saveBattle(reference.id, log);
      await store.saveBattle(reference.id, log.undo());

      expect((await store.loadBattle(reference.id)).state.round, 1);
    });

    test('clearing a battle leaves the roster intact', () async {
      await store.save(reference);
      await store.saveBattle(
          reference.id, const core.BattleLog().add(const core.SetRound(2)));
      await store.clearBattle(reference.id);

      expect((await store.loadBattle(reference.id)).events, isEmpty);
      expect(await store.load(reference.id), isNotNull);
    });

    test('recorded casualties shrink the weapon table', () async {
      await store.save(reference);
      await store.saveBattle(
        reference.id,
        const core.BattleLog()
            .add(const core.SetModelsRemaining(instanceId: 'u02', models: 2)),
      );

      final army = (await store.load(reference.id))!;
      final state = (await store.loadBattle(reference.id)).state;
      final attached = army.combatUnits
          .firstWhere((u) => u.group.any((g) => g.instanceId == 'u02'));

      final full = attached.weapons(core.WeaponKind.ranged);
      final wounded = attached.weapons(core.WeaponKind.ranged,
          modelsRemaining: state.modelsRemaining);

      expect(full.weapons.map((w) => w.attacks.fixed), containsAll([8, 12]));
      expect(wounded.weapons.map((w) => w.attacks.fixed), containsAll([8, 8]),
          reason: 'two of three Crisis suits left, so 4 pods not 6');
    });
  });

  test('stored documents are verbatim, not re-derived', () async {
    // A snapshot's value is that a later build can read a list saved today,
    // so the bytes must go in and come back unchanged.
    await store.save(reference);
    final row = (await store.list()).single;
    final restored = core.RosterSnapshot.fromJson(jsonDecode(row.snapshotJson));
    expect(restored.entryCount, reference.snapshot.entryCount);
    expect(restored.units.keys, containsAll(reference.snapshot.units.keys));
  });
}
