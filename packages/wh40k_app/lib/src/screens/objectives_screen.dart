import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../widgets/scoring_text.dart';
import '../widgets/secondary_cards.dart';

import '../theme.dart';
import '../widgets/collapsible.dart';

/// What each side is playing for, and how the score got where it is
/// (DESIGN.md §7.3.11).
///
/// The turn page answers *what do I do now*, which is why scoring lives in its
/// END section next to the tap that records it. This page answers the other
/// question — *where does the game stand* — which the turn page cannot, because
/// the answer is spread across five rounds and two missions and the turn page
/// only ever shows the round you are in.
///
/// It is deliberately read-only apart from nothing at all: every number here
/// is derived from the same [BattleState] the END section writes to, so the
/// two cannot disagree. Adding a second place to *enter* points would be a
/// second source of truth and the first thing to drift.
class ObjectivesScreen extends StatelessWidget {
  final BattleState state;
  final MissionPack pack;
  final SecondaryDeck deck;

  /// Ends the game and files it away (§7.3.12). Null when there is nothing to
  /// finish, or on a surface where finishing makes no sense.
  final VoidCallback? onFinish;

  /// Scoring happens here too, not only on the turn page. This is the page a
  /// player has open while working out what they scored, and reading it
  /// somewhere you cannot act on it is a trip back (§7.3.19).
  final void Function(BattleEvent) onEvent;

  const ObjectivesScreen({
    super.key,
    required this.state,
    required this.pack,
    this.deck = const SecondaryDeck([]),
    this.onFinish,
    this.onEvent = _ignore,
  });

  static void _ignore(BattleEvent _) {}

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final setup = state.setup;

    if (setup == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Set up a battle to see what each side is playing for.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final mine = pack.card(setup.myMissionId);
    final theirs = pack.card(setup.opponentMissionId);
    final opponentName = setup.opponentName?.trim().isNotEmpty ?? false
        ? setup.opponentName!.trim()
        : 'Opponent';

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _Standings(state: state, opponentName: opponentName),
        _History(state: state, opponentName: opponentName),
        // One block per side, and everything that side has is inside it: the
        // mission, what it pays this round, the buttons that score it, and
        // their cards. Nothing folds inside a fold and nothing opens a sheet
        // (§7.3.19).
        _SideBlock(
          title: 'MY OBJECTIVES',
          side: Player.me,
          card: mine,
          state: state,
          deck: deck,
          score: state.me,
          initiallyOpen: true,
          onEvent: onEvent,
        ),
        _SideBlock(
          // Their mission is a different one — the matchup table is asymmetric
          // (§7.3.1) — and how they score is how you decide what to contest.
          title: '${opponentName.toUpperCase()} OBJECTIVES',
          side: Player.opponent,
          card: theirs,
          state: state,
          deck: deck,
          score: state.opponent,
          initiallyOpen: false,
          onEvent: onEvent,
        ),
        // The other place a game ends. This page is where you read where the
        // game stands, so it is where you conclude it has finished — and the
        // END section is a long scroll away on the turn page (§7.2).
        if (onFinish != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: OutlinedButton.icon(
              onPressed: onFinish,
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: const Text('Finish battle'),
            ),
          ),
        const _Provenance(),
      ],
    );
  }
}

/// The margin, which is the number that decides the game.
class _Standings extends StatelessWidget {
  final BattleState state;
  final String opponentName;

