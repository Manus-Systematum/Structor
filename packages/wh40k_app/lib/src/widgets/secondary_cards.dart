import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../theme.dart';
import 'faq_button.dart';
import 'rule_text.dart';
import 'scoring_text.dart';
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

  /// Published questions, so a card that has any can offer them (§3.16).
  final List<FactionFaq> faqs;

  const SecondaryPanel({
    super.key,
    required this.state,
    required this.deck,
    required this.onEvent,
    this.side = Player.me,
    this.title,
    this.faqs = const [],
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
                // The published sequence (§7.3.26): at the end of your turn
                // you may discard one or more and gain a single command
                // point, once per your turn — and never on Fixed missions,
                // which cannot be discarded at all.
                onTradeForCp: state.canTradeForCp(side)
                    ? () => onEvent(
                        DiscardSecondary(card.id, side: side, forCp: true))
                    : null,
                // Once per battle, a point buys a swap. The draw after it is
                // the player's own, which is why this only discards.
                onRedraw: state.canRedraw(side)
                    ? () => onEvent(RedrawSecondary(card.id, side: side))
                    : null,
                // A Fixed mission is active all battle and cannot be binned.
                canDiscard: !state.isFixed,
                headroom: (side == Player.me ? state.me : state.opponent)
                    .headroom(state.round, primaryKind: false),
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
                faqs: faqs,
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
                      onPressed: () => _choose(context),
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

  /// The whole deck, with this side's hand already selected (§7.3.25).
  ///
  /// It edits the hand rather than adding one card to it, because what it is
  /// for is **correcting the record**: a card entered as the wrong one, a
  /// discard that did not happen, a hand typed in after three turns played on
  /// paper. Offering only undrawn cards made every one of those unfixable.
  ///
  /// The selection is a set the sheet writes into, so closing it by the button
  /// or by swiping it away both keep the edits — losing them on a swipe would
  /// be the app changing something the player did not (§7.7).
  Future<void> _choose(BuildContext context) async {
    final held = _mine.hand.toSet();
    final selection = {...held};
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _PickSheet(
        cards: deck.cards,
        inHand: held,
        discarded: _mine.discarded.toSet(),
        selection: selection,
      ),
    );
    for (final card in deck.cards) {
      final chosen = selection.contains(card.id);
      if (chosen && !held.contains(card.id)) {
        onEvent(DrawSecondary(card.id, side: side));
      } else if (!chosen && held.contains(card.id)) {
        onEvent(DiscardSecondary(card.id, side: side));
      }
    }
  }
}

/// The whole deck as a checklist: what is in hand, what was discarded, and
/// everything still unseen.
///
/// Both facts are shown rather than only the selection, because they are not
/// the same fact. A card in hand is one the player is holding; a discarded one
/// is one they turned down — still available to take back, and worth marking
/// so a player scanning the list knows why they remember seeing it.
class _PickSheet extends StatefulWidget {
  final List<MissionCard> cards;

  /// The hand as it stood when the sheet opened, for the pills.
  final Set<String> inHand;
  final Set<String> discarded;

  /// Written in place: what the hand should be when the sheet closes.
  final Set<String> selection;

  const _PickSheet({
    required this.cards,
    required this.inHand,
    required this.discarded,
    required this.selection,
  });

  @override
  State<_PickSheet> createState() => _PickSheetState();
}

