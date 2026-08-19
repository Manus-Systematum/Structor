import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../widgets/rule_text.dart';

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

  const ObjectivesScreen({
    super.key,
    required this.state,
    required this.pack,
    this.deck = const SecondaryDeck([]),
    this.onFinish,
  });

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
        if (mine != null)
          _MissionBlock(
            title: 'YOUR PRIMARY',
            card: mine,
            round: state.round,
            initiallyOpen: true,
          ),
        if (theirs != null)
          // Their mission is a different one — the matchup table is asymmetric
          // (§7.3.1) — and how they score is how you decide what to contest.
          _MissionBlock(
            title: '${opponentName.toUpperCase()} PRIMARY',
            card: theirs,
            round: state.round,
            initiallyOpen: false,
          ),
        if (!deck.isEmpty) _Hand(state: state, deck: deck),
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
          Text('${score.primaryTotal} primary · ${score.secondaryTotal} secondary',
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
class _MissionBlock extends StatelessWidget {
  final String title;
  final MissionCard card;
  final int round;
  final bool initiallyOpen;

  const _MissionBlock({
    required this.title,
    required this.card,
    required this.round,
    required this.initiallyOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nowCommand = card.scoresIn(phase: 'command', round: round);
    final nowEnd = card.scoresIn(phase: 'end', round: round);

    return CollapsibleGroup(
      title: title,
      icon: Icons.flag_outlined,
      trailing: card.name,
      initiallyOpen: initiallyOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Where this round's points are available, since the card's tiers
            // change with the round and the player is deciding now.
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (nowCommand)
                  _When(
                      label: 'Scores in your Command phase',
                      colour: scheme.primary),
                if (nowEnd)
                  _When(label: 'Scores at end of turn', colour: scheme.primary),
                if (!nowCommand && !nowEnd)
                  _When(
                      label: 'Nothing scores this round',
                      colour: scheme.outline),
              ],
            ),
            const SizedBox(height: 6),
            RuleText(card.text,
                style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: scheme.onSurfaceVariant)),
          ],
        ),
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
class _Hand extends StatelessWidget {
  final BattleState state;
  final SecondaryDeck deck;

  const _Hand({required this.state, required this.deck});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hand = deck.hand(state.secondaries);
    final remaining = deck.remaining(state.secondaries).length;

    return CollapsibleGroup(
      title: 'SECONDARIES IN HAND',
      icon: Icons.style_outlined,
      trailing: hand.isEmpty ? 'none · $remaining left' : '${hand.length} held',
      initiallyOpen: hand.isNotEmpty,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hand.isEmpty)
              Text('No cards in hand.',
                  style:
                      TextStyle(fontSize: 11, color: scheme.onSurfaceVariant))
            else
              for (final card in hand)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.name,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                      RuleText(card.text,
                          style: TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

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
