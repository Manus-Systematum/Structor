import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../data/army.dart';
import '../data/play_density.dart';
import '../theme.dart';
import '../widgets/battle_record.dart';
import '../widgets/collapsible.dart';
import '../widgets/remembered_toggle.dart';
import '../widgets/rule_text.dart';
import '../widgets/score_board.dart';
import '../widgets/sheet_header.dart';
import '../widgets/stratagem_list.dart';
import '../widgets/unit_profiles.dart';
import '../widgets/weapon_table.dart';

/// The turn page (DESIGN.md §7.3.13).
///
/// **One page per turn, not one per phase.** The page it replaces was six
/// phase sections with every unit's weapons and every rule's full text
/// repeated under each: measured by rendering it, a 2,000 point T'au turn
/// scrolled **41.7 screens**, 61% of it the Shooting section, and **94% of the
/// strings drawn were repeats of something already on the page**. Phase is a
/// property of *rules*; what you scroll past is units and weapons, which are
/// phase-invariant — so sorting by phase was what forced the duplication.
///
/// Sorted by unit, each rule is drawn once. What is on the page and what is a
/// tap away follows the one measurement that decides it: a rule *name* costs
/// 12–15 characters, its printed text 174–198 on average and up to 993. Names
/// and weapon statlines stay on the page; **the only thing behind a tap is
/// rules text**, because it is the only thing that cannot fit.
class TurnScreen extends StatefulWidget {
  final Army army;
  final BattleLog log;
  final void Function(BattleEvent) onEvent;
  final VoidCallback onUndo;
  final VoidCallback? onFinish;
  final SecondaryDeck deck;
  final MissionPack pack;

  /// How much detail to carry. Null until the stored preference loads, when
  /// it falls back to what the roster's own size suggests.
  final PlayDensity? density;
  final void Function(PlayDensity)? onDensity;

  const TurnScreen({
    super.key,
    required this.army,
    this.log = const BattleLog(),
    this.onEvent = _ignore,
    this.onUndo = _nothing,
    this.onFinish,
    this.deck = const SecondaryDeck([]),
    this.pack = const MissionPack(),
    this.density,
    this.onDensity,
  });

  static void _ignore(BattleEvent _) {}
  static void _nothing() {}

  @override
  State<TurnScreen> createState() => _TurnScreenState();
}

class _TurnScreenState extends State<TurnScreen> {
  /// Which past turn is being read, as an index into [_turnEnds]. Null is the
  /// live turn, which is where the page always starts.
  int? _reviewing;

  /// The index of the last event of each turn, in order.
  ///
  /// A turn is a run of events sharing a round and an active player, which is
  /// what `timeline` already works out — so the boundaries come from the same
  /// replay the state does rather than from a second reading of the log.
  List<int> get _turnEnds {
    final ends = <int>[];
    ({int round, Player player})? current;
    for (final entry in widget.log.timeline) {
      final key = (round: entry.round, player: entry.activePlayer);
      if (current != null && key != current) ends.add(entry.index - 1);
      current = key;
    }
    return ends;
  }

  /// The state as it stood at the end of the reviewed turn, or the live state.
  BattleLog get _shown {
    final at = _reviewing;
    if (at == null) return widget.log;
    final ends = _turnEnds;
    if (at < 0 || at >= ends.length) return widget.log;
    return BattleLog(
      events: widget.log.events.sublist(0, ends[at] + 1),
      secondaryCaps: widget.log.secondaryCaps,
    );
  }

  void _stepBack() {
    final ends = _turnEnds;
    if (ends.isEmpty) return;
    setState(() {
      final at = _reviewing;
      _reviewing =
          at == null ? ends.length - 1 : (at - 1).clamp(0, ends.length);
    });
  }

  void _stepForward() => setState(() {
        final at = _reviewing;
        if (at == null) return;
        // Past the last boundary is the live turn, which is not a boundary.
        _reviewing = at + 1 >= _turnEnds.length ? null : at + 1;
      });

