/// Renders structured ability effects into short English (DESIGN.md §7.3.6).
///
/// Required infrastructure rather than a nicety: abilities in the source data
/// carry structured effects and **no prose at all** — 0 of 129 T'au abilities
/// have a text field. Without this the play screen can name a rule but not say
/// what it does.
///
/// Two properties follow from generating the text rather than transcribing it.
/// The output is **ours**, which sidesteps the copyright constraint of §0
/// entirely; and it is terse and uniform in a way printed rules never are,
/// which matters on a phone held in one hand mid-game.
///
/// Where a shape is not recognised the renderer **says so** (§7.6). A rules aid
/// that quietly invents a sentence is worse than one that admits a gap.
library;

import '../source/json.dart';
import '../source/source_models.dart';

class RenderedRule {
  final String abilityId;
  final String name;
  final String text;

  /// Phases mentioned by `phase-is` conditions, so the card can surface itself
  /// in the right section of the turn page.
  final List<String> phases;

  /// Effect or condition types encountered but not understood. Non-empty means
  /// [text] contains a visible placeholder rather than a silent omission.
  final List<String> unrendered;

  const RenderedRule({
    required this.abilityId,
    required this.name,
    required this.text,
    required this.phases,
    required this.unrendered,
  });

  bool get isComplete => unrendered.isEmpty;

  @override
  String toString() => '$name — $text';
}

class RulesRenderer {
  const RulesRenderer();

  RenderedRule render(SourceAbility ability) {
    final ctx = _Ctx();
    var text = _effect(ability.effect, ctx);

    final frequency = str(ability.usage['frequency']);
    if (frequency != null) text = '$text (${_words(frequency)})';

    return RenderedRule(
      abilityId: ability.abilityId,
      name: ability.name,
      text: text.isEmpty ? '—' : _sentence(text),
      phases: ctx.phases.toList(),
      unrendered: ctx.unrendered.toList(),
    );
  }

  // ---------------------------------------------------------------- effects

