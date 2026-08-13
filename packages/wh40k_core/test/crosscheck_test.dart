import 'dart:io';

import 'package:test/test.dart';
import 'package:wh40k_core/wh40k_core.dart';

const _yaml = '''
name: Test Faction
slug: testers
version: "1.2"
detachments:
  - name: Alpha Cadre
    dp: 2
    objective: TAKE AND HOLD
    unique: Battlesuit
    enhancements:
      - { name: Big Hat, points: 20 }
units:
  - name: Squad
    pricing:
      - range: "[1,2]"
        costs:
          - { models: 3, points: 100 }
          - { models: 6, points: 200 }
      - range: "[3,)"
        costs:
          - { models: 3, points: 110 }
  - name: Platform
    pricing:
      - range: "[1,)"
        costs:
          - { models: 1, points: 85 }
          - { models: 1, points: 20, desc: Defence Platform, addon: true }
  - name: Old Thing
    pricing:
      - range: "[1,)"
        costs:
          - { models: 1, points: 50 }
    legends: true
''';

SourceUnit unit(String name, List<Map<String, Object?>> points) =>
    SourceUnit.fromJson({'id': name, 'name': name, 'points': points});

SourceDetachment detachment({
  int dp = 2,
  List<String> dispositions = const ['take-and-hold'],
  List<String> tags = const ['Battlesuit'],
}) =>
    SourceDetachment.fromJson({
      'id': 'alpha',
      'name': 'Alpha Cadre',
      'detachment_points': dp,
      'force_dispositions': dispositions,
      'unique_tags': tags,
      'enhancement_ids': ['big-hat'],
    });

CrossCheckReport check({
  List<SourceUnit>? units,
  SourceDetachment? det,
  Map<String, int> enhancementPoints = const {'big-hat': 20},
}) =>
    CrossChecker(
      units: units ??
          [
            unit('Squad', [
              {'models': 3, 'cost': 100, 'unit_count_min': 1, 'unit_count_max': 2},
              {'models': 4, 'models_max': 6, 'cost': 200,
                'unit_count_min': 1, 'unit_count_max': 2},
              {'models': 3, 'cost': 110, 'unit_count_min': 3},
            ]),
            unit('Platform', [
              {'models': 1, 'cost': 85},
            ]),
          ],
      detachments: [det ?? detachment()],
      enhancementPoints: enhancementPoints,
      enhancementNames: const {'big-hat': 'Big Hat'},
    ).compare(MfmFaction.parse(_yaml), factionId: 'testers');

