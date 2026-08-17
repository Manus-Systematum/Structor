import 'dart:io';

import 'package:test/test.dart';
import 'package:wh40k_core/wh40k_core.dart';

void main() {
  final root = Directory('../../data/40kdc');
  final skip = root.existsSync() ? null : 'no snapshot';
  final loader = DatasetLoader('../../data/40kdc',
      corrections: DatasetLoader.correctionsAt('../../data-corrections.yaml'));
  const renderer = RulesRenderer();

  RenderedRule render(String faction, String id) => renderer.render(loader
      .loadFaction(faction)
      .abilities
      .firstWhere((a) => a.abilityId == id));

  group('a rule that only repeats its name is a keyword', () {
    test('Deep Strike and Leader are keywords, not descriptions', () {
      // "Deep Strike: Deep Strike" and "Leader: grants Leader" are honest —
      // the meaning lives in the rulebook and there is nothing to render —
      // but printed as name-and-description they read as rules the app
      // failed to explain, at two lines each.
      expect(render('adeptus-astartes', 'deep-strike').isBareKeyword, isTrue);
      expect(render('adeptus-astartes', 'leader').isBareKeyword, isTrue);
    }, skip: skip);

    test('a rule with something to say is not', () {
      expect(render('adepta-sororitas', 'cherub').isBareKeyword, isFalse);
      expect(render('adepta-sororitas', 'acts-of-faith').isBareKeyword,
          isFalse);
      expect(
          render('adepta-sororitas', 'purge-and-cleanse').isBareKeyword,
          isFalse,
          reason: 'it names the rule it grants');
    }, skip: skip);

    test('detected, not listed', () {
      // A hand-kept list of core keywords goes stale the first time upstream
      // adds one, so this is derived from what the renderer produced. 166 of
      // 7,484 at the current revision.
      var total = 0;
      var bare = 0;
      for (final factionId in loader.availableFactions()) {
        for (final ability in loader.loadFaction(factionId).abilities) {
          total++;
          if (renderer.render(ability).isBareKeyword) bare++;
        }
      }
      expect(bare, greaterThan(100));
      expect(bare / total, lessThan(0.05),
          reason: 'if most rules look empty, the renderer has regressed');
    }, skip: skip);

    test('an empty render counts as one', () {
      const empty = RenderedRule(
          abilityId: 'x', name: 'Stealth', text: '—', phases: [],
          unrendered: []);
      expect(empty.isBareKeyword, isTrue);
    });

    test('punctuation and case do not hide the repetition', () {
      const same = RenderedRule(
          abilityId: 'x', name: 'Fights First', text: 'Fights First.',
          phases: [], unrendered: []);
      expect(same.isBareKeyword, isTrue);

      const granted = RenderedRule(
          abilityId: 'x', name: 'Leader', text: 'Grants leader.', phases: [],
          unrendered: []);
      expect(granted.isBareKeyword, isTrue);
    });
  });
}