  String _effect(Map<String, dynamic> node, _Ctx ctx) {
    if (node.isEmpty) return '';
    final type = strOr(node['type'], '');
    final mod = asMap(node['modifier']);

    switch (type) {
      case 'sequence':
        final steps = asList(node['steps'])
            .map((s) => _effect(asMap(s), ctx))
            .where((s) => s.isNotEmpty)
            .toList();
        return steps.join('; ');

      case 'conditional':
        final condition = _condition(asMap(node['condition']), ctx);
        final inner = _effect(asMap(node['effect']), ctx);
        return condition.isEmpty ? inner : '$condition: $inner';

      case 'dice-gated':
        final dice = strOr(node['dice'], 'D6');
        final threshold = str(node['threshold']) ?? '?';
        final comparison =
            strOr(node['comparison'], 'gte') == 'gte' ? '+' : '';
        final success = _effect(asMap(node['on_success']), ctx);
        final fail = _effect(asMap(node['on_fail']), ctx);
        final tail = fail.isEmpty ? '' : ', otherwise $fail';
        return 'on a $dice of $threshold$comparison, $success$tail';

      case 'stat-modifier':
        final stat = _statName(strOr(mod['stat'], '?'));
        final qualifier =
            str(mod['weapon_type']) ?? str(mod['attack_type']);
        final scope = qualifier == null ? '' : ' (${_words(qualifier)})';
        // Whose characteristic changes is the whole meaning of an ability
        // like Enforcer Commander, where the AP being worsened is the
        // *attacker's*. Rendering it ownerless reads as a buff.
        final owner = switch (strOr(node['target'], '')) {
          'attacker' => "attacker's ",
          'defender' => "target's ",
          _ => '',
        };
        return '$owner${_statChange(stat, mod, ctx)}$scope';

      case 'aura':
        final range = str(mod['range']) ?? '?';
        final eligible = _eligibility(asMap(mod['eligible']));
        final inner = _effect(asMap(mod['effect']), ctx);
        return 'aura $range": $eligible$inner';

      case 'choice':
        final label = str(node['choice_label']);
        final options = asList(node['options'])
            .map((o) => _effect(asMap(o), ctx))
            .where((s) => s.isNotEmpty)
            .toList();
        final body = options.join(', or ');
        return label == null ? 'choose: $body' : '${_words(label)} — $body';

      case 'select-units':
        final selector = asMap(node['selector']);
        final count = str(selector['count']) ?? '1';
        final owner = _words(strOr(selector['owner'], 'friendly'));
        final keywords = strList(selector['keywords']).map(_keyword).join(' ');
        final within = str(selector['within_inches']);
        final range = within == null ? '' : ' within $within"';
        final inner = _effect(asMap(node['effect']), ctx);
        return 'select $count $owner $keywords unit(s)$range: $inner';

      case 'stance-select':
        final when = _words(strOr(node['select'], 'start of battle round'));
        final names = asList(node['options'])
            .map((o) => str(asMap(o)['name']))
            .whereType<String>()
            .toList();
        return 'at $when, select one: ${names.join(' / ')}';

      case 'rule-state':
        final rule = _words(strOr(mod['rule'], 'that rule'));
        return strOr(mod['direction'], '') == 'suppressed'
            ? 'cannot $rule'
            : 'can $rule';

      case 'resurrection':
        final frequency = str(mod['type']);
        final qualifier = frequency == null ? '' : ' (${_words(frequency)})';
        return 'returns destroyed models$qualifier';

      case 'unit-attachment':
        return 'may be led by ${_keyword(strOr(mod['led_by'], 'a character'))}';

      case 'fight-first':
        return 'Fights First';

      case 'fight-on-death':
        return 'may fight after being destroyed';

      case 'shoot-on-death':
        return 'may shoot after being destroyed';

      case 'roll-modifier':
        final roll = _rollName(strOr(mod['roll'], 'all'));
        final context = str(mod['context']);
        final when = context == null ? '' : ' (${_words(context)})';
        return switch (strOr(mod['operation'], 'add')) {
          'ignore-modifiers' => 'ignore modifiers to $roll rolls',
          'ignore-engagement-penalty' =>
            'ignore the Engagement Range penalty to $roll rolls',
          // A fixed roll, not a bonus: Sentinel Protocols hits on 5+ in
          // Overwatch regardless of BS.
          'set' => '$roll on ${str(mod['value']) ?? '?'}+$when',
          'crit-on' =>
            'critical $roll on ${str(mod['value']) ?? '?'}+$when',
          'add' || 'subtract' => '${_signed(mod)} to $roll$when',
          final other => _unknownOperation(other, '$roll rolls', mod, ctx),
        };

      case 'bs-modifier':
        return '${_signed(mod)} to Hit';

      case 'charge-roll-modifier':
        return '${_signed(mod)} to Charge rolls';

      case 're-roll':
        final roll = _rollName(strOr(mod['roll'], 'hit'));
        // The adjective belongs before the roll name: "failed Hit rolls", not
        // "Hit failed rolls".
        return switch (strOr(mod['subset'], 'all-failures')) {
          'ones' => 're-roll $roll rolls of 1',
          'all-failures' => 're-roll failed $roll rolls',
          'all' => 're-roll $roll rolls',
          final other => 're-roll ${_words(other)} $roll rolls',
        };

      case 'keyword-grant':
        final keywords = strList(mod['keywords']).map(_keyword).join(', ');
        return 'gains $keywords';

      case 'unit-keyword':
        return 'gains ${_keyword(strOr(mod['keyword_id'], '?'))}';

      case 'ability-grant':
        final ability = str(mod['ability']);
        if (ability != null) return 'grants ${_words(ability)}';
        final weapon = str(mod['weapon']);
        if (weapon != null) return 'grants ${_words(weapon)}';
        return 'grants a ${_words(strOr(mod['grant_type'], 'bonus'))}';

      case 'movement-modifier':
        final distance = str(mod['distance']);
        final moveType = _words(strOr(mod['move_type'], 'move'));
        return distance == null ? moveType : '$moveType $distance"';

      case 'mortal-wounds':
        final count = strOr(mod['count'], '1').toUpperCase();
        final range = str(mod['range']);
        final within = range == null ? '' : ' to units within $range"';
        return '$count mortal wounds$within';

      case 'invulnerable-save':
        return '${str(mod['invuln_sv']) ?? '?'}+ invulnerable save';

      case 'feel-no-pain':
        return 'Feel No Pain ${str(mod['threshold']) ?? '?'}+';

      case 'damage-reduction':
        return strOr(mod['reduction'], '') == 'to-zero'
            ? 'damage reduced to 0'
            : 'damage reduced by ${str(mod['reduction']) ?? '?'}';

      case 'cp-gain':
        return 'gain ${str(mod['amount']) ?? '1'}CP';

      case 'cp-refund':
        return strOr(mod['type'], '') == 'stratagem-for-0cp'
            ? 'use that Stratagem for 0CP'
            : 'refunds CP';

      case 'fallback-and-act':
        return 'may act normally after Falling Back';

      case 'deep-strike':
        return 'Deep Strike';

      case 'cover-benefit':
        return 'has the Benefit of Cover';

      case 'objective-control-modifier':
        if (mod['sticky'] == true) {
          return 'objectives remain controlled after leaving';
        }
        if (mod['operation'] == null) return 'modifies objective control';
        return _statChange('OC', mod, ctx);

      case 'leadership-modifier':
        final test = _words(strOr(mod['test'], 'Leadership'));
        return 'must take a $test test';

      case 'attack-restriction':
        return _words(strOr(mod['restriction'], 'restricted'));

      case 'targeting-permission':
        final attack = _words(strOr(mod['attack_type'], ''));
        final range = str(mod['range']);
        return range == null
            ? 'restricts $attack targeting'
            : 'may only be targeted by $attack attacks within $range"';

      case 'disembark-after-move':
        final after = _words(strOr(mod['after'], 'moving'));
        final charge =
            mod['can_charge'] == true ? ' and may charge' : ' but may not charge';
        return 'may disembark after $after$charge';

      case 'resource-spend':
        return 'spends ${_words(strOr(mod['resource'], 'a resource'))}';

      case 'designate-target':
        final designation = _keyword(strOr(node['designation'], 'marked'));
        final select = asMap(node['select']);
        final count = str(select['count']) ?? '1';
        final scope = _words(strOr(select['scope'], 'unit'));
        final applies = _effect(asMap(asMap(node['applies'])['effect']), ctx);
        final duration = str(node['duration']);
        final until = duration == null ? '' : ' until ${_words(duration)}';
        final result = applies.isEmpty ? '' : ' — that unit suffers $applies';
        return 'designate $count $scope as $designation$result$until';

      case '':
        return '';

      default:
        ctx.unrendered.add(type);
        return '[$type]';
    }
  }

