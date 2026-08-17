import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../theme.dart';
import 'sheet_header.dart';

/// The END section of the turn page: victory points and the secondary deck
/// (DESIGN.md §7.3.2, §7.3.3).
///
/// **Both players are tracked.** Knowing you are on 42 is useless without
/// knowing they are on 47, and the alternative is the thing every player
/// already does badly on a scrap of paper.
///
/// Scoring is entered, not derived. The app cannot see the table, so it never
/// guesses a total — it offers the payouts the card actually names and a
/// stepper for everything else (§7.6).
class EndPhase extends StatelessWidget {
  final BattleState state;
  final SecondaryDeck deck;
  final void Function(BattleEvent) onEvent;

  /// Mission data, for each side's primary. Empty until it loads.
  final MissionPack pack;

  /// Ends the game and files it away (§7.3.12).
  final VoidCallback? onFinish;

  const EndPhase({
    super.key,
    required this.state,
    required this.deck,
    required this.onEvent,
    this.pack = const MissionPack(),
    this.onFinish,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScorePanel(state: state, pack: pack, onEvent: onEvent),
          if (!deck.isEmpty)
            SecondaryPanel(state: state, deck: deck, onEvent: onEvent),
          // Last on the page, under the scores it files away. A game ends
          // after the fifth round's scoring, so the end of the END section
          // is where the hand already is.
          if (onFinish != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: OutlinedButton.icon(
                onPressed: onFinish,
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Finish battle'),
              ),
            ),
        ],
      );
}

/// Both sides' victory points, with the payouts each primary names.
///
/// Public because the Command phase shows it too: the primary's round-2-onward
/// tier is scored there, and a second copy of this control would be a second
/// source of truth. It reads [BattleState] and emits events, so wherever it
/// appears it shows the same numbers (DESIGN.md §7.3.11).
class ScorePanel extends StatelessWidget {
  final BattleState state;
  final MissionPack pack;
  final void Function(BattleEvent) onEvent;

