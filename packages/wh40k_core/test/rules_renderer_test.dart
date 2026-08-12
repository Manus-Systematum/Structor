import 'dart:io';

import 'package:test/test.dart';
import 'package:wh40k_core/wh40k_core.dart';

const _renderer = RulesRenderer();

/// Renders an ability from its raw effect, as it appears in the source data.
RenderedRule _render(Object? effect, {String name = 'Test', Object? usage}) =>
    _renderer.render(SourceAbility.fromJson({
      'ability_id': 'test',
      'name': name,
      'effect': effect,
      if (usage != null) 'usage': usage,
    }));

String _text(Object? effect) => _render(effect).text;

void main() {
  group('leaf effects', () {
    test('stat modifiers read as signed characteristics', () {
      expect(
        _text({
          'type': 'stat-modifier',
          'modifier': {'stat': 'W', 'operation': 'add', 'value': 1},
        }),
        '+1 Wound.',
      );
      expect(
        _text({
          'type': 'stat-modifier',
          'modifier': {'stat': 'S', 'operation': 'add', 'value': 1,
              'weapon_type': 'melee'},
        }),
        '+1 Strength (melee).',
      );
    });

    test('roll modifiers distinguish a penalty from ignoring modifiers', () {
      expect(
        _text({
          'type': 'roll-modifier',
          'modifier': {'roll': 'hit', 'operation': 'subtract', 'value': 1},
        }),
        '-1 to Hit.',
      );
      expect(
        _text({
          'type': 'roll-modifier',
          'modifier': {'roll': 'all', 'operation': 'ignore-modifiers'},
        }),
        'Ignore modifiers to all rolls.',
      );
    });

    test('re-rolls put the adjective before the roll name', () {
      expect(
        _text({
          'type': 're-roll',
          'modifier': {'roll': 'hit', 'subset': 'all-failures'},
        }),
        'Re-roll failed Hit rolls.',
      );
      expect(
        _text({
          'type': 're-roll',
          'modifier': {'roll': 'wound', 'subset': 'ones'},
        }),
        'Re-roll Wound rolls of 1.',
      );
    });

    test('keywords render in the rulebook\'s upper case', () {
      expect(
        _text({
          'type': 'keyword-grant',
          'modifier': {
            'keywords': ['markerlight'],
          },
        }),
        'Gains MARKERLIGHT.',
      );
    });

    test('saves and Feel No Pain keep their threshold notation', () {
      expect(
        _text({'type': 'invulnerable-save', 'modifier': {'invuln_sv': 4}}),
        '4+ invulnerable save.',
      );
      expect(
        _text({'type': 'feel-no-pain', 'modifier': {'threshold': 5}}),
        'Feel No Pain 5+.',
      );
    });
  });

  group('combinators recurse', () {
    test('a conditional prefixes its inner effect', () {
      expect(
        _text({
          'type': 'conditional',
          'condition': {
            'type': 'phase-is',
            'parameters': {'phase': 'shooting'},
          },
          'effect': {
            'type': 'roll-modifier',
            'modifier': {'roll': 'all', 'operation': 'ignore-modifiers'},
          },
        }),
        'Shooting phase: ignore modifiers to all rolls.',
      );
    });

    test('a sequence joins its steps', () {
      expect(
        _text({
          'type': 'sequence',
          'steps': [
            {
              'type': 'keyword-grant',
              'modifier': {
                'keywords': ['markerlight'],
              },
            },
            {
              'type': 'ability-grant',
              'modifier': {'ability': 'observer-unit'},
            },
          ],
        }),
        'Gains MARKERLIGHT; grants observer unit.',
      );
    });

    test('a dice gate states the roll it needs', () {
      expect(
        _text({
          'type': 'dice-gated',
          'dice': 'D6',
          'threshold': 6,
          'comparison': 'gte',
          'on_success': {
            'type': 'mortal-wounds',
            'modifier': {'count': '3D6', 'range': 6},
          },
          'on_fail': null,
        }),
        'On a D6 of 6+, 3D6 mortal wounds to units within 6".',
      );
    });

    test('an aura carries its range and eligibility', () {
      expect(
        _text({
          'type': 'aura',
          'modifier': {
            'range': 6,
            'eligible': {
              'required_keywords': ['NECRONS'],
              'excluded_keywords': ['MONSTER'],
            },
            'effect': {
              'type': 'stat-modifier',
              'modifier': {'stat': 'M', 'operation': 'add', 'value': 2},
            },
          },
        }),
        'Aura 6": NECRONS (not MONSTER) — +2 Move.',
      );
    });

    test('nesting composes rather than flattening', () {
      // The real Fireknife shape: a phase gate wrapping a sequence whose second
      // step is itself conditional on the target's strength.
      expect(
        _text({
          'type': 'conditional',
          'condition': {
            'type': 'phase-is',
            'parameters': {'phase': 'shooting'},
          },
          'effect': {
            'type': 'sequence',
            'steps': [
              {
                'type': 're-roll',
                'modifier': {'roll': 'hit', 'subset': 'ones'},
              },
              {
                'type': 'conditional',
                'condition': {
                  'type': 'unit-below-starting-strength',
                  'parameters': {'subject': 'target'},
                  'negated': true,
                },
                'effect': {
                  'type': 're-roll',
                  'modifier': {'roll': 'hit', 'subset': 'all-failures'},
                },
              },
            ],
          },
        }),
        'Shooting phase: re-roll Hit rolls of 1; target at full strength: '
        're-roll failed Hit rolls.',
      );
    });
  });

  group('conditions', () {
    test('operators join their operands', () {
      expect(
        _text({
          'type': 'conditional',
          'condition': {
            'operator': 'or',
            'operands': [
              {'type': 'advanced-this-turn', 'parameters': <String, Object?>{}},
              {'type': 'charged-this-turn'},
            ],
          },
          'effect': {'type': 'fight-first', 'modifier': <String, Object?>{}},
        }),
        'If it Advanced or if it charged this turn: Fights First.',
      );
    });

    test('negation reads as "unless" except where wording folds it in', () {
      expect(
        _text({
          'type': 'conditional',
          'condition': {
            'type': 'is-battle-shocked',
            'negated': true,
          },
          'effect': {'type': 'deep-strike', 'modifier': <String, Object?>{}},
        }),
        'Unless while Battle-shocked: Deep Strike.',
      );
    });

    test('battle-round bounds render as a window', () {
      expect(
        _text({
          'type': 'conditional',
          'condition': {
            'type': 'battle-round',
            'parameters': {'max': 3},
          },
          'effect': {'type': 'fight-first', 'modifier': <String, Object?>{}},
        }),
        'Until battle round 3: Fights First.',
      );
    });
  });

  group('phases are extracted for the turn page', () {
    test('a phase condition is reported alongside the text', () {
      final rule = _render({
        'type': 'conditional',
        'condition': {
          'type': 'phase-is',
          'parameters': {'phase': 'fight'},
        },
        'effect': {'type': 'fight-first', 'modifier': <String, Object?>{}},
      });
      expect(rule.phases, ['fight']);
    });

    test('an unconditioned ability reports no phase', () {
      expect(_render({'type': 'deep-strike'}).phases, isEmpty);
    });
  });

  group('unknown shapes are admitted, never invented', () {
    test('an unrecognised effect leaves a visible placeholder', () {
      final rule = _render({'type': 'warp-shenanigans', 'modifier': {}});
      expect(rule.isComplete, isFalse);
      expect(rule.unrendered, ['warp-shenanigans']);
      expect(rule.text, contains('[warp-shenanigans]'));
    });

    test('an unrecognised condition is reported too', () {
      final rule = _render({
        'type': 'conditional',
        'condition': {'type': 'moon-is-full', 'parameters': <String, Object?>{}},
        'effect': {'type': 'deep-strike', 'modifier': <String, Object?>{}},
      });
      expect(rule.unrendered, ['condition:moon-is-full']);
      expect(rule.text, contains('Deep Strike'),
          reason: 'the understood half is still rendered');
    });

    test('an empty effect renders as a dash rather than an empty card', () {
      expect(_render(<String, Object?>{}).text, '—');
    });
  });

  test('usage frequency is appended', () {
    expect(
      _render(
        {'type': 'cp-gain', 'modifier': {'amount': 1}},
        usage: {'frequency': 'once-per-turn'},
      ).text,
      'Gain 1CP (once per turn).',
    );
  });

  group('coverage against real data', () {
    final snapshot = Directory('../../data/40kdc');

    ({int total, int complete, Set<String> gaps}) coverageOf(String faction) {
      final data = DatasetLoader(snapshot.path).loadFaction(faction);
      final rules = data.abilities.map(_renderer.render).toList();
      return (
        total: rules.length,
        complete: rules.where((r) => r.isComplete).length,
        gaps: rules.expand((r) => r.unrendered).toSet(),
      );
    }

    bool has(String faction) =>
        Directory('${snapshot.path}/enrichment/$faction').existsSync();

    test("every T'au ability renders completely", () {
      final result = coverageOf('tau-empire');
      expect(result.total, greaterThan(100));
      expect(result.complete, result.total, reason: result.gaps.join(', '));
    }, skip: has('tau-empire') ? null : 'no snapshot');

    test('other factions stay above 90%', () {
      for (final faction in ['necrons', 'adeptus-astartes']) {
        if (!has(faction)) continue;
        final result = coverageOf(faction);
        final percent = result.complete * 100 / result.total;
        expect(percent, greaterThan(90),
            reason: '$faction at ${percent.round()}%: ${result.gaps.join(', ')}');
      }
    }, skip: has('necrons') ? null : 'no snapshot');
  });
}
