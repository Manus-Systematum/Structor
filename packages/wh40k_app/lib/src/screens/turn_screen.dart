import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../data/army.dart';
import '../theme.dart';
import '../widgets/collapsible.dart';
import '../widgets/end_phase.dart';
import '../widgets/stratagem_list.dart';
import '../widgets/weapon_table.dart';

/// The turn page (DESIGN.md §7.2, §7.3).
///
/// **Phase is a scroll axis, not tracked state.** Where you are scrolled *is*
/// the phase. An earlier design had the player advance a phase state machine so
/// the app could filter — six taps a turn, sixty a game, to maintain something
/// the player already knows. Only round and active player are tracked, because
/// they change five and ten times a game respectively and so earn their taps.
class TurnScreen extends StatelessWidget {
  final Army army;

  /// The game so far. Everything shown here is derived from it (§7.4).
  final BattleLog log;

  final void Function(BattleEvent) onEvent;
  final VoidCallback onUndo;

  /// The secondary deck. Empty until the mission pack loads, which is why the
  /// END section degrades to the score panel alone rather than failing.
  final SecondaryDeck deck;

  /// The mission data, for the primary each side is playing. Empty until it
  /// loads, which the END section degrades around rather than failing.
  final MissionPack pack;

  const TurnScreen({
    super.key,
    required this.army,
    this.log = const BattleLog(),
    this.onEvent = _ignore,
    this.onUndo = _nothing,
    this.deck = const SecondaryDeck([]),
    this.pack = const MissionPack(),
  });

  static void _ignore(BattleEvent _) {}
  static void _nothing() {}

