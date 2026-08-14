import 'dart:io';

import 'package:test/test.dart';
import 'package:wh40k_core/wh40k_core.dart';

const _yaml = '''
abilities:
  - faction: tau-empire
    id: advanced-armour
    reason: Only applies to mortal wounds.
    upstream: not yet reported
    effect:
      type: conditional
      condition:
        type: damage-is-mortal
      effect:
        type: feel-no-pain
        modifier:
          threshold: 4
''';

List<Object?> get _records => [
      {
        'ability_id': 'advanced-armour',
        'name': 'Advanced Armour',
        'effect': {
          'type': 'feel-no-pain',
          'modifier': {'threshold': 4},
        },
      },
      {
        'ability_id': 'for-the-greater-good',
        'name': 'For the Greater Good',
        'effect': {'type': 'fight-first'},
      },
    ];

void main() {
  group('parsing', () {
    test('an ability correction round-trips its effect and its reason', () {
      final corrections = DataCorrections.parse(_yaml).abilities;
      expect(corrections, hasLength(1));
      final only = corrections.single;
      expect(only.faction, 'tau-empire');
      expect(only.abilityId, 'advanced-armour');
      expect(only.upstream, 'not yet reported');
      expect(only.effect['type'], 'conditional');
      // YAML nodes are not JSON-encodable, so the nested maps must have been
      // copied into plain ones on the way through.
      expect(only.effect, isA<Map<String, Object?>>());
      expect(
        (only.effect['condition']! as Map)['type'],
        'damage-is-mortal',
      );
    });

    test('a correction with no reason is not applied', () {
      // Same rule as an accepted divergence: unexplained is indistinguishable
      // from unexamined.
      const unexplained = '''
abilities:
  - faction: tau-empire
    id: advanced-armour
    effect:
      type: fight-first
''';
      expect(DataCorrections.parse(unexplained).abilities, isEmpty);
    });

    test('an empty or malformed document yields no corrections', () {
      expect(DataCorrections.parse('').isEmpty, isTrue);
      expect(DataCorrections.parse('abilities: []').isEmpty, isTrue);
      expect(DataCorrections.parse('- just: a list').isEmpty, isTrue);
    });
  });

  group('application', () {
    test('the named ability is replaced and the rest left alone', () {
      final result = DataCorrections.parse(_yaml)
          .applyToAbilities('tau-empire', _records);

      expect(result.applied, hasLength(1));
      expect(result.unmatched, isEmpty);

      final corrected = result.records
          .cast<Map<String, Object?>>()
          .firstWhere((r) => r['ability_id'] == 'advanced-armour');
      expect((corrected['effect']! as Map)['type'], 'conditional');
      // Provenance travels with the record rather than living in a build log.
      expect((corrected['corrected']! as Map)['reason'], isNotEmpty);

      final untouched = result.records
          .cast<Map<String, Object?>>()
          .firstWhere((r) => r['ability_id'] == 'for-the-greater-good');
      expect((untouched['effect']! as Map)['type'], 'fight-first');
      expect(untouched.containsKey('corrected'), isFalse);
    });

    test("another faction is not touched by a T'au correction", () {
      final records = _records;
      final result =
          DataCorrections.parse(_yaml).applyToAbilities('necrons', records);
      expect(result.applied, isEmpty);
      expect(result.unmatched, isEmpty,
          reason: 'a correction for a faction not being built is not stale');
      expect(result.records, same(records));
    });

    test('the input records are not mutated', () {
      // The cross-check reads upstream data while the bundler writes corrected
      // data; the two must not see each other's view.
      final records = _records;
      DataCorrections.parse(_yaml).applyToAbilities('tau-empire', records);
      expect(
        ((records.first! as Map)['effect']! as Map)['type'],
        'feel-no-pain',
      );
    });

    test('a wildcard faction matches every faction that has the ability', () {
      const wildcard = '''
abilities:
  - faction: "*"
    id: advanced-armour
    reason: Core abilities are transcribed once per faction file.
    effect:
      type: cover-benefit
''';
      final corrections = DataCorrections.parse(wildcard);
      for (final faction in ['tau-empire', 'necrons', 'adeptus-astartes']) {
        final result = corrections.applyToAbilities(faction, _records);
        expect(result.applied, hasLength(1), reason: faction);
      }
    });

    test('a wildcard is stale only when no faction anywhere carries it', () {
      const wildcard = '''
abilities:
  - faction: "*"
    id: nonexistent
    reason: Deliberately matches nothing.
    effect:
      type: cover-benefit
''';
      final corrections = DataCorrections.parse(wildcard);
      final result = corrections.applyToAbilities('necrons', _records);
      // Not reported per-faction — a faction without the ability is normal.
      expect(result.unmatched, isEmpty);
      // Reported once the whole run has been seen.
      expect(corrections.neverApplied(result.applied), hasLength(1));
    });

    test('a correction that matches nothing is reported, not silent', () {
      // Otherwise a correction upstream has since adopted goes on shadowing
      // data that is now correct, and nobody finds out.
      final result = DataCorrections.parse(_yaml)
          .applyToAbilities('tau-empire', [_records.last]);
      expect(result.applied, isEmpty);
      expect(result.unmatched.single.subject, 'advanced-armour');
    });
  });

  group('the shipped corrections file', () {
    final file = File('../../data-corrections.yaml');

    test('parses, and every entry carries a reason', () {
      expect(file.existsSync(), isTrue,
          reason: 'the bundler defaults to this path');
      final corrections = DataCorrections.parse(file.readAsStringSync());
      expect(corrections.abilities, isNotEmpty);
      for (final correction in corrections.abilities) {
        expect(correction.reason, isNotEmpty);
        expect(correction.faction, isNotEmpty);
        expect(correction.abilityId, isNotEmpty);
        expect(correction.effect, isNotEmpty);
      }
    });

    test('every correction still matches an ability in the snapshot', () {
      final loader = DatasetLoader(
        '../../data/40kdc',
        corrections: DatasetLoader.correctionsAt('../../data-corrections.yaml'),
      );
      if (!loader.root.existsSync()) return;

      final applied = <Correction>[];
      for (final factionId in loader.availableFactions()) {
        for (final result in [
          loader.correctedAbilities(factionId),
          loader.correctedUnits(factionId),
          loader.correctedWeapons(factionId),
        ]) {
          applied.addAll(result.applied);
          expect(
            result.unmatched.map((c) => c.subject),
            isEmpty,
            reason: 'a correction for $factionId matches nothing — either a '
                'typo, or upstream has fixed it and the entry should go',
          );
        }
      }
      expect(
        loader.corrections.neverApplied(applied).map((c) => c.subject),
        isEmpty,
        reason: 'a wildcard correction fired for no faction at all',
      );
    });

    test('the corrected T\'au abilities read as the rulebook has them', () {
      final loader = DatasetLoader(
        '../../data/40kdc',
        corrections: DatasetLoader.correctionsAt('../../data-corrections.yaml'),
      );
      if (!loader.root.existsSync()) return;

      const renderer = RulesRenderer();
      final rendered = {
        for (final a in loader.loadFaction('tau-empire').abilities)
          a.abilityId: renderer.render(a),
      };

      expect(
        rendered['advanced-armour']?.text,
        'Against mortal wounds: Feel No Pain 4+.',
      );
      // The whole squad's ranged weapons, not just the Commander's — being
      // able to shoot after Advancing is the point of the ability.
      expect(
        rendered['coldstar-commander']?.text,
        'While leading a unit: Move set to 12; ranged weapons gain ASSAULT.',
      );
      // The exclusion is the rule: -1 AP against everything the Starscythe
      // is not built to kill would be a promise the datasheet does not make.
      expect(
        rendered['starscythe']?.text,
        'Shooting phase, except vs VEHICLE or MONSTER: -1 AP.',
      );

      for (final id in ['advanced-armour', 'coldstar-commander', 'starscythe',
          'stealth']) {
        expect(rendered[id]?.isComplete, isTrue,
            reason: '$id renders a placeholder');
      }
    });

    test('a weapon upstream does not have at all is added', () {
      // The Missile Drone granted `{grant_type: ranged-weapon}` with no
      // weapon named and no record to name — so Broadsides fielded drones
      // that shot nothing.
      final loader = DatasetLoader(
        '../../data/40kdc',
        corrections: DatasetLoader.correctionsAt('../../data-corrections.yaml'),
      );
      if (!loader.root.existsSync()) return;

      final faction = loader.loadFaction('tau-empire');
      final pod = faction.weapons
          .where((w) => w.id == 'drone-missile-pod')
          .toList();
      expect(pod, hasLength(1), reason: 'added, not duplicated');

      final profile = pod.single.profiles.single;
      expect(profile.range, '30');
      expect(profile.stats['A'], '2');
      expect(profile.skill, '5');
      expect(profile.stats['S'], '7');
      expect(profile.stats['AP'], '-1');
      expect(profile.stats['D'], '2');

      // Derived, not copied: everything but the skill matches the namesake,
      // so an upstream revision to the missile pod carries over.
      final namesake =
          faction.weapons.firstWhere((w) => w.id == 'missile-pod');
      final original = namesake.profiles.single;
      expect(original.skill, '4', reason: 'the battlesuit fires it better');
      for (final stat in ['A', 'S', 'AP', 'D']) {
        expect(profile.stats[stat], original.stats[stat], reason: stat);
      }
      expect(profile.range, original.range);
      expect(profile.keywords.map((k) => k.key),
          original.keywords.map((k) => k.key));

      // And the grant now resolves to it.
      final drone =
          faction.abilities.firstWhere((a) => a.abilityId == 'missile-drone');
      expect(drone.grantedWeaponId, 'drone-missile-pod');
    });

    test('every granted weapon resolves to a record', () {
      // A grant naming a weapon that does not exist is silently no weapon at
      // all, which is how three drones came to shoot nothing. Anything not
      // listed below is a new one, and needs a weapons: correction.
      // Empty, and it should stay that way: a drone's gun is its namesake at
      // BS5+, so any new one is a two-line `derive_from` entry.
      const knownDangling = <String>{};

      final loader = DatasetLoader(
        '../../data/40kdc',
        corrections: DatasetLoader.correctionsAt('../../data-corrections.yaml'),
      );
      if (!loader.root.existsSync()) return;

      final faction = loader.loadFaction('tau-empire');
      final known = {for (final w in faction.weapons) w.id};
      final dangling = {
        for (final ability in faction.abilities)
          if (ability.grantedWeaponId case final id?)
            if (!known.contains(id)) '${ability.abilityId} -> $id',
      };

      expect(dangling.difference(knownDangling), isEmpty,
          reason: 'a new unresolvable weapon grant');
      expect(knownDangling.difference(dangling), isEmpty,
          reason: 'upstream fixed one — drop it from knownDangling');
    });

    test("a drone fires its own gun, not the battlesuit's", () {
      // Pointing the Gun Drone's grant at the plain twin-pulse-carbine had it
      // shooting at BS4+ — the battlesuit's skill, on the drone's gun.
      final loader = DatasetLoader(
        '../../data/40kdc',
        corrections: DatasetLoader.correctionsAt('../../data-corrections.yaml'),
      );
      if (!loader.root.existsSync()) return;

      final faction = loader.loadFaction('tau-empire');
      final byId = {for (final w in faction.weapons) w.id: w};
      for (final id in [
        'drone-missile-pod',
        'drone-burst-cannon',
        'drone-twin-pulse-carbine',
        'twin-pulse-blaster',
      ]) {
        expect(byId[id]?.profiles.single.skill, '5', reason: id);
      }
    });

    test('Stealth is the Benefit of Cover in every faction that has it', () {
      final loader = DatasetLoader(
        '../../data/40kdc',
        corrections: DatasetLoader.correctionsAt('../../data-corrections.yaml'),
      );
      if (!loader.root.existsSync()) return;

      var seen = 0;
      for (final factionId in loader.availableFactions()) {
        for (final ability in loader.loadFaction(factionId).abilities) {
          if (ability.abilityId != 'stealth') continue;
          seen++;
          expect(
            const RulesRenderer().render(ability).text,
            'Has the Benefit of Cover.',
            reason: '$factionId still carries the 10th edition -1 to Hit',
          );
        }
      }
      expect(seen, greaterThan(1), reason: 'Stealth is a core ability');
    });

    test('Advanced Armour renders as a mortal-wounds-only save', () {
      final loader = DatasetLoader(
        '../../data/40kdc',
        corrections: DatasetLoader.correctionsAt('../../data-corrections.yaml'),
      );
      if (!loader.root.existsSync()) return;

      final ability = loader
          .loadFaction('tau-empire')
          .abilities
          .where((a) => a.abilityId == 'advanced-armour')
          .toList();
      if (ability.isEmpty) return;

      expect(
        const RulesRenderer().render(ability.single).text,
        'Against mortal wounds: Feel No Pain 4+.',
      );
    });
  });
}
