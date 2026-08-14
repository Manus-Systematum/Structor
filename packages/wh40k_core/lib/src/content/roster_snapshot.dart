/// A self-contained copy of the content a roster references (DESIGN.md §2.2).
///
/// Two jobs, both of which the raw dataset cannot do:
///
///   - **Offline play.** The play screen must work with no network and no
///     downloaded faction, which means the roster carries its own datasheets.
///   - **Lists from strangers.** An imported or scanned list has to render even
///     when the receiver lacks the sender's catalogue, or worse, has a
///     different revision of it (§6.4).
///
/// A snapshot is deliberately *not* the whole faction — only what this roster
/// names, which for a 2,000 pt army is a small fraction of it.
library;

import '../roster/roster.dart';
import '../source/dataset_loader.dart';
import '../source/json.dart';
import 'dataset.dart';

class RosterSnapshot {
  final DatasetVersion version;

  /// Raw source records keyed by id, as loaded. Kept in source form on purpose:
  /// a snapshot's value is that it can be read by a build of the app whose
  /// domain model has since moved on.
  final Map<String, Object?> units;
  final Map<String, Object?> weapons;
  final Map<String, Object?> detachments;
  final Map<String, Object?> abilities;

  const RosterSnapshot({
    required this.version,
    required this.units,
    required this.weapons,
    required this.detachments,
    required this.abilities,
  });

  int get entryCount =>
      units.length + weapons.length + detachments.length + abilities.length;

  Map<String, Object?> toJson() => {
        'version': version.toJson(),
        'units': units,
        'weapons': weapons,
        'detachments': detachments,
        'abilities': abilities,
      };

  factory RosterSnapshot.fromJson(Object? v) {
    final j = asMap(v);
    return RosterSnapshot(
      version: DatasetVersion.fromJson(asMap(j['version'])),
      units: asMap(j['units']),
      weapons: asMap(j['weapons']),
      detachments: asMap(j['detachments']),
      abilities: asMap(j['abilities']),
    );
  }
}

/// Builds the transitive closure of content a roster references: its units,
/// their weapons and abilities, and its detachments.
class SnapshotBuilder {
  final Dataset dataset;

  /// Source records as loaded from disk, needed because [Dataset] holds parsed
  /// DTOs and a snapshot must preserve the original JSON.
  final Map<String, Object?> rawUnits;
  final Map<String, Object?> rawWeapons;
  final Map<String, Object?> rawDetachments;
  final Map<String, Object?> rawAbilities;

  const SnapshotBuilder({
    required this.dataset,
    this.rawUnits = const {},
    this.rawWeapons = const {},
    this.rawDetachments = const {},
    this.rawAbilities = const {},
  });

  /// Builds against a snapshot on disk, pulling the raw records the parsed
  /// [Dataset] does not retain.
  factory SnapshotBuilder.fromLoader(DatasetLoader loader, Dataset dataset) {
    final factionId = dataset.version.factionId;
    return SnapshotBuilder(
      dataset: dataset,
      rawUnits: loader.rawUnits(factionId),
      rawWeapons: loader.rawWeapons(factionId),
      rawDetachments: loader.rawDetachments(factionId),
      rawAbilities: loader.rawAbilities(factionId),
    );
  }

  RosterSnapshot build(Roster roster) {
    final units = <String, Object?>{};
    final weapons = <String, Object?>{};
    final detachments = <String, Object?>{};
    final abilities = <String, Object?>{};

    void takeAbility(String id) {
      final raw = rawAbilities[id];
      if (raw != null) abilities[id] = raw;
    }

    for (final entry in roster.detachments) {
      final raw = rawDetachments[entry.detachmentId];
      if (raw != null) detachments[entry.detachmentId] = raw;

      // A detachment's rule is an ability, and the play screen needs it.
      final ruleId = dataset.detachment(entry.detachmentId)?.detachmentRuleId;
      if (ruleId != null) takeAbility(ruleId);
    }

    for (final rosterUnit in roster.units) {
      final datasheet = dataset.unit(rosterUnit.datasheetId);
      if (datasheet == null) continue;

      final rawUnit = rawUnits[datasheet.id];
      if (rawUnit != null) units[datasheet.id] = rawUnit;

      for (final abilityId in datasheet.abilityIds) {
        takeAbility(abilityId);
      }

      // Only the weapons this unit actually carries, resolved through the
      // carrier so the scoped variant is captured rather than the generic one
      // (§7.3.5).
      for (final selection in rosterUnit.wargear) {
        var weapon = dataset.weaponFor(datasheet, selection.itemId);

        // Wargear that is an ability can still bring a gun: a Gun Drone is a
        // twin pulse carbine (§7.3.7). Missing it here leaves the shooting
        // table short a weapon on any list rebuilt from the snapshot alone,
        // which is the case the snapshot exists for.
        if (weapon == null) {
          final grantedId =
              dataset.ability(selection.itemId)?.grantedWeaponId;
          if (grantedId == null) continue;
          weapon = dataset.weaponFor(datasheet, grantedId) ??
              dataset.weapon(grantedId);
          if (weapon == null) continue;
        }

        final raw = rawWeapons[weapon.id];
        if (raw != null) weapons[weapon.id] = raw;
      }
    }

    return RosterSnapshot(
      version: dataset.version,
      units: units,
      weapons: weapons,
      detachments: detachments,
      abilities: abilities,
    );
  }
}
