import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../data/army.dart';
import '../theme.dart';
import '../widgets/weapon_table.dart';

/// Roster overview: points, validation, and a card per combat unit.
///
/// Validation findings are shown with severity and **never block** (§2.3) —
/// people build illegal lists on purpose. Informational findings such as
/// unspent Detachment Points are surfaced too, because they are the ones that
/// change a list.
class ArmyScreen extends StatelessWidget {
  final Army army;

  const ArmyScreen({super.key, required this.army});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final roster = army.roster;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Container(
          color: scheme.surfaceContainerHigh,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(roster.name,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                '${roster.factionId.replaceAll('-', ' ')} · '
                '${army.battleSize?.name ?? roster.battleSizeId}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Metric(
                      label: 'POINTS',
                      value: '${army.points}',
                      sub: 'of ${army.pointsLimit}'),
                  _Metric(
                      label: 'UNITS',
                      value: '${army.combatUnits.length}',
                      sub: '${roster.units.length} entries'),
                  _Metric(
                      label: 'DETACH',
                      value: '${roster.detachments.length}',
                      sub: roster.declaredDisposition
                              ?.replaceAll('-', ' ') ??
                          'undeclared'),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final detachment in roster.detachments)
                    Chip(
                      label:
                          Text(army.detachmentName(detachment.detachmentId)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
        const _SectionHeader('Validation'),
        if (army.validation.findings.isEmpty)
          const _Note('No findings — the list is legal.')
        else
          for (final finding in army.validation.findings)
            _FindingTile(finding: finding),
        const _SectionHeader('Units'),
        for (final unit in army.combatUnits) _UnitCard(unit: unit),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String sub;

  const _Metric({required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant)),
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800)),
          Text(sub,
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _FindingTile extends StatelessWidget {
  final ValidationFinding finding;

  const _FindingTile({required this.finding});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, colour) = switch (finding.severity) {
      Severity.error => (Icons.error_outline, scheme.error),
      Severity.warning => (Icons.warning_amber_outlined, scheme.tertiary),
      Severity.info => (Icons.info_outline, scheme.onSurfaceVariant),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colour),
          const SizedBox(width: 8),
          Expanded(
            child: Text(finding.message,
                style: TextStyle(fontSize: 12.5, color: scheme.onSurface)),
          ),
        ],
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final CombatUnit unit;

  const _UnitCard({required this.unit});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Card(
        child: Theme(
          data: Theme.of(context)
              .copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: Text(unit.label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
            subtitle: Text(
              '${unit.models} model${unit.models == 1 ? '' : 's'} · '
              '${unit.points} pts',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            children: [
              _StatBlock(unit: unit),
              const _Subheader('Ranged'),
              WeaponTable(result: unit.weapons(WeaponKind.ranged)),
              const _Subheader('Melee'),
              WeaponTable(result: unit.weapons(WeaponKind.melee)),
              if (unit.rules.isNotEmpty) const _Subheader('Abilities'),
              for (final entry in unit.attributedRules)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
                  child: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: '${entry.rule.name}: ',
                          style: const TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: entry.rule.text,
                          style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurfaceVariant),
                        ),
                        // Only when it could be either half: a Shield
                        // Generator on the Commander is not one on the suits
                        // it leads. Empty when both halves have the rule.
                        if (entry.source.isNotEmpty)
                          TextSpan(
                            text: '  (${entry.source})',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                              color: scheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Per-model statlines. Divergent profiles inside one attached unit are normal
/// — a Commander at M8 W6 Sv2+ leading Crisis suits at M10 W4 Sv3+ (§7.3.6) —
/// so every distinct profile gets a row.
class _StatBlock extends StatelessWidget {
  final CombatUnit unit;

  const _StatBlock({required this.unit});

  static const _columns = ['M', 'T', 'SV', 'INV', 'W', 'LD', 'OC'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    List<String?> values(ModelProfile p) =>
        [p.m, p.t, p.sv, p.invulnSv, p.w, p.ld, p.oc];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DataTable(
        headingRowHeight: 26,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 32,
        horizontalMargin: 0,
        columnSpacing: 16,
        columns: [
          const DataColumn(label: Text('MODEL', style: _head)),
          for (final column in _columns)
            DataColumn(label: Text(column, style: _head)),
        ],
        rows: [
          for (final entry in unit.profiles)
            DataRow(cells: [
              DataCell(Text(entry.name,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600))),
              for (final value in values(entry.profile))
                DataCell(Text(
                  _format(value),
                  style: AppTheme.numeric(context, size: 12.5),
                )),
            ]),
        ],
      ),
    ).withFallback(context, unit, scheme);
  }

  static String _format(String? value) {
    if (value == null || value.isEmpty) return '—';
    return value;
  }

  static const _head = TextStyle(
      fontSize: 9, letterSpacing: 0.6, fontWeight: FontWeight.w700);
}

extension _StatBlockFallback on Widget {
  /// Guards against a snapshot that carried no profiles for a unit.
  Widget withFallback(BuildContext context, CombatUnit unit, ColorScheme s) =>
      unit.profiles.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text('No model profile in this snapshot',
                  style: TextStyle(fontSize: 12, color: s.error)),
            )
          : this;
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            )),
      );
}

class _Subheader extends StatelessWidget {
  final String label;

  const _Subheader(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
        child: Text(label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
      );
}

class _Note extends StatelessWidget {
  final String text;

  const _Note(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}
