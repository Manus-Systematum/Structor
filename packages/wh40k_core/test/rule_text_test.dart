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
        corrections:
            DatasetLoader.correctionsAt('../../data-corrections.yaml'));
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
  test('an unpaired small-caps marker is dropped, not printed', () {
    // Custodes' Revered Companions opens a small-caps run and closes it in
    // the wrong place: `**^Anathema Psykana**` at one end, `Psykana^^**` at
    // the other. The folds only match balanced runs, so the odd marker
    // survived them and reached the screen as a literal caret.
    expect(normaliseRuleText('a **^Foo** and that Bar^^** unit'),
        isNot(contains('^')));
    // The balanced case still folds to emphasis rather than being stripped.
    expect(normaliseRuleText('the ^^Foo^^ unit'), 'the **Foo** unit');
  });
  test('a detachment rule carries its printed wording', () {
    // What a player looks up mid-game, and for 127 of 239 rules the app had
    // only a community paraphrase of the structured effect to show — every
    // Adepta Sororitas detachment among them. The wording was in BSData the
    // whole time: a detachment rule is a `sharedRule`, or a `rules` entry on
    // the non-datasheet container the detachments hang off, and the harvest
    // walked neither.
    final loader = DatasetLoader('../../data/merged',
        corrections:
            DatasetLoader.correctionsAt('../../data-corrections.yaml'));
    if (!loader.root.existsSync()) return;

    var total = 0, described = 0;
    for (final factionId in loader.availableFactions()) {
      for (final ability in loader.loadFaction(factionId).abilities) {
        if (ability.abilityType != 'detachment') continue;
        total++;
        if ((ability.description ?? '').trim().isNotEmpty) described++;
      }
    }
    expect(total, greaterThan(200));
    // 234 of 263 as counted here, which walks chapters as well as parents.
    // It was under half before the harvest reached shared rules.
    expect(described / total, greaterThan(0.85),
        reason: '$described of $total detachment rules are printed');
  });
  test('bold and small caps fold in every order the data writes them', () {
    // Four orders exist and only two were handled. The missed pair came from
    // Custodes' Revered Companions, which opens nested and closes
    // interleaved. The bare small-caps rule then ran on half a pair and ate
    // the space in front of it — `All other**Adeptus Custodes` — which is a
    // spacing bug produced by a markup bug, and reads as a source typo.
    for (final raw in const [
      'a **^^Foo^^** b', // nested, bold outside
      'a ^^**Foo**^^ b', // nested, small caps outside
      'a ^^**Foo^^** b', // interleaved
      'a **^^Foo**^^ b', // interleaved, the other way
      'a ^^Foo^^ b', // small caps alone
      'a **Foo** b', // bold alone
    ]) {
      expect(normaliseRuleText(raw), 'a **Foo** b', reason: raw);
    }
  });

  test('no ability description carries a caret or a tripled marker', () {
    final loader = DatasetLoader('../../data/merged',
        corrections:
            DatasetLoader.correctionsAt('../../data-corrections.yaml'));
    if (!loader.root.existsSync()) return;

    final offenders = <String>[];
    for (final factionId in loader.availableFactions()) {
      for (final ability in loader.loadFaction(factionId).abilities) {
        final text = ability.description ?? '';
        if (text.contains('^') || text.contains('***')) {
          offenders.add('$factionId/${ability.abilityId}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.take(5).join(', '));
  });
  test('a rule with a number in its name keeps the number', () {
    // BSData writes `Scouts X"` as one shared rule, and a datasheet that has
    // `Scouts 6"` links it with a name modifier. Reading the target's bare
    // name filed every such datasheet under `scouts` — the rulebook
    // explanation, which carries no distance — so a Dominion Squad showed
    // "Scouts" with no number and never reached the Scout moves list.
    final loader = DatasetLoader('../../data/merged',
        corrections:
            DatasetLoader.correctionsAt('../../data-corrections.yaml'));
    if (!loader.root.existsSync()) return;

    final sisters = loader.loadFaction('adepta-sororitas');
    final dominions = sisters.units.firstWhere((u) => u.id == 'dominion-squad');
    expect(dominions.abilityIds, contains('scouts-6'));
    expect(dominions.abilityIds, isNot(contains('scouts')));

    // Not one datasheet: the same shape carries Deadly Demise, Feel No Pain
    // and Firing Deck, and the numbers are the whole content of those rules.
    var numbered = 0;
    for (final factionId in loader.availableFactions()) {
      for (final unit in loader.loadFaction(factionId).units) {
        for (final id in unit.abilityIds) {
          if (RegExp(r'^scouts-\d').hasMatch(id)) numbered++;
        }
      }
    }
    expect(numbered, greaterThan(50));
  });

  test('every movement characteristic carries its inch mark', () {
    // Upstream writes it both ways — `7"` on most datasheets and a bare `10`
    // on a handful — so one screen showed `5"` on a statline and `10` in the
    // move list, which reads as two different kinds of number.
    final loader = DatasetLoader('../../data/merged',
        corrections:
            DatasetLoader.correctionsAt('../../data-corrections.yaml'));
    if (!loader.root.existsSync()) return;

    final offenders = <String>[];
    for (final factionId in loader.availableFactions()) {
      for (final unit in loader.loadFaction(factionId).units) {
        for (final profile in unit.profiles) {
          final m = profile.m;
          if (m == null || m.isEmpty || m == '-') continue;
          if (!m.endsWith('"')) offenders.add('$factionId/${unit.id}: $m');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.take(5).join(', '));
  });
}