class _PickSheetState extends State<_PickSheet> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(title: 'Choose secondaries'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text(
                'Tap to take a card or put it back. What is selected when you '
                'close is the hand.',
                style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: scheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final card in widget.cards)
                    _PickRow(
                      card: card,
                      selected: widget.selection.contains(card.id),
                      wasInHand: widget.inHand.contains(card.id),
                      wasDiscarded: widget.discarded.contains(card.id),
                      onTap: () => setState(() {
                        if (!widget.selection.remove(card.id)) {
                          widget.selection.add(card.id);
                        }
                      }),
                    ),
                  const _CardTextProvenance(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close (${widget.selection.length} in hand)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  final MissionCard card;
  final bool selected;
  final bool wasInHand;
  final bool wasDiscarded;
  final VoidCallback onTap;

  const _PickRow({
    required this.card,
    required this.selected,
    required this.wasInHand,
    required this.wasDiscarded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = selected
        ? scheme.primaryContainer.withValues(alpha: 0.45)
        : wasDiscarded
            ? scheme.errorContainer.withValues(alpha: 0.3)
            : null;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: background,
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 19,
              color: selected ? scheme.primary : scheme.outline,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(card.name,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      if (wasInHand) ...[
                        const SizedBox(width: 6),
                        _Pill(
                          label: 'in hand',
                          color: scheme.primary,
                          background: scheme.primaryContainer,
                        ),
                      ],
                      if (wasDiscarded) ...[
                        const SizedBox(width: 6),
                        _Pill(
                          label: 'discarded',
                          color: scheme.onErrorContainer,
                          background: scheme.errorContainer,
                        ),
                      ],
                    ],
                  ),
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
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _Pill({
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 9.5,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w700,
              color: color,
            )),
      );
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

  /// Null when this side has already taken the point this turn, or is
  /// playing Fixed missions, which cannot be discarded (§7.3.26).
  final VoidCallback? onTradeForCp;

  /// Null once the once-per-battle swap has been spent.
  final VoidCallback? onRedraw;

  /// False on Fixed missions: they stay on the table all battle.
  final bool canDiscard;

  /// Points this side can still take from secondaries this round (§7.3.27).
  final int? headroom;

  /// Published questions, so a card that has any can offer them.
  final List<FactionFaq> faqs;

  const _CardTile({
    required this.card,
    required this.note,
    required this.onScore,
    required this.onDiscard,
    this.onTradeForCp,
    this.onRedraw,
    this.canDiscard = true,
    this.headroom,
    this.faqs = const [],
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A card that pays only per objective or per unit names no total, and the
    // app cannot see the table — those keep the stepper.
    final named = ScoringText.hasPayout(card.text);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(card.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              FaqButton(cardId: card.id, faqs: faqs),
            ],
          ),
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
          // Each payout's button on the line that earns it, the same as the
          // primary (§7.3.22). A secondary is read at the moment it is scored
          // — it was drawn a turn ago and the conditions are the whole card.
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ScoringText(
              text: card.text,
              card: card,
              headroom: headroom,
              onScore: onScore,
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (!named)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('Score…'),
                  onPressed: () => _scoreCustom(context),
                ),
              if (canDiscard)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.close, size: 15),
                  label: const Text('Discard'),
                  onPressed: () => _confirmDiscard(context, forCp: false),
                ),
              if (onTradeForCp != null)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.bolt, size: 15),
                  label: const Text('Discard for 1 CP'),
                  onPressed: () => _confirmDiscard(context, forCp: true),
                ),
              if (onRedraw != null)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.autorenew, size: 15),
                  label: const Text('Swap for 1 CP'),
                  onPressed: () => _confirmRedraw(context),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Both discards ask first (§7.3.25).
  ///
  /// A discard is a chip's width from `Score 5`, it is the one action on the
  /// card that cannot be read back off the table, and the CP one also spends
  /// the round's single trade. Undo exists, but it is on another screen and
  /// several taps away from a player mid-turn.
  Future<void> _confirmDiscard(BuildContext context,
      {required bool forCp}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            forCp ? 'Discard ${card.name} for 1 CP?' : 'Discard ${card.name}?'),
        content: Text(forCp
            ? 'The card leaves your hand and you gain 1 command point. One '
                'card a battle round can be traded this way.'
            : 'The card leaves your hand. Choose takes it back.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(forCp ? 'Discard for 1 CP' : 'Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (forCp) {
      onTradeForCp!();
    } else {
      onDiscard();
    }
  }

  /// The once-per-battle swap (§7.3.26). It asks like the discards do, and
  /// says what it costs: this one *spends* a point where the other pays one,
  /// and two chips a finger apart that move CP in opposite directions is
  /// exactly where a mis-tap is expensive.
  Future<void> _confirmRedraw(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Swap ${card.name} for 1 CP?'),
        content: const Text(
          'The card is discarded and you spend 1 command point. Draw its '
          'replacement yourself. This can be done once a battle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Swap for 1 CP'),
          ),
        ],
      ),
    );
    if (confirmed == true) onRedraw!();
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
