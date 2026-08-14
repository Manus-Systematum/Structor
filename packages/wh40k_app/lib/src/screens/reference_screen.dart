import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../data/army.dart';

/// The reference page (DESIGN.md §7.3, §7.3.8).
///
/// The page you open when the inline row is not enough. Its job is **recall**,
/// so search comes first and runs across everything at once — mid-game you
/// remember a word, not whether it was a detachment rule, an ability, an
/// enhancement or a stratagem.
class ReferenceScreen extends StatefulWidget {
  final Army army;

  const ReferenceScreen({super.key, required this.army});

  @override
  State<ReferenceScreen> createState() => _ReferenceScreenState();
}

class _ReferenceScreenState extends State<ReferenceScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static const _sections = [
    (ReferenceKind.detachmentRule, 'DETACHMENT RULES'),
    (ReferenceKind.enhancement, 'ENHANCEMENTS & UPGRADES'),
    (ReferenceKind.unitAbility, 'UNIT ABILITIES'),
    (ReferenceKind.stratagem, 'STRATAGEMS'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final matches = widget.army.reference.search(_query);
    final searching = _query.trim().isNotEmpty;

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
          child: matches.isEmpty
              ? _Empty(searching: searching)
              : ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    for (final (kind, label) in _sections)
                      ..._section(context, label, [
                        for (final e in matches)
                          if (e.kind == kind) e,
                      ]),
                    _Provenance(army: widget.army),
                  ],
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

  List<Widget> _section(
    BuildContext context,
    String label,
    List<ReferenceEntry> entries,
  ) {
    if (entries.isEmpty) return const [];
    final scheme = Theme.of(context).colorScheme;
    return [
      Container(
        color: scheme.surfaceContainer,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Text('$label  ·  ${entries.length}',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            )),
      ),
      for (final entry in entries) _EntryTile(entry: entry),
    ];
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

  /// Upstream shouts some names and not others; a list that shouts at random
  /// reads as a bug.
  static String _titleCase(String name) {
    if (name != name.toUpperCase()) return name;
    return name
        .split(' ')
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
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