  // ------------------------------------------------------------- conditions

  String _condition(Map<String, dynamic> node, _Ctx ctx) {
    if (node.isEmpty) return '';

    final operator = str(node['operator']);
    if (operator != null) {
      final parts = asList(node['operands'])
          .map((o) => _condition(asMap(o), ctx))
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.isEmpty) return '';
      return parts.join(operator == 'and' ? ' and ' : ' or ');
    }

    final type = strOr(node['type'], '');
    final params = asMap(node['parameters']);
    final negated = node['negated'] == true;

    final rendered = switch (type) {
      'phase-is' => _phase(strOr(params['phase'], ''), ctx),
      'player-turn-is' => strOr(params['turn'], '') == 'opponent'
          ? "opponent's turn"
          : 'your turn',
      'timing-is' => _words(strOr(params['timing'], '')),
      'target-has-keyword' =>
        'vs ${_keyword(strOr(params['keyword'], '?'))}',
      'unit-has-keyword' =>
        'while ${_keyword(strOr(params['keyword'], '?'))}',
      'attack-is-type' =>
        '${_words(strOr(params['attack_type'], ''))} attacks',
      'battle-round' => _battleRound(params),
      'unit-within-range-of' =>
        'within ${str(params['range']) ?? '?'}" of a '
            '${_words(strOr(params['target_type'], 'unit'))}',
      'opponent-unit-within-range' =>
        'against the ${_words(strOr(params['target_qualifier'], 'nearest enemy'))}',
      'was-hit-by-attack' =>
        'after being hit by ${_words(strOr(params['attack_type'], ''))} attacks',
      'unit-below-starting-strength' => negated
          ? '${_words(strOr(params['subject'], 'unit'))} at full strength'
          : '${_words(strOr(params['subject'], 'unit'))} below starting strength',

      'attack-stat-compare' =>
        '${_statName(strOr(params['attacker_stat'], '?'))} '
            '${_words(strOr(params['comparison'], 'vs'))} '
            '${_statName(strOr(params['target_stat'], '?'))}',
      'destroyed-by-attack-type' =>
        'destroyed by ${_words(strOr(params['attack_type'], ''))} attacks',
      'model-is-leader' =>
        'while led by ${_keyword(strOr(params['leader_type'], 'a character'))}',
      'terrain-area-control' =>
        'controlling ${_words(strOr(params['area'], 'the terrain area'))}',
      'units-destroyed' => 'if ${str(params['count_min']) ?? '1'}+ '
          '${_words(strOr(params['side'], 'enemy'))} unit(s) were destroyed '
          '${_words(strOr(params['window'], 'this phase'))}',

      // Parameterless conditions: the type name carries the whole meaning.
      'is-attached' => 'while leading a unit',
      'remained-stationary' => 'if it Remained Stationary',
      'unit-below-half-strength' => 'below half strength',
      'charged-this-turn' => 'if it charged this turn',
      'advanced-this-turn' => 'if it Advanced',
      'is-battle-shocked' => 'while Battle-shocked',
      'engagement-state' => 'while in Engagement Range',
      'has-lost-wounds' => 'if it has lost wounds',
      'controls-objective' => 'while controlling an objective',
      'within-range-of-objective' => 'within range of an objective',
      'disembarked-from-transport' => 'after disembarking',
      'damage-is-mortal' => 'against mortal wounds',

      _ => null,
    };

