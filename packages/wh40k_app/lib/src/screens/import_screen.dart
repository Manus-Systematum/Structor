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
  final String factionId;

  const ImportScreen({
    super.key,
    required this.datasets,
    this.factionId = 'tau-empire',
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final dataset = await widget.datasets.faction(widget.factionId);
      final parsed = const core.TextListParser().parse(_controller.text);
      final result = core.RosterResolver(
        dataset,
        abilityLookup: dataset.ability,
        knownAbilities: dataset.faction.abilities,
      ).resolve(parsed, factionId: widget.factionId);

      // The saved roster carries its own snapshot, so it stays renderable once
      // the bundled dataset changes or goes away (§2.2).
      final snapshot = core.SnapshotBuilder(
        dataset: dataset,
        rawUnits: _raw(dataset.faction.units, (u) => u.id),
        rawWeapons: _raw(dataset.faction.weapons, (w) => w.id),
        rawDetachments: _raw(dataset.faction.detachments, (d) => d.id),
        rawAbilities: _raw(dataset.faction.abilities, (a) => a.abilityId),
      ).build(result.roster);

      setState(() {
        _result = result;
        _army = Army.fromSnapshot(result.roster, snapshot,
            id: DateTime.now().microsecondsSinceEpoch.toString());
      });
    } catch (error) {
      setState(() => _failure = '$error');
    } finally {
      setState(() => _busy = false);
    }
  }

  /// The snapshot builder wants the original records. The bundled loader keeps
  /// parsed DTOs, so they are re-serialised here — acceptable because the
  /// bundle and the model are the same build.
  Map<String, Object?> _raw<T>(Iterable<T> items, String Function(T) idOf) => {
        for (final item in items) idOf(item): _toJson(item),
      };

  Object? _toJson(Object? item) => switch (item) {
        core.SourceUnit u => {
            'id': u.id,
            'name': u.name,
            'faction_id': u.factionId,
            'keywords': u.keywords,
            'ability_ids': u.abilityIds,
            'weapon_ids': u.weaponIds,
            'attachment_role': u.attachmentRole,
            'profiles': [
              for (final p in u.profiles)
                {
                  'name': p.name,
                  'M': p.m,
                  'T': p.t,
                  'W': p.w,
                  'Sv': p.sv,
                  'invuln_sv': p.invulnSv,
                  'Ld': p.ld,
                  'OC': p.oc,
                },
            ],
            'points': [
              for (final b in u.points)
                {
                  'models': b.models,
                  'models_max': b.modelsMax,
                  'cost': b.cost,
                  'unit_count_min': b.unitCountMin,
                  'unit_count_max': b.unitCountMax,
                },
            ],
            'wargear_costs': [
              for (final c in u.wargearCosts)
                {'item_id': c.itemId, 'cost': c.cost},
            ],
          },
        core.SourceWeapon w => {
            'id': w.id,
            'name': w.name,
            'type': w.type,
            'profiles': [
              for (final p in w.profiles)
                {
                  'name': p.name,
                  'range': p.range,
                  'stats': p.stats,
                  'keywords': [
                    for (final k in p.keywordIds) {'keyword_id': k},
                  ],
                },
            ],
          },
        core.SourceDetachment d => {
            'id': d.id,
            'name': d.name,
            'faction_id': d.factionId,
            'detachment_rule_id': d.detachmentRuleId,
            'detachment_points': d.detachmentPoints,
            'force_dispositions': d.forceDispositions,
            'unique_tags': d.uniqueTags,
            'stratagem_ids': d.stratagemIds,
            'enhancement_ids': d.enhancementIds,
          },
        core.SourceAbility a => {
            'ability_id': a.abilityId,
            'name': a.name,
            'ability_type': a.abilityType,
            'behavior': a.behavior,
            'effect': a.effect,
            'usage': a.usage,
            'unit_ids': a.unitIds,
          },
        _ => null,
      };

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
            'Only T’au Empire is bundled so far.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 10,
            minLines: 6,
            style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'),
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
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
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
      core.IssueSeverity.warning =>
        (Icons.warning_amber_outlined, scheme.tertiary),
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
            child: Text(issue.message,
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
