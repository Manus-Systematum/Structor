import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../data/database.dart';
import '../data/roster_store.dart';
import '../theme.dart';
import '../widgets/collapsible.dart';
import '../widgets/deployment_diagram.dart';

/// Battles that have been played to their end (DESIGN.md §7.3.12).
///
/// **The Play tab's resting state.** With no game in progress the tab used to
/// show a bare prompt to set one up, which is a screen that exists only to
/// hold a button. What a player actually wants between games is the record:
/// who they played, what they declared, how it finished. The button to start
/// the next one sits on top of that rather than instead of it.
///
/// Every row is rebuilt from the log the battle left behind, so the summary
/// cannot drift from the game — there is no second copy of the score.
class BattlesScreen extends StatelessWidget {
  final RosterStore store;
  final MissionPack pack;

  /// Starts a new battle. Null while the mission data is still loading, which
  /// disables the button rather than letting it fail.
  final VoidCallback? onStart;

  const BattlesScreen({
    super.key,
    required this.store,
    required this.pack,
    this.onStart,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<List<BattleRow>>(
        stream: store.watchBattles(),
        builder: (context, snapshot) => BattlesView(
          rows: snapshot.data,
          pack: pack,
          onStart: onStart,
          onDelete: store.deleteBattleRecord,
        ),
      );
}

/// The page itself, given rows rather than a stream.
///
/// Split from [BattlesScreen] so it can be rendered from a plain list. A
/// widget test that has to drive a live database stream spends its time
/// proving the stream works rather than the page, and an indeterminate
/// spinner waiting on one never lets `pumpAndSettle` finish.
class BattlesView extends StatelessWidget {
  /// Null while the records are still being read.
  final List<BattleRow>? rows;

  final MissionPack pack;
  final VoidCallback? onStart;
  final void Function(String id)? onDelete;

  const BattlesView({
    super.key,
    required this.rows,
    required this.pack,
    this.onStart,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = this.rows;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('No battle in progress',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Setting up decides which mission you play — and with two '
                'detachments, that is a choice.',
                style:
                    TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Set up battle'),
              ),
            ],
          ),
        ),
        if (rows == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Text(
              'Battles you finish are kept here — the missions, the armies, '
              'the score by round and the table you played on.',
              style:
                  TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          )
        else ...[
          Container(
            color: scheme.surfaceContainer,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Text('PAST BATTLES · ${rows.length}',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                )),
          ),
          for (final row in rows)
            _BattleCard(
              row: row,
              pack: pack,
              onDelete: onDelete == null ? null : () => onDelete!(row.id),
            ),
        ],
      ],
    );
  }
}

class _BattleCard extends StatelessWidget {
  final BattleRow row;
  final MissionPack pack;
  final VoidCallback? onDelete;

