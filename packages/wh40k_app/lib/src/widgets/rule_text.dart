import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

/// Rules text with its emphasis rendered rather than printed.
///
/// BSData supplies rules as they appear in a codex, and the typography is part
/// of the sentence: `**T’AU EMPIRE** models` and `T’au Empire models` do not
/// tell a player the same thing about whether a rule applies. Shown through a
/// plain [Text] the asterisks appear literally, which is worse than either —
/// noise that also hides which words are the keywords (§3.10).
///
/// Only two levels exist, because only two are used: bold for a keyword,
/// italic for a designer's note.
class RuleText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const RuleText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final spans = ruleSpans(text);

    // Nothing to mark up: the common case, and a plain Text is cheaper than a
    // one-span RichText.
    if (spans.length == 1 && !spans.single.bold && !spans.single.italic) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }

    return Text.rich(
      TextSpan(
        children: [
          for (final span in spans)
            TextSpan(
              text: span.text,
              style: TextStyle(
                fontWeight: span.bold ? FontWeight.w700 : null,
                fontStyle: span.italic ? FontStyle.italic : null,
              ),
            ),
        ],
      ),
      style: base,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
