import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../data/army.dart';

/// The reference page (DESIGN.md §7.3, §7.3.8, §7.3.9).
///
/// Two readings of the same content, chosen by whether anything is being
/// searched for.
///
/// **Searching** is recall: one query across detachment rules, unit abilities,
/// enhancements and stratagems, because mid-game you remember a word and not
/// which of the four it lives in. That is the flat list this page has always
/// shown.
///
/// **Not searching** is orientation, and wants the opposite shape. A flat list
/// answers "who has this rule" for every rule, including the large majority
/// only one datasheet has — where the answer is the heading directly above.
/// So the resting state files rules by reach (§7.3.9): what the whole army
/// has, what several units share, and what belongs to one unit. The shared
/// tier is a grid because it is the only tier where both questions are live at
/// once — read a row for one unit's rules, read a column for one rule's units.
class ReferenceScreen extends StatefulWidget {
  final Army army;

  const ReferenceScreen({super.key, required this.army});

  @override
  State<ReferenceScreen> createState() => _ReferenceScreenState();
}

class _ReferenceScreenState extends State<ReferenceScreen> {
  final _search = TextEditingController();
  String _query = '';

  /// The row or column the player last touched, highlighted across the grid.
  ///
  /// A dot says *that* unit has *that* rule, but a lone dot in a wide grid is
  /// hard to trace back to either heading — so touching one lights its whole
  /// row and column and names the rule underneath (§7.3.9).
  String? _pinnedUnit;
  String? _pinnedRule;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _pin({String? unit, String? rule}) {
    setState(() {
      // Touching the same heading twice clears it, so the grid can be put back
      // to neutral without hunting for an X.
      _pinnedUnit = unit != null && unit == _pinnedUnit ? null : unit;
      _pinnedRule = rule != null && rule == _pinnedRule ? null : rule;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final searching = _query.trim().isNotEmpty;
    final matches = widget.army.reference.search(_query);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: SearchBar(
            controller: _search,
            hintText: 'Search rules, stratagems, enhancements',
            leading: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.search, size: 20),
            ),
            trailing: [
              if (searching)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
            ],
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: searching
              ? _SearchResults(matches: matches, army: widget.army)
              : _Tiers(
                  rules: widget.army.armyRules,
                  army: widget.army,
                  pinnedUnit: _pinnedUnit,
                  pinnedRule: _pinnedRule,
                  onPin: _pin,
                ),
        ),
        if (searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('${matches.length} matching',
                style:
                    TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- resting

class _Tiers extends StatelessWidget {
  final ArmyRules rules;
  final Army army;
  final String? pinnedUnit;
  final String? pinnedRule;
  final void Function({String? unit, String? rule}) onPin;

  const _Tiers({
    required this.rules,
    required this.army,
    required this.pinnedUnit,
    required this.pinnedRule,
    required this.onPin,
  });

  @override
  Widget build(BuildContext context) {
    if (rules.isEmpty) {
      return const _Empty(searching: false);
    }
    final names = {
      for (final unit in rules.units) unit.datasheetId: unit.name,
    };

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _SectionHeader(label: 'WHOLE ARMY', count: rules.armyWide.length),
        for (final entry in rules.armyWide) _ArmyRuleTile(entry: entry),
        if (rules.universalKeywords.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
            child: Text(
              'Every unit: ${rules.universalKeywords.join(', ')}',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.outline),
            ),
          ),
        if (rules.columns.isNotEmpty) ...[
          _SectionHeader(label: 'SHARED RULES', count: rules.columns.length),
          _FlagGrid(
            units: rules.units,
            columns: [
              for (final column in rules.columns)
                (id: column.abilityId, label: column.name),
            ],
            has: (unit, id) => unit.columnIds.contains(id),
            pinnedUnit: pinnedUnit,
            pinnedColumn: pinnedRule,
            onPin: onPin,
          ),
          _PinnedDetail(
            rules: rules,
            pinnedUnit: pinnedUnit,
            pinnedRule: pinnedRule,
            names: names,
          ),
        ],
        if (rules.keywordColumns.isNotEmpty) ...[
          _SectionHeader(
              label: 'KEYWORDS', count: rules.keywordColumns.length),
          _FlagGrid(
            units: rules.units,
            columns: [
              for (final keyword in rules.keywordColumns)
                (id: keyword, label: keyword),
            ],
            has: (unit, id) => unit.keywords.contains(id),
            pinnedUnit: pinnedUnit,
            pinnedColumn: null,
            onPin: ({String? unit, String? rule}) => onPin(unit: unit),
          ),
        ],
        const _SectionHeader(label: 'ONLY THIS UNIT', count: null),
        for (final unit in rules.units)
          if (unit.only.isNotEmpty)
            _UnitRules(unit: unit, highlighted: unit.datasheetId == pinnedUnit),
        _Provenance(army: army),
      ],
    );
  }
}

/// A units x flags table, scrollable sideways on its own.
///
/// How many columns there are is a property of the army, not of the phone —
/// a T'au battlesuit list shares twelve rules where a Space Marine one shares
/// six. Rather than cap the count and hide the overflow somewhere else, the
/// grid keeps every column and scrolls horizontally inside its own box, so the
/// page still scrolls vertically as one piece.
class _FlagGrid extends StatelessWidget {
  final List<UnitRules> units;
  final List<({String id, String label})> columns;
  final bool Function(UnitRules unit, String id) has;
  final String? pinnedUnit;
  final String? pinnedColumn;
  final void Function({String? unit, String? rule}) onPin;

