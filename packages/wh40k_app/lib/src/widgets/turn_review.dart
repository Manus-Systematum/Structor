import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../theme.dart';
import 'sheet_header.dart';

/// What this turn scored, before it is handed over (§7.3.29).
///
/// The last moment a turn's scoring can be corrected while the player still
/// remembers what happened. A card scored twice, a primary entered against
/// the wrong side, a figure counted before the last unit died — all of it is
/// easy to fix now and archaeology later.
///
/// Corrections are appended, never cut out: the events are deltas, so taking
/// something back is another delta and undo still works one pop at a time.
class TurnReviewSheet extends StatefulWidget {
  final BattleLog log;
  final BattleState state;

  /// Their name, for the row that is not yours.
  final String opponentName;

  final void Function(BattleEvent) onEvent;

  const TurnReviewSheet({
    super.key,
    required this.log,
    required this.state,
    required this.opponentName,
    required this.onEvent,
  });

  @override
  State<TurnReviewSheet> createState() => _TurnReviewSheetState();
}

class _TurnReviewSheetState extends State<TurnReviewSheet> {
  /// The events this sheet has added, so it can show their effect without
  /// waiting for the log to come back down through the widget tree.
  final _added = <BattleEvent>[];

  BattleLog get _log => _added.fold(widget.log, (log, event) => log.add(event));

  void _emit(BattleEvent event) {
    widget.onEvent(event);
    setState(() => _added.add(event));
  }

  /// Taking one entry back, as its own compensating event.
  void _takeBack(BattleEvent event) {
    switch (event) {
      case final ScoreVp e:
        _emit(ScoreVp(side: e.side, kind: e.kind, round: e.round, vp: -e.vp));
      case final ScoreSecondaryCard e:
        _emit(UnscoreSecondary(
            cardId: e.cardId, vp: e.vp, round: e.round, side: e.side));
      default:
        break;
    }
  }

  String _nameOf(Player side) =>
      side == Player.me ? 'You' : widget.opponentName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final log = _log;
    final state = log.state;
    final entries = log.scoringIn(state.turn);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(title: 'Round ${state.round}, turn ${state.turn}'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  if (entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('Nothing scored this turn.',
                          style: TextStyle(
                              fontSize: 12.5, color: scheme.onSurfaceVariant)),
                    ),
                  for (final entry in entries)
                    _Entry(
                      entry: entry,
                      who: _nameOf(_sideOf(entry.event)),
                      cardName: _cardName(entry.event),
                      onTakeBack: _isCorrection(entry.event)
                          ? null
                          : () => _takeBack(entry.event),
                    ),
                  const Divider(height: 24),
                  for (final side in Player.values)
                    _Adjust(
                      label: _nameOf(side),
                      primary: (side == Player.me ? state.me : state.opponent)
                              .primary[state.round] ??
                          0,
                      secondary: (side == Player.me ? state.me : state.opponent)
                              .secondary[state.round] ??
                          0,
                      onAdjust: (kind, delta) => _emit(ScoreVp(
                        side: side,
                        kind: kind,
                        round: state.round,
                        vp: delta,
                      )),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.done_all, size: 18),
                label: Text(state.passingEndsRound
                    ? 'End turn · R${state.round + 1}'
                    : 'End turn'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether this entry is itself a take-back. Taking one back is undo's job,
/// and undo is one tap away.
bool _isCorrection(BattleEvent event) => switch (event) {
      UnscoreSecondary() => true,
      final ScoreVp e => e.vp < 0,
      _ => false,
    };

Player _sideOf(BattleEvent event) => switch (event) {
      final ScoreVp e => e.side,
      final ScoreSecondaryCard e => e.side,
      final UnscoreSecondary e => e.side,
      _ => Player.me,
    };

String? _cardName(BattleEvent event) => switch (event) {
      final ScoreSecondaryCard e => e.cardId,
      final UnscoreSecondary e => e.cardId,
      _ => null,
    };

class _Entry extends StatelessWidget {
  final LogEntry entry;
  final String who;
  final String? cardName;

  /// Null on an entry that is itself a correction — a negative delta or an
  /// unscore. Taking back a take-back is undo's job, and it is one tap away.
  final VoidCallback? onTakeBack;

  const _Entry({
    required this.entry,
    required this.who,
    required this.cardName,
    required this.onTakeBack,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final event = entry.event;
    final (vp, what) = switch (event) {
      final ScoreVp e => (
          e.vp,
          e.kind == ScoreKind.primary ? 'primary' : 'secondary'
        ),
      final ScoreSecondaryCard e => (e.vp, _pretty(e.cardId)),
      final UnscoreSecondary e => (-e.vp, '${_pretty(e.cardId)} taken back'),
      _ => (0, ''),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              vp >= 0 ? '+$vp' : '$vp',
              style: AppTheme.numeric(context, size: 15).copyWith(
                fontWeight: FontWeight.w800,
                color: vp >= 0 ? scheme.onSurface : scheme.error,
              ),
            ),
          ),
          Expanded(
            child: Text('$who · $what', style: const TextStyle(fontSize: 12.5)),
          ),
          if (onTakeBack case final take?)
            TextButton(
              onPressed: take,
              child: const Text('Take back'),
            ),
        ],
      ),
    );
  }

  /// `outflank` reads as `Outflank`. The card's own name is not in the event
  /// — the log stores what happened, not how to print it.
  static String _pretty(String id) => id
      .split('-')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

class _Adjust extends StatelessWidget {
  final String label;
  final int primary;
  final int secondary;
  final void Function(ScoreKind kind, int delta) onAdjust;

  const _Adjust({
    required this.label,
    required this.primary,
    required this.secondary,
    required this.onAdjust,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          // Named rather than initialled: the board says PRIMARY and
          // SECONDARY, and a `P` the reader has to decode is shorter without
          // being clearer.
          for (final (kind, name, value) in [
            (ScoreKind.primary, 'Primary', primary),
            (ScoreKind.secondary, 'Secondary', secondary),
          ])
            Row(
              children: [
                SizedBox(
                  width: 84,
                  child: Text(name,
                      style: TextStyle(
                          fontSize: 11.5, color: scheme.onSurfaceVariant)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: value <= 0 ? null : () => onAdjust(kind, -1),
                  icon: const Icon(Icons.remove, size: 16),
                ),
                SizedBox(
                  width: 26,
                  child: Text('$value',
                      textAlign: TextAlign.center,
                      style: AppTheme.numeric(context, size: 14)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onAdjust(kind, 1),
                  icon: const Icon(Icons.add, size: 16),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
