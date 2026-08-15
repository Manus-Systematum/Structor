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
        expect(unit!.abilityIds, containsAll(entry.value), reason: entry.key);
      }
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
      expect(const RulesRenderer().render(ability!).text,
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
        final parsed = const TextListParser()
            .parse(File(entry.key).readAsStringSync());
        final result = RosterResolver(
          tau,
          abilityLookup: tau.ability,
          knownAbilities: tau.faction.abilities,
        ).resolve(parsed, factionId: 'tau-empire');

        // Not merely "no errors": an info line about a drone the datasheet
        // does not list is the symptom of a bundle built before the
        // corrections, which is the thing this file exists to catch.
        expect(result.issues, isEmpty,
            reason: result.issues.join('\n'));
        expect(PointsCalculator(tau).price(result.roster).total, entry.value);
        expect(result.printedPoints, entry.value);
      });
    }
  });
}