    if (rendered == null) {
      ctx.unrendered.add('condition:$type');
      return '[$type]';
    }

    // `unit-below-starting-strength` folds negation into its own wording; every
    // other condition negates uniformly.
    if (negated && type != 'unit-below-starting-strength') {
      return 'unless $rendered';
    }
    return rendered;
  }

  /// `{required_keywords: [NECRONS], excluded_keywords: [MONSTER]}` becomes
  /// `NECRONS (not MONSTER) `, ready to prefix an aura's effect.
  String _eligibility(Map<String, dynamic> eligible) {
    if (eligible.isEmpty) return '';
    final required = strList(eligible['required_keywords']).map(_keyword);
    final excluded = strList(eligible['excluded_keywords']).map(_keyword);
    final parts = <String>[
      if (required.isNotEmpty) required.join(' '),
      if (excluded.isNotEmpty) '(not ${excluded.join(' ')})',
    ];
    return parts.isEmpty ? '' : '${parts.join(' ')} — ';
  }

  String _battleRound(Map<String, dynamic> params) {
    final min = str(params['min']);
    final max = str(params['max']);
    if (min != null && max != null) return 'battle rounds $min-$max';
    if (min != null) return 'from battle round $min';
    if (max != null) return 'until battle round $max';
    return 'battle round';
  }

  String _phase(String phase, _Ctx ctx) {
    if (phase.isEmpty) return '';
    ctx.phases.add(phase);
    return '${_capitalise(phase)} phase';
  }

  // ---------------------------------------------------------------- helpers

  /// A characteristic change written the way the operation actually behaves.
  ///
  /// The data uses twelve operations, not two. Collapsing them into `+N`/`-N`
  /// is how the Coldstar Commander's *Move set to 12* became `+12 Move` — a
  /// buff of half again on a suit that already moves 12 — and how thirteen
  /// `{operation: add, value: -1}` AP improvements read as penalties.
  String _statChange(String stat, Map<String, dynamic> mod, _Ctx ctx) {
    final value = asInt(mod['value']);
    final magnitude = (value ?? 1).abs();
    return switch (strOr(mod['operation'], 'add')) {
      'add' || 'subtract' => '${_signed(mod)} $stat',
      'set' => '$stat set to ${value ?? '?'}',
      'improve' => '$stat improved by $magnitude',
      'worsen' => '$stat worsened by $magnitude',
      'multiply' => '$stat ×$magnitude',
      'halve' => '$stat halved',
      'improve-vs-D1' =>
        '$stat improved by $magnitude against Damage 1 attacks',
      'set-on-crit-wound' =>
        'on a Critical Wound, $stat set to ${value ?? '?'}',
      final other => _unknownOperation(other, stat, mod, ctx),
    };
  }

  /// An operation the renderer does not know. Shown, not guessed at (§7.6):
  /// silently treating it as an addition is exactly the failure this method
  /// exists to stop repeating.
  String _unknownOperation(
    String operation,
    String subject,
    Map<String, dynamic> mod,
    _Ctx ctx,
  ) {
    ctx.unrendered.add('operation:$operation');
    final value = str(mod['value']);
    return '[$operation${value == null ? '' : ' $value'}] $subject';
  }

  /// `{operation: add, value: 1}` becomes `+1`; a negative value keeps its
  /// sign, because `{add, -1}` on AP is an improvement, not a bonus of one.
  String _signed(Map<String, dynamic> mod) {
    final value = asInt(mod['value']) ?? 1;
    final effective =
        strOr(mod['operation'], 'add') == 'subtract' ? -value.abs() : value;
    return effective < 0 ? '$effective' : '+$effective';
  }

  static const _stats = {
    'M': 'Move',
    'T': 'Toughness',
    'W': 'Wound',
    'Sv': 'Save',
    'Ld': 'Leadership',
    'OC': 'OC',
    'A': 'Attacks',
    'S': 'Strength',
    'AP': 'AP',
    'D': 'Damage',
    'BS': 'BS',
    'WS': 'WS',
  };

  String _statName(String stat) => _stats[stat] ?? stat;

  static const _rolls = {
    'hit': 'Hit',
    'wound': 'Wound',
    'save': 'Save',
    'charge': 'Charge',
    'advance': 'Advance',
    'damage': 'Damage',
    'all': 'all',
    'any': 'any roll',
  };

  String _rollName(String roll) => _rolls[roll] ?? _words(roll);

  /// Keywords are shown as the rulebook shows them: upper case.
  String _keyword(String keyword) => keyword.toUpperCase();

  /// `before-bearer-removed` becomes `before bearer removed`.
  String _words(String value) =>
      value.replaceAll('-', ' ').replaceAll('_', ' ').trim();

  String _capitalise(String value) {
    final words = _words(value);
    if (words.isEmpty) return words;
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }

  String _sentence(String text) {
    if (text.isEmpty) return text;
    final capitalised = '${text[0].toUpperCase()}${text.substring(1)}';
    return capitalised.endsWith('.') ? capitalised : '$capitalised.';
  }
}

class _Ctx {
  final Set<String> phases = {};
  final Set<String> unrendered = {};
}