  /// The record, over the page rather than beside it.
  ///
  /// Mid-game the question is "what did I already score this round", which is
  /// asked rarely and answered in a glance — so it is a sheet that closes back
  /// to the turn, not a tab that takes the page away.
  void _showRecord(BuildContext context) {
    final names = {
      for (final unit in widget.army.combatUnits)
        unit.head.instanceId: unit.label,
    };
    final stratagems = {
      for (final s in widget.army.stratagems.stratagems) s.id: s.name,
    };
    final cards = {
      for (final c in widget.deck.cards) c.id: c.name,
    };
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            BattleRecord(
              log: widget.log,
              unitName: (id) => names[id] ?? id,
              cardName: (id) => stratagems[id] ?? cards[id] ?? id,
              opponentName:
                  widget.log.state.setup?.opponentName?.trim().isNotEmpty ??
                          false
                      ? widget.log.state.setup!.opponentName!.trim()
                      : 'Opponent',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final state = shown.state;
    final reviewing = _reviewing != null;
    final density = widget.density ?? PlayDensity.defaultFor(widget.army);

    // Reviewing is reading. A tap that scored a past round from a page that
    // says it is showing a past round would be a different feature, and a
    // surprising one, so the controls are inert until it is dismissed.
    void emit(BattleEvent event) {
      if (!reviewing) widget.onEvent(event);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TurnBar(
          state: state,
          density: density,
          canUndo: widget.log.canUndo && !reviewing,
          onEvent: emit,
          onUndo: widget.onUndo,
          onDensity: widget.onDensity,
          onRecord: () => _showRecord(context),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              if (reviewing)
                _ReviewBanner(
                  state: state,
                  onExit: () => setState(() => _reviewing = null),
                ),
              ScoreBoard(
                state: state,
                pack: widget.pack,
                deck: widget.deck,
                onEvent: emit,
              ),
              _Stratagems(
                army: widget.army,
                state: state,
                onEvent: emit,
              ),
              if (density.showsPrompts)
                _Prompts(army: widget.army, state: state),
              if (state.round <= 1) _Scouting(army: widget.army),
              _Heading(
                label: 'UNITS',
                trailing: '${widget.army.combatUnits.length}',
              ),
              for (final unit in widget.army.combatUnits)
                _UnitRow(
                  unit: unit,
                  state: state,
                  density: density,
                  onEvent: emit,
                ),
              // The foot of the page is where a turn actually ends — you have
              // just read down it — so the controls that move between turns
              // are here as well as in the bar (§7.3.20).
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _turnEnds.isEmpty ? null : _stepBack,
                        icon: const Icon(Icons.chevron_left, size: 18),
                        label: const Text('Previous turn'),
                      ),
                    ),
                    // Only when there is a turn to come back to. At the live
                    // turn there is nothing forward of here.
                    if (reviewing) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _stepForward,
                          icon: const Icon(Icons.chevron_right, size: 18),
                          label: const Text('Next turn'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!reviewing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: FilledButton.icon(
                    onPressed: () => widget.onEvent(const EndTurn()),
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('End turn'),
                  ),
                ),
              if (widget.onFinish != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                  child: OutlinedButton.icon(
                    onPressed: widget.onFinish,
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: const Text('Finish battle'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Says the page is showing a turn that has already been played.
///
/// Without it the only difference between reviewing round two and being in
/// round two is a number in the bar, and a player who scrolled back would
/// score into the past believing it was now.
class _ReviewBanner extends StatelessWidget {
  final BattleState state;
  final VoidCallback onExit;

  const _ReviewBanner({required this.state, required this.onExit});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final whose = state.activePlayer == Player.me ? 'your turn' : 'their turn';
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.history, size: 16, color: scheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Round ${state.round}, $whose — already played. '
              'Nothing here can be changed.',
              style: TextStyle(
                  fontSize: 12, color: scheme.onTertiaryContainer, height: 1.3),
            ),
          ),
          TextButton(onPressed: onExit, child: const Text('Back to now')),
        ],
      ),
    );
  }
}

/// Round, whose turn it is, command points, and the one control that moves the
/// game on.
class _TurnBar extends StatelessWidget {
  final BattleState state;
  final PlayDensity density;
  final bool canUndo;
  final void Function(BattleEvent) onEvent;
  final VoidCallback onUndo;
  final void Function(PlayDensity)? onDensity;
  final VoidCallback onRecord;

