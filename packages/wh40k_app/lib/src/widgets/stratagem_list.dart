import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import 'rule_text.dart';

import '../data/army.dart';

/// Stratagems for one phase section of the turn page (DESIGN.md §7.3).
///
/// They sit **inline in the phase**, not on a page of their own. That is
/// §7.2's scroll axis paying off: the Shooting section shows shooting
/// stratagems because that is where you are reading, with no phase state to
/// advance and nothing to get out of step.
///
/// Unplayable ones are shown greyed with the reason, never hidden. "Why can't
/// I use that?" is the question a player actually asks, and an app that
/// answers by omission is worse than the printed card.
class StratagemList extends StatelessWidget {
  final Army army;
  final String phase;
  final BattleState state;
  final void Function(BattleEvent) onEvent;

  const StratagemList({
    super.key,
    required this.army,
    required this.phase,
    required this.state,
    required this.onEvent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final available = army.stratagems.forPhase(phase, state: state);
    if (available.isEmpty) return const SizedBox.shrink();

    // **No heading of its own.** The turn page wraps this in a collapsible
    // group already titled STRATAGEMS, and the two stacked — one heading
    // directly under an identical one, the second able to say a different
    // count from the first.
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Card(
        color: scheme.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            for (final entry in available)
              _StratagemRow(
                entry: entry,
                army: army,
                phase: phase,
                state: state,
                onEvent: onEvent,
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

/// One stratagem: what it costs, what it is, and — when you ask — what it says.
///
/// **Tapping reads it; a button plays it.** The whole row used to be the play
/// action, so opening a card you were only considering spent the CP. Reading
/// one mid-turn is the common act and playing it the rare one, and the rare
/// one is the one that changes state and cannot be undone by tapping again.
///
/// The text is folded because these are full cards now, not one-liners:
/// COMMAND RE-ROLL alone runs to eight bulleted rolls, and five of those open
/// at once buries the phase under them.
class _StratagemRow extends StatefulWidget {
  final AvailableStratagem entry;
  final Army army;
  final String phase;
  final BattleState state;
  final void Function(BattleEvent) onEvent;

  const _StratagemRow({
    required this.entry,
    required this.army,
    required this.phase,
    required this.state,
    required this.onEvent,
  });

  @override
  State<_StratagemRow> createState() => _StratagemRowState();
}

class _StratagemRowState extends State<_StratagemRow> {
  bool _open = false;

  AvailableStratagem get entry => widget.entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final playable = entry.playable;
    final foreground = playable
        ? scheme.onSurface
        : scheme.onSurfaceVariant.withValues(alpha: 0.55);
    final body = entry.text ?? entry.effect?.text;

    // **No ripple.** An `InkWell` splashed across the whole row — a card's
    // worth of height once one is open — for a tap whose only job is to show
    // or hide text. The expansion is its own feedback, and a better one: it
    // says which row and what happened, where the splash only said "tapped".
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: body == null ? null : () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CpChip(cost: entry.cpCost, enabled: playable),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.stratagem.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: foreground,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _subtitle(),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: scheme.onSurfaceVariant
                              .withValues(alpha: playable ? 1 : 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (body != null)
                  Icon(_open ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                // Disabled rather than absent: "why can't I use that?" is the
                // question a player asks, and the reason is printed below.
                FilledButton.tonal(
                  onPressed: playable ? () => _play(context) : null,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text('Use', style: TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
            if (entry.blockedReason case final reason?)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 38),
                child: Text(
                  reason,
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: scheme.error.withValues(alpha: 0.85),
                  ),
                ),
              ),
            // The stratagem as printed. Where there is none, the sentence
            // derived from a structured effect stands in — 116 of 2,246 have
            // neither, and the row then says what it knows and stops (§3.12).
            if (_open && body != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(38, 4, 0, 2),
                child: RuleText(
                  body,
                  style: TextStyle(
                      fontSize: 11.5, height: 1.35, color: foreground),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[
      entry.source,
      if (entry.stratagem.type case final type?) type.replaceAll('-', ' '),
    ];
    return parts.join(' · ');
  }

  Future<void> _play(BuildContext context) async {
    final targets = widget.army.targetsFor(
      entry.stratagem,
      phase: widget.phase,
      state: widget.state,
    );

    // A stratagem with no unit to nominate commits straight away — Command
    // Re-roll targets a die, not a model.
    if (targets.isEmpty) {
      _commit(null);
      return;
    }

    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => _TargetSheet(
        title: entry.stratagem.displayName,
        cost: entry.cpCost,
        targets: targets,
      ),
    );
    if (chosen != null) {
      _commit(chosen == _TargetSheet.noTarget ? null : chosen);
    }
  }

  void _commit(String? instanceId) => widget.onEvent(UseStratagem(
        stratagemId: entry.id,
        targetInstanceId: instanceId,
        round: widget.state.round,
        phase: widget.phase,
        cp: entry.cpCost,
      ));
}

class _TargetSheet extends StatelessWidget {
  static const noTarget = '';

  final String title;
  final int cost;
  final List<StratagemTarget> targets;

  const _TargetSheet({
    required this.title,
    required this.cost,
    required this.targets,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text('Spend $cost CP on which unit?',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
          for (final target in targets)
            ListTile(
              dense: true,
              enabled: target.eligible,
              title: Text(target.label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              // Ineligible units are listed, not dropped: a unit missing from
              // the list reads as a bug, a unit with a reason reads as a rule.
              subtitle: target.blockedReason == null
                  ? null
                  : Text(target.blockedReason!,
                      style: TextStyle(fontSize: 11, color: scheme.error)),
              onTap: target.eligible
                  ? () => Navigator.of(context).pop(target.instanceId)
                  : null,
            ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: const Icon(Icons.remove_circle_outline, size: 18),
            title:
                const Text('No specific unit', style: TextStyle(fontSize: 13)),
            subtitle: Text('Spend the CP without marking a unit',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            onTap: () => Navigator.of(context).pop(noTarget),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CpChip extends StatelessWidget {
  final int cost;
  final bool enabled;

  const _CpChip({required this.cost, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 30,
      padding: const EdgeInsets.symmetric(vertical: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:
            enabled ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$cost',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: enabled
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
