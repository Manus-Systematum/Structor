import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

/// What happened, in the order it happened (DESIGN.md §7.3.15).
///
/// The same widget during the battle and after it. Mid-game it answers "what
/// did I already score this round" without unpicking the scoreboard; afterwards
/// it is the record the result is read from, which is why it is derived from
/// the log rather than summarised into columns at the end — a summary written
/// once cannot answer a question nobody thought to ask.
///
/// **Names are resolved where they can be and never invented.** A finished
/// battle outlives the roster it was played with, so a unit deleted since is
/// shown by what the log holds rather than blanked out.
class BattleRecord extends StatelessWidget {
  final BattleLog log;

  /// Resolves an instance id to the name the player used. Absent for a
  /// finished battle whose roster has been deleted.
  final String Function(String instanceId)? unitName;

  /// Resolves a stratagem or card id to its printed name.
  final String Function(String id)? cardName;

  final String opponentName;

  const BattleRecord({
    super.key,
    required this.log,
    this.unitName,
    this.cardName,
    this.opponentName = 'Opponent',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = [
      for (final entry in log.timeline)
        if (_line(entry) case final line?) (entry, line),
    ];

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Nothing recorded yet.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      );
    }

    // Grouped by round, and within a round by whose turn it was — which is
    // how the game is remembered, and the only grouping the log can support
    // without the player having marked anything.
    final rounds = <int, List<(LogEntry, _Line)>>{};
    for (final e in entries) {
      rounds.putIfAbsent(e.$1.round, () => []).add(e);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final round in rounds.keys.toList()..sort())
          _Round(
            round: round,
            entries: rounds[round]!,
            opponentName: opponentName,
          ),
      ],
    );
  }

  /// One line of record, or null for an event that records nothing a player
  /// would look for later.
  ///
  /// Bookkeeping is left out on purpose: a command point corrected by hand, a
  /// round set straight because the app and the table disagreed. Those are how
  /// the log stays honest, not what happened in the game, and printing them
  /// turns a record into an audit.
  _Line? _line(LogEntry entry) {
    String unit(String? id) => id == null ? '' : (unitName?.call(id) ?? id);
    String card(String id) => cardName?.call(id) ?? id;

    return switch (entry.event) {
      final ScoreVp e => _Line(
          text: '${e.vp > 0 ? '+' : ''}${e.vp} '
              '${e.kind == ScoreKind.primary ? 'primary' : 'secondary'}',
          side: e.side,
          vp: e.vp,
        ),
      final ScoreSecondaryCard e => _Line(
          text: '${card(e.cardId)}  +${e.vp}',
          side: Player.me,
          vp: e.vp,
        ),
      final UseStratagem e => _Line(
          text: [
            card(e.stratagemId),
            if (e.targetInstanceId != null) 'on ${unit(e.targetInstanceId)}',
          ].join(' '),
          detail: '${e.cp} CP · ${e.phase}',
        ),
      final DrawSecondary e => _Line(text: 'Drew ${card(e.cardId)}'),
      final DiscardSecondary e => _Line(text: 'Discarded ${card(e.cardId)}'),
      final UseOncePerBattle e =>
        _Line(text: '${card(e.abilityId)} — ${unit(e.instanceId)}'),
      final SetUnitStatus e => switch (e.status) {
          UnitStatus.destroyed =>
            _Line(text: '${unit(e.instanceId)} destroyed'),
          UnitStatus.reserves =>
            _Line(text: '${unit(e.instanceId)} into reserves'),
          UnitStatus.onBoard => _Line(text: '${unit(e.instanceId)} arrived'),
        },
      final SetModelsRemaining e => e.models <= 0
          ? _Line(text: '${unit(e.instanceId)} destroyed')
          : _Line(text: '${unit(e.instanceId)} down to ${e.models}'),
      _ => null,
    };
  }
}

class _Line {
  final String text;
  final String? detail;
  final Player? side;
  final int? vp;

  const _Line({required this.text, this.detail, this.side, this.vp});
}

class _Round extends StatelessWidget {
  final int round;
  final List<(LogEntry, _Line)> entries;
  final String opponentName;

  const _Round({
    required this.round,
    required this.entries,
    required this.opponentName,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('ROUND $round',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              )),
        ),
        for (final (entry, line) in entries)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 62,
                  child: Text(
                    entry.activePlayer == Player.me
                        ? 'your turn'
                        : 'their turn',
                    style: TextStyle(
                        fontSize: 9.5, color: scheme.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.text,
                          style: const TextStyle(fontSize: 12, height: 1.3)),
                      if (line.detail != null)
                        Text(line.detail!,
                            style: TextStyle(
                                fontSize: 10, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (line.vp != null)
                  Text(
                    line.side == Player.me ? 'you' : opponentName,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: line.side == Player.me
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