  const _Standings({required this.state, required this.opponentName});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final me = state.me.total;
    final them = state.opponent.total;
    final margin = me - them;

    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('ROUND ${state.round}',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary)),
                const Spacer(),
                Text(
                  margin == 0
                      ? 'Level'
                      : margin > 0
                          ? '+$margin you'
                          : '+${-margin} $opponentName',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: margin >= 0 ? scheme.primary : scheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _Total(label: 'You', score: state.me, ahead: me >= them),
                _Total(
                    label: opponentName,
                    score: state.opponent,
                    ahead: them >= me),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  final String label;
  final SideScore score;
  final bool ahead;

  const _Total({
    required this.label,
    required this.score,
    required this.ahead,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          Text('${score.total}',
              style: AppTheme.numeric(context, size: 26).copyWith(
                  fontWeight: FontWeight.w800,
                  color: ahead ? scheme.primary : scheme.onSurface)),
          Text(
              '${score.primaryTotal} primary · ${score.secondaryTotal} secondary',
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Round by round, both sides.
///
/// A running total says who is ahead; it does not say the game turned in round
/// three, which is the thing a player actually wants afterwards and the thing
/// no scrap of paper survives.
class _History extends StatelessWidget {
  final BattleState state;
  final String opponentName;

  const _History({required this.state, required this.opponentName});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rounds = [
      for (var round = 1; round <= 5; round++) round,
    ];
    final played = rounds.where((r) =>
        (state.me.primary[r] ?? 0) > 0 ||
        (state.me.secondary[r] ?? 0) > 0 ||
        (state.opponent.primary[r] ?? 0) > 0 ||
        (state.opponent.secondary[r] ?? 0) > 0 ||
        r <= state.round);

    Widget cell(String text, {bool strong = false, bool muted = false}) =>
        Expanded(
          child: Text(text,
              textAlign: TextAlign.center,
              style: AppTheme.numeric(context, size: 12).copyWith(
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                color: muted ? scheme.outline : scheme.onSurface,
              )),
        );

    return CollapsibleGroup(
      title: 'SCORE BY ROUND',
      icon: Icons.timeline,
      initiallyOpen: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Text('ROUND',
                      style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 0.6,
                          color: scheme.onSurfaceVariant)),
                ),
                for (final label in [
                  'You P',
                  'You S',
                  '${opponentName.split(' ').first} P',
                  '${opponentName.split(' ').first} S',
                ])
                  Expanded(
                    child: Text(label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 0.4,
                            color: scheme.onSurfaceVariant)),
                  ),
              ],
            ),
            const Divider(height: 8),
            for (final round in played)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(
                        round == state.round ? '$round  ←' : '$round',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: round == state.round
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: round == state.round
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    // A round that scored nothing reads as a dash rather than
                    // a zero: zero is a result, blank is "not yet".
                    cell(_fmt(state.me.primary[round]),
                        muted: (state.me.primary[round] ?? 0) == 0),
                    cell(_fmt(state.me.secondary[round]),
                        muted: (state.me.secondary[round] ?? 0) == 0),
                    cell(_fmt(state.opponent.primary[round]),
                        muted: (state.opponent.primary[round] ?? 0) == 0),
                    cell(_fmt(state.opponent.secondary[round]),
                        muted: (state.opponent.secondary[round] ?? 0) == 0),
                  ],
                ),
              ),
            const Divider(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Text('TOTAL',
                      style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary)),
                ),
                cell('${state.me.primaryTotal}', strong: true),
                cell('${state.me.secondaryTotal}', strong: true),
                cell('${state.opponent.primaryTotal}', strong: true),
                cell('${state.opponent.secondaryTotal}', strong: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(int? vp) => (vp ?? 0) == 0 ? '–' : '$vp';
}

/// One side's primary, with what it pays and when.
/// Everything one side is playing for, in one fold.
///
/// It replaces three separate groups — your primary, their primary, and the
/// hand — and the sheets those opened. The page is read while deciding what
/// you scored, so what you read and what you tap have to be the same place
/// (§7.3.19).
class _SideBlock extends StatelessWidget {
  final String title;
  final Player side;
  final MissionCard? card;
  final BattleState state;
  final SecondaryDeck deck;
  final SideScore score;
  final bool initiallyOpen;
  final void Function(BattleEvent) onEvent;

