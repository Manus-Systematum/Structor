import 'package:test/test.dart';
import 'package:wh40k_core/wh40k_core.dart';

void main() {
  group('tolerant parsing', () {
    test('numeric and dice attack values both parse', () {
      final missilePod = WeaponProfile.fromJson({
        'name': 'Missile pod',
        'range': 30,
        'stats': {'A': 2, 'S': 7, 'AP': -1, 'D': 2, 'BS': 3},
        'keywords': <Object>[],
      });
      final flamer = WeaponProfile.fromJson({
        'name': "T'au flamer",
        'range': 12,
        'stats': {'A': 'D6', 'S': 4, 'AP': 0, 'D': 1, 'BS': null},
        'keywords': [
          {'keyword_id': 'torrent'},
          {'keyword_id': 'ignores-cover'},
        ],
      });

      expect(missilePod.stats['A'], '2');
      expect(missilePod.skill, '3');
      expect(flamer.stats['A'], 'D6');
      expect(flamer.skill, isNull, reason: 'Torrent weapons have no BS');
      expect(flamer.keywordIds, containsAll(['torrent', 'ignores-cover']));
    });

    test('absent and malformed fields degrade instead of throwing', () {
      final unit = SourceUnit.fromJson({'id': 'x', 'profiles': 'not-a-list'});
      expect(unit.name, '(unnamed)');
      expect(unit.profiles, isEmpty);
      expect(unit.weaponIds, isEmpty);
      expect(unit.gameVersion.dataslate, 'unknown');
    });

    test('detachment unique tags accept either upstream key', () {
      final withUnique = SourceDetachment.fromJson({
        'id': 'a',
        'unique_tags': ['retaliation'],
      });
      final withTags = SourceDetachment.fromJson({
        'id': 'b',
        'tags': ['retaliation'],
      });
      expect(withUnique.uniqueTags, ['retaliation']);
      expect(withTags.uniqueTags, ['retaliation']);
    });
  });

  group('weapon aggregation identity (DESIGN.md 7.3.5)', () {
    WeaponProfile pod(int bs) => WeaponProfile.fromJson({
          'name': 'Missile pod',
          'range': 30,
          'stats': {'A': 2, 'S': 7, 'AP': -1, 'D': 2, 'BS': bs},
          'keywords': <Object>[],
        });

    test('same name with different BS yields different profile keys', () {
      expect(pod(3).profileKey, isNot(pod(4).profileKey));
    });

    test('identical profiles yield equal keys regardless of stat ordering', () {
      final a = WeaponProfile.fromJson({
        'name': 'Missile pod',
        'range': 30,
        'stats': {'A': 2, 'BS': 4, 'S': 7, 'AP': -1, 'D': 2},
        'keywords': <Object>[],
      });
      final b = WeaponProfile.fromJson({
        'name': 'Missile pod',
        'range': 30,
        'stats': {'D': 2, 'AP': -1, 'S': 7, 'BS': 4, 'A': 2},
        'keywords': <Object>[],
      });
      expect(a.profileKey, b.profileKey);
    });

    test('keyword differences separate otherwise identical profiles', () {
      final plain = pod(4);
      final assault = WeaponProfile.fromJson({
        'name': 'Missile pod',
        'range': 30,
        'stats': {'A': 2, 'S': 7, 'AP': -1, 'D': 2, 'BS': 4},
        'keywords': [
          {'keyword_id': 'assault'},
        ],
      });
      expect(plain.profileKey, isNot(assault.profileKey));
    });
  });

  group('points brackets (DESIGN.md 2.1)', () {
    test('copy-scaled brackets are detected', () {
      final first = PointsBracket.fromJson(
          {'models': 3, 'cost': 85, 'unit_count_min': 1, 'unit_count_max': 2});
      final third = PointsBracket.fromJson(
          {'models': 3, 'cost': 95, 'unit_count_min': 3, 'unit_count_max': null});

      expect(first.isCopyScaled, isTrue,
          reason: 'bounded by unit_count_max, so pricing depends on copy index');
      expect(third.isCopyScaled, isTrue);
      expect(third.cost, 95);
    });

    test('a plain bracket is not copy-scaled', () {
      final flat = PointsBracket.fromJson({'models': 1, 'cost': 80});
      expect(flat.isCopyScaled, isFalse);
    });
  });

  group('pricing (verified against a real 2,000 pt list)', () {
    // Crisis Fireknife Battlesuits as published in 40kdc: a copy-scaled base
    // bracket plus a per-instance wargear cost. War Organ prices the squad in
    // the reference list at 130, which this must reproduce.
    final fireknife = SourceUnit.fromJson({
      'id': 'crisis-fireknife-battlesuits',
      'name': 'Crisis Fireknife Battlesuits',
      'profiles': [
        {'name': "Crisis Fireknife Shas'ui", 'M': 10, 'T': 5, 'W': 4, 'Sv': 3},
      ],
      'points': [
        {'models': 3, 'cost': 100, 'unit_count_min': 1, 'unit_count_max': 2},
        {'models': 3, 'cost': 110, 'unit_count_min': 3, 'unit_count_max': null},
      ],
      'wargear_costs': [
        {'item_id': 'missile-pod', 'cost': 5},
      ],
      'wargear_budgets': [
        {'items': ['shield-drone'], 'count': 3, 'per_models': 3},
      ],
    });

    test('base bracket plus wargear reproduces the printed cost', () {
      final base = fireknife.bracketFor(models: 3)!.cost;
      final missilePods = 6; // 2 on the Shas'vre, 4 across two Shas'ui
      expect(base + missilePods * fireknife.costOfWargear('missile-pod'), 130);
    });

    test('the third copy of a datasheet costs more than the first', () {
      expect(fireknife.bracketFor(models: 3, copyIndex: 1)!.cost, 100);
      expect(fireknife.bracketFor(models: 3, copyIndex: 2)!.cost, 100);
      expect(fireknife.bracketFor(models: 3, copyIndex: 3)!.cost, 110);
      expect(fireknife.bracketFor(models: 3, copyIndex: 9)!.cost, 110,
          reason: 'an open-ended bracket has no upper copy bound');
    });

    test('an unmatched model count yields no bracket rather than a guess', () {
      expect(fireknife.bracketFor(models: 4), isNull);
    });

    test('budgeted wargear costs nothing', () {
      expect(fireknife.costOfWargear('shield-drone'), 0);
      expect(fireknife.wargearBudgets.single.count, 3);
    });
  });

  group('ability effect fingerprints (DESIGN.md 7.3.6)', () {
    test('near-duplicate records with identical effects match', () {
      Map<String, Object?> support(String id) => {
            'ability_id': id,
            'name': 'Weapon Support System',
            'effect': {
              'type': 'conditional',
              'condition': {
                'type': 'phase-is',
                'parameters': {'phase': 'shooting'},
              },
              'effect': {
                'type': 'roll-modifier',
                'target': 'unit',
                'modifier': {'roll': 'all', 'operation': 'ignore-modifiers'},
              },
            },
          };

      final singular = SourceAbility.fromJson(support('weapon-support-system'));
      final plural = SourceAbility.fromJson(support('weapon-support-systems'));

      expect(singular.effectFingerprint, plural.effectFingerprint);
      expect(singular.abilityId, isNot(plural.abilityId));
    });

    test('fingerprints are key-order independent but value sensitive', () {
      final a = SourceAbility.fromJson({
        'ability_id': 'a',
        'effect': {'type': 'stat-modifier', 'modifier': {'stat': 'W', 'value': 1}},
      });
      final b = SourceAbility.fromJson({
        'ability_id': 'b',
        'effect': {'modifier': {'value': 1, 'stat': 'W'}, 'type': 'stat-modifier'},
      });
      final c = SourceAbility.fromJson({
        'ability_id': 'c',
        'effect': {'type': 'stat-modifier', 'modifier': {'stat': 'W', 'value': 2}},
      });

      expect(a.effectFingerprint, b.effectFingerprint);
      expect(a.effectFingerprint, isNot(c.effectFingerprint));
      expect(a.effectType, 'stat-modifier');
    });
  });

  group('game version', () {
    test('provisional dataslates are flagged', () {
      expect(
        GameVersion.fromJson(
                {'edition': '11th', 'dataslate': 'pre-launch-provisional'})
            .isProvisional,
        isTrue,
      );
      expect(
        GameVersion.fromJson({'edition': '11th', 'dataslate': 'launch'})
            .isProvisional,
        isFalse,
      );
    });
  });
}
