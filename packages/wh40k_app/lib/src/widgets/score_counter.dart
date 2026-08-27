import 'package:flutter/material.dart';

import '../theme.dart';
import 'sheet_header.dart';

/// Counting the *things*, not the points (§7.3.27).
///
/// A card that pays a rate with no ceiling of its own — `3 VP each: For each
/// objective you control` — cannot be offered as a short list of totals. What
/// the player knows at the table is how many objectives they hold, so that is
/// what this counts, and the points follow from it.
///
/// **The round's cap is shown and enforced here**, because this is the one
/// place the app can see both the rate and the headroom. Fifteen a round means
/// the fifth objective at 3VP each is worth nothing, and a player who counts
/// five and scores fifteen should be told that rather than discover it when
/// the total does not move.
class ScoreCounterSheet extends StatefulWidget {
  /// What is being scored, for the heading.
  final String cardName;

  /// The line that earns it, so the counter is anchored to the words the
  /// player just read rather than to the card as a whole.
  final String line;

  /// Points per thing.
  final int rate;

  /// Points already taken from this source this round, and the round's
  /// ceiling. Null when nothing caps it.
  final int? scoredThisRound;
  final int? roundCap;

  const ScoreCounterSheet({
    super.key,
    required this.cardName,
    required this.line,
    required this.rate,
    this.scoredThisRound,
    this.roundCap,
  });

  @override
  State<ScoreCounterSheet> createState() => _ScoreCounterSheetState();
}

class _ScoreCounterSheetState extends State<ScoreCounterSheet> {
  int _count = 1;

  /// What the count is worth before the cap.
  int get _raw => _count * widget.rate;

  int? get _headroom => widget.roundCap == null
      ? null
      : (widget.roundCap! - (widget.scoredThisRound ?? 0)).clamp(0, 1 << 30);

  /// What it is actually worth. Points in excess of the maximum are ignored,
  /// so the figure offered is the one that will land.
  int get _vp => _headroom == null ? _raw : _raw.clamp(0, _headroom!);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader(title: widget.cardName),
            Text(
              widget.line,
              style: TextStyle(
                  fontSize: 12, height: 1.35, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Step(
                  icon: Icons.remove,
                  onTap: _count <= 1 ? null : () => setState(() => _count -= 1),
                ),
                SizedBox(
                  width: 52,
                  child: Center(
                    child: Text('$_count',
                        style: AppTheme.numeric(context, size: 26)
                            .copyWith(fontWeight: FontWeight.w800)),
                  ),
                ),
                _Step(
                  icon: Icons.add,
                  onTap: () => setState(() => _count += 1),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$_count × ${widget.rate} VP',
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                      Text('$_vp VP',
                          style: AppTheme.numeric(context, size: 20).copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.primary)),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.roundCap case final cap?) ...[
              const SizedBox(height: 10),
              Text(
                '${(widget.scoredThisRound ?? 0) + _vp}/$cap scored this round',
                style: TextStyle(
                  fontSize: 11.5,
                  color: _vp < _raw ? scheme.error : scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed:
                    _vp <= 0 ? null : () => Navigator.of(context).pop(_vp),
                child: Text('Score $_vp'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _Step({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: scheme.surfaceContainerHighest,
        minimumSize: const Size(40, 40),
      ),
    );
  }
}