  const _TurnBar({
    required this.state,
    required this.density,
    required this.canUndo,
    required this.onEvent,
    required this.onUndo,
    required this.onRecord,
    this.onDensity,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = state.activePlayer == Player.me;

    return Material(
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ROUND ${state.round}',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      )),
                  Text(mine ? 'Your turn' : 'Their turn',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(width: 14),
              // CP arrives on its own at the start of your turn, so this is a
              // readout with a correction rather than the only way to get it.
              _Cp(cp: state.cp, onEvent: onEvent),
              const Spacer(),
              if (onDensity != null)
                _DensityButton(density: density, onDensity: onDensity!),
              IconButton(
                tooltip: 'What has happened',
                visualDensity: VisualDensity.compact,
                onPressed: onRecord,
                icon: const Icon(Icons.history, size: 20),
              ),
              IconButton(
                tooltip: 'Undo',
                visualDensity: VisualDensity.compact,
                onPressed: canUndo ? onUndo : null,
                icon: const Icon(Icons.undo, size: 20),
              ),
              FilledButton(
                onPressed: () => onEvent(const EndTurn()),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(state.passingEndsRound
                    ? 'End turn · R${state.round + 1}'
                    : 'End turn'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Command points, and the two controls that change them.
///
/// It was a tap on the number to add and a long press to subtract, which is
/// two invisible gestures on the figure a player adjusts most. The plus is a
/// button now; the minus appears beside it once there is something to take
/// away (§7.3.18).
class _Cp extends StatelessWidget {
  final int cp;
  final void Function(BattleEvent) onEvent;

  const _Cp({required this.cp, required this.onEvent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cp > 0)
          _CpButton(
            icon: Icons.remove,
            tooltip: 'Spend a command point',
            onTap: () => onEvent(const AdjustCp(-1)),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('CP',
                  style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant)),
              Text('$cp',
                  style: AppTheme.numeric(context, size: 18)
                      .copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        _CpButton(
          icon: Icons.add,
          tooltip: 'Gain a command point',
          onTap: () => onEvent(const AdjustCp(1)),
        ),
      ],
    );
  }
}

class _CpButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CpButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 15, color: scheme.onSurface),
        ),
      ),
    );
  }
}

class _DensityButton extends StatelessWidget {
  final PlayDensity density;
  final void Function(PlayDensity) onDensity;

  const _DensityButton({required this.density, required this.onDensity});

  @override
  Widget build(BuildContext context) => PopupMenuButton<PlayDensity>(
        tooltip: 'How much detail',
        initialValue: density,
        onSelected: onDensity,
        icon: const Icon(Icons.tune, size: 20),
        itemBuilder: (_) => [
          for (final d in PlayDensity.values)
            PopupMenuItem(
              value: d,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(d.label),
                subtitle: Text(d.note, style: const TextStyle(fontSize: 11)),
                trailing:
                    d == density ? const Icon(Icons.check, size: 18) : null,
              ),
            ),
        ],
      );
}

/// Every stratagem the army can play, in one place.
///
/// Collected rather than de-duplicated: measured across three rosters, only
/// **3 of 19** stratagems appear in more than one phase, so scattering them
/// across six phase sections never repeated them — it just meant hunting six
/// places for sixteen cards that each live in one.
class _Stratagems extends StatelessWidget {
  final Army army;
  final BattleState state;
  final void Function(BattleEvent) onEvent;

  const _Stratagems({
    required this.army,
    required this.state,
    required this.onEvent,
  });

  static const _phases = [
    'command',
    'movement',
    'shooting',
    'charge',
    'fight',
    'end',
  ];

