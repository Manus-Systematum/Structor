/// Editing a roster (DESIGN.md §4, brief item 1).
///
/// Every operation returns a **new** [Roster]; nothing here mutates. That is
/// what makes undo, live validation and "show me the points before I commit"
/// all fall out of the same mechanism, and it matches how battle state already
/// works (§7.4).
///
/// **The editor is permissive and the validator is honest.** It will let you
/// build an illegal list and tell you exactly how it is illegal, rather than
/// refusing the tap. Two reasons, and the second is the real one:
///
///   - §2.3 already settled this for validation — findings with severity,
///     never a hard block.
///   - The wargear-option data is demonstrably incomplete. Six T'au datasheets
///     did not list the drones their units carry (§3.8), and `wargear-options`
///     comes in three different shapes across 87 records. An editor that
///     enforced it would refuse legal lists, and a builder that will not let
///     you enter the army standing on your table is worthless.
library;

import '../rules/battle_size.dart';
import '../rules/catalogue.dart';
import 'roster.dart';

class RosterEditor {
  final Catalogue catalogue;

  const RosterEditor(this.catalogue);

  /// A new, empty roster. The battle size sets the points limit and the
  /// detachment budget, so it is asked for up front rather than inferred.
  static Roster blank({
    required String name,
    required String factionId,
    BattleSize battleSize = BattleSize.strikeForce,
  }) =>
      Roster(
        name: name,
        factionId: factionId,
        battleSizeId: battleSize.id,
        units: const [],
      );

  // ------------------------------------------------------------------ units

  /// Adds [datasheetId] at its smallest legal size with its default loadout.
  ///
  /// "Every weapon on the datasheet" would be the wrong starting point — a
  /// Crisis suit lists nine and carries three — so this reads the composition
  /// where one exists and adds a bare unit where it does not.
  Roster addUnit(Roster roster, String datasheetId) {
    final composition = catalogue.composition(datasheetId);
    final datasheet = catalogue.unit(datasheetId);

    final models = composition?.defaultModels ??
        datasheet?.points
            .map((b) => b.models)
            .where((m) => m > 0)
            .fold<int?>(null, (a, b) => a == null || b < a ? b : a) ??
        1;

    final wargear = composition?.defaultWargear() ?? const <String, int>{};

    return _withUnits(roster, [
      ...roster.units,
      RosterUnit(
        instanceId: _nextInstanceId(roster),
        datasheetId: datasheetId,
        models: models,
        wargear: [
          for (final entry in wargear.entries)
            WargearSelection(itemId: entry.key, count: entry.value),
        ],
      ),
    ]);
  }

  /// Removes a unit, and anything that only made sense while it was there:
  /// its attachment links, its enhancement, and the Warlord nomination.
  Roster removeUnit(Roster roster, String instanceId) {
    final units = [
      for (final u in roster.units)
        if (u.instanceId != instanceId) u,
    ];
    return roster.copyWith(
      units: units,
      links: [
        for (final link in roster.links)
          if (link.fromInstanceId != instanceId &&
              link.toInstanceId != instanceId)
            link,
      ],
      enhancements: [
        for (final e in roster.enhancements)
          if (e.targetInstanceId != instanceId) e,
      ],
      upgrades: [
        for (final u in roster.upgrades)
          if (u.targetInstanceIds.contains(instanceId))
            UpgradeSelection(
              upgradeId: u.upgradeId,
              targetInstanceIds: [
                for (final id in u.targetInstanceIds)
                  if (id != instanceId) id,
              ],
            )
          else
            u,
      ].where((u) => u.targetInstanceIds.isNotEmpty).toList(),
      clearWarlordIf: roster.warlordInstanceId == instanceId,
    );
  }

  /// Duplicates a unit, loadout and all. Lists are full of second Broadsides.
  Roster duplicateUnit(Roster roster, String instanceId) {
    final source = _unit(roster, instanceId);
    if (source == null) return roster;
    return _withUnits(roster, [
      ...roster.units,
      RosterUnit(
        instanceId: _nextInstanceId(roster),
        datasheetId: source.datasheetId,
        models: source.models,
        wargear: [
          for (final w in source.wargear)
            WargearSelection(itemId: w.itemId, count: w.count),
        ],
      ),
    ]);
  }

  Roster setModels(Roster roster, String instanceId, int models) =>
      _mapUnit(roster, instanceId, (u) => u.copyWith(models: models.clamp(1, 30)));

  /// Sets how many of [itemId] the unit carries. Zero removes it.
  Roster setWargear(
    Roster roster,
    String instanceId,
    String itemId,
    int count,
  ) =>
      _mapUnit(roster, instanceId, (unit) {
        final kept = [
          for (final w in unit.wargear)
            if (w.itemId != itemId) w,
        ];
        return unit.copyWith(wargear: [
          ...kept,
          if (count > 0) WargearSelection(itemId: itemId, count: count),
        ]);
      });

  /// Restores the datasheet's default loadout, discarding what was chosen.
  Roster resetWargear(Roster roster, String instanceId) {
    final unit = _unit(roster, instanceId);
    final composition =
        unit == null ? null : catalogue.composition(unit.datasheetId);
    if (composition == null) return roster;
    return _mapUnit(roster, instanceId, (u) {
      // Scaled to the unit's current size, since the composition describes
      // its smallest legal form.
      final base = composition.defaultModels;
      final factor = base <= 0 ? 1 : (u.models / base);
      return u.copyWith(wargear: [
        for (final entry in composition.defaultWargear().entries)
          WargearSelection(
            itemId: entry.key,
            count: (entry.value * factor).round().clamp(1, 1 << 20),
          ),
      ]);
    });
  }

