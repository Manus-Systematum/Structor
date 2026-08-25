import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../data/enhancement_offers.dart';
import '../theme.dart';
import 'sheet_header.dart';
import 'unit_profiles.dart';

/// Editing one unit: size, loadout, who it joins, what it carries.
///
/// The builder is still permissive (§2.3) — nothing here refuses an edit, and
/// the validator remains the thing that says a list is wrong. What changed is
/// that permissive was being read as shapeless: every item was an independent
/// counter, so the sheet offered to remove weapons no rule lets you remove,
/// asked for three separate numbers where the datasheet asks one question, and
/// let a "replace A with B" choice leave you holding both.
///
/// [UnitLoadout] sorts the published options by how far they can be trusted,
/// and the sheet renders each kind as the control that matches it (§4.5):
///
///   * **fixed** items are stated, not offered — a line of text with no
///     counter, because there is no legal list without them;
///   * **groups** are one row of choices, so *up to two drones, of different
///     kinds* is one tap rather than three counters and a rule to remember;
///   * **everything else** stays a counter, with any published limit shown
///     beside it and a swap wired to whatever it replaces.
class UnitEditorSheet extends StatelessWidget {
  final Dataset dataset;
  final Roster roster;
  final String instanceId;

  /// Applies an edit. The sheet rebuilds in place, so counts update without
  /// the modal being torn down and re-presented.
  final void Function(Roster Function(RosterEditor)) onEdit;
  final VoidCallback onRemove;

  /// The whole combat unit this datasheet belongs to, when it is part of one.
  ///
  /// A character and the squad it joined are one row in the army list, and the
  /// row opens the character. Without a way across, the squad's loadout and
  /// its size were unreachable from the builder entirely.
  final List<String> groupInstanceIds;

  /// Switches which member the sheet is editing.
  final void Function(String instanceId)? onSelect;

