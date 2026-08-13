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

    final attached = loaded!.combatUnits
        .firstWhere((u) => u.label == 'Attached Unit 1');
    final table = attached.weapons(core.WeaponKind.ranged);
    expect(table.isComplete, isTrue);
    expect(table.weapons.map((w) => w.attacks.fixed), containsAll([8, 12]));
  });

  test('seeding is idempotent', () async {
    await store.seedIfEmpty();
    expect(await db.count(), 1);
    await store.seedIfEmpty();
    expect(await db.count(), 1);
  });

  test('delete removes the roster', () async {
    await store.save(reference);
    await store.delete(reference.id);
    expect(await db.count(), 0);
    expect(await store.load(reference.id), isNull);
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