  const ScorePanel({
    super.key,
    required this.state,
    required this.pack,
    required this.onEvent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              child: Row(
                children: [
                  Icon(Icons.emoji_events_outlined,
                      size: 15, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text('VICTORY POINTS',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      )),
                  const Spacer(),
                  Text('ROUND ${state.round}',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            _SideRow(
              label: 'You',
              score: state.me,
              round: state.round,
              ahead: state.me.total > state.opponent.total,
              primary: pack.card(state.setup?.myMissionId ?? ''),
              onScore: (kind, delta) => onEvent(ScoreVp(
                side: Player.me,
                kind: kind,
                round: state.round,
                vp: delta,
              )),
            ),
            const Divider(height: 1, indent: 12, endIndent: 12),
            _SideRow(
              label: state.setup?.opponentName?.trim().isNotEmpty ?? false
                  ? state.setup!.opponentName!.trim()
                  : 'Opponent',
              score: state.opponent,
              round: state.round,
              ahead: state.opponent.total > state.me.total,
              // Their primary is a *different* mission — the matchup table is
              // asymmetric (§7.3.1) — and knowing how they score is how you
              // decide what to contest (§7.3.3).
              primary: pack.card(state.setup?.opponentMissionId ?? ''),
              onScore: (kind, delta) => onEvent(ScoreVp(
                side: Player.opponent,
                kind: kind,
                round: state.round,
                vp: delta,
              )),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _SideRow extends StatefulWidget {
  final String label;
  final SideScore score;
  final int round;

  /// Whose total is higher. The margin is the number that decides the game,
  /// and two bare totals make you do the subtraction yourself.
  final bool ahead;

  /// This side's primary mission. Null before the pack loads, or if the
  /// mission has no card — the row degrades to the bare stepper rather than
  /// showing an empty disclosure.
  final MissionCard? primary;

  final void Function(ScoreKind, int) onScore;

  const _SideRow({
    required this.label,
    required this.score,
    required this.round,
    required this.ahead,
    required this.onScore,
    this.primary,
  });

  @override
  State<_SideRow> createState() => _SideRowState();
}

class _SideRowState extends State<_SideRow> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = widget.label;
    final score = widget.score;
    final round = widget.round;
    final ahead = widget.ahead;
    final onScore = widget.onScore;
    final primary = widget.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              if (ahead)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.arrow_upward,
                      size: 14, color: scheme.primary),
                ),
              Text('${score.total}',
                  style: AppTheme.numeric(context, size: 20).copyWith(
                    fontWeight: FontWeight.w800,
                    color: ahead ? scheme.primary : scheme.onSurface,
                  )),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              _VpStepper(
                label: 'PRIMARY',
                total: score.primaryTotal,
                thisRound: score.primary[round] ?? 0,
                onDelta: (d) => onScore(ScoreKind.primary, d),
              ),
              const SizedBox(width: 14),
              _VpStepper(
                label: 'SECONDARY',
                total: score.secondaryTotal,
                thisRound: score.secondary[round] ?? 0,
                onDelta: (d) => onScore(ScoreKind.secondary, d),
              ),
            ],
          ),
          // What the primary actually pays for. The number above is entered by
          // hand (§7.6), and entering it correctly means remembering a scoring
          // rule that changes at battle round 2 — so the rule is put beside the
          // stepper rather than left on a card face-down under the table.
          if (primary != null) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _open = !_open),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined,
                        size: 13, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(primary.name,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          )),
                    ),
                    Icon(_open ? Icons.expand_less : Icons.expand_more,
                        size: 16, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            if (_open)
              Padding(
                padding: const EdgeInsets.only(left: 18, top: 2, bottom: 2),
                child: Text(
                  primary.text.isEmpty
                      ? 'No scoring text is published for this mission.'
                      : primary.text,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Adds to *this round's* score. Totals are shown beside it because the cap is
/// applied per round and then per game (§7.3.3), so the running figure is not
/// simply the sum of what was tapped.
class _VpStepper extends StatelessWidget {
  final String label;
  final int total;
  final int thisRound;
  final void Function(int) onDelta;

  const _VpStepper({
    required this.label,
    required this.total,
    required this.thisRound,
    required this.onDelta,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // This round's delta rides on the label rather than beside the
          // stepper: two steppers side by side on a phone have no room for a
          // trailing phrase, and it overflowed at 420pt.
          Text(
            thisRound == 0 ? label : '$label  +$thisRound',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 9,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
                color: thisRound == 0 ? scheme.onSurfaceVariant : scheme.primary),
          ),
          Row(
            children: [
              _Tap(icon: Icons.remove, onTap: () => onDelta(-1)),
              Expanded(
                child: Text('$total',
                    maxLines: 1,
                    style: AppTheme.numeric(context, size: 15)
                        .copyWith(fontWeight: FontWeight.w800)),
              ),
              _Tap(icon: Icons.add, onTap: () => onDelta(1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tap extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _Tap({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => InkResponse(
        onTap: onTap,
        radius: 18,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16),
        ),
      );
}

/// The secondary deck: what is in hand, what it pays, and drawing the next.
///
/// Public for the same reason [ScorePanel] is (§7.3.11). Cards are drawn at
/// the start of a turn and scored at the end of one, so a deck reachable only
/// from END is a scroll away from half of what it is for. It reads and writes
/// the same [BattleState] wherever it appears, so two copies cannot disagree.
class SecondaryPanel extends StatelessWidget {
  final BattleState state;
  final SecondaryDeck deck;
  final void Function(BattleEvent) onEvent;

  const SecondaryPanel({
    super.key,
    required this.state,
    required this.deck,
    required this.onEvent,
  });

  bool get _isTactical =>
      (state.setup?.secondaryMode ?? SecondaryMode.tactical) ==
      SecondaryMode.tactical;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hand = deck.hand(state.secondaries);
    final remaining = deck.remaining(state.secondaries);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Card(
        color: scheme.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              child: Row(
                children: [
                  Icon(Icons.style_outlined, size: 15, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text('SECONDARIES',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      )),
                  const Spacer(),
                  Text('${remaining.length} left',
                      style: TextStyle(
                          fontSize: 10.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (hand.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: Text(
                  _isTactical
                      ? 'No cards in hand.'
                      : 'No secondaries chosen yet.',
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
            for (final card in hand)
              _CardTile(
                card: card,
                note: deck.drawNote(
                  card,
                  round: state.round,
                  hand: state.secondaries.hand,
                ),
                onScore: (vp) => onEvent(ScoreSecondaryCard(
                  cardId: card.id,
                  round: state.round,
                  vp: vp,
                )),
                onDiscard: () => onEvent(DiscardSecondary(card.id)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              // Two buttons share the row rather than sitting at their natural
              // widths, which overflowed at phone size.
              child: Row(
                children: [
                  if (_isTactical) ...[
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed:
                            remaining.isEmpty ? null : () => _drawAtRandom(),
                        icon: const Icon(Icons.casino_outlined, size: 17),
                        label: const Text('Draw'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Drawing blind is the rule, but the app is a record of what
                  // happened at the table, not the referee: cards get drawn by
                  // hand, missed, or corrected, and a player who cannot enter
                  // the card actually in front of them stops using the app.
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: remaining.isEmpty
                          ? null
                          : () => _choose(context, remaining),
                      icon: Icon(_isTactical ? Icons.list_alt : Icons.add,
                          size: 17),
                      label: const Text('Choose'),
                    ),
                  ),
                ],
              ),
            ),
            if (state.secondaries.scored.isNotEmpty)
              _ScoredStrip(state: state, deck: deck),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  /// Either way the card that ends up in hand is the event, so undo puts it
  /// back and a replay of the log deals the same hand — the randomness never
  /// enters the state (§7.3.2).
  void _drawAtRandom() {
    final drawn = deck.draw(state.secondaries);
    if (drawn != null) onEvent(DrawSecondary(drawn.id));
  }

  Future<void> _choose(
      BuildContext context, List<MissionCard> remaining) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _PickSheet(cards: remaining),
    );
    if (chosen != null) onEvent(DrawSecondary(chosen));
  }
}

class _PickSheet extends StatelessWidget {
  final List<MissionCard> cards;

  const _PickSheet({required this.cards});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const SheetHeader(title: 'Choose a secondary'),
          for (final card in cards)
            InkWell(
              onTap: () => Navigator.of(context).pop(card.id),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    // In full. These run to 800 characters and describe tiers,
                    // timings and exclusions — a three-line clamp cut the half
                    // that decides whether the card is worth taking.
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(card.text,
                          style: TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              color: scheme.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
            ),
          const _CardTextProvenance(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Whose words these are (§7.3.4, §7.6).
///
/// The descriptions are community-authored summaries, which is exactly why
/// they can be redistributed — but they are good enough to *play* from and not
/// good enough to *argue* from. Saying so once at the foot of the list beats
/// repeating a disclaimer on every card, and beats leaving a player to assume
/// this is the printed wording.
class _CardTextProvenance extends StatelessWidget {
  const _CardTextProvenance();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        'Descriptions are summaries written by the 40kdc community, not the '
        'printed card text. They are enough to play from; for a rules dispute '
        'the card itself is authoritative.',
        style: TextStyle(fontSize: 10.5, height: 1.35, color: scheme.outline),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final MissionCard card;

  /// Why this card may not stick — too early, mutually exclusive, or no valid
  /// target in the opponent's army. Null when it is simply theirs to keep.
  final String? note;

  final void Function(int) onScore;
  final VoidCallback onDiscard;

  const _CardTile({
    required this.card,
    required this.note,
    required this.onScore,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final payouts = SecondaryDeck.payouts(card);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(card.name,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          if (note case final note?)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                note,
                style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: scheme.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(card.text,
                style:
                    TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              // The payouts the card itself names. A card that pays per
              // objective names no total, so those fall to the stepper.
              for (final vp in payouts)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: Text('Score $vp'),
                  onPressed: () => onScore(vp),
                ),
              if (payouts.isEmpty)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('Score…'),
                  onPressed: () => _scoreCustom(context),
                ),
              ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.close, size: 15),
                label: const Text('Discard'),
                onPressed: onDiscard,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _scoreCustom(BuildContext context) async {
    final vp = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => _AmountSheet(name: card.name),
    );
    if (vp != null && vp > 0) onScore(vp);
  }
}

/// For cards that pay per objective or per unit, where only the player can see
/// the board.
class _AmountSheet extends StatefulWidget {
  final String name;

  const _AmountSheet({required this.name});

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  int _vp = 2;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.name,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(
              children: [
                _Tap(
                    icon: Icons.remove,
                    onTap: () => setState(() => _vp = (_vp - 1).clamp(1, 15))),
                SizedBox(
                  width: 44,
                  child: Text('$_vp',
                      style: AppTheme.numeric(context, size: 22)
                          .copyWith(fontWeight: FontWeight.w800)),
                ),
                _Tap(
                    icon: Icons.add,
                    onTap: () => setState(() => _vp = (_vp + 1).clamp(1, 15))),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_vp),
                  child: const Text('Score'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoredStrip extends StatelessWidget {
  final BattleState state;
  final SecondaryDeck deck;

  const _ScoredStrip({required this.state, required this.deck});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      child: Wrap(
        spacing: 8,
        runSpacing: 2,
        children: [
          for (final entry in state.secondaries.scored.entries)
            Text('${deck.card(entry.key)?.name ?? entry.key} ${entry.value}',
                style: TextStyle(
                    fontSize: 10.5,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
