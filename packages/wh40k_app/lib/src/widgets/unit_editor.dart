import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../theme.dart';
import 'sheet_header.dart';

/// Editing one unit: size, loadout, who it joins, what it carries.
///
/// The wargear list is the datasheet's **own vocabulary** — its weapons plus
/// whatever its budgets allow — and every item is a counter rather than a
/// gated option. `wargear-options` comes in three shapes across 87 records and
/// is demonstrably incomplete (§3.8), so enforcing it would refuse legal
/// lists. The validator says what is wrong instead.
class UnitEditorSheet extends StatelessWidget {
  final Dataset dataset;
  final Roster roster;
  final String instanceId;

  /// Applies an edit and reopens, so counts on screen match the roster.
  final void Function(Roster Function(RosterEditor)) onEdit;
  final VoidCallback onRemove;

  const UnitEditorSheet({
    super.key,
    required this.dataset,
    required this.roster,
    required this.instanceId,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unit = roster.unitByInstance(instanceId);
    final datasheet =
        unit == null ? null : dataset.unit(unit.datasheetId);
    if (unit == null || datasheet == null) {
      return const SizedBox(height: 120);
    }

    final cost = PointsCalculator(dataset).price(roster);
    final points = cost.units
        .where((c) => c.instanceId == instanceId)
        .fold(0, (sum, c) => sum + c.total);

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          SheetHeader(
            title: datasheet.name,
            trailing: Text('$points pts',
                style: AppTheme.numeric(context, size: 15)
                    .copyWith(fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(datasheet.keywords.join(' · '),
                style:
                    TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ),

          _Row(
            label: 'Models',
            child: _Counter(
              value: unit.models,
              onChange: (n) =>
                  onEdit((e) => e.setModels(roster, instanceId, n)),
            ),
          ),

          const _Heading('WARGEAR'),
          for (final item in _wargearOptions(datasheet))
            _Row(
              label: item.name,
              detail: item.cost > 0 ? '${item.cost} pts each' : null,
              child: _Counter(
                value: unit.countOf(item.id),
                min: 0,
                onChange: (n) =>
                    onEdit((e) => e.setWargear(roster, instanceId, item.id, n)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () =>
                      onEdit((e) => e.resetWargear(roster, instanceId)),
                  icon: const Icon(Icons.restart_alt, size: 17),
                  label: const Text('Default loadout'),
                ),
              ],
            ),
          ),

          if (datasheet.isLeader) ...[
            const _Heading('LEADS'),
            _AttachPicker(
              dataset: dataset,
              roster: roster,
              instanceId: instanceId,
              onEdit: onEdit,
            ),
          ],

          if (datasheet.isCharacter) ...[
            const _Heading('ENHANCEMENT'),
            _EnhancementPicker(
              dataset: dataset,
              roster: roster,
              instanceId: instanceId,
              onEdit: onEdit,
            ),
          ],

          const _Heading('ARMY'),
          SwitchListTile(
            dense: true,
            title: const Text('Warlord', style: TextStyle(fontSize: 13)),
            subtitle: Text(
              datasheet.isCharacter
                  ? 'One per army'
                  : 'The Warlord must be a Character',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            value: roster.warlordInstanceId == instanceId,
            onChanged: (on) => onEdit(
                (e) => e.setWarlord(roster, on ? instanceId : null)),
          ),
          ListTile(
            dense: true,
            leading: Icon(Icons.copy_all_outlined, color: scheme.primary),
            title: const Text('Duplicate', style: TextStyle(fontSize: 13)),
            onTap: () {
              onEdit((e) => e.duplicateUnit(roster, instanceId));
            },
          ),
          ListTile(
            dense: true,
            leading: Icon(Icons.delete_outline, color: scheme.error),
            title: Text('Remove from army',
                style: TextStyle(fontSize: 13, color: scheme.error)),
            onTap: onRemove,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// What this datasheet can carry: its own weapons, plus its budgeted items
  /// (drones and support systems), priced where the datasheet prices them.
  List<({String id, String name, int cost})> _wargearOptions(
      SourceUnit datasheet) {
    final out = <String, ({String id, String name, int cost})>{};

    for (final weaponId in datasheet.weaponIds) {
      final weapon = dataset.weapon(weaponId);
      final suffix = '-${datasheet.id}';
      final itemId = weaponId.endsWith(suffix)
          ? weaponId.substring(0, weaponId.length - suffix.length)
          : weaponId;
      out[itemId] = (
        id: itemId,
        name: weapon?.name ?? itemId.replaceAll('-', ' '),
        cost: datasheet.costOfWargear(itemId),
      );
    }

    // Drones are wargear whose rules are abilities (§7.3.7), so they are not
    // in weaponIds and have to come from the budgets.
    for (final budget in datasheet.wargearBudgets) {
      for (final itemId in budget.items) {
        if (out.containsKey(itemId)) continue;
        out[itemId] = (
          id: itemId,
          name: dataset.ability(itemId)?.name ?? itemId.replaceAll('-', ' '),
          cost: datasheet.costOfWargear(itemId),
        );
      }
    }

    final list = out.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }
}

class _AttachPicker extends StatelessWidget {
  final Dataset dataset;
  final Roster roster;
  final String instanceId;
  final void Function(Roster Function(RosterEditor)) onEdit;

  const _AttachPicker({
    required this.dataset,
    required this.roster,
    required this.instanceId,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final editor = RosterEditor(dataset);
    final options = editor.eligibleBodyguards(roster, instanceId);
    final current = roster.links
        .where((l) =>
            l.type == LinkType.leads && l.fromInstanceId == instanceId)
        .map((l) => l.toInstanceId)
        .firstOrNull;

    if (options.isEmpty && current == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text(
          'Nothing in this army may be led by it. The dataset publishes the '
          'attachment rule, so an absent one is a gap upstream rather than a '
          'rule against it.',
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      );
    }

    return RadioGroup<String?>(
      groupValue: current,
      onChanged: (id) => onEdit((e) => id == null
          ? e.detach(roster, instanceId)
          : e.attach(roster, instanceId, id)),
      child: Column(
        children: [
          const RadioListTile<String?>(
            dense: true,
            value: null,
            title: Text('Not attached', style: TextStyle(fontSize: 13)),
          ),
          for (final option in options)
            RadioListTile<String?>(
              dense: true,
              value: option.instanceId,
              title: Text(
                dataset.unit(option.datasheetId)?.name ?? option.datasheetId,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          // The unit it already leads is not in `options` — that list is what
          // is still free — so it is added back or the selection would vanish.
          if (current != null && !options.any((o) => o.instanceId == current))
            RadioListTile<String?>(
              dense: true,
              value: current,
              title: Text(
                dataset
                        .unit(roster.unitByInstance(current)?.datasheetId ?? '')
                        ?.name ??
                    current,
                style: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

class _EnhancementPicker extends StatelessWidget {
  final Dataset dataset;
  final Roster roster;
  final String instanceId;
  final void Function(Roster Function(RosterEditor)) onEdit;

  const _EnhancementPicker({
    required this.dataset,
    required this.roster,
    required this.instanceId,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final taken = {for (final d in roster.detachments) d.detachmentId};
    final offered = [
      for (final enhancement in dataset.enhancements)
        if (enhancement.detachmentId == null ||
            taken.contains(enhancement.detachmentId))
          enhancement,
    ]..sort((a, b) => a.name.compareTo(b.name));

    if (offered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text('Add a detachment to unlock its enhancements.',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
      );
    }

    final mine = roster.enhancements
        .where((e) => e.targetInstanceId == instanceId)
        .map((e) => e.enhancementId)
        .firstOrNull;
    // One bearer per enhancement, so one already on somebody else is shown as
    // taken rather than silently stolen.
    final elsewhere = {
      for (final e in roster.enhancements)
        if (e.targetInstanceId != instanceId) e.enhancementId,
    };

    return RadioGroup<String?>(
      groupValue: mine,
      onChanged: (id) => onEdit((e) => id == null
          ? (mine == null ? roster : e.setEnhancement(roster, mine, null))
          : e.setEnhancement(roster, id, instanceId)),
      child: Column(
        children: [
          const RadioListTile<String?>(
            dense: true,
            value: null,
            title: Text('None', style: TextStyle(fontSize: 13)),
          ),
          for (final enhancement in offered)
            RadioListTile<String?>(
              dense: true,
              value: enhancement.id,
              // One bearer per enhancement, so one already on somebody else is
              // shown as taken rather than silently stolen.
              enabled: !elsewhere.contains(enhancement.id),
              title:
                  Text(enhancement.name, style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                [
                  '${enhancement.cost} pts',
                  if (enhancement.isUpgrade) 'Unit Upgrade' else 'Enhancement',
                  if (elsewhere.contains(enhancement.id)) 'on another unit',
                ].join(' · '),
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String? detail;
  final Widget child;

  const _Row({required this.label, required this.child, this.detail});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 3, 12, 3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13)),
                if (detail != null)
                  Text(detail!,
                      style: TextStyle(
                          fontSize: 10.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final int value;
  final int min;
  final void Function(int) onChange;

  const _Counter({
    required this.value,
    required this.onChange,
    this.min = 1,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value <= min ? null : () => onChange(value - 1),
            icon: const Icon(Icons.remove, size: 18),
          ),
          SizedBox(
            width: 24,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: AppTheme.numeric(context, size: 14)
                    .copyWith(fontWeight: FontWeight.w700)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onChange(value + 1),
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      );
}

class _Heading extends StatelessWidget {
  final String label;

  const _Heading(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
        child: Text(label,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            )),
      );
}
