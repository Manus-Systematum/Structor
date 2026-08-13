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

    test('a correction that matches nothing is reported, not silent', () {
      // Otherwise a correction upstream has since adopted goes on shadowing
      // data that is now correct, and nobody finds out.
      final result = DataCorrections.parse(_yaml)
          .applyToAbilities('tau-empire', [_records.last]);
      expect(result.applied, isEmpty);
      expect(result.unmatched.single.abilityId, 'advanced-armour');
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

      for (final factionId in loader.availableFactions()) {
        final result = loader.correctedAbilities(factionId);
        expect(
          result.unmatched.map((c) => c.abilityId),
          isEmpty,
          reason: 'a correction for $factionId matches no ability — either a '
              'typo, or upstream has fixed it and the entry should go',
        );
      }
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