  @override
  Widget build(BuildContext context) {
    final total = army.stratagems.stratagems.length;
    if (total == 0) return const SizedBox.shrink();
    final usedNow = state
        .usesIn(phase: 'command')
        .length; // any use this round shows on the header
    return CollapsibleGroup(
      title: 'STRATAGEMS',
      icon: Icons.bolt,
      trailing: '$total · ${state.cp} CP',
      initiallyOpen: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final phase in _phases)
            if (army.stratagems.forPhase(phase, state: state).isNotEmpty)
              _PhaseStratagems(
                army: army,
                phase: phase,
                state: state,
                onEvent: onEvent,
              ),
          if (usedNow < 0) const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _PhaseStratagems extends StatelessWidget {
  final Army army;
  final String phase;
  final BattleState state;
  final void Function(BattleEvent) onEvent;

  const _PhaseStratagems({
    required this.army,
    required this.phase,
    required this.state,
    required this.onEvent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text(phase.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
              )),
        ),
        StratagemList(
          army: army,
          phase: phase,
          state: state,
          onEvent: onEvent,
        ),
      ],
    );
  }
}

/// What fires this phase, counted once — guided mode only.
class _Prompts extends StatelessWidget {
  final Army army;
  final BattleState state;

  const _Prompts({required this.army, required this.state});