  // ------------------------------------------------------------ attachments

  /// Attaches a leader to a bodyguard, replacing any existing link on either.
  ///
  /// A character can lead one unit and a unit can be led by one character, so
  /// the old links go rather than accumulating into an illegal tangle the
  /// validator would then have to complain about.
  Roster attach(Roster roster, String leaderId, String bodyguardId) {
    if (leaderId == bodyguardId) return roster;
    return roster.copyWith(links: [
      for (final link in roster.links)
        if (link.type != LinkType.leads ||
            (link.fromInstanceId != leaderId &&
                link.toInstanceId != bodyguardId))
          link,
      RosterLink(
        type: LinkType.leads,
        fromInstanceId: leaderId,
        toInstanceId: bodyguardId,
      ),
    ]);
  }

  Roster detach(Roster roster, String instanceId) => roster.copyWith(links: [
        for (final link in roster.links)
          if (link.type != LinkType.leads ||
              (link.fromInstanceId != instanceId &&
                  link.toInstanceId != instanceId))
            link,
      ]);

  /// Units [leaderId] may join: the data's own attachment rule, minus units
  /// already led by someone else.
  List<RosterUnit> eligibleBodyguards(Roster roster, String leaderId) {
    final leader = _unit(roster, leaderId);
    if (leader == null) return const [];
    final allowed = catalogue.eligibleBodyguards(leader.datasheetId).toSet();
    final ledAlready = {
      for (final link in roster.links)
        if (link.type == LinkType.leads && link.fromInstanceId != leaderId)
          link.toInstanceId,
    };
    return [
      for (final unit in roster.units)
        if (unit.instanceId != leaderId &&
            allowed.contains(unit.datasheetId) &&
            !ledAlready.contains(unit.instanceId))
          unit,
    ];
  }

  // ------------------------------------------------------------ army-level

  Roster setWarlord(Roster roster, String? instanceId) => roster.copyWith(
        warlordInstanceId: instanceId,
        clearWarlordIf: instanceId == null,
      );

  Roster setName(Roster roster, String name) =>
      roster.copyWith(name: name.trim().isEmpty ? roster.name : name.trim());

  Roster setBattleSize(Roster roster, BattleSize size) =>
      roster.copyWith(battleSizeId: size.id);

  Roster setDisposition(Roster roster, String? disposition) =>
      roster.copyWith(declaredDisposition: disposition);

  Roster addDetachment(Roster roster, String detachmentId) {
    if (roster.detachments.any((d) => d.detachmentId == detachmentId)) {
      return roster;
    }
    return roster.copyWith(detachments: [
      ...roster.detachments,
      RosterDetachment(detachmentId: detachmentId),
    ]);
  }

  /// Removes a detachment, and the enhancements that came with it — an
  /// enhancement outliving its detachment is a points total that quietly
  /// stops adding up.
  Roster removeDetachment(Roster roster, String detachmentId) {
    final gone = catalogue.detachment(detachmentId)?.enhancementIds.toSet() ??
        const <String>{};
    return roster.copyWith(
      detachments: [
        for (final d in roster.detachments)
          if (d.detachmentId != detachmentId) d,
      ],
      enhancements: [
        for (final e in roster.enhancements)
          if (!gone.contains(e.enhancementId)) e,
      ],
      upgrades: [
        for (final u in roster.upgrades)
          if (!gone.contains(u.upgradeId)) u,
      ],
    );
  }

  // ----------------------------------------------------------- enhancements

  /// Puts [enhancementId] on a unit, or removes it when [instanceId] is null.
  /// One bearer per enhancement, so an existing assignment is replaced.
  Roster setEnhancement(
    Roster roster,
    String enhancementId,
    String? instanceId,
  ) =>
      roster.copyWith(enhancements: [
        for (final e in roster.enhancements)
          if (e.enhancementId != enhancementId) e,
        if (instanceId != null)
          EnhancementSelection(
            enhancementId: enhancementId,
            targetInstanceId: instanceId,
          ),
      ]);

  // --------------------------------------------------------------- helpers

  RosterUnit? _unit(Roster roster, String instanceId) {
    for (final unit in roster.units) {
      if (unit.instanceId == instanceId) return unit;
    }
    return null;
  }

  Roster _mapUnit(
    Roster roster,
    String instanceId,
    RosterUnit Function(RosterUnit) change,
  ) =>
      _withUnits(roster, [
        for (final unit in roster.units)
          if (unit.instanceId == instanceId) change(unit) else unit,
      ]);

  Roster _withUnits(Roster roster, List<RosterUnit> units) =>
      roster.copyWith(units: units);

  /// Instance ids are stable and never reused, so a link or an enhancement
  /// cannot silently re-target a different unit after a delete.
  String _nextInstanceId(Roster roster) {
    var highest = 0;
    for (final unit in roster.units) {
      final digits = RegExp(r'\d+').firstMatch(unit.instanceId)?.group(0);
      final n = int.tryParse(digits ?? '') ?? 0;
      if (n > highest) highest = n;
    }
    return 'u${(highest + 1).toString().padLeft(2, '0')}';
  }
}