  @override
  Widget build(BuildContext context) {
    final state = log.state;
    return Column(
      children: [
        _StickyHeader(
          state: state,
          canUndo: log.canUndo,
          onRound: (delta) =>
              onEvent(SetRound((state.round + delta).clamp(1, 5))),
          onTurn: () => onEvent(SetActivePlayer(
              state.activePlayer == Player.me ? Player.opponent : Player.me)),
          onCp: (delta) => onEvent(AdjustCp(delta)),
          onUndo: onUndo,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              for (final phase in [
                // Scout moves happen once, after deployment and before the
                // first turn (§7.3.10) — so from the second battle round the
                // section is not merely unused, it is describing a moment
                // that has passed. Left in place it invites a move that
                // cannot be taken.
                if (state.round <= 1) 'scout',
                'command',
                'movement',
                'shooting',
                'charge',
                'fight',
                'end',
              ])
                _PhaseSection(
                  phase: phase,
                  army: army,
                  state: state,
                  deck: deck,
                  pack: pack,
                  onEvent: onEvent,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StickyHeader extends StatelessWidget {
  final BattleState state;
  final bool canUndo;
  final void Function(int) onRound;
  final VoidCallback onTurn;
  final void Function(int) onCp;
  final VoidCallback onUndo;

  const _StickyHeader({
    required this.state,
    required this.canUndo,
    required this.onRound,
    required this.onTurn,
    required this.onCp,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final yourTurn = state.activePlayer == Player.me;
    return Material(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _Stepper(
              label: 'ROUND',
              value: '${state.round}',
              onDown: () => onRound(-1),
              onUp: () => onRound(1),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: onTurn,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: yourTurn
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        yourTurn ? 'YOUR TURN' : 'OPPONENT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: yourTurn
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      // The round moves on its own when the turn comes back to
                      // whoever opened, so it is announced before the tap
                      // rather than discovered afterwards.
                      if (state.passingEndsRound) ...[
                        const Spacer(),
                        Text(
                          '→ R${state.round + 1}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: (yourTurn
                                    ? scheme.onPrimaryContainer
                                    : scheme.onSurfaceVariant)
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _Stepper(
              label: 'CP',
              value: '${state.cp}',
              onDown: () => onCp(-1),
              onUp: () => onCp(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onDown;
  final VoidCallback onUp;

  const _Stepper({
    required this.label,
    required this.value,
    required this.onDown,
    required this.onUp,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 9,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TapTarget(icon: Icons.remove, onTap: onDown),
            SizedBox(
              width: 26,
              child: Text(value,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            _TapTarget(icon: Icons.add, onTap: onUp),
          ],
        ),
      ],
    );
  }
}

class _TapTarget extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TapTarget({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => InkResponse(
        onTap: onTap,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18),
        ),
      );
}

/// One phase's worth of the turn. Content is filtered to this phase, which is
/// what makes phase-as-scroll-position work: relevance comes from where you are
/// reading rather than from state you had to maintain.
class _PhaseSection extends StatelessWidget {
  final String phase;
  final Army? army;
  final BattleState state;
  final SecondaryDeck deck;
  final MissionPack pack;
  final void Function(BattleEvent) onEvent;

  const _PhaseSection({
    required this.phase,
    this.army,
    this.state = const BattleState(),
    this.deck = const SecondaryDeck([]),
    this.pack = const MissionPack(),
    this.onEvent = TurnScreen._ignore,
  });

  static const _labels = {
    'scout': 'SCOUTING',
    'command': 'COMMAND',
    'movement': 'MOVEMENT',
    'shooting': 'SHOOTING',
    'charge': 'CHARGE',
    'fight': 'FIGHT',
    'end': 'END',
  };

  /// Whether either side's primary pays out in this Command phase.
  ///
  /// Asked of the mission data rather than assumed from the round: every
  /// phased award in the shipped cards is a command-phase one gated at round
  /// two, but a screen that hard-coded "round >= 2" would quietly stop being
  /// right the moment upstream adds a tier.
  bool get _scoresNow {
    final setup = state.setup;
    if (setup == null) return false;
    for (final id in [setup.myMissionId, setup.opponentMissionId]) {
      final card = pack.card(id);
      if (card != null &&
          card.scoresIn(phase: 'command', round: state.round)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final army = this.army;

    final kind = switch (phase) {
      'shooting' => WeaponKind.ranged,
      'fight' => WeaponKind.melee,
      _ => null,
    };

    final hasStratagems =
        army != null && army.stratagems.forPhase(phase, state: state).isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: scheme.surfaceContainer,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Text(
            _labels[phase] ?? phase.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: scheme.primary,
            ),
          ),
        ),
        // Scouting is a pre-game list, not a phase of the turn, so it carries
        // its own content and none of the per-phase machinery.
        if (phase == 'scout')
          _ScoutGroup(army: army)
        else ...[
          // Stratagems lead the section. They are the decision the phase turns
          // on, and the weapon tables below are the reference for making it.
          if (army != null && hasStratagems)
            CollapsibleGroup(
              title: 'STRATAGEMS',
              icon: Icons.bolt,
              trailing:
                  '${army.stratagems.forPhase(phase, state: state).length}',
              // Open where the decision is made, folded where it is reference.
              initiallyOpen: true,
              child: StratagemList(
                army: army,
                phase: phase,
                state: state,
                onEvent: onEvent,
              ),
            ),
          // The primary's round-2-onward tier is scored in the Command phase,
          // and every phased award in the data is a command-phase one. It
          // reads and writes the same BattleState as the END section, so the
          // two can never show different numbers (§7.3.11).
          if (phase == 'command' && _scoresNow)
            CollapsibleGroup(
              title: 'SCORE THE PRIMARY',
              icon: Icons.emoji_events_outlined,
              trailing: 'round ${state.round}',
              initiallyOpen: true,
              child: ScorePanel(state: state, pack: pack, onEvent: onEvent),
            ),
          // Secondaries are **drawn** at the start of a turn and **scored** at
          // the end of one, so a deck reachable only from END sat a scroll
          // away from half of what it is for. The same panel appears in both,
          // reading and writing the same state — including the cards that pay
          // out at the start of your next turn, which are scored here because
          // here is when they happen.
          // Unwrapped, as it is in END: the panel carries its own header, and
          // a CollapsibleGroup around it prints "SECONDARIES" twice.
          if (phase == 'command' && !deck.isEmpty)
            SecondaryPanel(state: state, deck: deck, onEvent: onEvent),
          // END is where both players' scores live and where the deck is
          // worked (§7.3.2, §7.3.3).
          // The Movement phase turns on one number, and it was the one number
          // the page did not show: every other phase had a weapon table while
          // this one said "nothing tracked here". Scout distances appear
          // beside it in the first round, since a Scout move is a movement
          // the player is about to make and the two are read together.
          if (phase == 'movement' && army != null)
            CollapsibleGroup(
              title: 'MOVE',
              icon: Icons.directions_run,
              trailing: '${army.combatUnits.length} units',
              initiallyOpen: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final unit in army.combatUnits)
                    _MoveRow(unit: unit, state: state),
                ],
              ),
            ),
          if (phase == 'end')
            EndPhase(state: state, deck: deck, pack: pack, onEvent: onEvent)
          else if (phase == 'movement')
            const SizedBox.shrink()
          else if (army == null || kind == null)
            // Only when the phase really carries nothing. Saying "nothing
            // tracked here" underneath a scoring panel contradicts itself.
            if (!(phase == 'command' && _scoresNow))
              _phasePlaceholder(context, army, hasStratagems: hasStratagems)
            else
              const SizedBox.shrink()
          else
            CollapsibleGroup(
              title: 'PROFILES',
              icon: Icons.grid_on,
              trailing: '${army.combatUnits.length} units',
              initiallyOpen: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final unit in army.combatUnits)
                    _UnitBlock(
                      unit: unit,
                      kind: kind,
                      phase: phase,
                      state: state,
                    ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _phasePlaceholder(
    BuildContext context,
    Army? army, {
    bool hasStratagems = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final rules = army == null
        ? <({String unit, RenderedRule rule})>[]
        : [
            for (final unit in army.combatUnits)
              for (final rule in unit.rules)
                if (rule.phases.contains(phase))
                  (unit: unit.label, rule: rule),
          ];

    // Stratagems alone make a section worth reading, so the empty note is
    // only honest when there is nothing at all.
    if (rules.isEmpty) {
      if (hasStratagems) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Text('Nothing tracked in this phase yet',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in rules)
          _RuleTile(unitLabel: entry.unit, rule: entry.rule),
      ],
    );
  }
}

class _UnitBlock extends StatelessWidget {
  final CombatUnit unit;
  final WeaponKind kind;
  final String phase;
  final BattleState state;

  const _UnitBlock({
    required this.unit,
    required this.kind,
    required this.phase,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Casualties recorded in the log shrink the table live (§7.3.5).
    final table = unit.weapons(kind, modelsRemaining: state.modelsRemaining);
    if (table.weapons.isEmpty && table.isComplete) {
      return const SizedBox.shrink();
    }

    // Rules tagged with this phase surface next to the weapons they modify,
    // rather than waiting in a reference screen (§7.3.6).
    final rules =
        unit.rules.where((r) => r.phases.contains(phase)).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(unit.label,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                  Text('${unit.points} pts',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            WeaponTable(result: table),
            for (final rule in rules)
              _RuleTile(rule: rule, compact: true),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  final RenderedRule rule;
  final String? unitLabel;
  final bool compact;

  const _RuleTile({
    required this.rule,
    this.unitLabel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 4, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bolt,
              size: 14,
              color: rule.isComplete ? scheme.tertiary : scheme.error),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  if (unitLabel != null)
                    TextSpan(
                      text: '$unitLabel · ',
                      style: TextStyle(
                          fontSize: 11.5, color: scheme.onSurfaceVariant),
                    ),
                  TextSpan(
                    text: '${rule.name}: ',
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: rule.text,
                    style: TextStyle(
                        fontSize: 11.5, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Units that may make a Scout move, and how far (DESIGN.md §7.3.10).
///
/// A pre-game step with a hard deadline: once deployment is finished the move
/// cannot be taken, and nothing else in the app was asking the question. The
/// distance comes from the ability's effect rather than its name, so a rule
/// One unit's Move, for the phase that turns on it.
///
/// Distinct profiles are shown separately for the same reason the statline is
/// (§7.3.6): a Commander at M12 leading Crisis suits at M10 moves as the
/// slowest model in the unit, and a single averaged figure would be a number
/// that is true of nobody.
class _MoveRow extends StatelessWidget {
  final CombatUnit unit;
  final BattleState state;

  const _MoveRow({required this.unit, required this.state});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final moves = <String, String>{};
    for (final entry in unit.profiles) {
      final m = entry.profile.m;
      if (m != null && m.isNotEmpty) moves[entry.name] = m;
    }
    if (moves.isEmpty) return const SizedBox.shrink();

    // One figure when the whole unit shares it, names when it does not.
    final distinct = moves.values.toSet();
    final destroyed = state.unit(unit.head.instanceId).isDestroyed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Opacity(
        opacity: destroyed ? 0.4 : 1,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(unit.label,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            if (distinct.length == 1)
              Text(distinct.first,
                  style: AppTheme.numeric(context, size: 14)
                      .copyWith(fontWeight: FontWeight.w800))
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final entry in moves.entries)
                    Text('${entry.value}  ${entry.key}',
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// that grants a Scout move without saying "Scouts" — the Necrons' Enlivened
/// Sentinels — is not silently dropped.
class _ScoutGroup extends StatelessWidget {
  final Army? army;

  const _ScoutGroup({this.army});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final army = this.army;
    final moves = army?.scoutMoves ?? const [];

    if (moves.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Text(
          army == null
              ? 'No army loaded.'
              : 'Nothing in this army makes a Scout move.',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      );
    }

    return CollapsibleGroup(
      title: 'SCOUT MOVES',
      icon: Icons.directions_run,
      trailing: '${moves.length} unit${moves.length == 1 ? '' : 's'}',
      initiallyOpen: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final move in moves)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 3, 16, 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(move.unit.label,
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                  Text('${move.distance}"',
                      style: AppTheme.numeric(context, size: 13)
                          .copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Text(
              'Before the first turn, after both armies are deployed. A unit '
              'led by a character without a Scout move does not get one.',
              style: TextStyle(
                  fontSize: 10.5, height: 1.35, color: scheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}
