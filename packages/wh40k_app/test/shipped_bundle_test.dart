import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/data/dataset_repository.dart';
import 'package:wh40k_core/wh40k_core.dart';

/// The bundles in `assets/` are built by hand with `bin/bundle.dart`, and
/// nothing else notices when that step is skipped: the core tests read
/// `data/40kdc` through a loader that applies corrections live, so they stay
/// green while the app ships the uncorrected data.
///
/// These tests read what the app actually reads.
void main() {
  late DatasetRepository repo;
  late Dataset tau;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    repo = DatasetRepository();
    tau = await repo.faction('tau-empire');
  });

  group('corrections reached the shipped bundle', () {
    test('the datasheets that were missing their drones now list them', () {
      // §3.8. Each of these was importing without its drones.
      //
      // Checked against the whole rule vocabulary rather than `ability_ids`:
      // a drone is optional wargear, and both sources say so — 40kdc as a
      // budget line, BSData through a `Drones (0-2)` group. Which field it
      // lands in is bookkeeping; that the datasheet can take one is the
      // thing being asserted (§3.10).
      const expected = {
        'commander-in-enforcer-battlesuit': ['gun-drone', 'shield-drone'],
        'commander-in-coldstar-battlesuit': ['gun-drone', 'shield-drone'],
        'crisis-starscythe-battlesuits': ['gun-drone', 'shield-drone'],
        'stealth-battlesuits': ['gun-drone', 'marker-drone'],
        'broadside-battlesuits': ['missile-drone'],
        'ghostkeel-battlesuit': ['battlesuit-support-system'],
      };
      for (final entry in expected.entries) {
        final unit = tau.unit(entry.key);
        expect(unit, isNotNull, reason: entry.key);
        expect(unit!.ruleVocabulary, containsAll(entry.value),
            reason: entry.key);
      }
    });

    test('a Commander is offered drones, not a Shield Generator', () {
      // The Shield Generator is a Riptide and Stormsurge support system.
      // Upstream lists it in the Enforcer Commander's wargear budget, where
      // it sits beside the drones and reads as the shield you meant — and
      // taking it spends points on a rule the model does not have.
      final enforcer = tau.unit('commander-in-enforcer-battlesuit')!;
      expect(enforcer.ruleVocabulary, contains('shield-drone'));
      expect(enforcer.ruleVocabulary, isNot(contains('shield-generator')));

      // The Coldstar **may buy** one and does not start with it. A
      // correction written against 40kdc — which listed the generator as
      // both a standard ability and an option — made it standard, so the
      // unit card printed "the bearer has a 4+ invulnerable save" and the
      // statline showed INV 4+ on a Commander that had bought nothing.
      // BSData lists it as an option on this datasheet and on the Enforcer,
      // and standard on neither.
      final coldstar = tau.unit('commander-in-coldstar-battlesuit')!;
      expect(coldstar.abilityIds, isNot(contains('shield-generator')),
          reason: 'an option, so not a rule the model already has');
      expect(coldstar.wargearVocabulary, contains('shield-generator'),
          reason: 'still offered — the Commander may buy one');
      expect(coldstar.ruleVocabulary, contains('shield-drone'));
    });

    test('a drone fires its own gun, at BS5+', () {
      for (final id in [
        'drone-missile-pod',
        'drone-burst-cannon',
        'drone-twin-pulse-carbine',
        'twin-pulse-blaster',
      ]) {
        expect(tau.weapon(id)?.profiles.single.skill, '5', reason: id);
      }
    });

    test('Advanced Armour is restricted to mortal wounds', () {
      final ability = tau.ability('advanced-armour');
      expect(ability, isNotNull);
      expect(const RulesRenderer().render(ability!).derived,
          'Against mortal wounds: Feel No Pain 4+.');
    });
  });

  group('the real exports import clean from the bundle', () {
    // Both are in the core package's fixtures; this reads them through the
    // app's own path — bundle, not loader.
    const fixtures = {
      '../wh40k_core/test/fixtures/war_organ_export.txt': 2000,
      '../wh40k_core/test/fixtures/war_organ_incursion_1000.txt': 995,
    };

    for (final entry in fixtures.entries) {
      test('${entry.key.split('/').last} imports with no issues at all', () {
        final parsed =
            const TextListParser().parse(File(entry.key).readAsStringSync());
        final result = RosterResolver(
          tau,
          abilityLookup: tau.ability,
          knownAbilities: tau.faction.abilities,
        ).resolve(parsed, factionId: 'tau-empire');

        // Not merely "no errors": an info line about a drone the datasheet
        // does not list is the symptom of a bundle built before the
        // corrections, which is the thing this file exists to catch.
        expect(result.issues, isEmpty, reason: result.issues.join('\n'));
        expect(PointsCalculator(tau).price(result.roster).total, entry.value);
        expect(result.printedPoints, entry.value);
      });
    }
  });

  group('every faction ships', () {
    late List<BundleEntry> factions;

    setUpAll(() async {
      factions = await repo.availableFactions();
    });

    test('all thirty-five of them, by their published names', () {
      expect(factions, hasLength(35));
      // Title-casing the id gives "Tau Empire"; the faction record gives the
      // name the game uses. Bundling `factions.json` is what makes the
      // difference visible.
      expect(factions.map((f) => f.name), contains('T’au Empire'));
      expect(factions.map((f) => f.id), containsAll(['orks', 'tyranids']));
    });

    test('and every one loads a dataset with datasheets in it', () async {
      for (final entry in factions) {
        final dataset = await repo.faction(entry.id);
        expect(dataset.allUnits, isNotEmpty, reason: entry.id);
        expect(dataset.allDetachments, isNotEmpty, reason: entry.id);
      }
    });
  });

  group('a chapter fields its parent’s datasheets', () {
    late Dataset bloodAngels;
    late Dataset astartes;

    setUpAll(() async {
      bloodAngels = await repo.faction('blood-angels');
      astartes = await repo.faction('adeptus-astartes');
    });

    test('the manifest says which parent', () async {
      final entry = (await repo.availableFactions())
          .firstWhere((f) => f.id == 'blood-angels');
      expect(entry.parentId, 'adeptus-astartes');
    });

    test('datasheets are inherited, not published twice', () {
      // The parent's datasheets are still not copied into the chapter bundle
      // — that would add roughly 840 KB across the twelve for data already
      // downloaded. What changed is that the chapter now publishes some of
      // its own too, so this is no longer an equality (§3.10).
      expect(bloodAngels.allUnits, isNotEmpty);
      expect(
          bloodAngels.allUnits.length, greaterThan(astartes.allUnits.length));

      final ids = {for (final u in bloodAngels.allUnits) u.id};
      expect(ids, contains('intercessor-squad'), reason: 'inherited');
      expect(ids, contains('sanguinary-guard'), reason: 'its own');
    });

    test('but detachments and stratagems are its own', () {
      final chapterOnly = bloodAngels.allDetachments
          .map((d) => d.id)
          .toSet()
          .difference(astartes.allDetachments.map((d) => d.id).toSet());
      expect(chapterOnly, isNotEmpty,
          reason: 'the reason to play the chapter at all');
      expect(chapterOnly, contains('liberator-assault-group'));
    });

    test('and so is its army rule', () {
      expect(bloodAngels.faction.factionRuleId, 'the-red-thirst');
      expect(astartes.faction.factionRuleId, isNot('the-red-thirst'));
    });
  });

  test('the army rule survives the trip through the bundle', () async {
    // It did not. `factions.json` was never bundled, so `factionRuleId`
    // arrived null in the app and every roster built or imported there lost
    // the one rule its whole army has. The CLI reads the snapshot directly
    // and kept it, which is exactly why nothing noticed.
    expect(tau.faction.factionRuleId, 'for-the-greater-good');
    expect(tau.faction.factionName, 'T’au Empire');

    // And it has to reach the snapshot, which is what the play screens read.
    final builder = await repo.snapshotBuilder('tau-empire');
    final parsed = const TextListParser().parse(
        File('../wh40k_core/test/fixtures/war_organ_export.txt')
            .readAsStringSync());
    final result = RosterResolver(
      tau,
      abilityLookup: tau.ability,
      knownAbilities: tau.faction.abilities,
    ).resolve(parsed, factionId: 'tau-empire');
    expect(builder.build(result.roster).factionRuleId, 'for-the-greater-good');
  });
}
