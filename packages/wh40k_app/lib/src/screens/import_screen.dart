import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart' as core;

import '../data/army.dart';
import '../data/dataset_repository.dart';

/// Paste a text export, review what the importer made of it, then save.
///
/// **Nothing imports silently** (DESIGN.md §6.5). Every run lands on this
/// review step showing what matched, what was assumed and what could not be
/// placed, because an importer that quietly drops a unit is worse than one
/// that refuses.
class ImportScreen extends StatefulWidget {
  final DatasetRepository datasets;

  /// Forces a faction instead of reading the one the export names. Only the
  /// tests pass it; the screen detects and offers a correction.
  final String? factionId;

  const ImportScreen({
    super.key,
    required this.datasets,
    this.factionId,
  });

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _controller = TextEditingController();
  core.ImportResult? _result;
  Army? _army;
  String? _failure;
  var _busy = false;

  List<core.BundleEntry> _factions = const [];

  /// Null means *read it from the list*, which is the default and is right
  /// almost every time — the export carries its own faction line.
  late String? _chosen = widget.factionId;

  /// The faction the last run actually used, so the summary can say which one
  /// the numbers came from rather than leaving it inferred.
  String? _usedFactionId;

  @override
  void initState() {
    super.initState();
    _loadFactions();
  }

  Future<void> _loadFactions() async {
    try {
      final factions = await widget.datasets.availableFactions();
      if (mounted) setState(() => _factions = factions);
    } catch (error) {
      if (mounted) setState(() => _failure = '$error');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _nameOf(String id) =>
      _factions.where((f) => f.id == id).map((f) => f.name).firstOrNull ?? id;

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      // Parsing needs no catalogue, so the faction line is read before a
      // dataset is chosen rather than after one has been assumed.
      final parsed = const core.TextListParser().parse(_controller.text);
      final factionId = _chosen ??
          core.matchFactionId(parsed.factionName, [
            for (final f in _factions)
              core.FactionCandidate(id: f.id, name: f.name, aliases: f.aliases),
          ]);

      if (factionId == null) {
        setState(() {
          _busy = false;
          _failure = parsed.factionName == null
              ? 'This list does not name a faction. Pick one above and '
                  'import again.'
              : 'No bundled faction matches “${parsed.factionName}”. Pick one '
                  'above and import again.';
        });
        return;
      }

      final dataset = await widget.datasets.faction(factionId);
      final result = core.RosterResolver(
        dataset,
        abilityLookup: dataset.ability,
        knownAbilities: dataset.faction.abilities,
      ).resolve(parsed, factionId: factionId);

      // The saved roster carries its own snapshot, so it stays renderable once
      // the bundled dataset changes or goes away (§2.2).
      //
      // Built from the shared builder rather than hand-assembled here: this
      // once omitted stratagems and enhancements, so an imported list came
      // back from storage with an empty stratagem section and priced lower
      // than it had at import.
      final builder = await widget.datasets.snapshotBuilder(factionId);
      final snapshot = builder.build(result.roster);

      setState(() {
        _result = result;
        _usedFactionId = factionId;
        _army = Army.fromSnapshot(result.roster, snapshot,
            id: DateTime.now().microsecondsSinceEpoch.toString());
      });
    } catch (error) {
      setState(() => _failure = '$error');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final result = _result;
    final army = _army;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import list'),
        actions: [
          if (army != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(army),
              child: const Text('SAVE'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Paste a text export from War Organ or the Warhammer app. '
            'All ${_factions.length} factions are bundled.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _chosen,
            isDense: true,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Faction',
              isDense: true,
              border: OutlineInputBorder(),
              helperText: 'The list names its own; override only if it is '
                  'wrong',
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Read it from the list'),
              ),
              for (final faction in _factions)
                DropdownMenuItem(
                  value: faction.id,
                  child: Text(faction.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) => setState(() => _chosen = id),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 10,
            minLines: 6,
            // Monospace, because a pasted list is columns — and named twice
            // because the two platforms ship different ones.
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Menlo',
              fontFamilyFallback: ['monospace'],
            ),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Paste here…',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _run,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow),
            label: const Text('Import'),
          ),
          if (_failure != null) ...[
            const SizedBox(height: 16),
            Text(_failure!, style: TextStyle(color: scheme.error)),
          ],
          if (result != null && army != null) ...[
            const SizedBox(height: 20),
            if (_usedFactionId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Resolved against ${_nameOf(_usedFactionId!)}',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            _Summary(army: army, result: result),
            const SizedBox(height: 12),
            for (final issue in result.issues) _IssueTile(issue: issue),
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final Army army;
  final core.ImportResult result;

  const _Summary({required this.army, required this.result});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final printed = result.printedPoints;
    final agrees = printed == null || printed == army.points;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(army.roster.name,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              '${army.combatUnits.length} units · '
              '${army.roster.units.length} entries · '
              '${army.roster.links.length} attachments',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(agrees ? Icons.check_circle : Icons.warning_amber,
                    size: 16, color: agrees ? scheme.tertiary : scheme.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    agrees
                        ? '${army.points} points — matches the printed total'
                        : '${army.points} points computed, but the source '
                            'printed $printed',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: agrees ? scheme.onSurface : scheme.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueTile extends StatelessWidget {
  final core.ResolutionIssue issue;

  const _IssueTile({required this.issue});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, colour) = switch (issue.severity) {
      core.IssueSeverity.error => (Icons.error_outline, scheme.error),
      core.IssueSeverity.warning => (
          Icons.warning_amber_outlined,
          scheme.tertiary
        ),
      core.IssueSeverity.info => (Icons.info_outline, scheme.onSurfaceVariant),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: colour),
          const SizedBox(width: 8),
          Expanded(
            child: Text(issue.message, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