  const UnitEditorSheet({
    super.key,
    required this.dataset,
    required this.roster,
    required this.instanceId,
    required this.onEdit,
    required this.onRemove,
    this.groupInstanceIds = const [],
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unit = roster.unitByInstance(instanceId);
    final datasheet = unit == null ? null : dataset.unit(unit.datasheetId);
    if (unit == null || datasheet == null) {
      return const SizedBox(height: 120);
    }

    final cost = PointsCalculator(dataset).price(roster);
    final points = cost.units
        .where((c) => c.instanceId == instanceId)
        .fold(0, (sum, c) => sum + c.total);

    final loadout = UnitLoadout.forDatasheet(
      datasheet,
      catalogue: dataset,
      vocabulary: datasheet.wargearVocabulary,
    );
    final carried = {
      for (final item in unit.wargear) item.itemId: item.count,
    };
    final maxModels = RosterEditor(dataset).maxModels(datasheet.id);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // **Pinned.** The name and the running cost are what you are
          // watching while you spend points, and they were the first thing to
          // scroll away — by the time the wargear is on screen the number it
          // is changing is not.
          SheetHeader(
            title: datasheet.name,
            trailing: Text('$points pts',
                style: AppTheme.numeric(context, size: 15)
                    .copyWith(fontWeight: FontWeight.w700)),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (groupInstanceIds.length > 1 && onSelect != null)
                  _GroupSwitcher(
                    dataset: dataset,
                    roster: roster,
                    instanceIds: groupInstanceIds,
                    current: instanceId,
                    onSelect: onSelect!,
                  ),

                // The statline sits under the name rather than behind a tap: it is
                // the thing you check while deciding what to buy (§4.5).
                UnitStatline.of(datasheet),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                  child: Text(datasheet.keywords.join(' · '),
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant)),
                ),

                _Row(
                  label: 'Models',
                  // The one counter that *is* capped. A unit grown past every
                  // published bracket priced at zero — there was no bracket to
                  // price it — so the builder let you make a unit that silently
                  // cost nothing. Unlike wargear, the size is stated twice over
                  // (composition and points table) and the looser of the two is
                  // taken, so the cap only ever refuses what neither supports.
                  detail: maxModels == null || maxModels == unit.models
                      ? null
                      : 'max $maxModels',
                  child: _Counter(
                    value: unit.models,
                    max: maxModels,
                    onChange: (n) =>
                        onEdit((e) => e.setModels(roster, instanceId, n)),
                  ),
                ),

                _Heading('WARGEAR',
                    trailing:
                        loadout.isUnpublished ? 'no options published' : null),

                for (final entry in loadout.fixed.entries)
                  _FixedRow(
                    label: _nameOf(entry.key, datasheet),
                    // What the unit carries, not what the datasheet's smallest legal
                    // form carries. Resizing scales the default kit now, so a
                    // four-model unit showed "×3" beside a weapon table listing four.
                    count: carried[entry.key] ?? entry.value,
                  ),

                for (final group in loadout.groups)
                  _GroupRow(
                    group: group,
                    carried: carried,
                    nameOf: (id) => _nameOf(id, datasheet),
                    onSelect: (bundle, copies) =>
                        onEdit((e) => e.selectLoadoutBundle(
                              roster,
                              instanceId,
                              group,
                              bundle,
                              copies: copies,
                            )),
                    maxCopies: unit.models,
                  ),

                for (final counter in loadout.counters)
                  _Row(
                    label: _nameOf(counter.itemId, datasheet),
                    detail: _counterDetail(counter, datasheet),
                    child: _Counter(
                      value: carried[counter.itemId] ?? 0,
                      min: 0,
                      // A stated cap colours the control without disabling it: the
                      // reference list itself exceeds one, so this is information,
                      // not a gate.
                      overLimit: counter.statedMax != null &&
                          (carried[counter.itemId] ?? 0) > counter.statedMax!,
                      onChange: (n) => onEdit((e) => e.swapWargear(
                            roster,
                            instanceId,
                            counter.itemId,
                            n,
                            replaces: counter.replaces,
                          )),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
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

                CarriedWeaponProfiles(
                  dataset: dataset,
                  datasheet: datasheet,
                  carried: carried,
                ),

                if (datasheet.attachesToUnit) ...[
                  const _Heading('LEADS'),
                  _AttachPicker(
                    dataset: dataset,
                    roster: roster,
                    instanceId: instanceId,
                    onEdit: onEdit,
                  ),
                ]
                // Only where a leader could ever attach. Shown on everything that
                // is not itself a character, the heading appeared on Paragon
                // Warsuits and Rhinos to announce that no character may lead them —
                // a section whose whole content was its own emptiness.
                else if (dataset.canBeLed(datasheet.id)) ...[
                  const _Heading('LED BY'),
                  _LeaderPicker(
                    dataset: dataset,
                    roster: roster,
                    instanceId: instanceId,
                    onEdit: onEdit,
                  ),
                ],

                // **Not only Characters.** A Unit Upgrade is a separate
                // mechanic (§2.1) and names its own targets — Symphonic
                // Payload goes on an Exorcist, which is a tank. The section
                // was gated on `isCharacter`, so 428 datasheets across the
                // game could not be offered an upgrade they may legally take,
                // even though the picker inside already sorted the two out
                // (§4.7).
                if (datasheet.isCharacter ||
                    EnhancementOffers.any(dataset, roster, datasheet)) ...[
                  _Heading(
                      datasheet.isCharacter ? 'ENHANCEMENT' : 'UNIT UPGRADE'),
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
                    style:
                        TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                  value: roster.warlordInstanceId == instanceId,
                  // Refused rather than merely flagged. §2.3's permissiveness is
                  // about data the source states badly — wargear options are
                  // incomplete, so enforcing them would reject legal armies. This is
                  // not that: "the Warlord must be a Character" is a rule with no
                  // missing data behind it, and the keyword is on every datasheet
                  // that has it. Paragon Warsuits are a Vehicle, and offering the
                  // switch only to fail validation afterwards wastes the tap.
                  onChanged: datasheet.isCharacter
                      ? (on) => onEdit(
                          (e) => e.setWarlord(roster, on ? instanceId : null))
                      : null,
                ),
                // Duplicate and remove share a row: two rare actions were taking two
                // full-width tiles at the end of every unit.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => onEdit(
                              (e) => e.duplicateUnit(roster, instanceId)),
                          icon: const Icon(Icons.copy_all_outlined, size: 17),
                          label: const Text('Duplicate'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onRemove,
                          style: OutlinedButton.styleFrom(
                              foregroundColor: scheme.error),
                          icon: const Icon(Icons.delete_outline, size: 17),
                          label: const Text('Remove'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _nameOf(String itemId, SourceUnit datasheet) =>
      dataset.weaponFor(datasheet, itemId)?.name ??
      dataset.weapon(itemId)?.name ??
      dataset.ability(itemId)?.name ??
      itemId.replaceAll('-', ' ');

  String? _counterDetail(LoadoutCounter counter, SourceUnit datasheet) {
    final cost = datasheet.costOfWargear(counter.itemId);
    final parts = [
      if (cost > 0) '$cost pts each',
      if (counter.statedMax != null) 'up to ${counter.statedMax}',
      if (counter.perModels != null) '1 per ${counter.perModels} models',
      if (counter.replaces.isNotEmpty)
        'replaces ${counter.replaces.map((r) => _nameOf(r, datasheet)).join(', ')}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// A wargear choice the datasheet spells out: pick one bundle, or none.
class _GroupRow extends StatelessWidget {
  final LoadoutGroup group;
  final Map<String, int> carried;
  final String Function(String) nameOf;
  final void Function(List<String>? bundle, int copies) onSelect;

  /// How many models could take the swap. The datasheet's own limit — two per
  /// five, say — is not published, so this is the unit's size and the
  /// validator has nothing tighter to check against (§2.3).
  final int maxCopies;

  const _GroupRow({
    required this.group,
    required this.carried,
    required this.nameOf,
    required this.onSelect,
    required this.maxCopies,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final held = group.selection(carried);
    final selected = held?.index;
    final copies = held?.copies ?? 0;

    String label(List<String> bundle) {
      final tally = <String, int>{};
      for (final item in bundle) {
        tally[item] = (tally[item] ?? 0) + 1;
      }
      return [
        for (final e in tally.entries)
          e.value > 1 ? '${e.value}× ${nameOf(e.key)}' : nameOf(e.key),
      ].join(' + ');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group.modelName != null)
            Text(group.modelName!,
                style:
                    TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('None'),
                selected: selected == null &&
                    group.items.every((i) => (carried[i] ?? 0) == 0),
                onSelected: (_) => onSelect(null, 0),
              ),
              for (final (index, bundle) in group.bundles.indexed)
                ChoiceChip(
                  label: Text(label(bundle)),
                  selected: selected == index,
                  // Keep the count when switching between bundles: the number
                  // of models making the swap is a separate decision from
                  // which swap they make.
                  onSelected: (_) => onSelect(bundle, copies == 0 ? 1 : copies),
                ),
            ],
          ),
          // **How many models take it.** More than one may, and the row was
          // yes-or-no — so a Seraphim Squad could make one swap where the
          // datasheet allows several (§4.5).
          if (held case final held? when maxCopies > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Text('Models taking it',
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant)),
                  const Spacer(),
                  _Counter(
                    value: held.copies,
                    min: 0,
                    max: maxCopies,
                    onChange: (n) => n == 0
                        ? onSelect(null, 0)
                        : onSelect(group.bundles[held.index], n),
                  ),
                ],
              ),
            ),
          // An imported list can carry a combination the datasheet does not
          // offer. Saying so beats silently rewriting somebody's army.
          if (selected == null && group.items.any((i) => (carried[i] ?? 0) > 0))
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                'Carrying a combination this datasheet does not list.',
                style: TextStyle(fontSize: 10.5, color: scheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kit the unit cannot give up, stated rather than offered.
class _FixedRow extends StatelessWidget {
  final String label;
  final int count;

  const _FixedRow({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 3, 20, 3),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 13, color: scheme.outline),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          ),
          Text('×$count', style: AppTheme.numeric(context, size: 13)),
        ],
      ),
    );
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
        .where(
            (l) => l.type == LinkType.leads && l.fromInstanceId == instanceId)
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

    return _ChipPicker<String?>(
      value: current,
      entries: [
        (value: null, label: 'Not attached', note: null, dimmed: false),
        for (final option in options)
          (
            value: option.instanceId,
            label: dataset.unit(option.datasheetId)?.name ?? option.datasheetId,
            note: null,
            dimmed: false,
          ),
        // The unit it already leads is not in `options` — that list is what is
        // still free — so it is added back or the selection would vanish.
        if (current != null && !options.any((o) => o.instanceId == current))
          (
            value: current,
            label: dataset
                    .unit(roster.unitByInstance(current)?.datasheetId ?? '')
                    ?.name ??
                current,
            note: null,
            dimmed: false,
          ),
      ],
      onSelect: (id) => onEdit((e) => id == null
          ? e.detach(roster, instanceId)
          : e.attach(roster, instanceId, id)),
    );
  }
}

/// The same decision from the unit's side: which character leads it.
///
/// Every eligible character is listed, including ones already leading
/// something else — that is usually the one you meant, and attaching moves it
/// rather than refusing (§4.5).
class _LeaderPicker extends StatelessWidget {
  final Dataset dataset;
  final Roster roster;
  final String instanceId;
  final void Function(Roster Function(RosterEditor)) onEdit;

