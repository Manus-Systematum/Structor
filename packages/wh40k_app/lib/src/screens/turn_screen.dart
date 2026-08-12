import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../data/army.dart';
import '../widgets/weapon_table.dart';

/// The turn page (DESIGN.md §7.2, §7.3).
///
/// **Phase is a scroll axis, not tracked state.** Where you are scrolled *is*
/// the phase. An earlier design had the player advance a phase state machine so
/// the app could filter — six taps a turn, sixty a game, to maintain something
/// the player already knows. Only round and active player are tracked, because
/// they change five and ten times a game respectively and so earn their taps.
class TurnScreen extends StatefulWidget {
  final Army army;

  const TurnScreen({super.key, required this.army});

  @override
  State<TurnScreen> createState() => _TurnScreenState();
}

class _TurnScreenState extends State<TurnScreen> {
  int _round = 1;
  bool _yourTurn = true;
  int _cp = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StickyHeader(
          round: _round,
          yourTurn: _yourTurn,
          cp: _cp,
          onRound: (delta) => setState(
              () => _round = (_round + delta).clamp(1, 5)),
          onTurn: () => setState(() => _yourTurn = !_yourTurn),
          onCp: (delta) => setState(() => _cp = (_cp + delta).clamp(0, 99)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: const [
              _PhaseSection(phase: 'command'),
              _PhaseSection(phase: 'movement'),
              _PhaseSection(phase: 'shooting'),
              _PhaseSection(phase: 'charge'),
              _PhaseSection(phase: 'fight'),
              _PhaseSection(phase: 'end'),
            ].map((s) => s.withArmy(widget.army)).toList(),
          ),
        ),
      ],
    );
  }
}

class _StickyHeader extends StatelessWidget {
  final int round;
  final bool yourTurn;
  final int cp;
  final void Function(int) onRound;
  final VoidCallback onTurn;
  final void Function(int) onCp;

  const _StickyHeader({
    required this.round,
    required this.yourTurn,
    required this.cp,
    required this.onRound,
    required this.onTurn,
    required this.onCp,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _Stepper(
              label: 'ROUND',
              value: '$round',
              onDown: () => onRound(-1),
              onUp: () => onRound(1),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: onTurn,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: yourTurn
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
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
                ),
              ),
            ),
            const SizedBox(width: 8),
            _Stepper(
              label: 'CP',
              value: '$cp',
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
                  textAlign: TextAlign.center,
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

  const _PhaseSection({required this.phase, this.army});

  _PhaseSection withArmy(Army army) =>
      _PhaseSection(phase: phase, army: army);

  static const _labels = {
    'command': 'COMMAND',
    'movement': 'MOVEMENT',
    'shooting': 'SHOOTING',
    'charge': 'CHARGE',
    'fight': 'FIGHT',
    'end': 'END',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final army = this.army;

    final kind = switch (phase) {
      'shooting' => WeaponKind.ranged,
      'fight' => WeaponKind.melee,
      _ => null,
    };

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
        if (army == null || kind == null)
          _phasePlaceholder(context, army)
        else
          for (final unit in army.combatUnits)
            _UnitBlock(unit: unit, kind: kind, phase: phase),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _phasePlaceholder(BuildContext context, Army? army) {
    final scheme = Theme.of(context).colorScheme;
    final rules = army == null
        ? <({String unit, RenderedRule rule})>[]
        : [
            for (final unit in army.combatUnits)
              for (final rule in unit.rules)
                if (rule.phases.contains(phase))
                  (unit: unit.label, rule: rule),
          ];

    if (rules.isEmpty) {
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

  const _UnitBlock({
    required this.unit,
    required this.kind,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final table = unit.weapons(kind);
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
