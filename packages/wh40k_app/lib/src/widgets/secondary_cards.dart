import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../theme.dart';
import 'rule_text.dart';
import 'sheet_header.dart';

/// One side's secondary cards: what is in hand, what each pays, drawing the
/// next, and putting one back.
///
/// **It takes a side.** Both players hold cards, from copies of the same deck,
/// so the same objective can be in both hands at once (§7.3.16). Everything
/// here reads `state.secondariesOf(side)` and stamps `side` on every event it
/// emits; nothing about one player's hand is derived from the other's.
///
/// It reads and writes the same [BattleState] wherever it appears, so two
/// copies of it cannot disagree.
class SecondaryPanel extends StatelessWidget {
  final BattleState state;
  final SecondaryDeck deck;
  final void Function(BattleEvent) onEvent;

  /// Whose cards these are.
  final Player side;

  /// Shown when the panel is not obviously about one player — a sheet opened
  /// from the opponent's row needs to say so.
  final String? title;

  const SecondaryPanel({
    super.key,
    required this.state,
    required this.deck,
    required this.onEvent,
    this.side = Player.me,
    this.title,
  });

  SecondaryState get _mine => state.secondariesOf(side);

  bool get _isTactical =>
      (state.setup?.secondaryMode ?? SecondaryMode.tactical) ==
      SecondaryMode.tactical;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hand = deck.hand(_mine);
    final remaining = deck.remaining(_mine);

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
                  Text(title?.toUpperCase() ?? 'SECONDARIES',
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
                  hand: _mine.hand,
                ),
                onScore: (vp) => onEvent(ScoreSecondaryCard(
                  cardId: card.id,
                  round: state.round,
                  vp: vp,
                  side: side,
                )),
                onDiscard: () => onEvent(DiscardSecondary(card.id, side: side)),
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
            if (_mine.scored.isNotEmpty)
              _ScoredStrip(scored: _mine.scored, deck: deck),
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
    final drawn = deck.draw(_mine);
    if (drawn != null) onEvent(DrawSecondary(drawn.id, side: side));
  }

  Future<void> _choose(
      BuildContext context, List<MissionCard> remaining) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _PickSheet(cards: remaining),
    );
    if (chosen != null) onEvent(DrawSecondary(chosen, side: side));
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
                      child: RuleText(card.text,
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
        'Card text is transcribed, not summarised, but the printed card is '
        'what settles a rules dispute.',
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
            child: RuleText(card.text,
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
  final Map<String, int> scored;
  final SecondaryDeck deck;

  const _ScoredStrip({required this.scored, required this.deck});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      child: Wrap(
        spacing: 8,
        runSpacing: 2,
        children: [
          for (final entry in scored.entries)
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
