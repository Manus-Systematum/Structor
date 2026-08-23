import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../theme.dart';

/// Both sides' score, entered in one tap wherever the card names a figure
/// (DESIGN.md §7.3.13).
///
/// The control this replaces was a `+1` stepper for the primary — and the
/// primary is the largest source of victory points in a game. Measured across
/// the shipped cards there are **96 flat awards at a mean of 4.4 taps each**,
/// so a five-round game spent roughly forty taps adding one at a time. 81% of
/// cards name at least one flat figure, so most of that is a button; the 19%
/// that pay *per objective* or *per unit destroyed* genuinely cannot be, since
/// the app cannot see the table, and those keep the stepper.
///
/// Both sides are here for the same reason they are tracked at all: knowing
/// you are on 42 is useless without knowing they are on 47.
class ScoreBoard extends StatelessWidget {
  final BattleState state;
  final MissionPack pack;
  final SecondaryDeck deck;
  final void Function(BattleEvent) onEvent;

  const ScoreBoard({
    super.key,
    required this.state,
    required this.pack,
    required this.onEvent,
    this.deck = const SecondaryDeck([]),
  });

  @override
  Widget build(BuildContext context) {
    final setup = state.setup;
    final opponentName = setup?.opponentName?.trim().isNotEmpty ?? false
        ? setup!.opponentName!.trim()
        : 'Opponent';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Side(
              label: 'You',
              side: Player.me,
              score: state.me,
              state: state,
              card: pack.card(setup?.myMissionId ?? ''),
              held: deck.hand(state.secondaries),
              ahead: state.me.total >= state.opponent.total,
              onEvent: onEvent,
            ),
            const Divider(height: 1, indent: 12, endIndent: 12),
            _Side(
              label: opponentName,
              side: Player.opponent,
              score: state.opponent,
              state: state,
              // Their mission is a different one — the matchup table is
              // asymmetric — and how they score is how you decide what to
              // contest.
              card: pack.card(setup?.opponentMissionId ?? ''),
              // Their hand is theirs; the app never sees it, so their
              // secondaries are a figure you are told rather than a card you
              // can tap.
              held: const [],
              ahead: state.opponent.total > state.me.total,
              onEvent: onEvent,
            ),
          ],
        ),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  final String label;
  final Player side;
  final SideScore score;
  final BattleState state;
  final MissionCard? card;
  final List<MissionCard> held;
  final bool ahead;
  final void Function(BattleEvent) onEvent;

  const _Side({
    required this.label,
    required this.side,
    required this.score,
    required this.state,
    required this.card,
    required this.held,
    required this.ahead,
    required this.onEvent,
  });

  void _score(ScoreKind kind, int vp) => onEvent(ScoreVp(
        side: side,
        kind: kind,
        round: state.round,
        vp: vp,
      ));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Only the figures this round can actually pay. A card's tiers change at
    // battle round two, so offering all of them would offer points that
    // cannot be taken.
    final payouts = <int>{
      ...?card?.payoutsIn(phase: 'command', round: state.round),
      ...?card?.payoutsIn(phase: 'end', round: state.round),
    }.toList()
      ..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Text('${score.primaryTotal}+${score.secondaryTotal}',
                  style: TextStyle(
                      fontSize: 11, color: scheme.onSurfaceVariant)),
              const SizedBox(width: 8),
              Text('${score.total}',
                  style: AppTheme.numeric(context, size: 21).copyWith(
                    fontWeight: FontWeight.w800,
                    color: ahead ? scheme.primary : scheme.onSurface,
                  )),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Line(
                  label: 'PRIMARY',
                  thisRound: score.primary[state.round] ?? 0,
                  payouts: payouts,
                  onScore: (vp) => _score(ScoreKind.primary, vp),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Line(
                  label: 'SECONDARY',
                  thisRound: score.secondary[state.round] ?? 0,
                  payouts: {
                    for (final c in held)
                      ...c.payoutsIn(phase: 'end', round: state.round),
                  }.toList()
                    ..sort(),
                  onScore: (vp) => _score(ScoreKind.secondary, vp),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One scoring line: the figures the card names as buttons, and a stepper for
/// everything it does not.
class _Line extends StatelessWidget {
  final String label;
  final int thisRound;
  final List<int> payouts;
  final void Function(int) onScore;

  const _Line({
    required this.label,
    required this.thisRound,
    required this.payouts,
    required this.onScore,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: TextStyle(
                  fontSize: 8.5,
                  letterSpacing: 0.9,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurfaceVariant,
                )),
            if (thisRound > 0) ...[
              const SizedBox(width: 5),
              Text('+$thisRound',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary)),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final vp in payouts)
              _Chip(label: '+$vp', onTap: () => onScore(vp)),
            // The stepper stays for the cards that pay per objective, and for
            // correcting a tap. Both directions, because a correction is as
            // common as a score.
            _Chip(label: '+1', onTap: () => onScore(1), quiet: true),
            if (thisRound > 0)
              _Chip(label: '−1', onTap: () => onScore(-1), quiet: true),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool quiet;

  const _Chip({required this.label, required this.onTap, this.quiet = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: quiet ? null : scheme.primaryContainer,
          border: Border.all(
              color: quiet ? scheme.outlineVariant : Colors.transparent),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: quiet ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
            )),
      ),
    );
  }
}