  const _BattleCard({
    required this.row,
    required this.pack,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final log = BattleLog.fromJson(jsonDecode(row.logJson));
    final state = log.state;
    final setup = state.setup;
    final opponent = (row.opponentName?.trim().isNotEmpty ?? false)
        ? row.opponentName!.trim()
        : 'Opponent';

    // Won, lost or drawn — said outright, because two totals side by side
    // still leave the reader doing the subtraction.
    final margin = row.myScore - row.opponentScore;
    final (verdict, verdictColour) = margin > 0
        ? ('WON by $margin', scheme.primary)
        : margin < 0
            ? ('LOST by ${-margin}', scheme.error)
            : ('DRAW', scheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Card(
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.only(bottom: 10),
            title: Row(
              children: [
                Expanded(
                  child: Text('${row.rosterName} vs $opponent',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                Text('${row.myScore}–${row.opponentScore}',
                    style: AppTheme.numeric(context, size: 16)
                        .copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            subtitle: Row(
              children: [
                Text(verdict,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w800,
                      color: verdictColour,
                    )),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_date(row.finishedAt)} · ${row.rounds} rounds · '
                    '${row.factionId.replaceAll('-', ' ')}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            children: [
              if (setup != null) ...[
                _Declarations(setup: setup, pack: pack, opponent: opponent),
                _ScoreTable(state: state, opponent: opponent),
                if (pack.deployment(setup.deploymentId ?? '')
                    case final pattern?)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pattern.name,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        DeploymentDiagram(
                          pattern: pattern,
                          iAmAttacker: setup.iAmAttacker,
                          layout: _layoutOf(setup),
                          templates: pack.terrainTemplates,
                        ),
                      ],
                    ),
                  ),
              ] else
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(
                    'This battle was recorded without a setup, so there is no '
                    'mission or table to show.',
                    style: TextStyle(
                        fontSize: 11.5, color: scheme.onSurfaceVariant),
                  ),
                ),
              if (onDelete != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: TextButton.icon(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline,
                        size: 17, color: scheme.error),
                    label: Text('Delete record',
                        style: TextStyle(color: scheme.error)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TerrainLayout? _layoutOf(MissionSetup setup) {
    for (final layout in pack.terrainLayouts) {
      if (layout.id == setup.terrainLayoutId) return layout;
    }
    return null;
  }

  static String _date(DateTime at) =>
      '${at.day} ${_months[at.month - 1]} ${at.year}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}

/// What each side declared, and the mission it bought them.
class _Declarations extends StatelessWidget {
  final MissionSetup setup;
  final MissionPack pack;
  final String opponent;

  const _Declarations({
    required this.setup,
    required this.pack,
    required this.opponent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget side(String who, String disposition, String missionId) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 92,
                child: Text(who,
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.dispositions[disposition]?.name ??
                          disposition.replaceAll('-', ' '),
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    Text(
                      pack.missions[missionId]?.name ??
                          missionId.replaceAll('-', ' '),
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DECLARED',
              style: TextStyle(
                fontSize: 9.5,
                letterSpacing: 1,
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              )),
          const SizedBox(height: 2),
          side('You', setup.myDisposition, setup.myMissionId),
          side(opponent, setup.opponentDisposition, setup.opponentMissionId),
        ],
      ),
    );
  }
}

/// Score by round, both sides, primary and secondary apart.
class _ScoreTable extends StatelessWidget {
  final BattleState state;
  final String opponent;

  const _ScoreTable({required this.state, required this.opponent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget cell(String text, {bool strong = false, bool muted = false}) =>
        Expanded(
          child: Text(text,
              textAlign: TextAlign.center,
              style: AppTheme.numeric(context, size: 11.5).copyWith(
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                color: muted ? scheme.outline : scheme.onSurface,
              )),
        );

    // A round that scored nothing reads as a dash. Zero is a result; blank is
    // "nothing happened", and the two look different on purpose (§7.3.11).
    String value(int? v) => (v ?? 0) == 0 ? '–' : '${v!}';

    return CollapsibleGroup(
      title: 'SCORE BY ROUND',
      icon: Icons.timeline,
      trailing: '${state.me.total}–${state.opponent.total}',
      initiallyOpen: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                    width: 74,
                    child: Text('',
                        style: TextStyle(color: scheme.onSurfaceVariant))),
                for (final label in ['P', 'S', 'P', 'S'])
                  Expanded(
                    child: Text(label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant)),
                  ),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 74),
                Expanded(
                  flex: 2,
                  child: Text('You',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant)),
                ),
                Expanded(
                  flex: 2,
                  child: Text(opponent,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant)),
                ),
              ],
            ),
            const Divider(height: 8),
            for (var round = 1; round <= state.round; round++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    SizedBox(
                      width: 74,
                      child: Text('Round $round',
                          style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant)),
                    ),
                    cell(value(state.me.primary[round])),
                    cell(value(state.me.secondary[round])),
                    cell(value(state.opponent.primary[round])),
                    cell(value(state.opponent.secondary[round])),
                  ],
                ),
              ),
            const Divider(height: 8),
            Row(
              children: [
                const SizedBox(
                  width: 74,
                  child: Text('Total',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                cell('${state.me.primaryTotal}', strong: true),
                cell('${state.me.secondaryTotal}', strong: true),
                cell('${state.opponent.primaryTotal}', strong: true),
                cell('${state.opponent.secondaryTotal}', strong: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
