import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../data/army.dart';
import '../widgets/collapsible.dart';
import '../widgets/unit_profiles.dart';
import '../widgets/weapon_table.dart';

/// Combat units by role, in the order [SourceUnit.roleOrder] gives.
Map<String, List<CombatUnit>> _byRole(Army army) {
  final out = <String, List<CombatUnit>>{};
  for (final unit in army.combatUnits) {
    (out[unit.battlefieldRole] ??= []).add(unit);
  }
  return out;
}

/// Roster overview: points, validation, and a card per combat unit.
///
/// Validation findings are shown with severity and **never block** (§2.3) —
/// people build illegal lists on purpose. Informational findings such as
/// unspent Detachment Points are surfaced too, because they are the ones that
/// change a list.
class ArmyScreen extends StatelessWidget {
  final Army army;

  /// Opens the builder. Null on surfaces where editing makes no sense.
  final VoidCallback? onEdit;

  const ArmyScreen({super.key, required this.army, this.onEdit});

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
              Row(
                children: [
                  Expanded(
                    child: Text(roster.name,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800)),
                  ),
                  if (onEdit != null)
                    IconButton(
                      tooltip: 'Edit army',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                ],
              ),
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
        // Same roles and the same order as the builder, so an army reads the
        // same way wherever you are looking at it.
        for (final role in SourceUnit.roleOrder)
          if (_byRole(army)[role] case final inRole?)
            CollapsibleGroup(
              title: role.toUpperCase(),
              trailing: '${inRole.length}',
              initiallyOpen: true,
              child: Column(
                children: [
                  for (final unit in inRole) _UnitCard(unit: unit),
                ],
              ),
            ),
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
              UnitStatline(profiles: unit.profiles),
              const _Subheader('Ranged'),
              WeaponTable(result: unit.weapons(WeaponKind.ranged)),
              const _Subheader('Melee'),
              WeaponTable(result: unit.weapons(WeaponKind.melee)),
              // Keywords first, as a row of chips. A rule whose description
              // only repeats its name — DEEP STRIKE, FIGHTS FIRST, LEADER —
              // is a keyword whose meaning lives in the rulebook, and given a
              // name-and-description line apiece they read as rules the app
              // failed to explain while costing two lines each.
              if (unit.attributedRules.any((e) => e.rule.isBareKeyword)) ...[
                const _Subheader('Keywords'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      for (final entry in unit.attributedRules)
                        if (entry.rule.isBareKeyword)
                          _KeywordChip(
                            label: entry.rule.name,
                            source: entry.source,
                          ),
                    ],
                  ),
                ),
              ],
              if (unit.attributedRules.any((e) => !e.rule.isBareKeyword))
                const _Subheader('Abilities'),
              for (final entry in unit.attributedRules)
                if (!entry.rule.isBareKeyword)
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
                        // Emphasis rendered rather than printed: the rule
                        // arrives with its keywords marked (§3.10).
                        for (final span in ruleSpans(entry.rule.text))
                          TextSpan(
                            text: span.text,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurfaceVariant,
                              fontWeight:
                                  span.bold ? FontWeight.w700 : null,
                              fontStyle:
                                  span.italic ? FontStyle.italic : null,
                            ),
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

/// A core keyword, shown as itself.
class _KeywordChip extends StatelessWidget {
  final String label;

  /// Which half of an attached unit has it, when only one does.
  final String source;

  const _KeywordChip({required this.label, required this.source});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        source.isEmpty ? label.toUpperCase() : '${label.toUpperCase()} ($source)',
        style: TextStyle(
          fontSize: 9.5,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
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
