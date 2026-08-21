import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../data/army.dart';
import '../data/dataset_repository.dart';
import '../data/roster_store.dart';
import '../theme.dart';
import '../widgets/collapsible.dart';
import '../widgets/rule_text.dart';
import '../widgets/source_pill.dart';
import '../widgets/sheet_header.dart';
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
  late Roster _roster =
      widget.initial ?? RosterEditor.blank(name: 'New army', factionId: '');
  String? _error;
  bool _saving = false;
  bool _dirty = false;

  /// The id this army is being written under. Fixed on the first autosave of
  /// a new army so every later one overwrites rather than piling up copies.
  late String? _id = widget.rosterId;

  Timer? _autosave;

  /// Prior states, newest last. Building is fiddly and undo costs one list.
  final _history = <Roster>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // Fire whatever is pending rather than dropping it: leaving the screen is
    // exactly the moment the debounce would otherwise lose the last edit.
    _autosave?.cancel();
    if (_dirty) unawaited(_persist());
    super.dispose();
  }

  /// Writes the roster in the background, debounced.
  ///
  /// **A draft is not saved until it is worth saving.** Opening the builder
  /// and backing out immediately should not leave an empty "New army" in the
  /// list, so nothing is written until the roster has something in it.
  void _scheduleAutosave() {
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 700), () {
      if (mounted) unawaited(_persist());
    });
  }

  bool get _worthSaving =>
      _roster.units.isNotEmpty || _roster.detachments.isNotEmpty;

  Future<void> _persist() async {
    if (_dataset == null || !_worthSaving) return;
    try {
      final builder = await widget.datasets.snapshotBuilder(_roster.factionId);
      final id =
          _id ??= 'r${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
      await widget.store
          .save(Army.fromSnapshot(_roster, builder.build(_roster), id: id));
      if (mounted) setState(() => _dirty = false);
    } catch (_) {
      // Left dirty on purpose: a failed background write must not report
      // success, and the explicit Save surfaces the error properly.
    }
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
    _scheduleAutosave();
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
    _scheduleAutosave();
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      _roster = _history.removeLast();
      _dirty = true;
    });
    _scheduleAutosave();
  }

  Future<void> _save() async {
    final dataset = _dataset;
    if (dataset == null) return;
    // A pending autosave would otherwise land after this one and re-save a
    // roster the screen has already finished with.
    _autosave?.cancel();
    setState(() => _saving = true);
    try {
      final builder = await widget.datasets.snapshotBuilder(_roster.factionId);
      // The same id the autosave used, or this becomes a second copy of the
      // army beside the one already written.
      final id =
          _id ??= 'r${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
      final army = Army.fromSnapshot(_roster, builder.build(_roster), id: id);
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

    // No discard prompt any more: edits are written as they are made, so
    // leaving keeps them. Asking "discard changes?" about work that is
    // already saved would be a lie, and the answer people give under time
    // pressure is the one that loses the army.
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (_, __) {},
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
        // What the detachment actually buys, readable without leaving the
        // builder. Folded, because it is reference rather than a decision —
        // the decision is the picker directly above.
        _DetachmentBrief(roster: _roster, dataset: dataset),
        const _SectionHeader('UNITS'),
        if (_roster.units.isEmpty)
          const _Note(text: 'No units yet. Add one to get started.')
        else
          // Grouped by the same roles as the picker, so the army reads back
          // in the order it was built. A combat unit is filed under the
          // character that leads it when there is one — that is the entry you
          // go looking for, and the squad is not separately in the list.
          for (final role in SourceUnit.roleOrder)
            if (_byRole(dataset)[role] case final groups?)
              CollapsibleGroup(
                title: role.toUpperCase(),
                trailing: '${groups.length}',
                initiallyOpen: true,
                child: Column(
                  children: [
                    for (final group in groups)
                      _UnitRow(
                        group: group,
                        dataset: dataset,
                        roster: _roster,
                        cost: cost,
                        onTap: () => _editUnit(group.first.instanceId),
                        onDuplicate: () => _edit((e) =>
                            e.duplicateUnit(_roster, group.first.instanceId)),
                      ),
                  ],
                ),
              ),
      ],
    );
  }

  /// Combat units by role, filed under whichever member carries the heading
  /// that sorts earliest — a Commander leading a squad is a Character, not
  /// Infantry, because the Commander is what you look for.
  Map<String, List<List<RosterUnit>>> _byRole(Dataset dataset) {
    final out = <String, List<List<RosterUnit>>>{};
    for (final group in _roster.combatUnits()) {
      var best = SourceUnit.roleOrder.length;
      for (final member in group) {
        final role = dataset.unit(member.datasheetId)?.battlefieldRole;
        final rank = SourceUnit.roleOrder.indexOf(role ?? 'Other');
        if (rank >= 0 && rank < best) best = rank;
      }
      final role = best < SourceUnit.roleOrder.length
          ? SourceUnit.roleOrder[best]
          : 'Other';
      (out[role] ??= []).add(group);
    }
    return out;
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

    // Which member of the combat unit the sheet is showing. A row in the list
    // is a *group* — a character and the squad it joined — and opening it went
    // straight to `group.first`, which is the character. The squad was then
    // unreachable: its loadout, its size and its removal were all behind a row
    // that only ever opened the leader (§7.3.9).
    var editing = instanceId;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      // The sheet rebuilds in place rather than being closed and reopened.
      // Reopening replayed the modal's slide-up on every single tap of a
      // counter, so changing a loadout looked like the page reloading from the
      // bottom of the screen each time.
      builder: (_) => StatefulBuilder(
        builder: (_, redrawSheet) {
          // Read fresh: attaching or detaching from inside the sheet changes
          // who is in the group.
          final group = _roster
              .combatUnits()
              .firstWhere(
                (g) => g.any((u) => u.instanceId == editing),
                orElse: () => const [],
              )
              .map((u) => u.instanceId)
              .toList();

          return UnitEditorSheet(
            dataset: dataset,
            roster: _roster,
            instanceId: editing,
            // Only when there is a choice to make; a lone datasheet needs no
            // switcher above it.
            groupInstanceIds: group.length > 1 ? group : const [],
            onSelect: (next) => redrawSheet(() => editing = next),
            onEdit: (change) {
              _edit(change);
              // `_roster` is read fresh on each rebuild, so redrawing the
              // sheet is enough to bring the new counts across.
              redrawSheet(() {});
            },
            onRemove: () {
              _edit((e) => e.removeUnit(_roster, editing));
              Navigator.of(context).pop();
            },
          );
        },
      ),
    );
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
          _NameField(value: roster.name, onChanged: onName),
          const SizedBox(height: 10),
          // A unit belongs to its faction, so the choice is only offered while
          // the roster is empty — silently rewriting a built list would be
          // worse than refusing.
          DropdownButtonFormField<String>(
            initialValue: factions.any((f) => f.id == roster.factionId)
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

/// The rules and stratagems the chosen detachments bring, folded away.
///
/// Choosing a detachment is the second-biggest decision in the list after the
/// faction, and until now it was made from a name and a points cost. The two
/// things it actually buys were a screen away, in a tab that only opens once
/// a battle is set up.
///
/// **Reference, not a control.** Nothing here is editable and nothing here is
/// validated; it exists so the choice above can be made with its consequences
/// in view. Both groups start folded — a builder that opens on two walls of
/// rules text has buried the units.
class _DetachmentBrief extends StatelessWidget {
  final Roster roster;
  final Dataset dataset;

  const _DetachmentBrief({required this.roster, required this.dataset});

  @override
  Widget build(BuildContext context) {
    if (roster.detachments.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    const renderer = RulesRenderer();

    final rules = <(String, String, String)>[];
    for (final taken in roster.detachments) {
      final detachment = dataset.detachment(taken.detachmentId);
      if (detachment == null) continue;
      final ruleId = detachment.detachmentRuleId;
      final ability = ruleId == null ? null : dataset.ability(ruleId);
      if (ability == null) continue;
      rules.add((ability.name, detachment.name, renderer.render(ability).text));
    }

    // The detachment's own, not the core ones: those are always available and
    // say nothing about this choice.
    final book = StratagemBook.forRoster(
      roster,
      all: dataset.faction.stratagems,
      catalogue: dataset,
    );
    final stratagems = [
      for (final s in book.stratagems)
        if (s.detachmentId != null) s,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rules.isNotEmpty)
          CollapsibleGroup(
            title: 'DETACHMENT RULES',
            trailing: '${rules.length}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (name, source, body) in rules)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: Text(name,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 8),
                            Text(source,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant)),
                          ],
                        ),
                        if (body.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          RuleText(body, style: const TextStyle(fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (stratagems.isNotEmpty)
          CollapsibleGroup(
            title: 'DETACHMENT STRATAGEMS',
            trailing: '${stratagems.length}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final stratagem in stratagems)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: Text(stratagem.displayName,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 8),
                            Text('${stratagem.cpCost} CP',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant)),
                          ],
                        ),
                        // Which detachment brings it. Both are listed here at
                        // once, and nine stratagems in one fold read as one
                        // pool unless each says where it came from.
                        if (stratagem.detachmentId case final id?)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SourcePill(
                                  dataset.detachment(id)?.name ?? id),
                            ),
                          ),
                        if (stratagem.text case final text?
                            when text.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          RuleText(text, style: const TextStyle(fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
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
    final all = dataset.buildableDetachments.toList()
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
  final VoidCallback onDuplicate;

  const _UnitRow({
    required this.group,
    required this.dataset,
    required this.roster,
    required this.cost,
    required this.onTap,
    required this.onDuplicate,
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
      // Three of the same squad is an ordinary list, and the duplicate
      // buried in the unit sheet meant four taps to say so.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$points',
              style: AppTheme.numeric(context, size: 14)
                  .copyWith(fontWeight: FontWeight.w700)),
          IconButton(
            onPressed: onDuplicate,
            tooltip: 'Duplicate',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_all_outlined, size: 18),
          ),
        ],
      ),
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

/// The army name, with the default placed so it does not have to be deleted.
///
/// A new army arrives called "New army", which is a prompt rather than a
/// name — but it is real text in a real field, so renaming meant putting the
/// cursor at the end and holding backspace nine times. Focusing selects it,
/// so the first keystroke replaces it, which is what a placeholder should
/// have done.
///
/// **Only while it is still the default.** Once the army has a name of its
/// own, focusing to fix one letter must not select the lot — that would turn
/// a small edit into a retype, which is the same annoyance the other way
/// round.
class _NameField extends StatefulWidget {
  final String value;
  final void Function(String) onChanged;

  const _NameField({required this.value, required this.onChanged});

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  static const _default = 'New army';

  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus && _controller.text == _default) {
        _controller.selection =
            TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        focusNode: _focus,
        decoration: const InputDecoration(
          labelText: 'Army name',
          isDense: true,
        ),
        onChanged: widget.onChanged,
      );
}

/// One datasheet in the picker.
///
/// **Every keyword, not the first two.** The subtitle used to take two, which
/// silently dropped the rest — a Canoness reads `Infantry · Character` and
/// stops, so GRENADES looks absent when it is on the datasheet. Keywords are
/// how a player checks a unit is what they think it is, and a truncated list
/// is worse than none because it looks complete.
class _DatasheetTile extends StatelessWidget {
  final SourceUnit unit;
  final VoidCallback onTap;

  const _DatasheetTile({required this.unit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cheapest = unit.points
        .map((b) => b.cost)
        .fold<int?>(null, (a, b) => a == null || b < a ? b : a);

    return ListTile(
      dense: true,
      onTap: onTap,
      title: Text(unit.name,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(
        [
          if (unit.isLeader) 'Leader',
          ...unit.keywords,
        ].join(' · '),
        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      ),
      trailing: Text(cheapest == null ? '—' : 'from $cheapest',
          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
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
    // Buildable, not all: Combat Patrol datasheets cost nothing and shadow
    // the real ones by name (§4.6).
    final units = widget.dataset.buildableUnits
        .where((u) => needle.isEmpty || u.name.toLowerCase().contains(needle))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    // Grouped by role: a faction is fifty datasheets and Adeptus Astartes is
    // 194, which is not a list anybody reads to the end.
    final grouped = <String, List<SourceUnit>>{};
    for (final unit in units) {
      (grouped[unit.battlefieldRole] ??= []).add(unit);
    }

    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHeader(title: 'Add unit'),
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
              child: ListView(
                shrinkWrap: true,
                children: [
                  // Searching flattens the groups. A search result behind a
                  // fold reads as no result, and headings earn their place by
                  // making a long list navigable — which is the problem
                  // searching has already solved.
                  if (needle.isNotEmpty)
                    for (final unit in units)
                      _DatasheetTile(
                        unit: unit,
                        onTap: () => Navigator.of(context).pop(unit.id),
                      )
                  else
                    for (final role in SourceUnit.roleOrder)
                      if (grouped[role] case final inRole?)
                        CollapsibleGroup(
                          title: role.toUpperCase(),
                          trailing: '${inRole.length}',
                          initiallyOpen: grouped.length == 1,
                          child: Column(
                            children: [
                              for (final unit in inRole)
                                _DatasheetTile(
                                  unit: unit,
                                  onTap: () =>
                                      Navigator.of(context).pop(unit.id),
                                ),
                            ],
                          ),
                        ),
                  if (units.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Nothing matches “$_query”.',
                          style: TextStyle(
                              fontSize: 12.5, color: scheme.onSurfaceVariant)),
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
