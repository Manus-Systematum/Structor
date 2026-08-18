/// Cleaning up BattleScribe's markup in printed rules text (DESIGN.md §3.10).
///
/// BSData writes rules more or less as they are printed, with its own
/// conventions for the typography a codex uses. Measured across the 11,870
/// descriptions in the merged dataset:
///
///     **bold**            20,663 occurrences   keywords and emphasis
///     ^^small caps^^       9,022                keywords
///     [KEYWORD]            1,920                datasheet notation
///     *italic*               476                designer's notes
///     non-breaking space   4,152                invisible noise
///     ■ ▪ ▫ •                323                sub-clauses
///
/// Shown raw, a player reads `**^^T’au Empire^^**` on a phone mid-game.
///
/// The split is between **noise and meaning**. Non-breaking spaces and hyphens
/// carry nothing a screen needs and go at ingest. Bullets are structure and
/// become real ones. Small caps and bold both mark a keyword, and one emphasis
/// level is enough on a phone, so they fold together. `[KEYWORD]` stays
/// exactly as printed — that *is* how a datasheet writes it.
///
/// Emphasis survives into the shipped data rather than being stripped, because
/// which words are keywords is information: `**T’AU EMPIRE** models` and
/// `T’au Empire models` do not say the same thing to someone checking whether
/// a rule applies. Rendering it is the app's job.
library;

final _nbsp = RegExp('[  ]');
final _nbHyphen = RegExp('[‐‑]');
/// Both markers on the same words, in either order — `**^^X^^**` and
/// `^^**X**^^`, and the data uses both. Handled before the bare form: folding
/// small caps into bold otherwise doubles the markers, and cleaning up after
/// that left a stray `**` in the middle of a sentence.
final _boldSmallCaps = RegExp(
    r'\*\*\s*\^\^(.*?)\^\^\s*\*\*|\^\^\s*\*\*(.*?)\*\*\s*\^\^',
    dotAll: true);
final _smallCaps = RegExp(r'\^\^(.*?)\^\^', dotAll: true);
final _bullets = RegExp('[▪▫■•]');
final _trailingSpace = RegExp(r'[ \t]+$', multiLine: true);
final _blankRun = RegExp(r'\n{3,}');
final _spaceRun = RegExp('[ \t]{2,}');
final _emptyEmphasis = RegExp(r'\*\*\s*\*\*');

/// BattleScribe's markup, reduced to what the app renders.
String normaliseRuleText(String raw) {
  var text = raw
      .replaceAll(_nbsp, ' ')
      .replaceAll(_nbHyphen, '-')
      // Small caps and bold both mark a keyword; the app has one emphasis
      // level, so they become the same thing rather than two.
      .replaceAllMapped(
          _boldSmallCaps, (m) => '**${(m[1] ?? m[2]!).trim()}**')
      .replaceAllMapped(_smallCaps, (m) => '**${m[1]!.trim()}**')
      .replaceAll(_emptyEmphasis, '');

  // A bullet is a new clause, and inline it reads as part of the previous
  // sentence: "…use this ability. If you do: ▫ Place this unit in…".
  text = text.replaceAllMapped(
      RegExp('\\s*(${_bullets.pattern})\\s*'), (m) => '\n• ');

  return text
      .replaceAll(_spaceRun, ' ')
      .replaceAll(_trailingSpace, '')
      .replaceAll(_blankRun, '\n\n')
      .trim();
}

/// One run of rule text, and whether it is emphasised.
class RuleSpan {
  final String text;
  final bool bold;
  final bool italic;

  const RuleSpan(this.text, {this.bold = false, this.italic = false});

  @override
  String toString() =>
      '${bold ? 'b' : ''}${italic ? 'i' : ''}:$text';
}

final _emphasis = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*', dotAll: true);

/// Splits normalised rule text into runs for a rich-text widget.
///
/// Lives in core rather than in the widget so it can be tested without
/// pumping one, and so the CLI reports can show the same thing the app does.
List<RuleSpan> ruleSpans(String text) {
  final spans = <RuleSpan>[];
  var at = 0;
  for (final match in _emphasis.allMatches(text)) {
    if (match.start > at) {
      spans.add(RuleSpan(text.substring(at, match.start)));
    }
    final bold = match.group(1);
    if (bold != null) {
      spans.add(RuleSpan(bold, bold: true));
    } else {
      spans.add(RuleSpan(match.group(2)!, italic: true));
    }
    at = match.end;
  }
  if (at < text.length) spans.add(RuleSpan(text.substring(at)));
  return [for (final s in spans) if (s.text.isNotEmpty) s];
}
