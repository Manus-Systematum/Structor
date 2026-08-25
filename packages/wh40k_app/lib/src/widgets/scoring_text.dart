import 'package:flutter/material.dart';

import 'rule_text.dart';

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

  /// Null on a card nobody can score right now: the opponent's card while
  /// their tier is closed, or a review of a turn already played.
  final void Function(int vp)? onScore;

  final TextStyle? style;

  const ScoringText({
    super.key,
    required this.text,
    required this.onScore,
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
  final void Function(int vp)? onScore;
  final TextStyle? style;

  const _Line({
    required this.line,
    required this.vp,
    required this.onScore,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final scoreable = vp != null && onScore != null;
    if (!scoreable) {
      return RuleText(line, style: style);
    }

    // The button sits at the end of the sentence rather than beside it: a
    // fixed column would leave the text a phone-width column of two words,
    // and these lines run to three lines of their own.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: RuleText(line, style: style)),
        const SizedBox(width: 8),
        _ScoreButton(vp: vp!, onTap: () => onScore!(vp!)),
      ],
    );
  }
}

class _ScoreButton extends StatelessWidget {
  final int vp;
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
        child: Text('Score $vp',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: scheme.onPrimaryContainer,
            )),
      ),
    );
  }
}