  const _LeaderPicker({
    required this.dataset,
    required this.roster,
    required this.instanceId,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final candidates =
        RosterEditor(dataset).eligibleLeaders(roster, instanceId);
    final current = roster.links
        .where((l) => l.type == LinkType.leads && l.toInstanceId == instanceId)
        .map((l) => l.fromInstanceId)
        .firstOrNull;

    if (candidates.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text(
          'No character in this army may lead it.',
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      );
    }

    String nameOf(String id) =>
        dataset.unit(roster.unitByInstance(id)?.datasheetId ?? '')?.name ?? id;

    return _ChipPicker<String?>(
      value: current,
      entries: [
        (value: null, label: 'Not led', note: null, dimmed: false),
        for (final candidate in candidates)
          (
            value: candidate.leader.instanceId,
            label: dataset.unit(candidate.leader.datasheetId)?.name ??
                candidate.leader.datasheetId,
            note: switch (candidate.leadingInstanceId) {
              null => null,
              final led when led == instanceId => null,
              final led => 'leads ${nameOf(led)}',
            },
            dimmed: candidate.leadingInstanceId != null &&
                candidate.leadingInstanceId != instanceId,
          ),
      ],
      onSelect: (id) => onEdit((e) => id == null
          ? (current == null ? roster : e.detach(roster, current))
          : e.attach(roster, id, instanceId)),
      footnote: candidates.any((c) =>
              c.leadingInstanceId != null && c.leadingInstanceId != instanceId)
          ? 'Choosing a character that already leads something moves it here.'
          : null,
    );
  }
}

/// A single-choice list rendered as chips.
///
/// Radio tiles cost a full row each; a Crisis-heavy army offers eight of them
/// and the sheet turned into a page of radio buttons. Chips wrap, so the same
/// choice fits in two or three lines and stays one tap (§4.5).
class _ChipPicker<T> extends StatelessWidget {
  final T value;
  final List<({T value, String label, String? note, bool dimmed})> entries;
  final void Function(T) onSelect;
  final String? footnote;