  const _SideBlock({
    required this.title,
    required this.side,
    required this.card,
    required this.state,
    required this.deck,
    required this.score,
    required this.initiallyOpen,
    required this.onEvent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mission = card;
    final nowCommand = mission?.scoresIn(phase: 'command', round: state.round);
    final nowEnd = mission?.scoresIn(phase: 'end', round: state.round);

    return CollapsibleGroup(
      title: title,
      icon: Icons.flag_outlined,
      trailing: '${score.total} VP',
      initiallyOpen: initiallyOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mission != null) ...[
              Text(mission.name,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              // Where this round's points are available, since a card's tiers
              // change with the round and the player is deciding now.
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (nowCommand == true)
                    _When(
                        label: 'Scores in your Command phase',
                        colour: scheme.primary),
                  if (nowEnd == true)
                    _When(
                        label: 'Scores at end of turn', colour: scheme.primary),
                  if (nowCommand == false && nowEnd == false)
                    _When(
                        label: 'Nothing scores this round',
                        colour: scheme.outline),
                ],
              ),
              const SizedBox(height: 6),
              // Each payout's button on the line that earns it (§7.3.22).
              ScoringText(
                text: mission.text,
                card: mission,
                headroom: (side == Player.me ? state.me : state.opponent)
                    .headroom(state.round, primaryKind: true),
                onScore: (vp) => onEvent(ScoreVp(
                  side: side,
                  kind: ScoreKind.primary,
                  round: state.round,
                  vp: vp,
                )),
                style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
            ],
            _ScoreRow(
              label: 'PRIMARY',
              thisRound: score.primary[state.round] ?? 0,
              onScore: (vp) => onEvent(ScoreVp(
                side: side,
                kind: ScoreKind.primary,
                round: state.round,
                vp: vp,
              )),
            ),
            const SizedBox(height: 8),
            _ScoreRow(
              label: 'SECONDARY',
              thisRound: score.secondary[state.round] ?? 0,
              onScore: (vp) => onEvent(ScoreVp(
                side: side,
                kind: ScoreKind.secondary,
                round: state.round,
                vp: vp,
              )),
            ),
            if (!deck.isEmpty) ...[
              const SizedBox(height: 4),
              // Inline, and the same panel the turn page uses, so the two
              // cannot drift apart.
              SecondaryPanel(
                state: state,
                deck: deck,
                onEvent: onEvent,
                side: side,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What this side has taken this round, and a correction.
///
/// The card's own figures are on the card's lines (§7.3.22). What is left is
/// the plus for cards that pay per something the app cannot see, and the minus
/// for a mis-tap.
class _ScoreRow extends StatelessWidget {
  final String label;
  final int thisRound;
  final void Function(int) onScore;

  const _ScoreRow({
    required this.label,
    required this.thisRound,
    required this.onScore,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Label above rather than beside: "SECONDARY +4" does not fit a fixed
    // column at phone width, and a fixed column that fits the longest label
    // wastes the width the chips need.
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
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _ScoreChip(label: '+1', onTap: () => onScore(1), quiet: true),
            if (thisRound > 0)
              _ScoreChip(label: '−1', onTap: () => onScore(-1), quiet: true),
          ],
        ),
      ],
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool quiet;

  const _ScoreChip({
    required this.label,
    required this.onTap,
    this.quiet = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: quiet ? null : scheme.primaryContainer,
          border: quiet ? Border.all(color: scheme.outlineVariant) : null,
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

class _When extends StatelessWidget {
  final String label;
  final Color colour;

  const _When({required this.label, required this.colour});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: colour),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: colour)),
      );
}

/// The secondaries currently held, in full.
/// Whose words the descriptions are (§7.3.4, §7.6).
class _Provenance extends StatelessWidget {
  const _Provenance();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        'Mission and card descriptions are summaries written by the 40kdc '
        'community, not the printed text. They are enough to play from; for a '
        'rules dispute the card itself is authoritative.',
        style: TextStyle(fontSize: 10.5, height: 1.35, color: scheme.outline),
      ),
    );
  }
}
