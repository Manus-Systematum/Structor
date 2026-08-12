import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:wh40k_core/wh40k_core.dart';

/// A roster plus everything needed to render it.
///
/// Content comes from the roster's **snapshot**, not from a faction dataset.
/// That is the same path an imported or QR-scanned list takes (DESIGN.md §6.4),
/// so the offline case is the default case rather than a fallback bolted on
/// later.
class Army {
  final Roster roster;
  final RosterSnapshot snapshot;
  final Catalogue catalogue;
  final ValidationResult validation;

  Army._({
    required this.roster,
    required this.snapshot,
    required this.catalogue,
    required this.validation,
  });

  factory Army.fromSnapshot(Roster roster, RosterSnapshot snapshot) {
    final catalogue = MapCatalogue(
      snapshot.units.values.map(SourceUnit.fromJson),
      weapons: snapshot.weapons.values.map(SourceWeapon.fromJson),
      detachments: snapshot.detachments.values.map(SourceDetachment.fromJson),
    );
    return Army._(
      roster: roster,
      snapshot: snapshot,
      catalogue: catalogue,
      validation: RosterValidator(catalogue).validate(roster),
    );
  }

  static Future<Army> loadReference() async {
    final rosterJson = await rootBundle.loadString('assets/reference_roster.json');
    final snapshotJson =
        await rootBundle.loadString('assets/reference_snapshot.json');
    return Army.fromSnapshot(
      Roster.fromJson(jsonDecode(rosterJson)),
      RosterSnapshot.fromJson(jsonDecode(snapshotJson)),
    );
  }

  BattleSize? get battleSize => BattleSize.byId(roster.battleSizeId);

  int get points => validation.cost.total;

  int get pointsLimit =>
      roster.pointsLimitOverride ?? battleSize?.points ?? points;

  /// Combat units — a leader and the unit it joined are one entry (§2.2).
  List<CombatUnit> get combatUnits => [
        for (final group in roster.combatUnits())
          CombatUnit(group: group, army: this),
      ];

  /// Abilities carried by a unit, rendered to English (§7.3.6). Abilities are
  /// only present when the snapshot captured them.
  List<RenderedRule> rulesFor(RosterUnit unit) {
    const renderer = RulesRenderer();
    final datasheet = catalogue.unit(unit.datasheetId);
    if (datasheet == null) return const [];

    final rules = <RenderedRule>[];
    for (final abilityId in datasheet.abilityIds) {
      final raw = snapshot.abilities[abilityId];
      if (raw == null) continue;
      rules.add(renderer.render(SourceAbility.fromJson(raw)));
    }
    return rules;
  }

  String detachmentName(String id) => catalogue.detachment(id)?.name ?? id;
}

/// A leader and its bodyguard presented as the single unit they fight as.
class CombatUnit {
  final List<RosterUnit> group;
  final Army army;

  const CombatUnit({required this.group, required this.army});

  RosterUnit get head => group.first;

  String get label =>
      head.customName ??
      group
          .map((u) => army.catalogue.unit(u.datasheetId)?.name ?? u.datasheetId)
          .join(' + ');

  int get points => army.validation.cost.units
      .where((c) => group.any((u) => u.instanceId == c.instanceId))
      .fold(0, (sum, c) => sum + c.total);

  int get models => group.fold(0, (sum, u) => sum + u.models);

  /// Distinct model profiles across the group. Divergent statlines within one
  /// attached unit are the norm, not an edge case (§7.3.6).
  List<({String name, ModelProfile profile})> get profiles {
    final seen = <String>{};
    final out = <({String name, ModelProfile profile})>[];
    for (final unit in group) {
      final datasheet = army.catalogue.unit(unit.datasheetId);
      if (datasheet == null) continue;
      for (final profile in datasheet.profiles) {
        if (seen.add(profile.statKey)) {
          out.add((name: profile.name, profile: profile));
        }
      }
    }
    return out;
  }

  AggregationResult weapons(WeaponKind kind) =>
      WeaponAggregator(army.catalogue).aggregate(group, kind: kind);

  List<RenderedRule> get rules {
    final seen = <String>{};
    final out = <RenderedRule>[];
    for (final unit in group) {
      for (final rule in army.rulesFor(unit)) {
        if (seen.add(rule.abilityId)) out.add(rule);
      }
    }
    return out;
  }
}
