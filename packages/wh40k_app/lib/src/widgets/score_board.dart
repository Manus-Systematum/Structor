import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../theme.dart';
import 'remembered_toggle.dart';
import 'scoring_text.dart';
import 'secondary_cards.dart';

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
              held: deck.hand(state.secondariesOf(Player.me)),
              deck: deck,
              objectivesLabel: 'MY OBJECTIVES',
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
              // Their hand is tracked too, from their own copy of the deck
              // (§7.3.16). What they hold is often visible at the table —
              // fixed secondaries are declared, and tactical ones get revealed
              // as they are scored — and knowing which card they are chasing
              // is most of what decides where you stand.
              held: deck.hand(state.secondariesOf(Player.opponent)),
              deck: deck,
              objectivesLabel: '${opponentName.toUpperCase()} OBJECTIVES',
              ahead: state.opponent.total > state.me.total,
              onEvent: onEvent,
            ),
          ],
        ),
      ),
    );
  }
}

/// One side's score, mission and cards.
///
/// Stateful only to remember whether its cards are showing. They open *in
/// place* rather than in a sheet: a sheet is a route built once from the state
/// it captured, so a card drawn inside one never appeared — the row behind
/// updated and the sheet did not. Inline, the board rebuilds on every event,
/// which is what was wanted.
class _Side extends StatefulWidget {
  final String label;
  final Player side;
  final SideScore score;
  final BattleState state;
  final MissionCard? card;
  final List<MissionCard> held;
  final SecondaryDeck deck;

  /// `My objectives` / `Kai's objectives` — what the one fold is called.
  final String objectivesLabel;
  final bool ahead;
  final void Function(BattleEvent) onEvent;

  const _Side({
    required this.label,
    required this.side,
    required this.score,
    required this.state,
    required this.card,
    required this.held,
    required this.deck,
    required this.objectivesLabel,
    required this.ahead,
    required this.onEvent,
  });

  @override
  State<_Side> createState() => _SideState();
}

class _SideState extends State<_Side> with RemembersToggle<_Side> {
  @override
  Object get toggleId => 'cards:${widget.side.name}';

  @override
  bool get initiallyOpen => false;

  /// Scoring a figure the card names, for this side.
  void _score(ScoreKind kind, int vp) => widget.onEvent(ScoreVp(
        side: widget.side,
        kind: kind,
        round: widget.state.round,
        vp: vp,
      ));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              _CpCounter(
                cp: widget.side == Player.me
                    ? widget.state.cp
                    : widget.state.opponentCp,
                onChange: (delta) =>
                    widget.onEvent(AdjustCp(delta, side: widget.side)),
              ),
              const SizedBox(width: 8),
              Text(
                  '${widget.score.primaryTotal}+${widget.score.secondaryTotal}',
                  style:
                      TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              const SizedBox(width: 8),
              Text('${widget.score.total}',
                  style: AppTheme.numeric(context, size: 21).copyWith(
                    fontWeight: FontWeight.w800,
                    color: widget.ahead ? scheme.primary : scheme.onSurface,
                  )),
            ],
          ),
          // One door per side, not two. The primary and the cards are the
          // same question — what can I score — and splitting them into a
          // mission expander and a Cards expander made the row ask it twice
          // (§7.3.24).
          InkWell(
            onTap: toggleOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(open ? Icons.expand_more : Icons.chevron_right,
                      size: 15, color: scheme.primary),
                  const SizedBox(width: 3),
                  Text(widget.objectivesLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary)),
                  const SizedBox(width: 6),
                  // Folded away, the row still says how much is inside.
                  Flexible(
                    child: Text(
                      [
                        if (widget.card case final mission?) mission.name,
                        if (widget.held.isNotEmpty)
                          '${widget.held.length} card'
                              '${widget.held.length == 1 ? '' : 's'}',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (open && widget.card != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: ScoringText(
                text: widget.card!.text,
                onScore: (vp) => _score(ScoreKind.primary, vp),
                style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: scheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Line(
                  label: 'PRIMARY',
                  thisRound: widget.score.primary[widget.state.round] ?? 0,
                  onScore: (vp) => _score(ScoreKind.primary, vp),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Line(
                  label: 'SECONDARY',
                  thisRound: widget.score.secondary[widget.state.round] ?? 0,
                  onScore: (vp) => _score(ScoreKind.secondary, vp),
                ),
              ),
            ],
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SecondaryPanel(
                state: widget.state,
                deck: widget.deck,
                onEvent: widget.onEvent,
                side: widget.side,
              ),
            ),
        ],
      ),
    );
  }
}

/// One scoring line: what this side has taken this round, and a correction.
///
/// The card's own figures used to be chips here. They are on the card's lines
/// now (§7.3.22); what is left is the running figure, the plus for cards that
/// pay per something the app cannot see, and the minus for a mis-tap.
class _Line extends StatelessWidget {
  final String label;
  final int thisRound;
  final void Function(int) onScore;

  const _Line({
    required this.label,
    required this.thisRound,
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
            // For the cards that pay per objective or per unit destroyed,
            // where only the player can see the board — and for correcting a
            // tap. Both directions, because a correction is as common as a
            // score.
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
              color:
                  quiet ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
            )),
      ),
    );
  }
}

/// One side's command points, on the row that scores for that side.
///
/// The opponent's are here rather than in the bar because the bar is this
/// player's: round, their own points, the control that ends their turn. Theirs
/// belong beside their score, which is the other thing about them worth
/// knowing and the thing it is compared against (§7.3.21).
///
/// Entered, not derived — the app cannot see their table. The Command phase
/// grant is derived for both sides, because that one follows from the turn
/// passing and nothing else.
class _CpCounter extends StatelessWidget {
  final int cp;
  final void Function(int delta) onChange;

  const _CpCounter({required this.cp, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cp > 0) _CpStep(icon: Icons.remove, onTap: () => onChange(-1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Text('$cp CP',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
              )),
        ),
        _CpStep(icon: Icons.add, onTap: () => onChange(1)),
      ],
    );
  }
}

class _CpStep extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CpStep({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkResponse(
      onTap: onTap,
      radius: 16,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(icon, size: 13, color: scheme.onSurface),
      ),
    );
  }
}
