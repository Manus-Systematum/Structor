/// Read-only content lookup used by pricing and validation.
///
/// Deliberately narrow. It is backed by source DTOs today; the normalised
/// domain model (DESIGN.md §2.1) can implement the same interface later
/// without touching the calculator or the validator.
library;

import '../source/dataset_loader.dart';
import '../source/source_models.dart';

abstract interface class Catalogue {
  SourceUnit? unit(String datasheetId);

  /// Every datasheet, for name-based lookup during import (DESIGN.md §6.1).
  Iterable<SourceUnit> get allUnits;

  /// Every detachment, for the same reason.
  Iterable<SourceDetachment> get allDetachments;

  SourceDetachment? detachment(String detachmentId);

  SourceWeapon? weapon(String weaponId);

  /// Datasheets [leaderDatasheetId] may join. Empty when the datasheet is not
  /// a leader, or when no attachment rule is published for it.
  List<String> eligibleBodyguards(String leaderDatasheetId);

  /// Resolves a roster wargear item to the weapon record **that unit** uses.
  ///
  /// Weapons are per-carrier: `missile-pod` is BS4+ on a Crisis suit while
  /// `missile-pod-commander-in-enforcer-battlesuit` is BS3+. Both names read
  /// "Missile pod" to the player, so resolution must be scoped to the unit's
  /// own `weapon_ids` or the shooting screen will report the wrong skill
  /// (DESIGN.md §7.3.5).
  SourceWeapon? weaponFor(SourceUnit unit, String itemId) {
    final scoped = '$itemId-${unit.id}';
    if (unit.weaponIds.contains(scoped)) return weapon(scoped);
    if (unit.weaponIds.contains(itemId)) return weapon(itemId);
    return null;
  }
}

class MapCatalogue implements Catalogue {
  final Map<String, SourceUnit> _units;
  final Map<String, SourceDetachment> _detachments;
  final Map<String, SourceWeapon> _weapons;
  final Map<String, List<String>> _attachments;

  MapCatalogue(
    Iterable<SourceUnit> units, {
    Iterable<SourceDetachment> detachments = const [],
    Iterable<SourceWeapon> weapons = const [],
    Iterable<LeaderAttachment> leaderAttachments = const [],
  })  : _units = {for (final u in units) u.id: u},
        _detachments = {for (final d in detachments) d.id: d},
        _weapons = {for (final w in weapons) w.id: w},
        _attachments = {
          for (final a in leaderAttachments) a.leaderId: a.eligibleBodyguardIds,
        };

  /// Builds a catalogue over a loaded faction snapshot.
  factory MapCatalogue.ofFaction(FactionData faction) => MapCatalogue(
        faction.units,
        detachments: faction.detachments,
        weapons: faction.weapons,
        leaderAttachments: faction.leaderAttachments,
      );

  @override
  SourceUnit? unit(String datasheetId) => _units[datasheetId];

  @override
  Iterable<SourceUnit> get allUnits => _units.values;

  @override
  Iterable<SourceDetachment> get allDetachments => _detachments.values;

  @override
  SourceDetachment? detachment(String detachmentId) =>
      _detachments[detachmentId];

  @override
  SourceWeapon? weapon(String weaponId) => _weapons[weaponId];

  @override
  List<String> eligibleBodyguards(String leaderDatasheetId) =>
      _attachments[leaderDatasheetId] ?? const [];

  @override
  SourceWeapon? weaponFor(SourceUnit unit, String itemId) {
    final scoped = '$itemId-${unit.id}';
    if (unit.weaponIds.contains(scoped)) return weapon(scoped);
    if (unit.weaponIds.contains(itemId)) return weapon(itemId);
    return null;
  }
}