  const _FlagGrid({
    required this.units,
    required this.columns,
    required this.has,
    required this.pinnedUnit,
    required this.pinnedColumn,
    required this.onPin,
  });

  static const _nameWidth = 132.0;
  static const _cellWidth = 30.0;
  static const _headerHeight = 92.0;
  static const _rowHeight = 26.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The names stay put: a row is unreadable once its label has scrolled
        // off the side.
        SizedBox(
          width: _nameWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: _headerHeight),
              for (final unit in units)
                _RowLabel(
                  unit: unit,
                  highlighted: unit.datasheetId == pinnedUnit,
                  onTap: () => onPin(unit: unit.datasheetId),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: _headerHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final column in columns)
                        _ColumnHeader(
                          label: column.label,
                          width: _cellWidth,
                          highlighted: column.id == pinnedColumn,
                          onTap: () => onPin(rule: column.id),
                        ),
                    ],
                  ),
                ),
                for (final unit in units)
                  SizedBox(
                    height: _rowHeight,
                    child: Row(
                      children: [
                        for (final column in columns)
                          SizedBox(
                            width: _cellWidth,
                            child: Center(
                              child: _Dot(
                                on: has(unit, column.id),
                                lit: unit.datasheetId == pinnedUnit ||
                                    column.id == pinnedColumn,
                                scheme: scheme,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RowLabel extends StatelessWidget {
  final UnitRules unit;
  final bool highlighted;
  final VoidCallback onTap;

  const _RowLabel({
    required this.unit,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: _FlagGrid._rowHeight,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 12, right: 6),
        color: highlighted ? scheme.surfaceContainerHighest : null,
        child: Row(
          children: [
            Flexible(
              child: Text(
                unit.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
            ),
            if (unit.count > 1)
              Text(' ×${unit.count}',
                  style: TextStyle(fontSize: 10, color: scheme.outline)),
          ],
        ),
      ),
    );
  }
}

/// A column heading, turned on its side so a rule name fits above a 30pt cell.
class _ColumnHeader extends StatelessWidget {
  final String label;
  final double width;
  final bool highlighted;
  final VoidCallback onTap;

  const _ColumnHeader({
    required this.label,
    required this.width,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: width,
        height: _FlagGrid._headerHeight,
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(bottom: 4),
        color: highlighted ? scheme.surfaceContainerHighest : null,
        child: RotatedBox(
          quarterTurns: 3,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              fontSize: 11,
              fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
              color: highlighted ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool on;
  final bool lit;
  final ColorScheme scheme;

  const _Dot({required this.on, required this.lit, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: on ? 9 : 5,
      height: on ? 9 : 5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on
            ? (lit ? scheme.primary : scheme.onSurfaceVariant)
            : scheme.outlineVariant,
      ),
    );
  }
}

/// What the pinned row or column means, spelled out under the grid.
class _PinnedDetail extends StatelessWidget {
  final ArmyRules rules;
  final String? pinnedUnit;
  final String? pinnedRule;
  final Map<String, String> names;

  const _PinnedDetail({
    required this.rules,
    required this.pinnedUnit,
    required this.pinnedRule,
    required this.names,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final column = pinnedRule == null
        ? null
        : rules.columns
            .where((c) => c.abilityId == pinnedRule)
            .firstOrNull;

    if (column == null && pinnedUnit == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Text('Tap a rule or a unit to trace it.',
            style: TextStyle(fontSize: 11, color: scheme.outline)),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (column != null) ...[
            Text(column.name,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface)),
            if (column.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(column.text,
                    style: TextStyle(
                        fontSize: 11.5, height: 1.35, color: scheme.onSurface)),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                column.owners.map((id) => names[id] ?? id).join(' · '),
                style: TextStyle(
                    fontSize: 10.5,
                    height: 1.3,
                    color: scheme.onSurfaceVariant),
              ),
            ),
          ],
          if (pinnedUnit != null)
            Padding(
              padding: EdgeInsets.only(top: column == null ? 0 : 8),
              child: Text(
                '${names[pinnedUnit] ?? pinnedUnit}: '
                '${_ruleNamesFor(pinnedUnit!)}',
                style: TextStyle(
                    fontSize: 11, height: 1.3, color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  String _ruleNamesFor(String datasheetId) {
    final shared = [
      for (final column in rules.columns)
        if (column.owners.contains(datasheetId)) column.name,
    ];
    return shared.isEmpty ? 'no shared rules' : shared.join(' · ');
  }
}

class _UnitRules extends StatelessWidget {
  final UnitRules unit;
  final bool highlighted;

  const _UnitRules({required this.unit, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: highlighted ? scheme.surfaceContainerHighest : null,
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  _titleCase(unit.name),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (unit.count > 1)
                Text(' ×${unit.count}',
                    style: TextStyle(fontSize: 11, color: scheme.outline)),
            ],
          ),
          for (final rule in unit.only)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                      fontSize: 11.5, height: 1.35, color: scheme.onSurface),
                  children: [
                    TextSpan(
                      text: rule.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (rule.phases.isNotEmpty)
                      TextSpan(
                        text: '  ${rule.phases.join(' · ')}',
                        style: TextStyle(
                            fontSize: 10, color: scheme.onSurfaceVariant),
                      ),
                    TextSpan(
                      text: ' — ${rule.text}',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArmyRuleTile extends StatelessWidget {
  final ReferenceEntry entry;

  const _ArmyRuleTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(_titleCase(entry.title),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface)),
              ),
              if (entry.source.isNotEmpty)
                Flexible(
                  child: Text('  ${entry.source}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.5, color: scheme.onSurfaceVariant)),
                ),
            ],
          ),
          if (entry.body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(entry.body,
                  style: TextStyle(
                      fontSize: 12, height: 1.35, color: scheme.onSurface)),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int? count;

  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainer,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      margin: const EdgeInsets.only(top: 8),
      child: Text(count == null ? label : '$label  ·  $count',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
            color: scheme.primary,
          )),
    );
  }
}

// ---------------------------------------------------------------- searching

class _SearchResults extends StatelessWidget {
  final List<ReferenceEntry> matches;
  final Army army;

  const _SearchResults({required this.matches, required this.army});

  static const _sections = [
    (ReferenceKind.detachmentRule, 'DETACHMENT RULES'),
    (ReferenceKind.enhancement, 'ENHANCEMENTS & UPGRADES'),
    (ReferenceKind.unitAbility, 'UNIT ABILITIES'),
    (ReferenceKind.stratagem, 'STRATAGEMS'),
  ];

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return const _Empty(searching: true);
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        for (final (kind, label) in _sections)
          if (matches.any((e) => e.kind == kind)) ...[
            _SectionHeader(
                label: label,
                count: matches.where((e) => e.kind == kind).length),
            for (final entry in matches)
              if (entry.kind == kind) _EntryTile(entry: entry),
          ],
        _Provenance(army: army),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  final ReferenceEntry entry;

  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // An enhancement the army did not buy is still worth listing — "what could
    // I have taken" is asked as often as "what did I take" — but it should not
    // read as though it were on the table.
    final dimmed = !entry.inPlay;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _titleCase(entry.title),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: dimmed
                  ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
                  : scheme.onSurface,
            ),
          ),
          // Source and detail share a wrapping line. An ability shared by five
          // datasheets names all five, which is a paragraph, not a suffix.
          if (entry.source.isNotEmpty || entry.detail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                [
                  if (entry.source.isNotEmpty) entry.source,
                  if (entry.detail.isNotEmpty) entry.detail,
                ].join('  ·  '),
                style: TextStyle(
                    fontSize: 10.5,
                    height: 1.3,
                    color: scheme.onSurfaceVariant),
              ),
            ),
          if (entry.body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(entry.body,
                  style: TextStyle(
                    fontSize: 12,
                    color: dimmed
                        ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
                        : scheme.onSurface,
                  )),
            ),
          if (entry.inPlay && entry.kind == ReferenceKind.enhancement)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('IN PLAY',
                  style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary)),
            ),
        ],
      ),
    );
  }
}

/// Upstream shouts some names and not others; a list that shouts at random
/// reads as a bug.
String _titleCase(String name) {
  if (name != name.toUpperCase()) return name;
  return name
      .split(' ')
      .map((w) => w.isEmpty
          ? w
          : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
}

class _Empty extends StatelessWidget {
  final bool searching;

  const _Empty({required this.searching});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          searching
              ? 'Nothing matches that.'
              : 'This roster carries no rules the dataset knows about.',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// What this page cannot tell you, said out loud (§7.6).
class _Provenance extends StatelessWidget {
  final Army army;

  const _Provenance({required this.army});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Every line above is generated from the structured dataset, not '
            'transcribed from a rulebook. Core rules — cover, Battle-shock, '
            'the keyword glossary — are not here: the dataset carries keyword '
            'names without their text, and writing that text out would be '
            'reproducing rules this app has no licence to.',
            style: TextStyle(
                fontSize: 11, height: 1.4, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text('Dataset ${army.snapshot.version}',
              style: TextStyle(fontSize: 10.5, color: scheme.outline)),
        ],
      ),
    );
  }
}
