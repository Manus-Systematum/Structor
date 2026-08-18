import 'package:test/test.dart';
import 'package:wh40k_core/wh40k_core.dart';

void main() {
  group('normalising BattleScribe markup', () {
    test('small caps and bold both mean keyword, so they become one thing', () {
      // `**^^T’au Empire^^**` is the commonest shape in the data and the worst
      // to read raw. One emphasis level is enough on a phone.
      expect(normaliseRuleText('**^^T’au Empire^^** models'),
          '**T’au Empire** models');
      expect(normaliseRuleText('^^Grey Knights Infantry^^ model only.'),
          '**Grey Knights Infantry** model only.');
      // Both orders appear. This one left a stray `**` mid-sentence: "If your
      // Army Faction is Adepta Sororitas**, each unit…".
      expect(normaliseRuleText('is ^^**Adepta Sororitas**^^, each unit'),
          'is **Adepta Sororitas**, each unit');
    });

    test('invisible characters go', () {
      // Non-breaking spaces and hyphens carry nothing a screen needs, and
      // 4,152 of them are in the merged data.
      expect(normaliseRuleText('ranged weapons'), 'ranged weapons');
      expect(normaliseRuleText('Rad‑Zone'), 'Rad-Zone');
    });

    test('a bullet is a clause, not a character mid-sentence', () {
      // Inline, they read as part of the previous sentence: "If you do: ▫
      // Place this unit in…".
      expect(
        normaliseRuleText('If you do: ▫ Place this unit. ▫ It can move.'),
        'If you do:\n• Place this unit.\n• It can move.',
      );
    });

    test('datasheet notation is left exactly as printed', () {
      // `[SUSTAINED HITS 1]` is how a datasheet writes it, not markup.
      expect(normaliseRuleText('has the **[SUSTAINED HITS 1]** ability'),
          'has the **[SUSTAINED HITS 1]** ability');
    });

    test('emphasis survives into the data rather than being stripped', () {
      // Which words are keywords is information: `**T’AU EMPIRE** models` and
      // `T’au Empire models` do not say the same thing to someone checking
      // whether a rule applies. Rendering it is the app's job.
      expect(normaliseRuleText('**T’AU EMPIRE** models'),
          contains('**T’AU EMPIRE**'));
    });
  });

  group('splitting into runs', () {
    test('bold and italic become their own runs', () {
      final spans = ruleSpans('While a **Harvester** is near, *see note*.');
      expect(spans.map((s) => s.text),
          ['While a ', 'Harvester', ' is near, ', 'see note', '.']);
      expect(spans[1].bold, isTrue);
      expect(spans[3].italic, isTrue);
    });

    test('plain text is one run', () {
      expect(ruleSpans('Nothing marked here.').single.bold, isFalse);
    });

    test('no run is empty', () {
      // An empty span renders as nothing and costs a TextSpan to say so.
      for (final span in ruleSpans('**A** **B**')) {
        expect(span.text, isNotEmpty);
      }
    });
  });

  test('the shipped data carries no raw markers', () {
    // The point of doing this at ingest: every consumer sees it cleaned, and
    // a marker reaching a screen is a bug nobody notices until a game.
    final loader = DatasetLoader('../../data/merged',
        corrections: DatasetLoader.correctionsAt('../../data-corrections.yaml'));
    if (!loader.root.existsSync()) return;

    final offenders = <String>[];
    for (final factionId in loader.availableFactions()) {
      for (final ability in loader.loadFaction(factionId).abilities) {
        final text = ability.description;
        if (text == null) continue;
        if (text.contains('^^') ||
            text.contains(' ') ||
            text.contains('▪') ||
            text.contains('■')) {
          offenders.add('$factionId/${ability.abilityId}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.take(5).join(', '));
  });
}