  const _ChipPicker({
    required this.value,
    required this.entries,
    required this.onSelect,
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final entry in entries)
                ChoiceChip(
                  selected: entry.value == value,
                  onSelected: (_) => onSelect(entry.value),
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.label,
                          style: TextStyle(
                            color: entry.dimmed
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
                          )),
                      if (entry.note != null)
                        Text(entry.note!,
                            style: TextStyle(
                                fontSize: 9.5, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
            ],
          ),
          if (footnote != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(footnote!,
                  style: TextStyle(
                      fontSize: 10.5, color: scheme.onSurfaceVariant)),
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
    final datasheet =
        dataset.unit(roster.unitByInstance(instanceId)?.datasheetId ?? '');
    final offered = EnhancementOffers.of(dataset, roster, datasheet);

    if (offered.isEmpty) {
      final none = datasheet != null && datasheet.isEpicHero
          ? 'An Epic Hero brings their own wargear and takes no enhancements.'
          : datasheet != null && !datasheet.isCharacter
              ? 'Enhancements go on Characters. Unit Upgrades that name this '
                  'datasheet would appear here.'
              : 'Add a detachment to unlock its enhancements.';
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text(none,
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

    return _ChipPicker<String?>(
      value: mine,
      entries: [
        (value: null, label: 'None', note: null, dimmed: false),
        for (final enhancement in offered)
          (
            value: enhancement.id,
            label: enhancement.name,
            note: [
              '${enhancement.cost} pts',
              if (elsewhere.contains(enhancement.id)) 'taken',
            ].join(' · '),
            dimmed: elsewhere.contains(enhancement.id),
          ),
      ],
      onSelect: (id) => onEdit((e) => id == null
          ? (mine == null ? roster : e.setEnhancement(roster, mine, null))
          : e.setEnhancement(roster, id, instanceId)),
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
      padding: const EdgeInsets.fromLTRB(20, 2, 12, 2),
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

  /// A ceiling the data actually states. Null leaves the counter open, which
  /// is right for wargear: §4.5 keeps a stated `max_count` as guidance rather
  /// than a stop, because the option data is demonstrably incomplete.
  final int? max;
  final bool overLimit;
  final void Function(int) onChange;

  const _Counter({
    required this.value,
    required this.onChange,
    this.min = 1,
    this.max,
    this.overLimit = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
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
              style: AppTheme.numeric(context, size: 14).copyWith(
                fontWeight: FontWeight.w700,
                color: overLimit ? scheme.error : scheme.onSurface,
              )),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed:
              max != null && value >= max! ? null : () => onChange(value + 1),
          icon: const Icon(Icons.add, size: 18),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  final String label;
  final String? trailing;

  const _Heading(this.label, {this.trailing});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              )),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(trailing!,
                  style: TextStyle(fontSize: 10, color: scheme.outline)),
            ),
          ],
        ],
      ),
    );
  }
}

/// The members of one combat unit, so the sheet can move between them.
///
/// A character and the squad it leads are one entry in the army list — that is
/// §7.3.9's decision and it is right for reading the list. It is wrong for
/// editing it, because there is only one row to tap and it opens the
/// character: the squad's own size and loadout had no route at all.
class _GroupSwitcher extends StatelessWidget {
  final Dataset dataset;
  final Roster roster;
  final List<String> instanceIds;
  final String current;
  final void Function(String instanceId) onSelect;

  const _GroupSwitcher({
    required this.dataset,
    required this.roster,
    required this.instanceIds,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THIS COMBAT UNIT',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in instanceIds)
                if (roster.unitByInstance(id) case final unit?)
                  if (dataset.unit(unit.datasheetId) case final sheet?)
                    ChoiceChip(
                      selected: id == current,
                      onSelected: (_) => onSelect(id),
                      visualDensity: VisualDensity.compact,
                      label: Text(sheet.name,
                          style: const TextStyle(fontSize: 12)),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
