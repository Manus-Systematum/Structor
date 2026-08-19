import 'package:test/test.dart';
import 'package:wh40k_core/wh40k_core.dart';

import 'support.dart';

void main() {
  final available = snapshotAvailable;

  Dataset load(String faction) =>
      Dataset.of(correctedLoader().loadFaction(faction), revision: 'test');

  UnitLoadout loadoutFor(Dataset dataset, String datasheetId) {
    final datasheet = dataset.unit(datasheetId)!;
    final vocabulary = <String>{
      for (final weaponId in datasheet.weaponIds)
        weaponId.endsWith('-$datasheetId')
            ? weaponId.substring(0, weaponId.length - datasheetId.length - 1)
            : weaponId,
      for (final budget in datasheet.wargearBudgets) ...budget.items,
    };
    return UnitLoadout.forDatasheet(
      datasheet,
      catalogue: dataset,
      vocabulary: vocabulary,
    );
  }

  group('wargear options are read at all', () {
    test('the file is parsed and reaches the catalogue', () {
      // It shipped from the first fetch and nothing ever looked at it.
      final dataset = load('tau-empire');
      expect(dataset.wargearOptions('crisis-fireknife-battlesuits'),
          isNotEmpty);
      expect(dataset.faction.wargearOptions, isNotEmpty);
    }, skip: available ? null : 'no snapshot');
  });

  group('fixed kit', () {
    test('a default weapon no option can replace is fixed', () {
      // Battlesuit Fists are in every Crisis model's default loadout and no
      // published option takes them away, so there is no legal list without
      // them and the editor should not offer to remove them.
      final loadout = loadoutFor(load('tau-empire'),
          'crisis-fireknife-battlesuits');
      expect(loadout.fixed.keys, contains('battlesuit-fists'));
      expect(loadout.isFixed('battlesuit-fists'), isTrue);
    }, skip: available ? null : 'no snapshot');

    test('a weapon an option can replace is not fixed', () {
      final loadout = loadoutFor(load('tau-empire'),
          'crisis-fireknife-battlesuits');
      expect(loadout.fixed.keys, isNot(contains('plasma-rifle')));
      expect(loadout.fixed.keys, isNot(contains('missile-pod')));
    }, skip: available ? null : 'no snapshot');

    test('a datasheet publishing no options is fixed, not open', () {
      // **Reversed** (§4.5). The old rule left everything open, reasoning
      // that absence of data is not evidence of a restriction. That is true
      // and it still produced the worse wrong: the editor put a `+` beside
      // every weapon of a character who has no choices at all, which asserts
      // a rule the data never had just as much as locking does — and asserts
      // one that does not exist in the game either.
      final loadout =
          loadoutFor(load('adeptus-astartes'), 'ballistus-dreadnought');
      expect(load('adeptus-astartes').wargearOptions('ballistus-dreadnought'),
          isEmpty);
      expect(loadout.fixed, isNotEmpty);
      for (final weapon in const [
        'ballistus-lascannon',
        'ballistus-missile-launcher',
        'twin-storm-bolter',
      ]) {
        expect(loadout.fixed.keys, contains(weapon));
        expect(loadout.counters.map((c) => c.itemId), isNot(contains(weapon)),
            reason: 'no + beside a weapon nothing offers to change');
      }
      expect(loadout.isUnpublished, isTrue,
          reason: 'the screen still says why the numbers do not move');
    }, skip: available ? null : 'no snapshot');

    test('a character with no options cannot be given a second relic', () {
      // The bug this fixes: Morvenn Vahl publishes no wargear options and
      // carries three weapons she always has. Every one had a `+`.
      final sisters = load('adepta-sororitas');
      final loadout = loadoutFor(sisters, 'morvenn-vahl');
      expect(sisters.wargearOptions('morvenn-vahl'), isEmpty);
      expect(loadout.counters, isEmpty);
      expect(loadout.fixed.keys, contains('lance-of-illumination'));
    }, skip: available ? null : 'no snapshot');
  });

  group('groups are the datasheet spelling out whole selections', () {
    test("the Stealth team's drones are one choice, not three counters", () {
      final loadout = loadoutFor(load('tau-empire'), 'stealth-battlesuits');
      final group = loadout.groups.singleWhere(
          (g) => g.items.contains('gun-drone'));

      // Up to two drones, of different kinds: one gun, one marker, or one of
      // each. Never two of the same.
      expect(
        group.bundles.map((b) => b.toSet()),
        containsAll([
          {'gun-drone'},
          {'marker-drone'},
          {'marker-drone', 'gun-drone'},
        ]),
      );
      for (final bundle in group.bundles) {
        expect(bundle.length, bundle.toSet().length,
            reason: 'no drone bundle doubles up');
      }
    }, skip: available ? null : 'no snapshot');

    test('items in a group are not also offered as loose counters', () {
      final loadout = loadoutFor(load('tau-empire'), 'stealth-battlesuits');
      final grouped = {for (final g in loadout.groups) ...g.items};
      expect(grouped, isNotEmpty);
      for (final counter in loadout.counters) {
        expect(grouped, isNot(contains(counter.itemId)));
      }
    }, skip: available ? null : 'no snapshot');

    test('the carried selection is matched back to its bundle', () {
      final loadout = loadoutFor(load('tau-empire'), 'stealth-battlesuits');
      final group =
          loadout.groups.singleWhere((g) => g.items.contains('gun-drone'));
      final both = group.bundles
          .indexWhere((b) => b.length == 2);

      expect(group.selectedIndex({'gun-drone': 1, 'marker-drone': 1}), both);
      expect(group.selectedIndex(const {}), isNull);
      // Two of the same is off-menu, and must read as off-menu rather than be
      // quietly matched to something else.
      expect(group.selectedIndex({'gun-drone': 2}), isNull);
    }, skip: available ? null : 'no snapshot');

    test('a bare cap on single items is not treated as an enumeration', () {
      // The Coldstar's ten weapons under `max_count: 3` are ten independent
      // items, not ten alternatives.
      final loadout = loadoutFor(
          load('tau-empire'), 'commander-in-coldstar-battlesuit');
      for (final group in loadout.groups) {
        expect(group.bundles.any((b) => b.length > 1), isTrue);
      }
    }, skip: available ? null : 'no snapshot');
  });

  group('a stated cap is information, not a gate', () {
    test('the reference list itself exceeds one', () {
      // Four T'au flamers on a Commander whose record caps them at three, in a
      // validated 2,000 point export. A cap that refused the tap would refuse
      // this army.
      final dataset = load('tau-empire');
      final capped = dataset
          .wargearOptions('commander-in-coldstar-battlesuit')
          .where((o) => o.maxCount != null);
      expect(capped, isNotEmpty);
      expect(capped.map((o) => o.maxCount), everyElement(lessThan(4)));
    }, skip: available ? null : 'no snapshot');

    test('the cap is carried on the counter for the editor to show', () {
      final loadout = loadoutFor(load('tau-empire'), 'stealth-battlesuits');
      final fusion = loadout.counters
          .singleWhere((c) => c.itemId == 'fusion-blaster');
      expect(fusion.statedMax, 2);
      expect(fusion.replaces, contains('burst-cannon'));
    }, skip: available ? null : 'no snapshot');
  });
}
