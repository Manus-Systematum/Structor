import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../data/army.dart';
import '../data/dataset_repository.dart';
import '../data/roster_store.dart';
import '../theme.dart';
import '../widgets/unit_editor.dart';

/// The army builder (DESIGN.md §4, the brief's first item).
///
/// **Permissive, with honest validation.** Every edit is allowed and the
/// findings panel says what is wrong — §2.3 settled that for validation, and
/// the wargear-option data is too incomplete to enforce (§3.8: six datasheets
/// did not list the drones their units carry). A builder that refuses the army
/// standing on your table is worthless.
///
/// Editing works against the **faction dataset**, unlike every play surface,
/// which reads a snapshot. Saving re-snapshots, so the saved list stops moving
/// when the dataset next updates.
class EditorScreen extends StatefulWidget {
  final RosterStore store;
  final DatasetRepository datasets;

  /// The roster being edited, or null to start a new one.
  final Roster? initial;
  final String? rosterId;

  const EditorScreen({
    super.key,
    required this.store,
    required this.datasets,
    this.initial,
    this.rosterId,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  Dataset? _dataset;
  List<BundleEntry> _factions = const [];
  late Roster _roster = widget.initial ??
      RosterEditor.blank(name: 'New army', factionId: '');
  String? _error;
  bool _saving = false;
  bool _dirty = false;

  /// Prior states, newest last. Building is fiddly and undo costs one list.
  final _history = <Roster>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final factions = await widget.datasets.availableFactions();
      final factionId =
          _roster.factionId.isNotEmpty ? _roster.factionId : factions.first.id;
      final dataset = await widget.datasets.faction(factionId);
      if (!mounted) return;
      setState(() {
        _factions = factions;
        _dataset = dataset;
        if (_roster.factionId.isEmpty) {
          _roster = _roster.copyWith(factionId: factionId);
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  /// Switching faction throws away the detachments, which belong to the one
  /// being left. Units are why this is only offered on an empty roster.
  Future<void> _setFaction(String factionId) async {
    if (factionId == _roster.factionId) return;
    setState(() {
      _history.add(_roster);
      _roster = _roster.copyWith(
        factionId: factionId,
        detachments: const [],
        enhancements: const [],
        upgrades: const [],
      );
      _dirty = true;
      _dataset = null;
    });
    final dataset = await widget.datasets.faction(factionId);
    if (mounted) setState(() => _dataset = dataset);
  }

  RosterEditor get _editor => RosterEditor(_dataset!);

  void _edit(Roster Function(RosterEditor) change) {
    setState(() {
      _history.add(_roster);
      _roster = change(_editor);
      _dirty = true;
    });
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      _roster = _history.removeLast();
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final dataset = _dataset;
    if (dataset == null) return;
    setState(() => _saving = true);
    try {
      final builder =
          await widget.datasets.snapshotBuilder(_roster.factionId);
      final army = Army.fromSnapshot(
        _roster,
        builder.build(_roster),
        id: widget.rosterId ??
            'r${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      );
      await widget.store.save(army);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataset = _dataset;
    final error = _error;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.initial == null ? 'New army' : 'Edit army'),
          actions: [
            IconButton(
              tooltip: 'Undo',
              onPressed: _history.isEmpty ? null : _undo,
              icon: const Icon(Icons.undo),
            ),
            TextButton(
              onPressed: dataset == null || _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
        floatingActionButton: dataset == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _addUnit,
                icon: const Icon(Icons.add),
                label: const Text('Add unit'),
              ),
        body: SafeArea(
          child: error != null
              ? _Note(text: error, isError: true)
              : dataset == null
                  ? const Center(child: CircularProgressIndicator())
                  : _body(dataset),
        ),
      ),
    );
  }

  Widget _body(Dataset dataset) {
    final validation = RosterValidator(dataset).validate(_roster);
    final cost = PointsCalculator(dataset).price(_roster);
    final size = BattleSize.byId(_roster.battleSizeId);

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _Header(
          roster: _roster,
          total: cost.total,
          limit: _roster.pointsLimitOverride ?? size?.points,
          factions: _factions,
          onName: (name) => _edit((e) => e.setName(_roster, name)),
          onSize: (next) => _edit((e) => e.setBattleSize(_roster, next)),
          onFaction: _setFaction,
        ),
        _Findings(validation: validation),
        _DetachmentPicker(
          roster: _roster,
          dataset: dataset,
          onAdd: (id) => _edit((e) => e.addDetachment(_roster, id)),
          onRemove: (id) => _edit((e) => e.removeDetachment(_roster, id)),
        ),
        const _SectionHeader('UNITS'),
        if (_roster.units.isEmpty)
          const _Note(text: 'No units yet. Add one to get started.')
        else
          for (final group in _roster.combatUnits())
            _UnitRow(
              group: group,
              dataset: dataset,
              roster: _roster,
              cost: cost,
              onTap: () => _editUnit(group.first.instanceId),
            ),
      ],
    );
  }

  Future<void> _addUnit() async {
    final dataset = _dataset;
    if (dataset == null) return;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => AddUnitSheet(dataset: dataset),
    );
    if (chosen != null) _edit((e) => e.addUnit(_roster, chosen));
  }

  Future<void> _editUnit(String instanceId) async {
    final dataset = _dataset;
    if (dataset == null) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => UnitEditorSheet(
        dataset: dataset,
        roster: _roster,
        instanceId: instanceId,
        onEdit: (change) {
          _edit(change);
          // The sheet reads the roster it was given, so it is rebuilt from the
          // new one rather than left showing stale counts.
          Navigator.of(context).pop();
          _editUnit(instanceId);
        },
        onRemove: () {
          _edit((e) => e.removeUnit(_roster, instanceId));
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('This army has unsaved changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }
}

class _Header extends StatelessWidget {
  final Roster roster;
  final int total;
  final int? limit;
  final List<BundleEntry> factions;
  final void Function(String) onName;
  final void Function(BattleSize) onSize;
  final void Function(String) onFaction;

  const _Header({
    required this.roster,
    required this.total,
    required this.limit,
    required this.factions,
    required this.onName,
    required this.onSize,
    required this.onFaction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final over = limit != null && total > limit!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            initialValue: roster.name,
            decoration: const InputDecoration(
              labelText: 'Army name',
              isDense: true,
            ),
            onFieldSubmitted: onName,
            onChanged: onName,
          ),
          const SizedBox(height: 10),
          // A unit belongs to its faction, so the choice is only offered while
          // the roster is empty — silently rewriting a built list would be
          // worse than refusing.
          DropdownButtonFormField<String>(
            initialValue:
                factions.any((f) => f.id == roster.factionId)
                    ? roster.factionId
                    : null,
            isDense: true,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Faction',
              isDense: true,
              helperText: roster.units.isEmpty
                  ? null
                  : 'Remove every unit to change faction',
            ),
            items: [
              for (final faction in factions)
                DropdownMenuItem(
                  value: faction.id,
                  child: Text(faction.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: roster.units.isEmpty
                ? (id) {
                    if (id != null) onFaction(id);
                  }
                : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: BattleSize.byId(roster.battleSizeId)?.id,
                  isDense: true,
                  // Without this the longest item sizes the field and pushes
                  // the points column off the screen.
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Battle size',
                    isDense: true,
                  ),
                  items: [
                    for (final size in BattleSize.all)
                      DropdownMenuItem(
                        value: size.id,
                        child: Text('${size.name} · ${size.points} pts',
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (id) {
                    final size = BattleSize.byId(id ?? '');
                    if (size != null) onSize(size);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    limit == null ? '$total' : '$total / $limit',
                    style: AppTheme.numeric(context, size: 20).copyWith(
                      fontWeight: FontWeight.w800,
                      color: over ? scheme.error : scheme.primary,
                    ),
                  ),
                  Text('POINTS',
                      style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The validator's findings, live. Never a gate — §2.3.
class _Findings extends StatelessWidget {
  final ValidationResult validation;

  const _Findings({required this.validation});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (validation.findings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, size: 15, color: scheme.primary),
            const SizedBox(width: 6),
            Text('Legal for this battle size',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final finding in validation.findings)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    switch (finding.severity) {
                      Severity.error => Icons.error_outline,
                      Severity.warning => Icons.warning_amber_outlined,
                      Severity.info => Icons.info_outline,
                    },
                    size: 14,
                    color: switch (finding.severity) {
                      Severity.error => scheme.error,
                      Severity.warning => scheme.tertiary,
                      Severity.info => scheme.onSurfaceVariant,
                    },
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(finding.message,
                        style: TextStyle(
                            fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetachmentPicker extends StatelessWidget {
  final Roster roster;
  final Dataset dataset;
  final void Function(String) onAdd;
  final void Function(String) onRemove;

  const _DetachmentPicker({
    required this.roster,
    required this.dataset,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final taken = {for (final d in roster.detachments) d.detachmentId};
    final all = dataset.allDetachments.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader('DETACHMENTS'),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final detachment in all)
                FilterChip(
                  visualDensity: VisualDensity.compact,
                  selected: taken.contains(detachment.id),
                  label: Text(
                    '${detachment.name} · ${detachment.detachmentPoints} DP',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  onSelected: (on) =>
                      on ? onAdd(detachment.id) : onRemove(detachment.id),
                ),
            ],
          ),
        ),
        if (taken.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Text(
              'A detachment brings the stratagems, enhancements and force '
              'disposition the rest of the app reads.',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _UnitRow extends StatelessWidget {
  final List<RosterUnit> group;
  final Dataset dataset;
  final Roster roster;
  final RosterCost cost;
  final VoidCallback onTap;

  const _UnitRow({
    required this.group,
    required this.dataset,
    required this.roster,
    required this.cost,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final points = cost.units
        .where((c) => group.any((u) => u.instanceId == c.instanceId))
        .fold(0, (sum, c) => sum + c.total);
    final isWarlord =
        group.any((u) => u.instanceId == roster.warlordInstanceId);
    final enhancement = roster.enhancements
        .where((e) => group.any((u) => u.instanceId == e.targetInstanceId))
        .map((e) => dataset.enhancements
            .where((x) => x.id == e.enhancementId)
            .map((x) => x.name)
            .firstOrNull)
        .whereType<String>()
        .toList();

    return ListTile(
      dense: true,
      onTap: onTap,
      title: Text(dataset.labelFor(group),
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
      subtitle: Text(
        [
          '${group.fold(0, (s, u) => s + u.models)} models',
          if (isWarlord) 'Warlord',
          ...enhancement,
        ].join(' · '),
        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      ),
      trailing: Text('$points',
          style: AppTheme.numeric(context, size: 14)
              .copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surfaceContainer,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Text(label,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            )),
      );
}

class _Note extends StatelessWidget {
  final String text;
  final bool isError;

  const _Note({required this.text, this.isError = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(text,
          style: TextStyle(
              fontSize: 12.5,
              color: isError ? scheme.error : scheme.onSurfaceVariant)),
    );
  }
}

/// The datasheet picker. Searchable, because a faction is fifty datasheets and
/// scrolling to Broadside past forty Kroot entries is not a design.
class AddUnitSheet extends StatefulWidget {
  final Dataset dataset;

  const AddUnitSheet({super.key, required this.dataset});

  @override
  State<AddUnitSheet> createState() => _AddUnitSheetState();
}

class _AddUnitSheetState extends State<AddUnitSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final needle = _query.trim().toLowerCase();
    final units = widget.dataset.allUnits
        .where((u) => needle.isEmpty || u.name.toLowerCase().contains(needle))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SearchBar(
                hintText: 'Search datasheets',
                leading: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.search, size: 20),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: units.length,
                itemBuilder: (context, index) {
                  final unit = units[index];
                  final cheapest = unit.points
                      .map((b) => b.cost)
                      .fold<int?>(null, (a, b) => a == null || b < a ? b : a);
                  return ListTile(
                    dense: true,
                    title: Text(unit.name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      [
                        if (unit.isCharacter) 'Character',
                        if (unit.isLeader) 'Leader',
                        ...unit.keywords.take(2),
                      ].join(' · '),
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                    trailing: Text(cheapest == null ? '—' : 'from $cheapest',
                        style: TextStyle(
                            fontSize: 11.5, color: scheme.onSurfaceVariant)),
                    onTap: () => Navigator.of(context).pop(unit.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
