import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../widgets/rule_text.dart';

import '../data/army.dart';
import '../widgets/deployment_diagram.dart';
import '../widgets/sheet_header.dart';

/// Pre-game setup (DESIGN.md §7.3.1).
///
/// **A decision aid, not a form.** Taking two detachments buys a *choice* of
/// primary mission, made after seeing what the opponent declares — and until
/// now nothing could show that, because it needs the matchup table as data.
///
/// Two rules the screen obeys. Every question is answered before the battle
/// screen opens, so play mode can assume a fully specified game. And the
/// matrix is rendered, never recommended: the app knows neither the matchup,
/// the terrain, nor how this player plays.
class SetupScreen extends StatefulWidget {
  final Army army;
  final MissionPack pack;

  /// Fetches the official layout picture on demand (§3.17). Null in tests
  /// and wherever the pictures are not wanted; the button is then absent.
  final Future<List<int>?> Function(String id)? officialLayout;

  const SetupScreen({
    super.key,
    required this.army,
    required this.pack,
    this.officialLayout,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String? _opponentDisposition;
  String? _myDisposition;
  String? _deploymentId;
  final _twist = TextEditingController();
  final _opponentName = TextEditingController();
  var _iAmAttacker = true;
  var _iGoFirst = true;
  var _mode = SecondaryMode.tactical;
  var _showFullGrid = false;

  /// The published table, once one is chosen. Choosing one also fixes the
  /// deployment pattern, because the layout names it.
  String? _layoutId;

  @override
  void dispose() {
    _twist.dispose();
    _opponentName.dispose();
    super.dispose();
  }

  List<ForceDisposition> get _mine =>
      widget.pack.availableTo(widget.army.roster.detachments
          .map((d) => widget.army.catalogue.detachment(d.detachmentId))
          .whereType<SourceDetachment>());

  DeploymentPattern? get _deployment =>
      widget.pack.deployment(_deploymentId ?? '');

  /// The tables published for this matchup. Empty until both dispositions are
  /// declared, since a layout is keyed by the pairing.
  List<TerrainLayout> get _layouts {
    final mine = _myDisposition;
    final theirs = _opponentDisposition;
    if (mine == null || theirs == null) return const [];
    return widget.pack
        .layoutsFor(disposition: mine, opponentDisposition: theirs);
  }

  TerrainLayout? get _layout {
    for (final layout in _layouts) {
      if (layout.id == _layoutId) return layout;
    }
    return null;
  }

  /// The table, full width and with the tape measure on.
  ///
  /// **The picture turns, the phone does not.** A 60×44 table drawn upright
  /// here fills 44% of the height it is given; turned a quarter it fills 82%,
  /// which is the difference between reading a shape and reading a position.
  /// Going to landscape instead was measured and is worse than either — the
  /// app bar and this caption live on the short dimension (§7.3.1).
  void _showFullScreen(DeploymentPattern pattern) {
    final layout = _layout;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(layout?.name ?? pattern.name),
            actions: [
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DeploymentDiagram(
                    pattern: pattern,
                    iAmAttacker: _iAmAttacker,
                    layout: layout,
                    templates: widget.pack.terrainTemplates,
                    measured: true,
                    // Turned and pinchable only here. The inline diagram is a
                    // picture of the shape, sitting in a form that scrolls;
                    // this is the one you set the table out from.
                    turned: true,
                    zoomable: true,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'The long edge runs down the screen. Pinch to zoom — the '
                    'numbers stay their own size, so crowded ones come apart. '
                    'Grid every 3″, numbered every 6″. Each piece is measured '
                    'to its two nearest edges — the tape pull you would '
                    'actually make, from wherever you are standing.',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Picking a table also sets the deployment, because the layout is built on
  /// one — offering them as separate questions would let the two disagree.
  /// The Warhammer Event Companion's own picture of this matchup (§3.17).
  ///
  /// Offered beside the app's drawing rather than replacing it: the geometry
  /// is not extractable — the battlefield art is raster and a feature's
  /// rotation appears nowhere on the page — so the page itself is the only
  /// honest reference for what the official layout actually is.
  Future<void> _showOfficialLayout(BuildContext context) async {
    final matchup = '${_myDisposition!}-vs-${_opponentDisposition!}';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _OfficialLayouts(
        matchup: matchup,
        fetch: widget.officialLayout!,
      ),
    );
  }

  void _pickLayout(TerrainLayout? layout) {
    setState(() {
      _layoutId = layout?.id;
      if (layout != null) _deploymentId = layout.deploymentPatternId;
    });
  }

  bool get _complete =>
      _opponentDisposition != null &&
      _myDisposition != null &&
      _deploymentId != null;

  MissionSetup? _build() {
    final mine = _myDisposition;
    final theirs = _opponentDisposition;
    if (mine == null || theirs == null) return null;

    // Both missions, because the table is asymmetric and the opponent plays a
    // different primary (§7.3.1).
    final myMission =
        widget.pack.missionFor(disposition: mine, opponentDisposition: theirs);
    final theirMission =
        widget.pack.missionFor(disposition: theirs, opponentDisposition: mine);

    return MissionSetup(
      myDisposition: mine,
      opponentDisposition: theirs,
      myMissionId: myMission?.id ?? '',
      opponentMissionId: theirMission?.id ?? '',
      deploymentId: _deploymentId,
      terrainLayoutId: _layoutId,
      twist: _twist.text.trim().isEmpty ? null : _twist.text.trim(),
      iAmAttacker: _iAmAttacker,
      iGoFirst: _iGoFirst,
      secondaryMode: _mode,
      opponentName:
          _opponentName.text.trim().isEmpty ? null : _opponentName.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = _mine;

    return Scaffold(
      appBar: AppBar(title: const Text('Set up battle')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed:
                _complete ? () => Navigator.of(context).pop(_build()) : null,
            child:
                Text(_complete ? 'Start battle' : 'Answer the questions above'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Step(
            number: 1,
            title: 'Your opponent',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _opponentName,
                  decoration: const InputDecoration(
                    labelText: 'Name (optional)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Their Force Disposition',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final d in widget.pack.allDispositions)
                      ChoiceChip(
                        label: Text(d.name),
                        selected: _opponentDisposition == d.id,
                        onSelected: (_) =>
                            setState(() => _opponentDisposition = d.id),
                      ),
                  ],
                ),
              ],
            ),
          ),
          _Step(
            number: 2,
            title: 'Your declaration',
            subtitle: mine.length > 1
                ? 'Two detachments means a choice — and it decides which '
                    'mission you play.'
                : 'Your detachments offer one disposition.',
            child: _opponentDisposition == null
                ? Text('Pick your opponent’s disposition first.',
                    style: TextStyle(
                        fontSize: 12.5, color: scheme.onSurfaceVariant))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final d in mine)
                        _DispositionOption(
                          disposition: d,
                          selected: _myDisposition == d.id,
                          outcome: widget.pack.outcomeFor(
                            disposition: d.id,
                            opponentDisposition: _opponentDisposition!,
                          ),
                          onTap: () => setState(() => _myDisposition = d.id),
                        ),
                      if (_myDisposition != null) ...[
                        const SizedBox(height: 10),
                        _TheirMission(
                          pack: widget.pack,
                          mine: _myDisposition!,
                          theirs: _opponentDisposition!,
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _showFullGrid = !_showFullGrid),
                        icon: Icon(
                            _showFullGrid ? Icons.expand_less : Icons.grid_on),
                        label: Text(_showFullGrid
                            ? 'Hide the full grid'
                            : 'Show every matchup'),
                      ),
                      if (_showFullGrid)
                        _FullGrid(pack: widget.pack, mine: mine),
                    ],
                  ),
          ),
          _Step(
            number: 3,
            title: 'The table',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_layouts.isNotEmpty) ...[
                  Text('Published table for this matchup',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('None'),
                        selected: _layoutId == null,
                        onSelected: (_) => _pickLayout(null),
                      ),
                      for (final layout in _layouts)
                        ChoiceChip(
                          label: Text('${layout.sourceLabel} '
                              '${layout.variant}'),
                          selected: _layoutId == layout.id,
                          onSelected: (_) => _pickLayout(layout),
                        ),
                    ],
                  ),
                  if (widget.officialLayout != null &&
                      _myDisposition != null &&
                      _opponentDisposition != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => _showOfficialLayout(context),
                          icon: const Icon(Icons.map_outlined, size: 17),
                          label: const Text('Official layouts'),
                        ),
                      ),
                    ),
                  // The chips name the source; this says how current it is
                  // (§7.6, §3.15). The Warhammer Event Companion of 26 August
                  // 2026 lists 27 of the official 45 layouts as changed in
                  // that version, and the app has no way yet to tell which of
                  // its own match. Said once, where the layout is chosen,
                  // rather than under every drawing of it.
                  if (_layouts.any((l) => l.source == 'battlemaster-11e'))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'These are Battlemaster’s layouts. 27 of the official '
                        '45 changed on 26 August 2026 — check the Warhammer '
                        'Event Companion before an event.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                ],
                Text(
                  _layout == null
                      ? 'Deployment'
                      : 'Deployment · set by the table',
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final pattern in widget.pack.deployments)
                      ChoiceChip(
                        label: Text(pattern.name),
                        selected: _deploymentId == pattern.id,
                        // A chosen layout is built on one deployment, so the
                        // pattern stops being a free choice rather than being
                        // allowed to contradict the table on screen.
                        onSelected: _layout != null
                            ? null
                            : (_) => setState(() => _deploymentId = pattern.id),
                      ),
                  ],
                ),
                if (_deployment case final pattern?) ...[
                  const SizedBox(height: 12),
                  Text(pattern.description,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  // Tappable, because the inline picture is small enough to
                  // show the shape and too small to set a table out from.
                  GestureDetector(
                    onTap: () => _showFullScreen(pattern),
                    child: DeploymentDiagram(
                      pattern: pattern,
                      iAmAttacker: _iAmAttacker,
                      layout: _layout,
                      templates: widget.pack.terrainTemplates,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.straighten,
                            size: 13, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 5),
                        Text('Tap the table for measurements',
                            style: TextStyle(
                                fontSize: 11, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  // Named, not implied. These are community layouts, and the
                  // app must not pass them off as Games Workshop's own (§7.6).
                  if (_layout case final table?)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${table.name} — ${table.sourceLabel} layout, not a '
                        'Games Workshop publication.\n'
                        'The real parts are L-shaped; upstream publishes each '
                        'as a bounding box, so the tick marks which way the '
                        'piece is turned rather than where its walls run.',
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: _twist,
                  decoration: const InputDecoration(
                    labelText: 'Twist (optional)',
                    // There is no twist data upstream, so the player records
                    // what they drew rather than picking from a list that
                    // does not exist.
                    helperText: 'Free text — no twist data is published yet',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                _Choice(
                  label: 'You are',
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Attacker')),
                      ButtonSegment(value: false, label: Text('Defender')),
                    ],
                    selected: {_iAmAttacker},
                    onSelectionChanged: (v) =>
                        setState(() => _iAmAttacker = v.first),
                  ),
                ),
                const SizedBox(height: 12),
                // Not implied by attacker/defender, and the battle round only
                // advances on its own once the app knows who opens (§7.4).
                _Choice(
                  label: 'First turn',
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('You')),
                      ButtonSegment(value: false, label: Text('Opponent')),
                    ],
                    selected: {_iGoFirst},
                    onSelectionChanged: (v) =>
                        setState(() => _iGoFirst = v.first),
                  ),
                ),
                const SizedBox(height: 12),
                _Choice(
                  label: 'Secondaries',
                  child: SegmentedButton<SecondaryMode>(
                    segments: const [
                      ButtonSegment(
                          value: SecondaryMode.tactical,
                          label: Text('Tactical')),
                      ButtonSegment(
                          value: SecondaryMode.fixed, label: Text('Fixed')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (v) => setState(() => _mode = v.first),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DispositionOption extends StatelessWidget {
  final ForceDisposition disposition;
  final MissionOutcome outcome;
  final bool selected;
  final VoidCallback onTap;

  const _DispositionOption({
    required this.disposition,
    required this.outcome,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: selected ? scheme.primary : scheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Text(disposition.name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'You would play ${outcome.mission?.name ?? '—'}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? scheme.onPrimaryContainer : scheme.primary,
                ),
              ),
              if (outcome.card != null) ...[
                const SizedBox(height: 4),
                RuleText(outcome.card!.text,
                    style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: scheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// What the opponent is playing. Knowing how they score is how a player
/// decides what to contest (§7.3.3).
class _TheirMission extends StatelessWidget {
  final MissionPack pack;
  final String mine;
  final String theirs;

  const _TheirMission({
    required this.pack,
    required this.mine,
    required this.theirs,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final outcome =
        pack.outcomeFor(disposition: theirs, opponentDisposition: mine);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('THEY PLAY',
              style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 0.9,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(outcome.mission?.name ?? '—',
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          if (outcome.card != null) ...[
            const SizedBox(height: 4),
            RuleText(outcome.card!.text,
                style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class _FullGrid extends StatelessWidget {
  final MissionPack pack;
  final List<ForceDisposition> mine;

  const _FullGrid({required this.pack, required this.mine});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final opponents = pack.allDispositions;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 34,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 44,
        columnSpacing: 14,
        columns: [
          const DataColumn(label: Text('THEY DECLARE', style: _head)),
          for (final d in mine)
            DataColumn(label: Text(d.name.toUpperCase(), style: _head)),
        ],
        rows: [
          for (final theirs in opponents)
            DataRow(cells: [
              DataCell(Text(theirs.name,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant))),
              for (final ours in mine)
                DataCell(Text(
                  pack
                          .missionFor(
                              disposition: ours.id,
                              opponentDisposition: theirs.id)
                          ?.name ??
                      '—',
                  style: const TextStyle(fontSize: 12),
                )),
            ]),
        ],
      ),
    );
  }

  static const _head =
      TextStyle(fontSize: 9, letterSpacing: 0.7, fontWeight: FontWeight.w800);
}

/// A labelled row of segmented buttons. Three unlabelled toggles in a column
/// is a quiz with the questions removed.
class _Choice extends StatelessWidget {
  final String label;
  final Widget child;

  const _Choice({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          child,
        ],
      );
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String? subtitle;
  final Widget child;

  const _Step({
    required this.number,
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: scheme.primary,
                child: Text('$number',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimary)),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 2),
              child: Text(subtitle!,
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// The Warhammer Event Companion's three layouts for one matchup (§3.17).
///
/// A, B and C, as printed. The pictures are fetched rather than bundled —
/// forty-five of them is eleven megabytes against a six-megabyte data bundle
/// — so each one says what it is doing while it loads, and says plainly when
/// it cannot be fetched rather than showing an empty frame.
class _OfficialLayouts extends StatelessWidget {
  final String matchup;
  final Future<List<int>?> Function(String id) fetch;

  const _OfficialLayouts({required this.matchup, required this.fetch});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(title: 'Official layouts'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                children: [
                  for (final letter in ['a', 'b', 'c'])
                    _OneLayout(
                      label: 'Layout ${letter.toUpperCase()}',
                      image: fetch('$matchup-$letter'),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                    child: Text(
                      'From the Warhammer Event Companion. The app draws its '
                      'own layouts from Battlemaster\u2019s data; these are '
                      'the printed pages, for checking one against the other.',
                      style: TextStyle(
                          fontSize: 10.5, height: 1.35, color: scheme.outline),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OneLayout extends StatelessWidget {
  final String label;
  final Future<List<int>?> image;

  const _OneLayout({required this.label, required this.image});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 4),
          FutureBuilder<List<int>?>(
            future: image,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final bytes = snapshot.data;
              if (bytes == null) {
                return Text(
                  'Not downloaded. The layout pictures are fetched when the '
                  'dataset is served from the network, which is not set up '
                  'yet.',
                  style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: scheme.onSurfaceVariant),
                );
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(Uint8List.fromList(bytes)),
              );
            },
          ),
        ],
      ),
    );
  }
}
