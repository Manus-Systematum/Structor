import 'dart:io';

import 'package:test/test.dart';
import 'package:wh40k_core/wh40k_core.dart';

const _parser = TextListParser();

void main() {
  group('name matching', () {
    test('folds case, typographic apostrophes and punctuation', () {
      expect(normalise('T’au flamer'), 'tau flamer');
      expect(normalise('Missile Pod'), 'missile pod');
      expect(normalise('  Seeker missile  '), 'seeker missile');
      expect(scoreName('T’au flamer', 'tau-flamer'), 1.0);
      expect(normalise('Crisis Shas’vre'), 'crisis shasvre');
    });

    test('containment beats length difference', () {
      // The export writes the long form; the catalogue has the short one.
      final long = scoreName(
          'Gun Drone With Twin Pulse Carbine and Shield Drone', 'Gun Drone');
      expect(long, greaterThan(0.7));
      expect(scoreName('Gun Drone', 'Fusion Blaster'), lessThan(0.3));
    });

    test('plurals match their singular', () {
      // Not 1.0: the strings genuinely differ, so this goes through the
      // containment path. Full coverage and full precision is 0.95, which is
      // well clear of every threshold in the resolver.
      expect(scoreName('Missile drones', 'Missile drone'), greaterThan(0.9));
      expect(scoreName('Missile drones', 'Missile drone'),
          greaterThan(scoreName('Missile drones', 'Shield drone')));
    });

    test('compound entries split only as a fallback', () {
      expect(splitCompound('Gun Drone and Shield Drone'),
          ['Gun Drone', 'Shield Drone']);
      expect(splitCompound('Heavy rail rifle'), ['Heavy rail rifle']);
    });

    test('bestMatch respects its threshold', () {
      final names = ['Missile pod', 'Plasma rifle', 'Battlesuit fists'];
      expect(bestMatch('missile pod', names, (n) => n)?.value, 'Missile pod');
      expect(bestMatch('grot blasta', names, (n) => n), isNull);
    });
  });

  group('text parser', () {
    late ParsedList parsed;

    setUpAll(() {
      parsed = _parser.parse(
          File('test/fixtures/war_organ_export.txt').readAsStringSync());
    });

    test('reads the preamble without mistaking it for units', () {
      expect(parsed.name, '2k ret');
      expect(parsed.printedPoints, 2000);
      expect(parsed.factionName, 'Tau Empire');
      expect(parsed.disposition, 'Reconnaissance');
      expect(parsed.detachmentNames,
          ['Advanced Acquisition Cadre', 'Experimental Prototype Cadre']);
      expect(parsed.detachmentPoints, 2);
      // "Strike Force (2000 Point)" also matches the unit-header pattern; the
      // preamble has to claim it first or it imports as a datasheet.
      expect(parsed.battleSizeName, 'Strike Force');
      expect(parsed.units.any((u) => u.name == 'Strike Force'), isFalse);
    });

    test('parses every unit and leaves nothing unread', () {
      expect(parsed.units, hasLength(16));
      expect(parsed.unparsedLines, isEmpty);
    });

    test('preserves attachment grouping', () {
      final group = parsed.units
          .where((u) => u.attachmentGroup == 'Attached Unit 1')
          .toList();
      expect(group, hasLength(2));
      expect(group.first.name, 'Commander In Enforcer Battlesuit');
      expect(group.last.name, 'Crisis Fireknife Battlesuits');
    });

    test('nests depth-2 nodes under their model group', () {
      final fireknife =
          parsed.units.firstWhere((u) => u.name.contains('Fireknife'));
      expect(fireknife.nodes, hasLength(2), reason: 'two model groups');
      final shasui =
          fireknife.nodes.firstWhere((n) => n.name.contains('Shas’ui'));
      expect(shasui.count, 2);
      expect(shasui.children, hasLength(3));
      expect(
        shasui.children.firstWhere((c) => c.name == 'Missile Pod').count,
        4,
        reason: 'depth-2 counts are group totals, not per-model',
      );
    });

    test('flags the warlord', () {
      final warlords = parsed.units.where((u) => u.isWarlord).toList();
      expect(warlords, hasLength(1));
      expect(warlords.single.name, 'The Twin Lance');
    });

    test('a unit with no bullets still parses', () {
      final bare = _parser.parse('My list (500 points)\n\n'
          'Orks\nStrike Force (2000 Point)\n\n'
          'OTHER DATASHEETS\n\nWarboss (85 points)\n');
      expect(bare.units.single.name, 'Warboss');
      expect(bare.units.single.nodes, isEmpty);
    });
  });

  group('resolution against the catalogue', () {
    final snapshot = Directory('../../data/40kdc');
    final available = snapshot.existsSync();

    late ImportResult result;
    late Dataset dataset;

    setUp(() {
      final faction =
          DatasetLoader(snapshot.path).loadFaction('tau-empire');
      dataset = Dataset.of(faction, revision: 'test');
      result = RosterResolver(
        dataset,
        abilityLookup: dataset.ability,
        knownAbilities: faction.abilities,
      ).resolve(
        _parser.parse(
            File('test/fixtures/war_organ_export.txt').readAsStringSync()),
        factionId: 'tau-empire',
      );
    });

    test('a real export imports without errors', () {
      expect(result.errors, isEmpty,
          reason: result.errors.map((e) => e.toString()).join('\n'));
      expect(result.isClean, isTrue);
    }, skip: available ? null : 'no snapshot');

    test('the imported roster prices to the printed total', () {
      final cost = PointsCalculator(dataset).price(result.roster);
      expect(cost.isComplete, isTrue);
      expect(cost.total, 2000);
      expect(cost.total, result.printedPoints,
          reason: 'computed and printed must agree');
    }, skip: available ? null : 'no snapshot');

    test('attachment groups become LEADS edges', () {
      expect(result.roster.links, hasLength(4));
      expect(result.roster.combatUnits(), hasLength(12),
          reason: '16 roster units, 4 attached pairs');

      // Direction matters: the Commander leads, not the other way round.
      final first = result.roster.links.first;
      expect(dataset.unit(
              result.roster.unitByInstance(first.fromInstanceId)!.datasheetId)!
          .isLeader,
          isTrue);
    }, skip: available ? null : 'no snapshot');

    test('the roster validates', () {
      final validation = RosterValidator(dataset).validate(result.roster);
      expect(validation.errors, isEmpty,
          reason: validation.errors.join('\n'));
      expect(result.roster.warlordInstanceId, isNotNull);
      expect(result.roster.declaredDisposition, 'reconnaissance');
      expect(result.roster.battleSizeId, 'strike-force');
      expect(result.roster.detachments, hasLength(2));
    }, skip: available ? null : 'no snapshot');

    test('weapons resolve to the carrier-scoped profile', () {
      final attached = result.roster
          .combatUnits()
          .firstWhere((g) => g.length == 2 && g.first.datasheetId.contains('enforcer'));
      final table = WeaponAggregator(dataset).aggregate(attached);
      expect(table.isComplete, isTrue);
      // The split that only exists if the Commander's pod resolved to its own
      // BS3+ record rather than the generic BS4+ one.
      expect(table.weapons.map((w) => w.attacks.fixed), containsAll([8, 12]));
    }, skip: available ? null : 'no snapshot');

    test('dataset attachment gaps are info, not warnings', () {
      // Drones the printed list carries but the datasheet does not list are an
      // upstream gap, not an import failure. They cost nothing and do not
      // affect the weapon table.
      final infos = result.issues
          .where((i) => i.severity == IssueSeverity.info)
          .where((i) => i.message.contains('does not list in the dataset'))
          .toList();
      expect(infos, isNotEmpty);
      expect(
        result.issues.where((i) => i.severity == IssueSeverity.warning),
        isEmpty,
        reason: result.issues.join('\n'),
      );
    }, skip: available ? null : 'no snapshot');
  });
}