  static const _phases = [
    'command',
    'movement',
    'shooting',
    'charge',
    'fight',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CollapsibleGroup(
      title: 'THIS TURN',
      icon: Icons.checklist,
      initiallyOpen: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final phase in _phases)
            Builder(builder: (_) {
              // One entry per distinct rule, not per unit carrying it: the
              // duplication is what made the old page unreadable.
              final rules = <String, List<String>>{};
              for (final unit in army.combatUnits) {
                for (final r in unit.rules) {
                  if (!r.phases.contains(phase)) continue;
                  rules.putIfAbsent(r.name, () => []).add(unit.label);
                }
              }
              if (rules.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(phase.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        )),
                    for (final entry in rules.entries)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${entry.key} — ${entry.value.length == 1 ? entry.value.single : '${entry.value.length} units'}',
                          style: TextStyle(
                              fontSize: 11.5, color: scheme.onSurface),
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Scout moves, which happen after deployment and before the first turn.
///
/// Round one only: from the second round it is not merely unused, it is
/// describing a moment that has passed, and a move that cannot be taken.
class _Scouting extends StatelessWidget {
  final Army army;

  const _Scouting({required this.army});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final moves = army.scoutMoves;
    if (moves.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Card(
        color: scheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SCOUT MOVES',
                  style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  )),
              const SizedBox(height: 3),
              for (final move in moves)
                Row(
                  children: [
                    Expanded(
                      child: Text(move.unit.label,
                          style: const TextStyle(fontSize: 12)),
                    ),
                    Text('${move.distance}"',
                        style: AppTheme.numeric(context, size: 12.5)
                            .copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One unit: what it is, what it carries, what it can do.
class _UnitRow extends StatefulWidget {
  final CombatUnit unit;
  final BattleState state;
  final PlayDensity density;
  final void Function(BattleEvent) onEvent;

  const _UnitRow({
    required this.unit,
    required this.state,
    required this.density,
    required this.onEvent,
  });

  @override
  State<_UnitRow> createState() => _UnitRowState();
}

/// The unit's Move, or null when its models disagree — in which case the
/// statline below says so properly rather than the row picking one.
String? _move(CombatUnit unit) {
  final values = <String>{
    for (final entry in unit.profiles)
      if (entry.profile.m case final m?)
        if (m.isNotEmpty) m,
  };
  return values.length == 1 ? values.single : null;
}

class _UnitRowState extends State<_UnitRow> with RemembersToggle<_UnitRow> {
  @override
  Object get toggleId => 'unit:${widget.unit.head.instanceId}';

  @override
  bool get initiallyOpen => widget.density.showsWeapons;

  @override
  void didUpdateWidget(_UnitRow old) {
    super.didUpdateWidget(old);
    // Changing the density is an explicit action, and it is the one thing
    // that may reset every row: that is what choosing a density means (§7.7).
    if (old.density != widget.density) setOpen(widget.density.showsWeapons);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unit = widget.unit;
    final unitState = widget.state.unit(unit.head.instanceId);
    final ranged = unit.weapons(WeaponKind.ranged,
        modelsRemaining: widget.state.modelsRemaining);
    final melee = unit.weapons(WeaponKind.melee,
        modelsRemaining: widget.state.modelsRemaining);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: toggleOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 10, 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        unit.label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          decoration: unitState.isDestroyed
                              ? TextDecoration.lineThrough
                              : null,
                          color: unitState.isDestroyed
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                    if (unitState.isInReserves)
                      _Tag(label: 'RESERVE', colour: scheme.onSurfaceVariant),
                    // Move rides on the row that already carries the name.
                    // The page it replaces had a MOVE section listing every
                    // unit again just to put a number beside it, which is the
                    // duplication this design exists to remove.
                    if (_move(unit) case final m?) ...[
                      Text(m,
                          style: AppTheme.numeric(context, size: 13)
                              .copyWith(fontWeight: FontWeight.w700)),
                      Text('  ${unit.models}',
                          style: TextStyle(
                              fontSize: 11, color: scheme.onSurfaceVariant)),
                    ] else
                      Text('${unit.models}',
                          style: AppTheme.numeric(context, size: 13)),
                    Icon(open ? Icons.expand_less : Icons.expand_more,
                        size: 18, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            // Rule *names* always, whatever the density. 12–15 characters
            // each against 174–198 for the printed text, so the names cost
            // 15–30 lines for a whole army and the text costs 330–686.
            _RuleChips(unit: unit),
            if (open) ...[
              UnitStatline(profiles: unit.profiles),
              if (ranged.weapons.isNotEmpty) WeaponTable(result: ranged),
              if (melee.weapons.isNotEmpty) WeaponTable(result: melee),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

/// The unit's rules, as names. Tapping one opens its text — the only thing on
/// this page that is behind a tap.
class _RuleChips extends StatelessWidget {
  final CombatUnit unit;

  const _RuleChips({required this.unit});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rules = unit.rules;
    if (rules.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(
        spacing: 5,
        runSpacing: 4,
        children: [
          for (final rule in rules)
            InkWell(
              onTap: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (_) => _RuleSheet(rule: rule, unitLabel: unit.label),
              ),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(rule.name,
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant)),
              ),
            ),
          // A chip per rule is a good index and a bad reading order: checking
          // an interaction means opening four sheets and holding them in your
          // head. This is the same rules, in one scroll, in the order they are
          // listed above.
          if (rules.length > 1)
            InkWell(
              onTap: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (_) => _AllRulesSheet(unit: unit),
              ),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book_outlined,
                        size: 12, color: scheme.onPrimaryContainer),
                    const SizedBox(width: 4),
                    Text('All ${rules.length}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: scheme.onPrimaryContainer)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Every rule this unit has, in full, in one scroll.
///
/// Attributed where the group is more than one datasheet: a Commander leading
/// a squad brings rules the squad does not have, and a flat list of the union
/// says the squad has them (§3.8). `attributedRules` has carried that since
/// the leader/bodyguard work and nothing had used it.
class _AllRulesSheet extends StatelessWidget {
  final CombatUnit unit;

  const _AllRulesSheet({required this.unit});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = unit.attributedRules;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, controller) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              title: unit.label,
              trailing: Text('${entries.length} rules',
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(height: 22),
                itemBuilder: (context, i) {
                  final entry = entries[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(entry.rule.name,
                                style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700)),
                          ),
                          // Only when it is not the whole group's — an empty
                          // source means every model has it.
                          if (entry.source.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(entry.source,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      RuleText(entry.rule.text,
                          style: const TextStyle(fontSize: 13, height: 1.4)),
                      if (!entry.rule.isPrinted)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Written from the structured data, not the '
                            'printed rule.',
                            style: TextStyle(
                                fontSize: 10.5, color: scheme.outline),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleSheet extends StatelessWidget {
  final RenderedRule rule;
  final String unitLabel;

  const _RuleSheet({required this.rule, required this.unitLabel});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rule.name,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text(unitLabel,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: RuleText(rule.text,
                    style: const TextStyle(fontSize: 13.5, height: 1.45)),
              ),
            ),
            if (!rule.isPrinted)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Written from the structured data, not the printed rule.',
                  style: TextStyle(fontSize: 11, color: scheme.outline),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color colour;

  const _Tag({required this.label, required this.colour});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          border: Border.all(color: colour),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 8.5,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w800,
                color: colour)),
      );
}

class _Heading extends StatelessWidget {
  final String label;
  final String? trailing;

  const _Heading({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              )),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(trailing!,
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}