void main() {
  group('parsing the Munitorum data', () {
    final faction = MfmFaction.parse(_yaml);

    test('copy ranges', () {
      expect(CopyRange.parse('[1,2]').min, 1);
      expect(CopyRange.parse('[1,2]').max, 2);
      expect(CopyRange.parse('[3,)').max, isNull);
      expect(CopyRange.parse('nonsense').min, 1);
    });

    test('units, pricing and legends', () {
      expect(faction.version, '1.2');
      expect(faction.units, hasLength(3));
      expect(faction.units.firstWhere((u) => u.name == 'Old Thing').isLegends,
          isTrue);
    });

    test('add-ons are excluded from the cost table', () {
      // A Defence Platform shares a model count with the base entry; treating
      // it as the unit's price makes the unit look 65 points cheaper.
      final platform = faction.units.firstWhere((u) => u.name == 'Platform');
      expect(platform.costTable[(1, 1)], 85);
      expect(platform.addons, hasLength(1));
      expect(platform.addons.single.description, 'Defence Platform');
    });

    test('detachments carry dp, objective, unique tag and enhancements', () {
      final d = faction.detachments.single;
      expect(d.dp, 2);
      expect(d.objective, 'TAKE AND HOLD');
      expect(d.unique, 'Battlesuit');
      expect(d.enhancements.single.points, 20);
    });
  });

  group('comparison', () {
    test('matching data produces no divergences', () {
      final report = check();
      expect(report.divergences, isEmpty, reason: report.divergences.join('\n'));
      expect(report.agrees, isTrue);
      expect(report.unitsCompared, 2);
      expect(report.detachmentsCompared, 1);
    });

    test('legends units are skipped rather than reported missing', () {
      expect(check().unmatched, isEmpty);
    });

    test('a bracket spanning a model range still matches its endpoint', () {
      // The primary data prices 4-6 models as one bracket; the Munitorum
      // lists the endpoint. Exact-matching the model count reports every such
      // bracket as missing.
      final report = check();
      expect(
        report.divergences.where((d) => d.subject.contains('6 models')),
        isEmpty,
      );
    });

    test('a points difference is caught', () {
      final report = check(units: [
        unit('Squad', [
          {'models': 3, 'cost': 95, 'unit_count_min': 1, 'unit_count_max': 2},
          {'models': 4, 'models_max': 6, 'cost': 200,
            'unit_count_min': 1, 'unit_count_max': 2},
          {'models': 3, 'cost': 110, 'unit_count_min': 3},
        ]),
        unit('Platform', [
          {'models': 1, 'cost': 85},
        ]),
      ]);
      final points = report.divergences
          .where((d) => d.kind == DivergenceKind.unitPoints)
          .toList();
      expect(points, hasLength(1));
      expect(points.single.primary, '95 pts');
      expect(points.single.munitorum, '100 pts');
    });

    test('copy-scaled brackets are compared separately', () {
      final report = check(units: [
        unit('Squad', [
          {'models': 3, 'cost': 100, 'unit_count_min': 1, 'unit_count_max': 2},
          {'models': 4, 'models_max': 6, 'cost': 200,
            'unit_count_min': 1, 'unit_count_max': 2},
          {'models': 3, 'cost': 999, 'unit_count_min': 3},
        ]),
        unit('Platform', [
          {'models': 1, 'cost': 85},
        ]),
      ]);
      expect(
        report.divergences.where((d) => d.subject.contains('copies 3+')),
        hasLength(1),
      );
    });

    test('a detachment point difference is caught', () {
      final report = check(det: detachment(dp: 3));
      expect(
        report.divergences.map((d) => d.kind),
        contains(DivergenceKind.detachmentPoints),
      );
    });

    test('a disposition mismatch is caught', () {
      final report = check(det: detachment(dispositions: ['purge-the-foe']));
      expect(
        report.divergences.map((d) => d.kind),
        contains(DivergenceKind.detachmentDisposition),
      );
    });

    test('a differently named unique tag is caught', () {
      final report = check(det: detachment(tags: ['retaliation']));
      expect(
        report.divergences.map((d) => d.kind),
        contains(DivergenceKind.detachmentUniqueTag),
      );
    });

    test('tag plurals and case do not count as a divergence', () {
      // "Auxiliary" against "auxiliaries" is a spelling difference, not a
      // rules difference.
      final report = check(det: detachment(tags: ['Battlesuits']));
      expect(
        report.divergences.where(
            (d) => d.kind == DivergenceKind.detachmentUniqueTag),
        isEmpty,
      );
    });

    test('an enhancement price difference is caught', () {
      final report = check(enhancementPoints: {'big-hat': 25});
      expect(
        report.divergences.map((d) => d.kind),
        contains(DivergenceKind.enhancementPoints),
      );
    });
  });

  group('against the real sources', () {
    final mfm = File('../../data/mfm/necrons.yaml');
    final available = mfm.existsSync() &&
        Directory('../../data/40kdc/core/necrons').existsSync();

    test('Necrons agree with the Munitorum', () {
      final faction = DatasetLoader('../../data/40kdc').loadFaction('necrons');
      final report = CrossChecker(
        units: faction.units,
        detachments: faction.detachments,
      ).compare(MfmFaction.parse(mfm.readAsStringSync()), factionId: 'necrons');

      expect(report.unitsCompared, greaterThan(40));
      expect(
        report.divergences.where((d) =>
            d.kind == DivergenceKind.unitPoints ||
            d.kind == DivergenceKind.detachmentPoints),
        isEmpty,
        reason: report.divergences.join('\n'),
      );
    }, skip: available ? null : 'no snapshot');
  });
}
