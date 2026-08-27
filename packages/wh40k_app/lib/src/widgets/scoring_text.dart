import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import 'rule_text.dart';
import 'score_counter.dart';

/// A mission card's text, with each payout's button on the line that earns it.
///
/// **The button and the condition are one thing.** A row of `+2 +4 +1` above a
/// block of text asks the player to hold "which figure was the objective one"
/// in their head while they read, and then to tap the right chip from memory.
/// Reading the line and tapping it is the same motion here (§7.3.22).
///
/// The lines come from the card's own composed text (§3.11), so this parses
/// rather than re-derives: a payout line opens `4 VP:`, `+2 VP each:`,
/// `5 VP, max 15 VP:`. Anything else — a section header, the ACTION block —
/// renders as text, which is what it is.
class ScoringText extends StatelessWidget {
  final String text;

  /// The card the text came from, when there is one.
  ///
  /// Only for the payout ladders (§7.3.27): a line that pays *per* something
  /// and caps can only ever come to a few totals, and those are on the card's
  /// awards rather than in its wording. Null where the caller has text and no
  /// card, which is every review of a past turn.
  final MissionCard? card;

  /// Points this source can still score this round, or null when uncapped.
  /// Only used by the counter (§7.3.27), which is the one place the app can
  /// see the rate and the headroom together.
  final int? headroom;

  /// Null on a card nobody can score right now: the opponent's card while
  /// their tier is closed, or a review of a turn already played.
  final void Function(int vp)? onScore;

  final TextStyle? style;

  const ScoringText({
    super.key,
    required this.text,
    required this.onScore,
    this.card,
    this.headroom,
    this.style,
  });

  /// `4 VP:`, `+2 VP each:`, `5 VP, max 15 VP:` — the figure is the first
  /// number, and the `+` means cumulative rather than a different amount.
  ///
  /// `\+*` rather than `\+?`: two cards briefly composed as `++1 VP each`,
  /// the source having already written the plus the merge then added. That is
  /// fixed upstream, and a line that still doubles it should carry its button
  /// rather than silently lose one.
  static final _payout = RegExp(r'^\+*(\d+)\s*VP\b[^:]*:\s*(.*)$');

  /// What a line pays, or null when it is not a payout line at all. Public
  /// for the test that pins the parsing against the shipped cards.
  static int? payoutOf(String line) {
    final match = _payout.firstMatch(line.trim());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// Whether any line names a figure — false for a card that pays only per
  /// objective or per unit, where the total is the player's to count.
  static bool hasPayout(String text) =>
      text.split('\n').any((line) => payoutOf(line) != null);

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          if (line.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: _Line(
                line: line,
                vp: payoutOf(line),
                ladder: payoutOf(line) == null
                    ? const []
                    : card?.ladderFor(payoutOf(line)!) ?? const [],
                rate: payoutOf(line) == null
                    ? null
                    : card?.uncappedRateFor(payoutOf(line)!),
                cardName: card?.name ?? '',
                headroom: headroom,
                onScore: onScore,
                style: style,
              ),
            ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  final String line;
  final int? vp;

  /// Every total this line can come to, when it pays per something and caps.
  /// Empty for a flat payout and for an uncapped rate.
  final List<int> ladder;

  /// Points per thing, when the line pays a rate that never stops.
  final int? rate;

  final String cardName;

  /// Points still available this round.
  final int? headroom;

  final void Function(int vp)? onScore;
  final TextStyle? style;

  const _Line({
    required this.line,
    required this.vp,
    required this.onScore,
    required this.style,
    this.ladder = const [],
    this.rate,
    this.cardName = '',
    this.headroom,
  });

  /// Counting the things, because the total cannot be listed (§7.3.27).
  Future<void> _count(BuildContext context) async {
    final vp = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => ScoreCounterSheet(
        cardName: cardName,
        line: line,
        rate: rate!,
        headroom: headroom,
      ),
    );
    if (vp != null && vp > 0) onScore!(vp);
  }

  @override
  Widget build(BuildContext context) {
    final scoreable = vp != null && onScore != null;
    if (!scoreable) {
      return RuleText(line, style: style);
    }

    // The button sits at the end of the sentence rather than beside it: a
    // fixed column would leave the text a phone-width column of two words,
    // and these lines run to three lines of their own.
    //
    // A capped per-something line gets one button per total it can reach
    // (§7.3.27) — `2 VP for each kill, up to 5` is 2, 4 or 5 and never 6, and
    // working that out is arithmetic the card leaves to a player with a clock
    // running.
    // A rate with no ceiling of its own cannot be listed, so it opens a
    // counter instead: the player knows how many objectives they hold, not
    // what that comes to against a cap.
    if (ladder.isEmpty && rate != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: RuleText(line, style: style)),
          const SizedBox(width: 8),
          _ScoreButton(vp: null, onTap: () => _count(context)),
        ],
      );
    }

    final figures = ladder.isEmpty ? [vp!] : ladder;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: RuleText(line, style: style)),
        const SizedBox(width: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final figure in figures)
              _ScoreButton(vp: figure, onTap: () => onScore!(figure)),
          ],
        ),
      ],
    );
  }
}

class _ScoreButton extends StatelessWidget {
  /// Null where the figure is not knowable until the player counts.
  final int? vp;
  final VoidCallback onTap;

  const _ScoreButton({required this.vp, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(vp == null ? 'Score…' : 'Score $vp',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: scheme.onPrimaryContainer,
            )),
      ),
    );
  }
}
